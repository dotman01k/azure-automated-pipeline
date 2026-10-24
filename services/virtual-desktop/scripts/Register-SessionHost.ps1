# Run inside the intended session host as an administrator, through an approved secure session.
# Installer paths must come from the official Microsoft links in the AVD add-session-host documentation.
[CmdletBinding()]
param([Parameter(Mandatory)][string]$AgentInstaller,[Parameter(Mandatory)][string]$BootloaderInstaller)
$ErrorActionPreference = 'Stop'
if ([string]::IsNullOrWhiteSpace($env:AVD_REGISTRATION_TOKEN)) { throw 'Supply a fresh registration token through a protected environment.' }
foreach ($path in @($AgentInstaller,$BootloaderInstaller)) {
    $signature = Get-AuthenticodeSignature -LiteralPath $path
    if ($signature.Status -ne 'Valid' -or $signature.SignerCertificate.Subject -notmatch 'Microsoft Corporation') { throw 'Require a valid Microsoft signed installer.' }
}
# Token is deliberately not written to Terraform state or printed. The installer needs it as an argument.
$agent = Start-Process msiexec.exe -ArgumentList @('/i',"`"$AgentInstaller`"",'/quiet','/norestart',"REGISTRATIONTOKEN=$env:AVD_REGISTRATION_TOKEN") -Wait -PassThru
if ($agent.ExitCode -notin @(0,3010)) { throw "AVD agent installer failed: $($agent.ExitCode)" }
$boot = Start-Process msiexec.exe -ArgumentList @('/i',"`"$BootloaderInstaller`"",'/quiet','/norestart') -Wait -PassThru
if ($boot.ExitCode -notin @(0,3010)) { throw "AVD bootloader installer failed: $($boot.ExitCode)" }
Remove-Item Env:AVD_REGISTRATION_TOKEN
Write-Host 'Installation completed; verify host pool registration, health, licensing and user access separately.'
