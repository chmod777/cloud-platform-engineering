# Technical interview notes

Use these notes to explain the implementation and reason about tradeoffs.
The [Lab 1 report](lab-01-gcp-foundations.md) and
[Lab 2 report](lab-02-vm-lifecycle.md) contain the observed evidence;
the [README](../README.md) describes the current lifecycle implementation.

## Project walkthrough

> I used Terraform to build a custom Google Cloud VPC with regional subnets and
> deploy a private Debian VM. I accessed it through IAP and OS Login, then examined
> its guest network configuration, routing, DNS, and outbound connectivity. A
> capacity error in Paris led me to deploy the VM in Belgium while retaining the
> Paris network foundation. I deleted the VM and boot disk after the session.
> I then added scripts that validate the full Terraform plan and allow only the
> intended VM creation or deletion, with permanent resource protection and tests.
> I validated a live start/access/cleanup session and confirmed that repeat plans
> proposed no changes for both the running and absent VM states.

Support each point with the code or recorded output. The scripts have been tested
with real plans, seven unit tests, and one live lifecycle session. Repeated start
and stop checks used plan mode; they were not repeated applies.

## Product concepts and implementation evidence

| Topic | Explanation to give | Evidence to show |
|---|---|---|
| VPC and subnets | VPC scope is global; subnets are regional. Dynamic routing mode is a separate setting. | `main.tf`, Paris and Belgium subnets |
| IAP | Provides the administrative tunnel to the private VM. IAM permission and the SSH firewall rule are both required parts of the access path. | `--tunnel-through-iap`, `allow-iap-ssh` |
| OS Login | Connects Google identity to Linux login; administrative login uses a distinct IAM role. | `enable-oslogin`, `roles/compute.osAdminLogin`, successful session |
| Service accounts | Workload identity differs from the human administrator's identity. OAuth scopes do not grant IAM permissions by themselves. | `service-account.tf`, VM `service_account` block |
| Firewall rules | Source ranges and target tags define the allowed traffic. A configured rule is not proof of application connectivity. | TCP 22 IAP rule; TCP 443 source subnet limitation |
| Guest networking | A `/32` guest address can work with an explicit route to the gateway even when the subnet is `/24`. | Recorded `ip addr` and `ip route` output |
| DNS and egress | Successful internal DNS resolution does not establish Internet connectivity. | Successful `getent`, HTTPS timeout |
| Terraform lifecycle | Plans describe intended actions; applying performs them. File separation does not create separate states. | Initial cleanup mistake; one state with an optional VM |
| Operational safeguards | Validate the exact plan, reject unexpected actions, and keep state private. | `check-plan.py`, temporary plan handling, `.gitignore` |
| Cost management | VM deletion and disk deletion matter separately; billing visibility remains necessary. | `auto_delete`, stop guard, post-cleanup inventory |

## Design questions to rehearse

### Why use IAP instead of a public SSH endpoint?

It supports administration without allocating a public IP to the VM. Explain
which IAM role permits tunnel access, which role permits administrative OS Login,
and why the firewall still needs to allow the tunnel's SSH traffic.

### Why did the deployment move to Belgium?

The observed error reported insufficient capacity in the requested Paris zone.
The solution preserved the existing foundation and added a regional subnet for
the VM. Discuss regional placement and potential cross-region latency or transfer
costs if an application were later deployed; no cross-region application traffic
was measured here.

### Why did a successful DNS lookup coexist with a failed HTTPS request?

Name resolution and destination connectivity are separate checks. The tested
internal name resolved, while the HTTPS connection timed out. The configuration
had no public VM IP or configured NAT/proxy path. Explain that a timeout alone
does not conclusively identify the failing layer.

### Why avoid routine targeted destruction?

A full plan exposes changes across the configuration. The scripts inspect that
plan and reject every resource change except the expected VM action. Targeting
was used during the first cleanup; the scripts are the current routine workflow.

### What does prevent_destroy protect, and where does it fall short?

It rejects plans that destroy the protected resource while its lifecycle rule
remains configured. It is not a cloud-side deletion lock and does not protect a
resource whose configuration block has been removed. Plan validation adds a
separate check for script-driven operations.

### What would you change before using this approach in production?

Define the environment and state boundaries, implement a remote backend and
appropriate locking, review IAM permissions, add CI plan review, and implement
reliable session expiry or resource cleanup. Broaden lifecycle validation to
interrupted and concurrent executions and validate application network paths.
These are proposed improvements, not delivered features.

## Claims to keep precise

- Say that private SSH access was verified; application HTTPS connectivity was not.
- Say that a live start/access/cleanup session succeeded and repeated start/stop
  plans returned no changes; repeat applies and failure recovery were not tested.
- Say that cleanup inventory was empty for instances, disks, and reserved IPs;
  other services and billing were not exhaustively audited.
- Say that this is a development lab demonstrating specific skills; avoid claims
  of production readiness, high availability, or a completed security audit.
