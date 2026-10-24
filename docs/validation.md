# Compute collection validation

The CI matrix now runs all eleven service folders, including Storage. Each job performs shared Python tests, PowerShell syntax parsing, recursive Terraform formatting, provider validation for its module and two environment roots, module mock plans, and the PowerShell validate entry point against both roots. Dependency versions and lock files are committed.

## Recorded collection result

On 24 October 2026, [run 40062606320](https://github.com/dotman01k/azure-automated-pipeline/actions/runs/40062606320) passed all ten service jobs for implementation commit `710322bd855de29c4785bbd2a6d4c50c5181b603`.

| Check | Result |
| :--- | :--- |
| Shared Python unit tests | 49 passed (repeated in each matrix job) |
| Terraform module mock tests | 26 passed across ten modules |
| AzureRM provider schema validation | Ten modules and 20 environment roots passed |
| PowerShell syntax | All committed scripts parsed successfully |
| Shared PowerShell validate operation | Dev and Prod passed for every service |
| Recursive Terraform formatting | Passed |
| Local relative Markdown links | Passed |

CI caught and the implementation corrected an App Service health check requirement, ACI probe scheme casing and a Batch API IP format constraint. AKS testing also exposed the dependency on an Azure-generated kubelet identity; the final design provisions a separate kubelet identity with scoped Managed Identity Operator and AcrPull assignments. The pipeline uses refreshable Azure DevOps OIDC configuration; real token issuance and renewal are still live acceptance requirements.

This evidence records credential-free checks, not a live deployment. No billable Azure resources were created during preparation. Subsequent documentation-only changes do not alter the tested implementation; use the linked commit and logs for exact evidence.

## Earlier baseline and acceptance boundary

The Windows implementation initially passed 18 Python and four Terraform tests before the collection refactor; that baseline run is [40060736344](https://github.com/dotman01k/azure-automated-pipeline/actions/runs/40060736344). Use the latest matrix run for the new folder layout and additional services. Earlier deployment history is not evidence for this newly authored collection.

Local Python, input, link and formatting checks are recorded during preparation. Provider plugin execution is restricted in the preparation runtime; hosted CI is the authority for provider validation/mock plans. A pass does not establish Azure DevOps server-side template expansion, service availability, capacity, authentication, application deployment, AVD session registration/login, Batch task execution or Service Fabric management/application behavior. Record those separately in a live acceptance run without publishing secrets or state.

## Storage extension

On 24 October 2026, [run 40063169402](https://github.com/dotman01k/azure-automated-pipeline/actions/runs/40063169402) passed all **eleven** service jobs for implementation commit `378edbd1a9846e21f4edcd8f130adb8a6c29c521`.

This expanded result includes Storage and the data-source file reorganization:

| Check | Result |
| :--- | :--- |
| Shared Python suite | 51 tests passed |
| Terraform module mock runs | 30 passed, including four Storage runs |
| Provider schema validation | Eleven modules and 22 environment roots passed |
| PowerShell syntax and validate entry point | Passed for every service and both roots |
| Recursive Terraform formatting | Passed |
| Data source organization | 25 data blocks in 24 separate data.tf files; none in main.tf |
| Local relative Markdown links | Passed |

Storage includes private Blob networking/DNS, Entra data RBAC, management-only provider provisioning, versioning, soft delete, point in time recovery configuration and lifecycle cooling. These checks do not prove live DNS, authorization, data access or successful recovery. The workload remains undeployed by these checks.

