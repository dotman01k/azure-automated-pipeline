[CmdletBinding()]
param([Parameter(Mandatory)][string]$ResourceGroup,[Parameter(Mandatory)][string]$ClusterName)
$ErrorActionPreference = 'Stop'
& az aks get-credentials -g $ResourceGroup -n $ClusterName --overwrite-existing
if ($LASTEXITCODE) { throw 'Cannot obtain cluster credentials.' }
& kubelogin convert-kubeconfig -l azurecli
if ($LASTEXITCODE) { throw 'kubelogin failed.' }
& kubectl apply -f (Join-Path (Split-Path $PSScriptRoot -Parent) 'app/deployment.yaml')
if ($LASTEXITCODE) { throw 'Manifest apply failed.' }
& kubectl -n compute-demo rollout status deployment/demo --timeout=300s
if ($LASTEXITCODE) { throw 'Rollout failed.' }
