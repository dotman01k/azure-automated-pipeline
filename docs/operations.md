# Operations and recovery

## Accepting a live deployment

Verify the selected pipeline environment, service connection, source commit, backend and reviewed plan first. After an approved apply, confirm VM provisioning state and its private IP, Bastion provisioning, OS disk size and extension status. Use Azure Portal → VM → Connect → Bastion with an authorized Azure account and the VM administrator credentials. Never paste those credentials into logs or GitHub issues.

On the Windows guest, verify:

```powershell
Get-Service W3SVC
Get-WindowsFeature Web-Server
Invoke-WebRequest http://localhost/index.html -UseBasicParsing
Get-Volume -DriveLetter C
```

The extension runs the local HTTP check during configuration. A successful VM provisioning status by itself does not prove IIS is reachable. Test browser access and patch assessment separately; do not assume source validation establishes them.

## Failure handling

| Symptom | Inspect |
| :--- | :--- |
| Agent job queued | Windows pool name, agent online status, pipeline permission and Agent.OS demand |
| PowerShell task cannot start | Install PowerShell 7 and restart the agent service so its PATH updates |
| Python unavailable | Ensure Python 3 is on the agent service account PATH, not only an interactive desktop account |
| WIF token missing | Use an ARM workload identity service connection and `addSpnToEnvironment`; this script intentionally rejects secret based connections |
| Blob 403 | Data role scope, Entra backend authentication, storage networking and role propagation |
| Placeholder subscription refused | Replace the synthetic subscription in the selected JSON file |
| Provider registration error | Register providers with bootstrap privileges; normal provider registration is disabled |
| Quota/capacity error | Check regional family vCPU quotas, selected VM size and image generation support |
| Plan says VM replacement | Stop. Compare image, computer name, zone, NIC, disk and configuration fields. Do not remove the gate casually |
| Stale plan | Start a new approved run with a new plan; do not replan secretly inside Apply |
| Bastion cannot connect | Bastion subnet/service health, workload NSG RDP rule, Windows service/firewall and credentials |
| IIS extension fails | Azure extension status and guest Custom Script Extension logs; inspect feature installation and local HTTP response |

## Importing an existing environment

This reconstruction must not be pointed at an existing state or RG without inventory review. Import every existing resource the new configuration will manage using the exact module address and actual ID. A NIC alone does not import its VM, NSG, subnet or VNet.

Example pattern for a known existing NIC:

```hcl
import {
  to = module.windows_vm.azurerm_network_interface.main
  id = "/subscriptions/SUB/resourceGroups/RG/providers/Microsoft.Network/networkInterfaces/NIC"
}
```

Review all fields after import. Import does not guarantee a no-op plan. An existing VM may use different disk size, image, patching, identity and security settings. Align configuration with the actual environment and review a plan before any apply. The normal gate rejects deletion/replacement; it permits in-place updates, so a no-destruction gate is not a promise of no changes.

## State lock recovery

A blob lease protects the state. Identify the owner and ensure no local Terraform, pipeline job or apply is active before a privileged operator considers force-unlock. Never automate lease breaking in a retry loop. Keep blob versions and backup copies available for approved state recovery.

## Retirement

No normal destroy operation is exposed. A reviewed maintenance process must deliberately remove VM lifecycle protection and account for the plan gate, data retention and resource dependencies. Export required data and verify the exact backend key. Remove Terraform resources first, bootstrap resources last, and reconcile Azure inventory before deleting the final state. A shared state container/account must be retained while another environment uses it.
