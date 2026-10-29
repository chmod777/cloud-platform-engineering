# Cloud Platform Engineering - Google Cloud

A collection of hands-on Google Cloud infrastructure labs, built with Terraform.
The project demonstrates private VM administration, network troubleshooting,
controlled infrastructure lifecycle management, authenticated serverless API
deployment, and hybrid container delivery to OpenShift. Each lab records
architecture decisions, observed results, and implementation limits.

## Labs and evidence

| Lab | Scope | Evidence |
|---|---|---|
| [Lab 1 - GCP foundations and a private VM](docs/lab-01-gcp-foundations.md) | VPC, regional subnets, Compute Engine, IAM, IAP, OS Login, Linux networking | VM deployment, SSH session, routing and DNS output, failed outbound HTTPS test, cleanup verification |
| [Lab 2 - Controlled VM lifecycle](docs/lab-02-vm-lifecycle.md) | Optional VM, Terraform plan validation, permanent resource protection, shell scripts | Live creation, repeated start plan with no changes, IAP SSH, empty cleanup inventory, repeated stop plan with no changes; seven plan guard tests |
| [Lab 3 - Containerized API on Cloud Run](docs/lab-03-cloud-run.md) | FastAPI, Docker, Artifact Registry, Cloud Run, IAM, isolated Terraform state | Local container checks, authenticated HTTP 200, anonymous HTTP 403, application logs, verified resource cleanup; nine automated tests |
| [Lab 4 - Private registry to OpenShift](docs/lab-04-hybrid-openshift.md) | Private Artifact Registry, Developer Sandbox, temporary OAuth pull credentials, SCC/RBAC, scaling and rollbacks | Operator-reported HTTPS checks, two pods on two nodes, rolling update/rollback, restricted-v2 process checks and cleanup |

[Architecture and operational notes](docs/architecture-notes.md) connect the implementation
to product concepts, design tradeoffs, and questions to discuss.

## Architecture and repository layout

```text
terraform/environments/dev/
  main.tf             # Provider, global VPC, regional subnets
  firewall.tf         # IAP SSH and management-to-application rules
  iam.tf              # Administrator access through IAP and OS Login
  service-account.tf  # Dedicated VM service account
  compute.tf          # Temporary VM, disabled by default
  variables.tf        # Project, region, and lab_enabled
  outputs.tf          # Network outputs
scripts/
  lab-start           # Preview and optionally apply VM creation
  lab-stop            # Preview and optionally apply VM deletion
  lab-status          # List instances, disks, and reserved IP addresses
  lab                 # Shared lifecycle implementation
  check-plan.py       # Reject changes outside the allowed VM lifecycle
tests/               # Plan guard unit tests
lab3/
  app/               # FastAPI application
  app_tests/         # API and Terraform plan guard tests
  Dockerfile         # Linux container, non-root runtime
  infra/             # Independent Lab 3 Terraform root and provider lock
  lifecycle          # Preview-first prepare, deploy, and clean commands
  guard.py           # Restrict plan addresses and actions
  README.md          # Step-by-step operating guide in French
lab4/
  manifests/         # Secret-free OpenShift workload template
  README.md          # French build, deploy, verify and cleanup guide
docs/                # Lab reports and architecture notes
```

The development project is `cloud-platform-engineering-hs`. The current design
keeps Lab 1/2 permanent resources and the temporary VM in **one local Terraform state**.
Separate files provide a clear code boundary; independent states are a future
migration, requiring a verified backup and an explicit migration procedure.
Lab 3 starts with its own local state in `lab3/infra`; it does not migrate or
manage the existing foundation resources.

The VM is disabled by default (`lab_enabled = false`). Permanent resources have
`prevent_destroy`; that protection depends on keeping the corresponding resource
blocks in the configuration. Do not run a global destroy or remove those blocks.

## Prerequisites

- Terraform >= 1.5, Python 3, and authenticated Google Cloud CLI.
- Google Cloud credentials available to Terraform, such as Application Default Credentials.
- Access to the existing local state for this deployed environment.

GitHub authentication is not required to run the lab. After cloning, securely
restore the existing state before planning against the existing project. Applying
with an empty state would attempt to create resources already managed elsewhere.
Initialize the locked provider dependencies with:

```bash
terraform -chdir=terraform/environments/dev init -lockfile=readonly
```

## Run Labs 1 and 2

From the repository root:

```bash
./scripts/lab-status
./scripts/lab-start --plan
./scripts/lab-start
./scripts/lab-stop --plan
./scripts/lab-stop
```

Start and stop generate a full Terraform plan and reject any resource change
other than creation or deletion of `google_compute_instance.mgmt_vm[0]`,
respectively. VM replacement and network or IAM changes block the operation.
The start guard checks the project, VM name, zone, machine type, subnet, absence
of public IPv4 access configuration, and boot disk size, type, and deletion flag.
The stop guard rejects retained boot disks and additional attached disks.

