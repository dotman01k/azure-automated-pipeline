# Shared Azure DevOps setup

## 1. Agent and source

Use a trusted Windows x64 self hosted Azure DevOps agent with PowerShell 7, Git, Azure CLI and Python 3 on the **agent service account PATH**. The default pool is InfraProject. Terraform 1.13.0 is downloaded by a script that compares the vendor SHA256 checksum over HTTPS. Do not run untrusted public pull requests on this privileged agent.

Create the Azure pipeline from this GitHub repository using either root `azure-pipelines.yml` or `services/<service>/azure-pipelines.yml`. The root file contains the complete parameters, variables and Validate/Plan/Apply stages directly. Each service entry point is also a complete standalone pipeline with its service fixed. The former `pipelines/compute.yml` template has been removed; CI checks that all standalone files retain the same stages and variables. Use the branch containing the approved source. Live triggers and PR triggers are disabled. The root selector defaults to Virtual Machines and `operation=plan`; each service entry point fixes its own service slug.

## 2. Bootstrap Azure prerequisites

Use an administrator session, choose the subscription and create a dedicated resource group matching the selected tfvars, for example `rg-compute-functions-dev`. Virtual Machines retains its previous names `rg-platform-vm-dev-eastus` and `rg-platform-vm-prod-eastus`. Register every provider listed in the service's `project.json`, plus Microsoft.Storage for the backend. AzureRM automatic registration is disabled.

Create or reuse an existing StorageV2 backend with a private tfstate container, TLS 1.2, anonymous blob access disabled, shared key access disabled, and blob versioning/soft delete. Use Entra data authorization for container operations. Ensure the agent can reach its network endpoint. Use your subscription and globally unique name, not values copied from another project.

Example CLI sequence, run only after choosing real identifiers:

```bash
az account set --subscription '<subscription-id>'
az group create --name '<workload-rg>' --location eastus
az group create --name '<backend-rg>' --location eastus
az storage account create -g '<backend-rg>' -n '<unique-account>' -l eastus \
  --sku Standard_LRS --kind StorageV2 --min-tls-version TLS1_2 \
  --allow-blob-public-access false --allow-shared-key-access false
# Assign the bootstrap operator Blob Data Contributor and allow propagation first.
az storage container create --account-name '<unique-account>' --name tfstate --auth-mode login
```

Enable versioning and retention through approved storage management before using live state. Public state networking is secured by Entra RBAC in this baseline; private endpoints/firewalls require corresponding agent connectivity. On Windows Git Bash set `MSYS_NO_PATHCONV=1` before passing ARM resource IDs.

## 3. Service connection and roles

Create an Azure Resource Manager service connection with **workload identity federation**, such as sc-compute-dev. Copy the exact issuer, subject and audience from the Azure DevOps wizard into its Azure trust configuration. Do not invent a GitHub subject or reuse the previous AKS federation. Grant only this pipeline permission to the connection.

Contributor on the selected workload RG is the normal infrastructure permission. Grant Storage Blob Data Contributor on the backend container/account, and Reader on its management metadata when needed for discovery. Services that create role assignments need scoped User Access Administrator or a suitably constrained role assignment permission on the workload RG. Functions storage, AKS network/registry and AVD user access assignments use that capability. Azure Batch job submission additionally needs appropriate Batch data-plane permissions, separate from ARM Contributor.

For Functions, ensure the pipeline can create the deployment storage container; Blob Data Contributor may be needed for data-plane container operations depending on the provider/API path. Scope that access to the application storage account and plan its bootstrap rather than granting storage data access across the subscription.

## 4. Variables and secrets

Create one variable group per service/environment, named `compute-<service>-<environment>`, for example `compute-functions-dev`. Authorize this pipeline only.

| Variable | Value |
| :--- | :--- |
| AZURE_SERVICE_CONNECTION_ID | Azure DevOps service connection GUID (not its display name); must identify the selected connection |
| STATE_RESOURCE_GROUP | Existing backend RG |
| STATE_STORAGE_ACCOUNT | Existing account name |
| STATE_CONTAINER | Existing private container, usually tfstate |
| TF_SECRET_JSON | JSON object with exactly the names in the selected service's project.json |

For services without required secrets, set TF_SECRET_JSON to `{}`. For Virtual Machines, Virtual Desktop and Service Fabric, set it as a **secret variable** containing `{"admin_password":"<actual complex secret>"}`. Never commit the real value. Secret names are checked against the selected service contract, then mapped to process-only TF_VAR values. Azure DevOps JSON secret masking is not a guarantee that every substring will be redacted; never print the object or individual values.

Edit that service's committed public tfvars with actual subscription and configuration. The live checker rejects the example subscription, documentation CIDRs, example SSH key and example certificate/group values. Use a dedicated reviewed branch. Do not point a fresh root at existing resources/state without inventory and import analysis.

Terraform uses the job-scoped `System.AccessToken`, `System.OidcRequestUri` and the service connection GUID to request fresh federated assertions. This supports token refresh during long operations instead of reusing AzureCLI's initial `idToken`. Keep the connection authorized for this pipeline, limit job authorization scope and never print these environment values. A fresh assertion is limited to the running job; it is not a stored client secret. Token refresh still needs a live acceptance check in your Azure DevOps organization.

The configuration follows the pinned [AzureRM 4.68 OIDC guide](https://github.com/hashicorp/terraform-provider-azurerm/blob/v4.68.0/website/docs/guides/service_principal_oidc.html.markdown) and [Terraform 1.13 backend implementation](https://github.com/hashicorp/terraform/blob/v1.13.0/internal/backend/remote-state/azure/backend.go).

## 5. Approval environments and serialization

Create Azure DevOps environments `compute-<service>-dev` and `compute-<service>-prod`. Configure required reviewers, branch controls and an exclusive lock under Approvals and checks. YAML `lockBehavior: sequential` controls a configured exclusive lock; it does not create one. Protect the service connection, variable group and branch too.

Use a **private Azure DevOps project** with restricted artifact permissions for live runs. Terraform binary plans and state can contain passwords and service secrets even when console text is redacted. Set short pipeline artifact retention and maintain trusted agent disk cleanup. The shared pipeline publishes a binary saved plan, review text and manifest, never raw plan JSON. Temporary plan JSON is deleted in finally blocks.

## 6. Run and accept

Select service/environment, Windows pool, exact service connection and operation=plan. The service connection's subscription must match tfvars. Inputs are checked, the correct backend initialized and the plan policy executed. No delete, replacement, forget, errored or deferred plan is accepted by normal deployment.

For apply, start a new run with operation=apply. Review **that run's** plan.txt before approving its Apply environment. Apply verifies service, environment, source commit, pipeline run ID, Terraform version, backend identity and SHA256, gates the saved plan again and applies exactly it. A stale plan fails. The manifest protects integrity inside the trusted pipeline; it is not an independently signed external attestation.

After infrastructure succeeds, use the selected service README's runtime checks and optional workload scripts. App Service and Functions application packages, AKS manifests, AVD host registration and Batch job submission are separate explicit operations. They are not implied by terraform apply.
