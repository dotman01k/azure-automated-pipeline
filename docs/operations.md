# Common operations and retirement

## Live acceptance

Verify the approved commit, service, environment, backend and plan before apply. After Azure provisioning succeeds, inspect the selected service's identity, networking, resource state and workload response. Its README has specific commands and failure checks. Terraform provider/mock tests do not replace a live service check.

Never use the whole collection as a single state or apply all folders merely to read the examples. Source CI is credential free and independent of live Azure DevOps pipeline execution.

## State and existing resources

A duplicate resource ID means inventory/state ownership must be reconciled. Add explicit import blocks only for known existing resource IDs and the correct module addresses. Importing a NIC does not import its subnet, NSG, VM or VNet. A successful import is not evidence that every attribute matches; inspect the resulting plan.

The normal gate rejects replacements and deletions but allows in-place updates. It does not prove that a proposed update is harmless. Pay particular attention to VMSS reimages, cluster upgrades, container group replacements, node counts, CIDRs, certificates, principal IDs and disk sizes.

A blob lease belongs to an active Terraform operation. Do not automatically break it. Check the run/host/process owner and confirm all writers have stopped before an authorized operator considers force-unlock. Keep state versions for approved recovery.

## Troubleshooting common stages

| Symptom | Check |
| :--- | :--- |
| Job queued | Windows pool name, Agent.OS demand, agent online and pipeline permission |
| Missing pwsh/python/az | Agent service account PATH and service restart after installation |
| Missing WIF settings or assertion refresh denied | Check the federated ARM connection, its GUID in AZURE_SERVICE_CONNECTION_ID, pipeline authorization and job token/URI mappings |
| Missing secret contract | Correct compute-service-environment variable group; `{}` for a service with no secrets |
| Invalid subscription/example input | Selected folder's tfvars and service connection must agree |
| Blob 403 | Data role, scope, storage networking and propagation |
| Plan rejected | Read the exact destructive/unsupported/incomplete action; do not bypass the gate casually |
| Apply plan mismatch | Build ID, source commit, service, environment, state key/account/container and artifact hash |
| Stale saved plan | Start a new run and review its new plan instead of secretly replanning in Apply |

## Retirement

No normal destroy workflow is exposed. Use a separately reviewed maintenance branch/process that explicitly handles the no-delete gate and lifecycle protection, confirms the exact service/environment/backend and retains required data. Windows VM, AVD session host and Service Fabric cluster have prevent_destroy. Data-bearing services may require backup/export first.

Remove workloads/registrations before their infrastructure. Delete guest/cluster compute and attached NIC/disks before subnets/VNets, and private DNS links/endpoints before parent networks. Service Fabric/AKS/Container Apps may have managed resource groups: inspect them after service deletion rather than deleting guessed shared resources. Public IP, NAT, Bastion, load balancer, logs, storage and registry resources can remain billable independently of compute.

Bootstrap RGs, backend storage, role assignments, service connections, variable groups, approval environments, agent registrations and local credential caches need separate cleanup. Retain shared backend accounts until every dependent state is reconciled. Never delete state to make drift disappear.

## Using both pipeline platforms

[GitHub Actions setup](github-actions.md) documents separate federated trust, protected approval environments, encrypted plan review and shared backend ownership. Start a complete new run when switching platforms; never reuse a binary plan from another platform or run. Keep one active deployment per service/environment.
