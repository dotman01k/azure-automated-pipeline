# Earlier InfraProject lessons

The original discussion covered Windows VM automation in Azure DevOps. Its actual local source was unavailable when this reference was reconstructed. The following are historical troubleshooting lessons, not observed Azure outcomes for the new service folders.

| Earlier issue | Design response |
| :--- | :--- |
| Terraform init received too many arguments | PowerShell native argument arrays and explicit exit checks |
| Missing AzureRM features block | Explicit provider setup in each root |
| Blob AuthorizationPermissionMismatch | Separate Blob Data Contributor permission from ARM Contributor |
| State held by a local desktop | State leases and externally configured environment locks |
| Zero regional DSv5 quota | Explicit VM size and a live quota/capacity check |
| Existing NIC duplicate resource ID | Inventory/import review before adopting an existing environment |
| Subnet lookup failure | Module dependency references instead of guessed subnet lookups |
| Deprecated automatic update attribute | Pinned provider schema validation |
| CRLF warnings | Text normalization and PowerShell Core |

The later AKS lab demonstrated that regenerated identities require every dependent client/principal/workload ID to be updated, OIDC subjects must match actual assertions, environment variables do not cross environment scopes, and loopback belongs to the machine running the command. Those lessons inform shared setup guidance, but the earlier AKS runtime evidence remains in its own repository.
