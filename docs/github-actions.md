# Deploying with GitHub Actions or Azure DevOps

Both platforms use the same service folders, Terraform 1.13.0, AzureRM 4.68.0, input checks, state keys, destructive-plan gate and reviewed saved plans. Azure DevOps shows the actual Terraform CLI commands inline, using Prepare/RecordPlan/VerifyPlan helpers for authentication and safety checks. GitHub keeps the Complete script path. Both paths share the same state, policy and provenance logic. The Azure DevOps entry points remain in place. GitHub deployment is an additional **manual** workflow at `.github/workflows/deploy.yml`; pushing code continues to run source validation only.

## Platform choices

| Capability | Azure DevOps | GitHub Actions |
| :--- | :--- | :--- |
| Entry point | Root or per-service azure-pipelines.yml | Actions → Deploy Azure service → Run workflow |
| Authentication | Azure DevOps ARM federated connection | GitHub federated Entra application |
| Stage configuration | compute-service-environment variable group | Separate compute-service-environment-plan and -apply environments |
| Deployment approval | Azure DevOps environment checks | GitHub Apply environment required reviewers |
| Saved plan | Restricted private Azure DevOps artifact | Authenticated encrypted GitHub artifact |
| Shared runner | Literal Terraform CLI in YAML with AzureDevOps helper phases | Invoke-Terraform.ps1 -Platform GitHubActions |

For example, AKS Dev uses GitHub environments `compute-aks-dev-plan` and `compute-aks-dev-apply`. These are GitHub objects, separate from Azure DevOps's `compute-aks-dev` environment.

## 1. Protect and configure environments first

In this repository's **Settings → Environments**, create the Plan and Apply environments for each service/environment you intend to use. Restrict both to the protected `main` branch. On the **Apply** environment require reviewers, prevent self review where appropriate, and disable administrative bypass if supported. Approvals are external configuration: YAML naming an environment does not create required reviewers. Review branch protection, CODEOWNERS and who can change workflows or dispatch them before enabling live runs.

Do not enable the workflow until those controls and the settings below exist. An unexpectedly auto-created environment has no approval rules. The repository variable `GH_DEPLOY_ENABLED` must equal the literal string `true` before the deployment workflow proceeds; otherwise its jobs skip. The source-validation workflow does not use this flag.

## 2. Runner and network access

The default is standard `ubuntu-24.04` GitHub hosted runners. For private network workloads such as Storage, use a trusted runner with the required routes and DNS instead. Set repository variable `GH_RUNNER_LABELS` to a JSON array, for example `["self-hosted","linux","x64","azure-private"]`; register and label the runner separately. Windows is also supported with matching labels. Both plan and apply use the same OS/architecture labels because saved plans and provider packages must remain compatible.

A self hosted runner needs PowerShell **7.4 or later**, Python 3, Git, Azure CLI and network access for actions/provider downloads. The workflow installs the pinned Terraform version. Do not permit untrusted pull requests on a privileged persistent runner. Source validation currently uses GitHub hosted runners and needs no Azure credentials.

## 3. Azure identity, trust and roles

Create or select a dedicated Entra application/service principal for GitHub federation through your approved identity process. Do not reuse an Azure DevOps federated subject: the issuers and subjects are different. Assign the selected service's documented workload permissions, role assignment authority where required, and Blob Data Contributor on its existing Terraform backend. Read the service README and [shared setup](setup.md) for scope and private connectivity requirements. Plan/apply may use separate principals if both can access the same backend and the apply identity has the required write roles.

Create one federated credential for each intended GitHub Plan/Apply environment. Use the actual assertion's issuer and subject, with audience `api://AzureADTokenExchange`. **Do not blindly copy a legacy subject string.** Current GitHub documentation describes immutable subjects for newer or renamed repositories; inspect the subject actually issued for this repository/environment. The workflow's `Show public federated identity claims` step prints only issuer, subject and audience, never the JWT or request token. If the initial login fails because trust is not yet established, use those non-secret claims to finish the approved federation configuration and rerun the whole workflow. No Terraform deployment occurs before Azure login succeeds.

The shared script requests refreshable OIDC assertions from the selected runtime for both the provider and backend. It clears stale static assertion settings and prevents an Azure DevOps connection ID leaking into GitHub authentication. AzureCLI login and Terraform authentication remain distinct consumers of the same federated identity.

## 4. Variables and secrets

Set these **environment variables in both Plan and Apply**. The Azure subscription must match the chosen service's committed public tfvars.

| GitHub environment variable | Value |
| :--- | :--- |
| AZURE_CLIENT_ID | Entra application/client ID |
| AZURE_TENANT_ID | Tenant ID |
| AZURE_SUBSCRIPTION_ID | Subscription ID |
| STATE_RESOURCE_GROUP | Existing backend resource group |
| STATE_STORAGE_ACCOUNT | Existing backend account |
| STATE_CONTAINER | Existing backend container |

Set these environment secrets in both environments:

| Secret | Value |
| :--- | :--- |
| PLAN_ARTIFACT_KEY | The same base64 encoded 32 random bytes in Plan and Apply |
| TF_SECRET_JSON | Exact service secret JSON, such as {"admin_password":"..."}; omit for services without secrets, which default to {} |

Generate the artifact key locally in a trusted PowerShell session:

```powershell
[Convert]::ToBase64String([Security.Cryptography.RandomNumberGenerator]::GetBytes(32))
```

Store it in a password manager and the two GitHub environment secrets. Do not send it in chat, commit it, print it in CI or pass it on a command line. The operator reviewing the plan needs a secure copy; GitHub does not reveal a stored secret later. Use a separate key for each service/environment, rotate deliberately between completed runs, and keep it unchanged from plan through approval/apply. Azure access itself uses federation, not this encryption key.

