[CmdletBinding()]
param([Parameter(Mandatory)][string]$ResourceGroup,[Parameter(Mandatory)][string]$AppName)
$ErrorActionPreference = 'Stop'
$source = Join-Path (Split-Path $PSScriptRoot -Parent) 'app'
$zip = Join-Path ([IO.Path]::GetTempPath()) ([guid]::NewGuid().ToString()+'.zip')
try {
    Compress-Archive -Path "$source/*" -DestinationPath $zip
    & az functionapp deployment source config-zip --resource-group $ResourceGroup --name $AppName --src $zip --build-remote true
    if ($LASTEXITCODE) { throw 'Function deployment failed.' }
} finally { Remove-Item $zip -Force -ErrorAction SilentlyContinue }
