# LAB 3 - Results recorded on 29 October 2026

A live create, publish, deploy, test and delete cycle was completed in project
`cloud-platform-engineering-hs`, region `europe-west9` (Paris).
The final check took place around 11:33 Paris time.

## Lessons and verified behavior

1. **FastAPI** exposes `/health` and `/`, with APP_ENV configuring the environment.
   Three tests cover health, configuration and an unknown route.
2. **Docker** packages the application and its Python environment. The image was
   built and tested for Linux amd64, running as user 10001. Two local HTTP calls
   verified health and APP_ENV=docker. The container was stopped.
3. **Artifact Registry** stored the private image. It was published with digest
   `sha256:47635b9c5738f40b3f04d8ee891af414d35642dc7e1659aac9d4ce2a1a9842d7`.
4. **Terraform** created the registry, service account without project roles and
   Cloud Run service in state separate from Labs 1 and 2. Guarded plans did not
   modify resources from previous labs.
5. **Cloud Run** ran that image: `/health` returned HTTP 200 and
   `{"status":"ok"}`; `/` returned HTTP 200 with APP_ENV=lab3.
6. **IAM** denied anonymous access (HTTP 403) and accepted the user's token.
   No `allUsers` binding was created; the operator's inherited permissions were
   sufficient. The network URL is public, but invocation requires an authorized
   identity.
7. **Logs:** Uvicorn startup and a listener on 0.0.0.0:8080 were observed.
8. **Cleanup:** the service, registry with its images, and service account were
   deleted. Lab 3 state was empty; a second cleanup plan showed no changes.

## Final checks

- 9 Lab 3 tests passed (3 API tests and 6 plan guard tests).
- 7 Lab 2 tests passed; Lab 2 configuration was unchanged.
- Terraform validate and fmt passed; shell syntax and Git whitespace checks passed.
- Cloud Run service inventory in Paris: empty.
- Artifact Registry repository inventory across all regions: empty.
- Service account inventory filtered to lab3-api-runtime: empty.
- Compute Engine inventories: no VMs, disks or reserved IP addresses.
- Colima stopped; Docker/Colima/Buildx installed and the image retained locally.
- Run, Artifact Registry and IAM APIs left enabled, with no active Lab 3 resources.

## Billing and limitations

The user confirmed **Free Trial** status, available credits and sufficient
validity in the console. APIs verified the billing link and open account;
they did not establish the credit balance or trial status. No paid upgrade,
payment-method change or billing-link change was performed.

The cycle can consume credits for compute, storage and requests. Exact costs
and the updated balance are unknown. Check billing reports after they update.
Logs can persist after deletion. These inventories are not a comprehensive
audit of every GCP product.

Zero minimum instances and a maximum of one instance were configured, without
a load test or a scale-to-zero measurement: the service was deleted immediately
after testing. No CI/CD, automatic shutdown or programmatic spending cap was
implemented. Keep the account on the trial: Google states that charges do not
begin without a manual upgrade to a paid account. Credits alone do not prevent
overspending on a paid account.

References:

- https://cloud.google.com/signup-faqs
- https://docs.cloud.google.com/run/docs/container-contract

## Repeat the lab

Follow `lab3/README.md` from the repository root. Lifecycle commands display a
plan by default; `--apply` applies only after confirmation. Always finish with
`./lab3/lifecycle clean --apply`, including after a partial failure. The cloud
repository and historical image were deleted; rebuild and republish the image
before deploying again.
