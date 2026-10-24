# Isolated integration test. Terraform and Azure CLI are functions, not real cloud calls.
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$originalDirectory = Get-Location
$temp = Join-Path ([IO.Path]::GetTempPath()) ([guid]::NewGuid().ToString())
New-Item -ItemType Directory "$temp/scripts","$temp/services/virtual-machines/environments/dev","$temp/artifacts","$temp/scratch" -Force | Out-Null
Copy-Item "$root/scripts/Invoke-Terraform.ps1","$root/scripts/validate_inputs.py","$root/scripts/plan_policy.py" "$temp/scripts/"
[IO.File]::WriteAllText("$temp/services/virtual-machines/project.json",'{"secret_variables":["admin_password"]}')
[IO.File]::WriteAllText("$temp/services/virtual-machines/environments/dev/terraform.tfvars.json",'{"subscription_id":"9d046dba-8c48-4fb8-91cc-a6011d06348b"}')
$global:fakeApplyCount = 0
function global:az { $global:LASTEXITCODE = 0; '9d046dba-8c48-4fb8-91cc-a6011d06348b' }
function global:terraform {
    $global:LASTEXITCODE = 0
    switch ($args[0]) {
        'init' { }
        'plan' {
            $target = @($args | Where-Object { $_ -like '-out=*' })[0].Substring(5)
            [IO.File]::WriteAllText($target,'mock-binary-plan')
        }
        'show' {
            if ($args -contains '-json') { '{"complete":true,"resource_changes":[]}' }
            else { 'Mock plan review text' }
        }
        'apply' { $global:fakeApplyCount++ }
        default { throw 'Unexpected mock Terraform command.' }
    }
}
function Expect-Failure([scriptblock]$Action) {
    $failed = $false
    try { & $Action } catch { $failed = $true }
    if (-not $failed) { throw 'Expected pipeline rejection.' }
}
try {
    $env:STATE_RESOURCE_GROUP='rg-state';$env:STATE_STORAGE_ACCOUNT='teststate';$env:STATE_CONTAINER='tfstate'
    $env:TF_SECRET_JSON='{"admin_password":"mock-only-test-value"}'
    $env:servicePrincipalId='test-client';$env:tenantId='test-tenant'
    $env:SYSTEM_ACCESSTOKEN='mock-ado-request-token';$env:SYSTEM_OIDCREQUESTURI='https://example.invalid/ado'
    $env:BUILD_SOURCEVERSION='test-commit';$env:BUILD_BUILDID='123';$env:AGENT_TEMPDIRECTORY="$temp/scratch"
    $env:GITHUB_SHA='test-commit';$env:GITHUB_RUN_ID='123';$env:GITHUB_RUN_ATTEMPT='1';$env:RUNNER_TEMP="$temp/scratch"
    $env:ACTIONS_ID_TOKEN_REQUEST_TOKEN='mock-github-request-token';$env:ACTIONS_ID_TOKEN_REQUEST_URL='https://example.invalid/github'
    $runner = "$temp/scripts/Invoke-Terraform.ps1"
    foreach ($platform in 'AzureDevOps','GitHubActions') {
        $env:ARM_ADO_PIPELINE_SERVICE_CONNECTION_ID='mock-service-connection'
        $env:ARM_CLIENT_ID='test-client';$env:ARM_TENANT_ID='test-tenant'
        & $runner -Service virtual-machines -Environment dev -Operation plan -Platform $platform -ArtifactDirectory "$temp/artifacts"
        $manifest = Get-Content "$temp/artifacts/manifest.json" -Raw | ConvertFrom-Json
        if ($manifest.platform -ne $platform) { throw 'Wrong manifest platform.' }
        $expectedToken = if ($platform -eq 'AzureDevOps') { $env:SYSTEM_ACCESSTOKEN } else { $env:ACTIONS_ID_TOKEN_REQUEST_TOKEN }
        if ($env:ARM_OIDC_REQUEST_TOKEN -ne $expectedToken) { throw 'Wrong OIDC source.' }
        if ($platform -eq 'GitHubActions' -and $env:ARM_ADO_PIPELINE_SERVICE_CONNECTION_ID) { throw 'ADO connection leaked into GitHub auth.' }
        & $runner -Service virtual-machines -Environment dev -Operation apply -Platform $platform -ArtifactDirectory "$temp/artifacts"
        $before = $global:fakeApplyCount
        $originalManifest = Get-Content "$temp/artifacts/manifest.json" -Raw
        foreach ($property in 'platform','run','attempt','commit','account','key','plan_hash') {
            $bad = $originalManifest | ConvertFrom-Json
            $bad.$property = 'mismatch'
            $bad | ConvertTo-Json | Set-Content "$temp/artifacts/manifest.json"
            Expect-Failure { & $runner -Service virtual-machines -Environment dev -Operation apply -Platform $platform -ArtifactDirectory "$temp/artifacts" }
        }
        $originalManifest | Set-Content "$temp/artifacts/manifest.json"
        [IO.File]::WriteAllText("$temp/artifacts/platform.tfplan",'tampered')
        Expect-Failure { & $runner -Service virtual-machines -Environment dev -Operation apply -Platform $platform -ArtifactDirectory "$temp/artifacts" }
        if ($global:fakeApplyCount -ne $before) { throw 'Rejected artifact reached Terraform apply.' }
    }
    if ($global:fakeApplyCount -ne 2) { throw 'Both platform happy paths must apply the mock plan.' }
    Write-Host 'Pipeline integration passed: both auth paths, exact plan apply and 16 provenance/tamper rejections.'
} finally {
    Set-Location $originalDirectory
    Remove-Item Function:global:az,Function:global:terraform -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $temp -Recurse -Force -ErrorAction SilentlyContinue
}
