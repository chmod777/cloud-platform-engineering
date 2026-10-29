# Lab 2 — Controlled VM lifecycle and idempotence

Status: one live start/access/cleanup cycle completed, with no-change repeat
plans for both the running and absent VM states. Evidence below comes from the
operator's terminal output during this session. No cloud resources were created
to write this report.

## Objective

Turn the manually operated VM from [Lab 1](lab-01-gcp-foundations.md) into a
repeatable workflow that preserves the network and IAM foundation. Validate
convergence using full Terraform plans, inspect the deployed VM through IAP,
and verify that cleanup removes both the instance and its disk.

## Implementation

| Component | Responsibility |
|---|---|
| `lab_enabled` | Boolean input, false by default; controls VM count |
| `compute.tf` | Temporary VM and address migration from the historical resource to index `[0]` |
| Permanent resource lifecycle blocks | Reject planned deletion while `prevent_destroy` remains configured |
| `scripts/lab-start` | Request the running configuration and validate the creation plan |
| `scripts/lab-stop` | Request the absent configuration and validate the deletion plan |
| `scripts/lab-status` | Inventory instances, disks, and reserved IP addresses |
| `scripts/check-plan.py` | Reject unexpected resource changes and selected unsafe disk/VM settings |

Permanent and temporary resources remain in a single local state. Their
separation is currently in configuration and allowed operations, not in separate
Terraform backends. No existing resource was moved between states.

The scripts generate a full saved plan, inspect its JSON representation, and
apply that exact plan after confirmation. Temporary plan files have restricted
permissions and are removed on exit. Local script locking and Terraform state
locking address concurrent operations within their respective scopes.

## Validation sequence and results

### 1. Create the temporary VM

From the existing repository root:

```bash
./scripts/lab-start
```

The operator confirmed the validated creation plan. Terraform reported:

```text
Apply complete! Resources: 1 added, 0 changed, 0 destroyed.

Outputs:
app_subnet = "10.10.1.0/24"
mgmt_subnet = "10.10.2.0/24"
vpc_name = "platform-vpc"
```

One Terraform resource was added: the instance, which includes its boot disk
configuration. The disk is not a separate `google_compute_disk` resource in this
configuration, so the resource count does not imply that no disk was created.

### 2. Inspect the deployed resources

```bash
./scripts/lab-status
```

Observed inventory, shortened:

```text
NAME        ZONE            STATUS
vm-mgmt-01  europe-west1-b  RUNNING

NAME        ZONE            SIZE_GB  STATUS
vm-mgmt-01  europe-west1-b  10       READY
```

The disk's `USERS` field referenced the running VM. No reserved IP address rows
were returned. Reserved address inventory alone does not prove the absence of an
ephemeral public IP; the VM configuration and creation guard exclude public IPv4
access configuration.

### 3. Request start again without applying

```bash
./scripts/lab-start --plan
```

Observed result:

```text
No changes. Your infrastructure matches the configuration.
Plan validated. No changes applied.
```

This demonstrates convergence for the running state: the same desired start
configuration does not propose a second VM or modify the foundation. This repeat
check was a plan, not a second apply.

### 4. Verify private administration and internal DNS

From the Mac:

```bash
gcloud compute ssh vm-mgmt-01 \
  --zone=europe-west1-b \
  --project=cloud-platform-engineering-hs \
  --tunnel-through-iap
```

Inside the VM:

```bash
hostname
ip -4 addr show ens4
getent hosts metadata.google.internal
exit
```

Observed output, shortened:

```text
vm-mgmt-01
inet 10.10.3.3/32 metric 100 scope global dynamic ens4
169.254.169.254 metadata.google.internal
```

The session confirmed the expected host, a private guest address, and resolution
of the internal metadata hostname. The address was `10.10.3.3`, compared with
`10.10.3.2` in Lab 1: this environment does not reserve the VM's private address.
Automation should not assume a previous dynamically allocated address will be
reused after recreation.

### 5. Delete the temporary resources and inspect inventory

The cleanup procedure was:

```bash
./scripts/lab-stop --plan
./scripts/lab-stop
./scripts/lab-status
```

The supplied post-cleanup status output contained the inventory header and final
reminder, with no instance, disk, or reserved IP address rows. That establishes
absence of the resources covered by those successful list calls.

The deletion apply summary was not included in the supplied transcript; cleanup
is evidenced by the subsequent inventory and repeat stop plan rather than a
quoted deletion counter.

### 6. Request stop again without applying

```bash
./scripts/lab-stop --plan
```

Observed result:

```text
No changes. Your infrastructure matches the configuration.
Plan validated. No changes applied.
```

The absent VM state is stable. The full plan proposes no creation, update, or
deletion, including no changes to the declared foundation.

## Guard verification

The existing seven unit tests cover:

- No-change plans in both start and stop modes.
- Allowed VM deletion.
- Rejection of a network resource change.
- Rejection of VM replacement.
- Rejection of a retained boot disk.
- Rejection of additional attached disks during cleanup.
- Rejection of an incomplete plan.

These tests complement the live session. They do not establish coverage of every
possible provider field, IAM failure, interruption, or state corruption scenario.

## Outcome and technical interview takeaways

- **Desired state:** start and stop use the same configuration with a controlled
  VM input, rather than a routine targeted destroy.
- **Convergence:** repeat plans returned no changes for both running and absent
  VM states in the tested session.
- **Operational boundaries:** the allowed VM lifecycle is checked independently
  from permanent resource deletion protection.
- **Identity and access:** the recreated private VM remained accessible through
  IAP and OS Login.
- **Cleanup evidence:** empty instance and disk inventory demonstrates more than
  simply observing a powered-off VM.
- **Addressing:** private dynamic IP addresses can change after recreation.

## Remaining limitations

This is one observed session, not a guarantee of behavior under every failure.
No second apply was performed on an already converged state, and concurrent or
interrupted executions were not exercised live. The foundation and VM still share
one local state. There is no automatic session expiry, remote backend, CI
workflow, application connectivity test, or billing enforcement.

No exact VM session cost or trial credit balance is published here. Resource
inventory is not a billing report or an exhaustive audit of other Google Cloud
services. See the [README](../README.md) and [interview notes](interview-notes.md).
