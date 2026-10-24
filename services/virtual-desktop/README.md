# Azure Virtual Desktop

Pooled host pool, workspace, desktop application group, user roles and one private Windows 11 session host with Entra join preparation.

This folder is one standalone reference in [Azure Automated Pipeline](../../README.md). It is not deployed by opening the repository or running source tests. The shared Azure DevOps pipeline uses a Windows agent, workload identity federation, a reviewed saved plan and separate Dev/Prod state.

## Files and entry point

Use this folder's `azure-pipelines.yml` in Azure DevOps, or select **virtual-desktop** in the root pipeline. Terraform is under `modules` and `environments/dev|prod`. Sample values are public, synthetic and must be replaced. [Shared setup](../../docs/setup.md) contains complete agent, backend, variable group, service connection and approval instructions.

| Setting | Dev example |
| :--- | :--- |
| Workload RG | `rg-compute-virtual-desktop-dev` |
| Region | `eastus` |
| Resource prefix | `avddev` |
| Variable group and deployment environment | `compute-virtual-desktop-dev` |
| Required secret names | admin_password |
| Backend key | `compute/virtual-desktop/dev.tfstate` |

## Prerequisites and identity

Create the dedicated workload RG and existing state backend first. From an authorized bootstrap session, register:

```bash
az provider register --namespace Microsoft.DesktopVirtualization --wait
az provider register --namespace Microsoft.Compute --wait
az provider register --namespace Microsoft.Network --wait
az provider register --namespace Microsoft.ManagedIdentity --wait
```

The backend additionally needs Microsoft.Storage registered. This module creates role assignments, so the deployment identity also needs scoped role assignment authority in the workload RG. State operations require Blob Data Contributor and network reachability independently of workload permissions. Use separate service connections for environments where isolation is required. No broad subscription permission is assigned by this module.

## Plan and apply

1. Edit `environments/dev/terraform.tfvars.json`; replace the synthetic subscription and all applicable example identities, network addresses, keys or certificate values.
2. Configure the WIF service connection and `compute-virtual-desktop-dev` variable group. Set TF_SECRET_JSON to the exact required secret contract above. Never put secret values in tfvars.
3. Configure required reviewers, main branch controls and an exclusive lock on the matching Azure DevOps environment. The YAML alone does not configure approval.
4. Run this service's pipeline with environment=dev, operation=plan, the real agent pool and the real service connection.
5. For deployment start operation=apply and review that run's own plan artifact before approving. Apply checks service/environment/provenance and applies exactly the saved plan.
6. Complete runtime verification below. Prod has separate public inputs and state; review them independently rather than assuming Dev approval covers Prod.

## Runtime verification and workload steps

Terraform prepares one private Entra-joined Windows 11 host and the host pool/workspace/app group/user role assignments. It does not register the host automatically. Generate a fresh expiring host pool registration token using the official AVD add-session-host workflow. Download the current Microsoft AVD Agent and Boot Loader installers from that documentation. Inside the intended guest via an approved secure administrative path, set AVD_REGISTRATION_TOKEN privately and run Register-SessionHost.ps1 with those installer paths. The script checks Microsoft Authenticode signatures and MSI exit codes. Avoid shell transcripts/process tracing that could capture the installer token argument. Do not put a registration token into Terraform state. Verify Available host status, user entitlement, SSO/MFA requirements and an actual licensed user's desktop login. There is no Bastion or private management connection provisioned here; arrange one before guest installation. FSLogix/profile persistence is deliberately outside this baseline.

## Security boundary and limitations

Creates the control plane and one Entra join prepared host. Registration is a separate explicit step with a fresh short lived host pool token and Microsoft agent installers. A VM template is not treated as host registration. Tenant SSO/MFA/client prerequisites, licensing and actual desktop login need live acceptance; FSLogix and profile storage are not included.

The default sample image/version, where applicable, is a starting point rather than a supply chain attestation. Pin an approved version/digest and validate regional service support before a live release. Do not infer production availability from a single reference deployment or source test.

## Costs

Windows 11 session host VM, disk, NAT and outbound IP. Eligible AVD user licensing must be established separately.

Use current region/offer pricing before apply. Stopping the primary compute process is not a promise that every related resource stops billing.

## Troubleshooting

First inspect the selected root/backend and Azure provisioning/operation logs. For service authentication, check the WIF service connection and user/data roles separately. For unreachable endpoints, check the documented public/private model, actual outbound CIDR, DNS and TLS trust. For resource replacement or a duplicate existing resource ID, stop and follow [state/import guidance](../../docs/operations.md) before making changes. Source validation does not establish live quota, capacity, connectivity or licensing.

## Cleanup

Use the [reviewed retirement procedure](../../docs/operations.md). The normal gate rejects deletes/replacements. Retain data and reconcile the exact selected state before any maintenance teardown. Remove workload registrations/packages and dependent compute/NICs before networking, then reconcile managed resource groups, logs, registry/storage, NAT/IP and private DNS resources. Bootstrap state/identity resources are separate, and shared backend accounts must not be deleted while another service uses them.

## Validation

The module has credential-free Terraform mock tests, both roots receive provider schema validation, and shared input/policy tests run in [GitHub CI](https://github.com/dotman01k/azure-automated-pipeline/actions/workflows/validate.yml). These are configuration checks. Azure DevOps server expansion, real authentication, provisioning and the runtime verification above require an authorized live run.

## References

1. https://registry.terraform.io/providers/hashicorp/azurerm/4.68.0/docs
2. https://learn.microsoft.com/azure/
3. https://learn.microsoft.com/azure/virtual-desktop/add-session-hosts-host-pool

## GitHub Actions alternative

This service can also deploy through the shared GitHub Actions workflow. Follow [GitHub setup](../../docs/github-actions.md), select this folder's service name and use the same backend key. Configure GitHub's separate Plan/Apply environments and approvals before enabling deployment. The Azure DevOps entry point remains available.
