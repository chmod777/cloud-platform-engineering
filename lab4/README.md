# LAB 4 - Private Artifact Registry to OpenShift Developer Sandbox

[Architecture and results](../docs/lab-04-hybrid-openshift.md)

Run this guide from the repository root in a Bash terminal. These commands create
resources during a future authorized session. No deployment was performed while
writing this guide. Resources from the original session have been deleted.

## 1. Prerequisites and scope

- Docker with Buildx, Python 3, gcloud, Terraform >= 1.5, and an `oc` CLI compatible
  with the Sandbox; network access to the registry and HTTPS route.
- A gcloud session using the intended account and project, with ADC available
  to Terraform. Use `oc login` from the Sandbox console without copying its
  token-bearing command into Git or a report.
- Project `cloud-platform-engineering-hs`, region `europe-west9`, existing namespace
  `hassensiad06-dev`, and quota for two pods plus one surge pod.
- GCP permissions for the resources managed by Lab 3 `prepare` and for publishing
  (`roles/artifactregistry.writer` on the repository). The pull token needs read
  access (`roles/artifactregistry.reader` is sufficient). The steps below use
  the current gcloud identity: the token carries that identity's permissions.
  Prefer a dedicated reader identity through impersonation when available;
  this requires permission to generate tokens for that identity.
- OpenShift permissions to manage Deployments, Services, Routes, ServiceAccounts
  and Secrets in this namespace. No cluster administrator access or `anyuid` SCC
  is required.
- Check credits, their expiration and billing status in the GCP console before
  creating resources. Quotas do not cap spending.

```bash
gcloud auth list --filter=status:ACTIVE
gcloud config get-value project
oc whoami
oc project hassensiad06-dev
oc get resourcequota,limitrange -n hassensiad06-dev
oc get deployment,service,route,serviceaccount,secret -n hassensiad06-dev --ignore-not-found \
  | grep -E 'fastapi-lab4|gar-pull-lab4' || true
```
If these names already exist, check ownership before proceeding. Do not overwrite
an existing workload or delete the shared namespace. The commands below target
the namespace explicitly.

## 2. Rebuild and publish an available image

The old digest is historical evidence and cannot be reused. Reuse the Lab 3
sources without editing them; the `/` message still identifies Lab 3.

```bash
python3 -m venv lab3/.venv
lab3/.venv/bin/pip install -r lab3/requirements-dev.txt
(cd lab3 && .venv/bin/python -m pytest app_tests -v)
docker buildx build --platform linux/amd64 --load -t lab4-api:local lab3
docker run --rm -d --name lab4-api-test --user 1004890000:0 \
  -p 127.0.0.1:8080:8080 -e APP_ENV=openshift-lab4 lab4-api:local
curl --fail http://127.0.0.1:8080/health
curl --fail http://127.0.0.1:8080/
docker stop lab4-api-test

terraform -chdir=lab3/infra init -lockfile=readonly
./lab3/lifecycle prepare
# Review the plan before applying with the built-in confirmation.
./lab3/lifecycle prepare --apply

gcloud auth configure-docker europe-west9-docker.pkg.dev
IMAGE=europe-west9-docker.pkg.dev/cloud-platform-engineering-hs/lab3-api/api:lab3
docker tag lab4-api:local "$IMAGE"
docker push "$IMAGE"
DIGEST=$(gcloud artifacts docker images describe "$IMAGE" \
  --project=cloud-platform-engineering-hs --format='value(image_summary.digest)')
[[ "$DIGEST" =~ ^sha256:[0-9a-f]{64}$ ]] || { echo 'Invalid digest'; exit 1; }
export LAB4_IMAGE="${IMAGE%:*}@$DIGEST"
```
The existing `prepare` also creates the Lab 3 runtime identity and enables its
APIs; it does not deploy Cloud Run. Do not run `lifecycle deploy` for this lab.
Keep the local state until cleanup completes. Bit-for-bit reproducibility is
not guaranteed: the base image and transitive dependencies are not fully pinned.

## 3. Temporary pull secret without a service account key

