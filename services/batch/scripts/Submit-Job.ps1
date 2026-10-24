[CmdletBinding()]
param([Parameter(Mandatory)][string]$ResourceGroup,[Parameter(Mandatory)][string]$AccountName,[string]$JobId='compute-demo')
$ErrorActionPreference = 'Stop'
& az batch account login -g $ResourceGroup -n $AccountName --auth-mode aad
if ($LASTEXITCODE) { throw 'Batch account login failed.' }
& az batch job create --id $JobId --pool-id workers
if ($LASTEXITCODE) { throw 'Job creation failed. Choose a new ID or inspect the existing job.' }
& az batch task create --job-id $JobId --json-file (Join-Path (Split-Path $PSScriptRoot -Parent) 'app/task.json')
if ($LASTEXITCODE) { throw 'Task submission failed.' }
& az batch task show --job-id $JobId --task-id hello --query '{state:state,exitCode:executionInfo.exitCode}'
if ($LASTEXITCODE) { throw 'Task status read failed.' }
