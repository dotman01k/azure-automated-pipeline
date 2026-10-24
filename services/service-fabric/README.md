# Service Fabric Managed Clusters

Managed Service Fabric cluster with client certificate authentication and a primary Windows node type.

This folder is one standalone reference in [Azure Automated Pipeline](../../README.md). It is not deployed by opening the repository or running source tests. The shared Azure DevOps pipeline uses a Windows agent, workload identity federation, a reviewed saved plan and separate Dev/Prod state.

## Files and entry point

Use this folder's `azure-pipelines.yml` in Azure DevOps, or select **service-fabric** in the root pipeline. Terraform is under `modules` and `environments/dev|prod`. Sample values are public, synthetic and must be replaced. [Shared setup](../../docs/setup.md) contains complete agent, backend, variable group, service connection and approval instructions.

| Setting | Dev example |
| :--- | :--- |
| Workload RG | `rg-compute-service-fabric-dev` |
| Region | `eastus` |
| Resource prefix | `sfdev` |
| Variable group and deployment environment | `compute-service-fabric-dev` |
| Required secret names | admin_password |
| Backend key | `compute/service-fabric/dev.tfstate` |

## Prerequisites and identity

Create the dedicated workload RG and existing state backend first. From an authorized bootstrap session, register:

```bash
az provider register --namespace Microsoft.ServiceFabric --wait
az provider register --namespace Microsoft.Compute --wait
az provider register --namespace Microsoft.Network --wait
```

The backend additionally needs Microsoft.Storage registered. Normal infrastructure deployment uses Contributor on the dedicated workload RG; additional data-plane/operator access is described below. State operations require Blob Data Contributor and network reachability independently of workload permissions. Use separate service connections for environments where isolation is required. No broad subscription permission is assigned by this module.

## Plan and apply

1. Edit `environments/dev/terraform.tfvars.json`; replace the synthetic subscription and all applicable example identities, network addresses, keys or certificate values.
2. Configure the WIF service connection and `compute-service-fabric-dev` variable group. Set TF_SECRET_JSON to the exact required secret contract above. Never put secret values in tfvars.
3. Configure required reviewers, main branch controls and an exclusive lock on the matching Azure DevOps environment. The YAML alone does not configure approval.
4. Run this service's pipeline with environment=dev, operation=plan, the real agent pool and the real service connection.
5. For deployment start operation=apply and review that run's own plan artifact before approving. Apply checks service/environment/provenance and applies exactly the saved plan.
6. Complete runtime verification below. Prod has separate public inputs and state; review them independently rather than assuming Dev approval covers Prod.

## Runtime verification and workload steps

Supply the thumbprint of an administrator client certificate whose private key is held by the authorized operator. After apply, read the actual management FQDN and server certificate thumbprint from Azure, verify certificate trust, and connect with the Service Fabric SDK/Explorer using the client certificate. Inspect primary node health and upgrade status. The output hostname is a hint derived from configuration, not proof of live DNS/certificate validity. The 443-to-8443 application LB rule is only a mapping: deploy an application with its own TLS listener/certificate before expecting an application response. This folder does not create an application package, read the client private key, open remote desktop rules or claim private management connectivity.

## Security boundary and limitations

Uses a pre-existing administrator client certificate thumbprint; the private certificate stays with the operator. Azure manages the cluster certificate and underlying resources. An application TLS load balancer mapping is defined, but an application, certificate binding and listener must be deployed separately before it serves traffic. Service Fabric Explorer/client authentication and management endpoints need a live security review; no private management endpoint is claimed.

The default sample image/version, where applicable, is a starting point rather than a supply chain attestation. Pin an approved version/digest and validate regional service support before a live release. Do not infer production availability from a single reference deployment or source test.

## Costs

At least three Windows nodes for Basic, five for Standard, managed disks and managed networking/load balancer resources.

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

## GitHub Actions alternative

This service can also deploy through the shared GitHub Actions workflow. Follow [GitHub setup](../../docs/github-actions.md), select this folder's service name and use the same backend key. Configure GitHub's separate Plan/Apply environments and approvals before enabling deployment. The Azure DevOps entry point remains available.
