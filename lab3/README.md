# LAB 3 - Docker, FastAPI and Cloud Run

[Architecture and technical report](../docs/lab-03-cloud-run.md) · [Verified results](RESULTS.md)

Status: a live deployment and cleanup cycle completed on 29 October 2026.

## 1. Understand and test the API

An API exposes HTTP paths. `GET /health` checks that the process responds;
`GET /` returns a message and the APP_ENV environment variable. Environment
variables configure the same image without rebuilding its code; do not put
secrets in this variable.

From the repository root:

```bash
python3 -m venv lab3/.venv
lab3/.venv/bin/pip install -r lab3/requirements-dev.txt
(cd lab3 && .venv/bin/python -m pytest app_tests -v)
(cd lab3 && .venv/bin/uvicorn app.main:app --host 127.0.0.1 --port 8080)
```
In a second terminal, run `curl --fail http://127.0.0.1:8080/health`.
Stop the server with Ctrl-C.

## 2. Build the container locally

Docker, Buildx and Colima were installed on this Mac during the session.
For subsequent sessions, run `colima start --cpu 2 --memory 2`.
At the end, run `colima stop` (this stops only the local engine, not GCP).
Linux amd64 emulation uses QEMU; Rosetta was not installed. An image contains
Python and its libraries; a container is a process launched from that image.
User 10001 avoids running the application as root. The Docker build context
excludes credentials, Terraform state and the local development environment.
Cloud Run expects Linux amd64 and a listener on `0.0.0.0:$PORT`.

```bash
docker buildx build --platform linux/amd64 --load -t lab3-api:local lab3
docker run --rm -d --name lab3-api-test -p 127.0.0.1:8080:8080 -e APP_ENV=docker lab3-api:local
curl --fail http://127.0.0.1:8080/health
curl --fail http://127.0.0.1:8080/
docker stop lab3-api-test
```
## 3. Billing prerequisite

Check the **Free Trial** status, remaining balance and expiration date in the
console. Do not upgrade to a paid account for this lab. An API response with
`billingEnabled=true` does not establish trial status. A budget is an alert,
not a spending limit. Maximum instances does not provide a financial cap.

The service uses 1 CPU, 256 MiB, request-based billing, zero minimum instances
and a service-level maximum of one instance. Stored images can incur charges
even without traffic: delete the repository at the end. Logs may persist after
deletion and incur costs depending on volume and retention. No Cloud Build,
NAT, VPC connector, load balancer or VM was added.

## 4. Prepare Artifact Registry with Terraform

Terraform describes the desired state. Its local state maps declared resources
to GCP objects. `lab3/infra` uses state independent of
`terraform/environments/dev`. Never run destroy against the Lab 1/2 environment.
The script saves a plan, checks its scope, then applies that exact plan.
Without `--apply`, it creates nothing. Updates and replacements are rejected.
Do not edit files or change accounts during an operation. Before creating
resources, the script requires `trial-verified` after the billing check;
applying a reviewed plan requires typing `yes`.

```bash
terraform -chdir=lab3/infra init -lockfile=readonly
./lab3/lifecycle prepare
./lab3/lifecycle prepare --apply
```
This enables the required APIs and creates the `lab3-api` repository in Paris
and a runtime identity without project roles. No service account key is created.
Enabled APIs remain enabled after cleanup to preserve other uses.

## 5. Publish the image and deploy

Artifact Registry stores private images. A SHA-256 digest identifies the exact
content being deployed, unlike a mutable tag.

```bash
gcloud auth configure-docker europe-west9-docker.pkg.dev
IMAGE=europe-west9-docker.pkg.dev/cloud-platform-engineering-hs/lab3-api/api:lab3
docker tag lab3-api:local "$IMAGE"
docker push "$IMAGE"
DIGEST=$(gcloud artifacts docker images describe "$IMAGE" --project=cloud-platform-engineering-hs --format='value(image_summary.digest)')
export LAB3_IMAGE="europe-west9-docker.pkg.dev/cloud-platform-engineering-hs/lab3-api/api@$DIGEST"
./lab3/lifecycle deploy
./lab3/lifecycle deploy --apply
```
The operator needs deployment permissions and `iam.serviceAccounts.actAs`.
Diagnose IAM denials without blindly granting Owner or Editor. No `allUsers`
access is granted: the service is network-accessible but protected by IAM.
The runtime identity and the caller's identity are separate.

```bash
URL=$(terraform -chdir=lab3/infra output -raw url)
curl --fail -H "Authorization: Bearer $(gcloud auth print-identity-token)" "$URL/health"
curl -s -o /dev/null -w '%{http_code}\n' "$URL/health"
gcloud run services logs read lab3-api --project=cloud-platform-engineering-hs --region=europe-west9 --limit=10
```
Expect HTTP 200 with an authorized identity (`run.routes.invoke` permission),
and a denial without a token. No load test was performed: scale-to-zero is
configured behavior, not an observed scaling result.

## 6. Clean up immediately, including after a partial failure

```bash
./lab3/lifecycle clean
./lab3/lifecycle clean --apply
gcloud run services list --project=cloud-platform-engineering-hs --region=europe-west9 --filter='metadata.name=lab3-api'
gcloud artifacts repositories list --project=cloud-platform-engineering-hs --location=europe-west9 --filter='name:lab3-api'
terraform -chdir=lab3/infra state list
./scripts/lab-status
```
Cleanup deletes only resources managed by the Lab 3 state, including the
repository and its images. It is not a comprehensive project inventory.
Do not erase the state before cleanup succeeds. On failure, retain the state,
rerun the cleanup plan and check resources in the console. Deleting resources
does not cancel costs already incurred.

## References

- https://cloud.google.com/signup-faqs
- https://docs.cloud.google.com/run/docs/container-contract
- https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/cloud_run_v2_service

## Backend update from Lab 7

The historical session used local state. The current root now uses the dedicated
GCS backend configured in `infra/backend.tf`. The empty Lab 3 state was migrated
without moving foundation resources. See [Lab 7](../docs/lab-07-keyless-ci.md)
for bootstrap access and CI boundaries. Do not initialize a replacement empty
backend when restoring an existing deployment; recover the correct state first.