## 5. Plan, review and approve

1. Replace the chosen service's synthetic public tfvars using its README. Configure prerequisites, identity, environments and secrets first.
2. Enable the repository variable `GH_DEPLOY_ENABLED=true` only when ready. Open **Actions → Deploy Azure service → Run workflow**, choose branch `main`, service, environment and `operation=plan`.
3. Validation runs first. Plan authenticates, initializes the existing backend, creates a saved plan and applies the destructive-plan policy. The public console uses Terraform's normal sensitive-value redaction; never enable TF_LOG or add secret-printing commands. Review provider sensitivity markings and use a private repository for confidential resource metadata. Encryption of artifacts does not make public workflow logs private.
4. The workflow packages exactly `platform.tfplan`, `plan.txt` and `manifest.json`, encrypts them using AES-256-GCM with a fresh nonce, and uploads only `plan.enc`. It retains the artifact for one day and cleans temporary files. No raw binary plan or private review text is uploaded. Wrong keys and modified ciphertext are rejected before extraction; archive entries are restricted to the three known names.
5. Download the artifact ZIP from the run. Extract `plan.enc` on a trusted machine, set `PLAN_ARTIFACT_KEY` privately in that process, then decrypt using the script from the same source commit:

```powershell
.\scripts\Protect-PlanArtifact.ps1 -Mode decrypt -Directory .\private-review -ArchivePath .\plan.enc
Get-Content .\private-review\plan.txt
```

6. For deployment, dispatch **a new complete workflow** with `operation=apply`. It creates a fresh plan. Download/decrypt/review **that run's** artifact before approving its Apply environment. An earlier plan-only run is not reused. Approve within the one-day retention window or start a fresh run.
7. Apply downloads the same-run encrypted artifact, decrypts it, checks platform, run ID, run attempt, source commit, backend and plan hash, gates it again, and applies exactly that saved binary. Tampering, a different backend, a cross-platform plan or stale Terraform state fails. Approval is not permission to silently replan.
8. Use the service README's runtime acceptance steps. Infrastructure success does not imply application publishing, AVD registration or successful recovery.

Do not use **Re-run failed jobs** to reuse an old plan: changing `GITHUB_RUN_ATTEMPT` invalidates its provenance and artifact name. Start a new complete run and review its new plan. Remove decrypted files from the review machine after the decision using your organization's data handling process.

## Shared state and concurrency

Both platforms must use the **same backend account, container and key** for the same Azure resources. Virtual Machines retains `windows-vm-dev.tfstate` or `windows-vm-prod.tfstate`; other services use `compute/<service>/<environment>.tfstate`. Do not create a second state for resources already managed by the other platform and do not copy a state key between unrelated services.

GitHub serializes whole deployment runs for each service/environment and does not cancel an active deployment for a new dispatch. Azure DevOps uses its separately configured exclusive lock. Those platform locks do not coordinate with each other. The Azure blob lease serializes actual Terraform state operations and stale saved plans are rejected, but it is not one approval lock shared across platforms. Choose one active deployment run for each service/environment, avoid dispatching both platforms simultaneously, and do not bypass locks. After a conflict or intervening deployment, generate and approve a new plan.

Platform provenance intentionally prevents downloading an Azure DevOps plan into GitHub or the reverse. Switching which platform starts the **next complete run** is supported; exchanging saved plans is not.

## Troubleshooting and costs

| Symptom | Action |
| :--- | :--- |
| All deployment jobs skipped | Use main and check the GH_DEPLOY_ENABLED repository variable |
| Job waiting before it starts | Review the selected environment's approvals and runner labels |
| Federated subject mismatch | Use the exact issuer/subject/audience printed before login; check environment names and repository subject format |
| Azure login missing values | Set all three Azure IDs in both matching GitHub environments |
| Decrypt authentication failure | Use the same 32-byte key from Plan in Apply; start a new run after rotation |
| Artifact missing on rerun | Start a complete new run; run attempt and one-day artifact retention are intentional boundaries |
| Provenance or stale-plan rejection | Check same platform/run/attempt/commit/backend; regenerate and review a new plan |
| Private resource unreachable | Use a runner with the service's private route and DNS requirements |
| State lock held by other platform | Let the owning run finish; investigate before any force unlock |

Source CI uses no Azure credentials and performs no live deployment. Enabling and dispatching the deployment workflow can create billable Azure resources; review the service's costs first. Actions runner/artifact usage depends on your GitHub account and runner choice. No external AI API is called by these workflows.

## Validation and references

CI tests the GitHub workflow contract, both script authentication branches with fake Terraform/Azure commands, exact-plan application, provenance/tamper rejection, authenticated encryption round trips and wrong-key/tamper rejection. The existing provider validation and Terraform mock tests continue across all eleven services. Live OIDC issuance/refresh, protected-environment approval configuration and real deployments still need account setup and live acceptance.

1. [GitHub OIDC with Azure](https://docs.github.com/en/actions/how-tos/secure-your-work/security-harden-deployments/oidc-in-azure)
2. [GitHub environment protection](https://docs.github.com/en/actions/how-tos/deploy/configure-and-manage-deployments/manage-environments)
3. [Pinned provider OIDC authentication](https://github.com/hashicorp/terraform-provider-azurerm/blob/v4.68.0/website/docs/guides/service_principal_oidc.html.markdown)
4. [Pinned Terraform backend authentication](https://github.com/hashicorp/terraform/blob/v1.13.0/internal/backend/remote-state/azure/backend.go)