The OAuth token normally expires after 60 minutes. The Kubernetes secret contains
this token: base64 encodes it but does not encrypt it. Never commit a Secret
export, display its value or enable `set -x`. The token is kept out of process
arguments; a private Docker configuration outside the repository is removed
even if the operation fails.

Run this block in a Bash subshell with `pipefail`:

```bash
(
  set -euo pipefail
  set +x
  umask 077
  AUTH_DIR=$(mktemp -d)
  trap 'rm -rf "$AUTH_DIR"' EXIT
  gcloud auth print-access-token | python3 -c '
import sys, json, base64
from pathlib import Path
token = sys.stdin.read().strip()
if not token:
    raise SystemExit("Missing token")
auth = base64.b64encode(("oauth2accesstoken:" + token).encode()).decode()
Path(sys.argv[1]).write_text(json.dumps({"auths": {
    "europe-west9-docker.pkg.dev": {"auth": auth}}}))
' "$AUTH_DIR/config.json"
  oc create secret generic gar-pull-lab4 -n hassensiad06-dev \
    --type=kubernetes.io/dockerconfigjson \
    --from-file=.dockerconfigjson="$AUTH_DIR/config.json" \
    --dry-run=client -o yaml | oc apply -n hassensiad06-dev -f -
)
```
Repeat this block before expiration whenever another pull is needed (scaling,
rollout, rollback or rescheduling). Running pods may continue, but that does not
guarantee future starts. For `ImagePullBackOff`, check events, the image digest,
GCP permissions and token validity. Avoiding a persistent key does not eliminate
the temporary credential stored in the cluster.

## 4. Deploy and verify HTTPS

The manifest contains an intentionally invalid `IMAGE_BY_DIGEST` placeholder.
Replace it with the newly published digest before applying. No Secret is included
in the manifests.

```bash
: "${LAB4_IMAGE:?Rebuild and publish the image before continuing}"
[[ "$LAB4_IMAGE" =~ ^europe-west9-docker\.pkg\.dev/cloud-platform-engineering-hs/lab3-api/api@sha256:[0-9a-f]{64}$ ]] || exit 1
# Preview the objects, then apply the same rendered manifest.
sed "s|IMAGE_BY_DIGEST|$LAB4_IMAGE|g" lab4/manifests/workload.yaml \
  | oc apply -n hassensiad06-dev --dry-run=server -f -
sed "s|IMAGE_BY_DIGEST|$LAB4_IMAGE|g" lab4/manifests/workload.yaml \
  | oc apply -n hassensiad06-dev -f -
oc rollout status deployment/fastapi-lab4 -n hassensiad06-dev --timeout=180s
HOST=$(oc get route fastapi-lab4 -n hassensiad06-dev -o jsonpath='{.spec.host}')
curl --fail --show-error "https://$HOST/health"
curl --fail --show-error "https://$HOST/"
```
Expect `{"status":"ok"}` and `environment=openshift-lab4`. Do not use `-k`:
the test must verify the certificate. The route is public and the API has no
application authentication. TLS terminates at the edge router, followed by HTTP
to the Service on port 8080; this does not provide end-to-end TLS.

## 5. Scaling, rolling update and rollback

```bash
oc scale deployment/fastapi-lab4 -n hassensiad06-dev --replicas=2
oc rollout status deployment/fastapi-lab4 -n hassensiad06-dev --timeout=180s
oc get pods -n hassensiad06-dev -l app=fastapi-lab4 -o wide
curl --fail "https://$HOST/health"
oc scale deployment/fastapi-lab4 -n hassensiad06-dev --replicas=1
oc rollout status deployment/fastapi-lab4 -n hassensiad06-dev --timeout=180s

oc rollout history deployment/fastapi-lab4 -n hassensiad06-dev
# Record the baseline revision before making the change.
oc set env deployment/fastapi-lab4 -n hassensiad06-dev APP_ENV=openshift-lab4-v2
oc rollout status deployment/fastapi-lab4 -n hassensiad06-dev --timeout=180s
curl --fail "https://$HOST/"
oc rollout undo deployment/fastapi-lab4 -n hassensiad06-dev
oc rollout status deployment/fastapi-lab4 -n hassensiad06-dev --timeout=180s
curl --fail "https://$HOST/"
```
Verify two Ready pods and their node assignments, then a return to one pod.
Anti-affinity is preferred: placement on two distinct nodes depends on Sandbox
capacity and is not guaranteed. The update should return `openshift-lab4-v2`;
the rollback should return `openshift-lab4`. `undo` restores the previous pod
template revision, not secrets or the Service. Without an intervening template
change, this is the recorded baseline; otherwise inspect history and explicitly
select `--to-revision`. Probes and `maxUnavailable: 0` control the rollout but
do not prove that no requests were lost. No load test or HPA was implemented.