Plans are written to a private temporary directory and removed on exit. The exact
validated plan is applied only after typing `yes`. `--plan` never applies changes.
A live session verified creation, SSH access, and cleanup. Repeat start and stop
plans returned no changes in the running and absent states, respectively. These
checks demonstrate convergence in that session; they were repeat plans rather
than repeat applies. See the [Lab 2 evidence](docs/lab-02-vm-lifecycle.md).

A local lock prevents concurrent script executions, alongside Terraform state
locking. After a crash, confirm no operation is running before removing a stale
`.lab-lock` directory.

`lab-stop` deletes the VM and its boot disk (`auto_delete = true`), rather than
only powering it off. It does not clean up unrelated project resources.
`lab-status` lists instances, disks, and reserved IP addresses. API failures are
errors, not evidence of an empty project. This command does not inventory every
Google Cloud service or retrieve billing data.

## Costs and session cleanup

The e2-micro VM and its 10 GB pd-standard disk in europe-west1 consume trial
credits. The scripts add neither a public IP address nor Cloud NAT. Before each
session, check the credit balance, expiration date, and billing account type in
Cloud Billing. Automated credit balance checks are not implemented.

Keep sessions short, then run `lab-stop` and `lab-status`. Automatic shutdown is
not implemented. Alert-only budgets do not cap Compute Engine spending; these
scripts do not guarantee that trial credits cannot be exhausted.

- [Free Tier eligibility](https://docs.cloud.google.com/free/docs/free-cloud-features)
- [Budgets](https://docs.cloud.google.com/billing/docs/how-to/budgets)
- [VM pricing](https://cloud.google.com/compute/vm-instance-pricing)
- [Disk pricing](https://cloud.google.com/compute/disks-image-pricing)

State files, backups, saved plans, and credentials must stay out of Git. The
provider dependency lock file is versioned. Keep private state backups outside
the repository.

## Verification

```bash
python3 -m unittest discover -s tests -v
bash -n scripts/lab scripts/lab-start scripts/lab-stop scripts/lab-status
terraform -chdir=terraform/environments/dev fmt -check
```

The seven guard tests cover no-op plans, permitted VM deletion, rejected network
changes, rejected VM replacement, retained disks, attached disks, and incomplete
plans. They complement the live lifecycle session documented in Lab 2.

## Known limitations and next steps

- Labs 1/2 share a local state; Lab 3 has a separate local state. No remote backend yet.
- The HTTPS firewall rule allows `10.10.2.0/24`; the Belgian VM uses `10.10.3.0/24`.
  Application connectivity from Belgium has not been implemented or validated.
- No automatic shutdown, billing enforcement, or project-wide resource cleanup.
- No CI workflow yet. Lab 3 has completed one application deployment and cleanup cycle.
- This is a development lab with recorded evidence, not a production readiness claim.

## Run Lab 3 - Docker & Cloud Run

Read the [architecture and evidence report](docs/lab-03-cloud-run.md) and the
[French step-by-step guide](lab3/README.md) before applying changes.

```bash
# Local API tests; no cloud resources are created.
python3 -m venv lab3/.venv
lab3/.venv/bin/pip install -r lab3/requirements-dev.txt
(cd lab3 && .venv/bin/python -m pytest app_tests -v)

# Preview the temporary registry and runtime identity.
terraform -chdir=lab3/infra init -lockfile=readonly
./lab3/lifecycle prepare

# Preview cleanup of resources tracked by the Lab 3 state.
./lab3/lifecycle clean
```

`prepare`, `deploy`, and `clean` generate and inspect a saved plan. Add `--apply`
to apply it after confirmation. Publishing the image and supplying its digest
are required before `deploy`; see the guide for the complete sequence.
`clean --apply` deletes the Lab 3 service, image repository, and runtime identity.
Never run a global destroy against the Lab 1/2 foundation.

**Verified on 29 October 2026:** the API returned HTTP 200 with authentication
and HTTP 403 without a token. The temporary cloud resources were then deleted;
no live demo is intentionally kept running. Trial status and credit validity
must be checked before every new session. Scaling limits and budget alerts do
not guarantee a spending cap.

## Run Lab 4 - Private Artifact Registry to OpenShift

Read the [architecture and recorded evidence](docs/lab-04-hybrid-openshift.md) and
the [French operating guide](lab4/README.md). The previous image was deleted:
rebuild the Lab 3 application and publish a new digest before rendering the
[OpenShift manifests](lab4/manifests/workload.yaml). The guide covers temporary
OAuth image-pull credentials, HTTPS checks, scaling, rollout/rollback, RBAC/SCC
verification and scoped cleanup. No live resources are retained.
