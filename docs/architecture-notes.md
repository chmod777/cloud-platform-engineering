# Architecture and operational notes

These notes document implementation decisions, operational behavior, and tradeoffs.
The [Lab 1 report](lab-01-gcp-foundations.md) and
[Lab 2 report](lab-02-vm-lifecycle.md) contain the observed evidence;
the [README](../README.md) describes the current lifecycle implementation.

## Implementation overview

Terraform manages a custom Google Cloud VPC with regional subnets and a private
Debian VM. Administration uses IAP and OS Login. Guest networking, routing, DNS,
and outbound connectivity were inspected during the recorded session. A capacity
error in Paris led to VM placement in Belgium while retaining the Paris network
foundation. The VM and boot disk were deleted after the session.

Lifecycle scripts validate full Terraform plans and permit only the intended VM
creation or deletion. Permanent resources have lifecycle protection. Seven unit
tests and a live start/access/cleanup cycle validate the workflow. Repeat start
and stop checks produced no-change plans; repeat applies were not performed.

## Product concepts and implementation evidence

| Topic | Behavior and rationale | Implementation evidence |
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

## Design rationale

### Why use IAP instead of a public SSH endpoint?

It supports administration without allocating a public IP to the VM. Tunnel access and administrative OS Login require separate IAM roles; the
firewall must also allow the tunnel's SSH traffic.

### Why did the deployment move to Belgium?

The observed error reported insufficient capacity in the requested Paris zone.
The solution preserved the existing foundation and added a regional subnet for
the VM. Regional placement can introduce cross-region latency or transfer
costs if an application is later deployed; no cross-region application traffic
was measured here.

### Why did a successful DNS lookup coexist with a failed HTTPS request?

Name resolution and destination connectivity are separate checks. The tested
internal name resolved, while the HTTPS connection timed out. The configuration
had no public VM IP or configured NAT/proxy path. A timeout alone
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

## Validation boundaries

- Private SSH access was verified; application HTTPS connectivity was not.
- A live start/access/cleanup cycle succeeded. Repeated start/stop plans returned
  no changes; repeat applies and failure recovery were not tested.
- Cleanup inventories were empty for instances, disks, and reserved IPs. Other
  services and billing were not exhaustively audited in the foundation labs.
- These development labs do not establish production readiness, high
  availability, or completion of a security audit.


## Labs 5-7: network policy, secret access and keyless planning

- [Lab 5](lab-05-private-networking.md): a default internet route did not provide
  private-VM egress. Extending the existing HTTPS source range restored Belgium
  to Paris connectivity; NAT enabled external HTTPS, and an independent egress
  firewall blocked HTTP. Temporary resources were deleted.
- [Lab 6](lab-06-least-privilege-secrets.md): an impersonated dedicated workload
  read exactly one secret, while a second read, a version write and project
  listing were denied. Positive access distinguishes identity validity from
  a negative result caused by failed authentication. Test resources were deleted.
- [Lab 7](lab-07-keyless-ci.md): GitHub OIDC claims bind trust to numeric owner
  and repository IDs, `master`, manual dispatch and a specific workflow path.
  Only Lab 3 uses GCS state. Public pull requests run without cloud credentials.
  CI has no infrastructure apply permission; its state-object access is still
  security-sensitive and requires trusted workflow changes.

Interview discussion: distinguish NAT from egress policy; a secret accessor
from a project viewer; an OIDC identity from the resulting impersonated account;
state isolation from code-file organization; and a successful plan from a
verified deployment. No automatic billing cap is claimed.
