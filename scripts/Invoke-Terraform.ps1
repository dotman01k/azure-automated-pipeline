[CmdletBinding()]
param(
    [Parameter(Mandatory)][ValidateSet('aks','app-service','batch','container-apps','container-instances','functions','service-fabric','virtual-desktop','virtual-machines','vm-scale-sets')][string]$Service,
    [Parameter(Mandatory)][ValidateSet('dev','prod')][string]$Environment,
    [Parameter(Mandatory)][ValidateSet('validate','plan','apply')][string]$Operation,
    [string]$ArtifactDirectory
)
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$directory = Join-Path $root "services/$Service/environments/$Environment"
$project = Get-Content (Join-Path $root "services/$Service/project.json") -Raw | ConvertFrom-Json
$stateKey = if ($Service -eq 'virtual-machines') { "windows-vm-$Environment.tfstate" } else { "compute/$Service/$Environment.tfstate" }
function Invoke-Checked {
    param([string]$Program,[string[]]$Arguments)
    & $Program @Arguments
    if ($LASTEXITCODE -ne 0) { throw "$Program exited $LASTEXITCODE" }
}
$env:TF_IN_AUTOMATION = 'true'
Set-Location $directory
if ($Operation -eq 'validate') {
    Invoke-Checked terraform @('fmt','-check','-recursive',$root)
    Invoke-Checked terraform @('init','-backend=false','-input=false','-lockfile=readonly')
    Invoke-Checked terraform @('validate','-no-color')
    Invoke-Checked python @((Join-Path $PSScriptRoot 'validate_inputs.py'),'terraform.tfvars.json')
    return
}
foreach ($name in 'servicePrincipalId','tenantId','idToken','STATE_RESOURCE_GROUP','STATE_STORAGE_ACCOUNT','STATE_CONTAINER','TF_SECRET_JSON') {
    $value = [Environment]::GetEnvironmentVariable($name)
    if ([string]::IsNullOrWhiteSpace($value) -or $value.StartsWith('$(')) { throw "Missing pipeline setting: $name" }
}
$env:ARM_USE_OIDC = 'true'
$env:ARM_USE_AZUREAD = 'true'
$env:ARM_CLIENT_ID = $env:servicePrincipalId
$env:ARM_TENANT_ID = $env:tenantId
$env:ARM_OIDC_TOKEN = $env:idToken
$secrets = ConvertFrom-Json -InputObject $env:TF_SECRET_JSON -AsHashtable
if ($secrets -isnot [System.Collections.IDictionary]) { throw 'TF_SECRET_JSON must be a JSON object.' }
$expectedSecrets = @($project.secret_variables)
if (@($secrets.Keys).Count -ne $expectedSecrets.Count) { throw 'Secret variable count does not match the selected service.' }
foreach ($name in $secrets.Keys) {
    if ($name -notin $expectedSecrets -or $secrets[$name] -isnot [string] -or [string]::IsNullOrWhiteSpace($secrets[$name])) { throw 'Unexpected/missing service secret.' }
    [Environment]::SetEnvironmentVariable("TF_VAR_$name", $secrets[$name], 'Process')
}
$subscription = & az account show --query id -o tsv
if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($subscription)) { throw 'Cannot identify authenticated subscription.' }
$env:ARM_SUBSCRIPTION_ID = $subscription.Trim()
$config = Get-Content terraform.tfvars.json -Raw | ConvertFrom-Json
if ($config.subscription_id -ne $env:ARM_SUBSCRIPTION_ID) { throw 'Service connection and Terraform subscription differ.' }
Invoke-Checked python @((Join-Path $PSScriptRoot 'validate_inputs.py'),'terraform.tfvars.json','--live')
Invoke-Checked terraform @('init','-input=false','-reconfigure','-lockfile=readonly',
    "-backend-config=resource_group_name=$env:STATE_RESOURCE_GROUP",
    "-backend-config=storage_account_name=$env:STATE_STORAGE_ACCOUNT",
    "-backend-config=container_name=$env:STATE_CONTAINER",
    "-backend-config=key=$stateKey",
    '-backend-config=use_azuread_auth=true','-backend-config=use_oidc=true')
$planPath = Join-Path $ArtifactDirectory 'platform.tfplan'
$manifestPath = Join-Path $ArtifactDirectory 'manifest.json'
if ($Operation -eq 'plan') {
    New-Item -ItemType Directory -Path $ArtifactDirectory -Force | Out-Null
    Invoke-Checked terraform @('plan','-input=false','-lock-timeout=120s',"-out=$planPath")
    $json = & terraform show -json $planPath
    if ($LASTEXITCODE) { throw 'Cannot decode saved plan.' }
    $privateJson = Join-Path $ArtifactDirectory 'private-plan.json'
    $json | Set-Content -LiteralPath $privateJson -Encoding utf8
    try { Invoke-Checked python @((Join-Path $PSScriptRoot 'plan_policy.py'),$privateJson) }
    finally { Remove-Item -LiteralPath $privateJson -Force -ErrorAction SilentlyContinue }
    $text = & terraform show -no-color $planPath
    if ($LASTEXITCODE) { throw 'Cannot render review plan.' }
    $text | Set-Content (Join-Path $ArtifactDirectory 'plan.txt') -Encoding utf8
    @{
        service=$Service;environment=$Environment;commit=$env:BUILD_SOURCEVERSION;build=$env:BUILD_BUILDID
        plan_hash=(Get-FileHash $planPath -Algorithm SHA256).Hash
        terraform='1.13.0';subscription=$env:ARM_SUBSCRIPTION_ID
        account=$env:STATE_STORAGE_ACCOUNT;container=$env:STATE_CONTAINER;key=$stateKey
    } | ConvertTo-Json | Set-Content $manifestPath -Encoding utf8
} else {
    $manifest = Get-Content $manifestPath -Raw | ConvertFrom-Json
    if ($manifest.service -ne $Service -or $manifest.environment -ne $Environment -or $manifest.commit -ne $env:BUILD_SOURCEVERSION -or
        $manifest.build -ne $env:BUILD_BUILDID -or $manifest.terraform -ne '1.13.0' -or
        $manifest.subscription -ne $env:ARM_SUBSCRIPTION_ID -or $manifest.account -ne $env:STATE_STORAGE_ACCOUNT -or
        $manifest.container -ne $env:STATE_CONTAINER -or $manifest.key -ne $stateKey -or
        $manifest.plan_hash -ne (Get-FileHash $planPath -Algorithm SHA256).Hash) { throw 'Saved plan provenance/backend mismatch.' }
    # Gate the downloaded binary again; apply exactly this plan, without replanning.
    $json = & terraform show -json $planPath
    if ($LASTEXITCODE) { throw 'Cannot decode downloaded saved plan.' }
    $temp = Join-Path $env:AGENT_TEMPDIRECTORY ([guid]::NewGuid().ToString()+'.json')
    $json | Set-Content $temp -Encoding utf8
    try { Invoke-Checked python @((Join-Path $PSScriptRoot 'plan_policy.py'),$temp) }
    finally { Remove-Item $temp -Force -ErrorAction SilentlyContinue }
    Invoke-Checked terraform @('apply','-input=false','-lock-timeout=120s',$planPath)
}
