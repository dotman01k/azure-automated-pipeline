[CmdletBinding()]
param([Parameter(Mandatory)][string]$ResourceGroup,[Parameter(Mandatory)][string]$AppName)
$ErrorActionPreference = 'Stop'
$source = Join-Path (Split-Path $PSScriptRoot -Parent) 'app'
$zip = Join-Path ([IO.Path]::GetTempPath()) ([guid]::NewGuid().ToString()+'.zip')
try {
    Compress-Archive -Path "$source/*" -DestinationPath $zip
    & az webapp deploy --resource-group $ResourceGroup --name $AppName --type zip --src-path $zip
    if ($LASTEXITCODE) { throw 'Application deployment failed.' }
} finally { Remove-Item $zip -Force -ErrorAction SilentlyContinue }