## 6. Verify RBAC, SCC and Linux identity

```bash
oc auth can-i create deployments.apps -n hassensiad06-dev \
  --as=system:serviceaccount:hassensiad06-dev:fastapi-lab4
oc auth can-i get secrets -n hassensiad06-dev \
  --as=system:serviceaccount:hassensiad06-dev:fastapi-lab4
POD=$(oc get pods -n hassensiad06-dev -l app=fastapi-lab4 \
  -o jsonpath='{.items[0].metadata.name}')
oc get pod "$POD" -n hassensiad06-dev \
  -o jsonpath='{.metadata.annotations.openshift\.io/scc}{"\n"}{.spec.containers[0].securityContext}{"\n"}'
oc exec -n hassensiad06-dev "$POD" -- id
oc exec -n hassensiad06-dev "$POD" -- sh -c \
  'grep -E "^(Uid|NoNewPrivs|CapEff|CapBnd):" /proc/1/status'
```
Expect `no` for both permissions, `restricted-v2` for the reference session's
SCC, a non-root UID from the namespace range, `NoNewPrivs: 1`, and zero
`CapEff`/`CapBnd` masks. An impersonation error is not evidence of an RBAC denial:
ask an authorized administrator to verify it rather than granting the workload
additional permissions. The manifest creates no RoleBinding and disables the
ServiceAccount API token mount.

Do not set `runAsUser: 1004890000`: that UID was observed in this namespace.
OpenShift must assign a UID allowed by its SCC. The Lab 3 Dockerfile declares
10001, which admission overrides; application code and dependencies are readable
by the arbitrary UID, and the API does not need to write to `/app`. SCC selection
depends on the Sandbox version and policies. Inspect the actual annotation;
do not request `anyuid` to bypass a failure.

## 7. Clean up, including after a partial session

Inspect the named objects, then delete only this lab's resources:

```bash
oc delete route,service,deployment,serviceaccount fastapi-lab4 \
  -n hassensiad06-dev --ignore-not-found
oc delete secret gar-pull-lab4 -n hassensiad06-dev --ignore-not-found
oc get route,service,deployment,serviceaccount fastapi-lab4 \
  -n hassensiad06-dev --ignore-not-found
oc get secret gar-pull-lab4 -n hassensiad06-dev --ignore-not-found
oc get pods,replicasets -n hassensiad06-dev -l app=fastapi-lab4

./lab3/lifecycle clean
# Verify that the plan targets only temporary Lab 3 resources.
./lab3/lifecycle clean --apply
terraform -chdir=lab3/infra state list
gcloud artifacts repositories list --location=europe-west9 \
  --project=cloud-platform-engineering-hs
gcloud run services list --region=europe-west9 \
  --project=cloud-platform-engineering-hs
```
Wait for pods, ReplicaSets and named objects to disappear, an empty Lab 3 state,
and the expected regional inventories. If other resources exist, do not delete
them to obtain an empty inventory. An API error is not an empty result. Lab 3
cleanup destroys everything managed by its state, including any Lab 3 Cloud Run
service: verify that no other session depends on it. Do not delete the Telco
applications or Sandbox project, or run destroy against
`terraform/environments/dev`. GCP APIs remain enabled according to the Lab 3
configuration. Keep the state if cleanup fails and resolve the failure. These
checks do not guarantee the absence of costs elsewhere in the project.
