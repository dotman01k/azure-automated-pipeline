$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$temp = Join-Path ([IO.Path]::GetTempPath()) ([guid]::NewGuid().ToString())
New-Item -ItemType Directory "$temp/source" -Force | Out-Null
$script = Join-Path $root 'scripts/Protect-PlanArtifact.ps1'
$oldKey = $env:PLAN_ARTIFACT_KEY
function Expect-Failure([scriptblock]$Action) {
    $failed = $false
    try { & $Action } catch { $failed = $true }
    if (-not $failed) { throw 'Expected artifact rejection.' }
}
try {
    $env:PLAN_ARTIFACT_KEY = [Convert]::ToBase64String([Security.Cryptography.RandomNumberGenerator]::GetBytes(32))
    [IO.File]::WriteAllBytes("$temp/source/platform.tfplan",[byte[]](0,1,2,255,99))
    [IO.File]::WriteAllText("$temp/source/plan.txt",'private review example')
    [IO.File]::WriteAllText("$temp/source/manifest.json",'{"run":"123"}')
    & $script -Mode encrypt -Directory "$temp/source" -ArchivePath "$temp/plan.enc"
    & $script -Mode decrypt -Directory "$temp/roundtrip" -ArchivePath "$temp/plan.enc"
    foreach ($name in 'platform.tfplan','plan.txt','manifest.json') {
        if ((Get-FileHash "$temp/source/$name").Hash -ne (Get-FileHash "$temp/roundtrip/$name").Hash) { throw 'Round trip altered plan bytes.' }
    }
    Expect-Failure { & $script -Mode decrypt -Directory "$temp/roundtrip" -ArchivePath "$temp/plan.enc" }
    $packed = [IO.File]::ReadAllBytes("$temp/plan.enc")
    $packed[$packed.Length-1] = $packed[$packed.Length-1] -bxor 1
    [IO.File]::WriteAllBytes("$temp/tampered.enc",$packed)
    Expect-Failure { & $script -Mode decrypt -Directory "$temp/tampered" -ArchivePath "$temp/tampered.enc" }
    $env:PLAN_ARTIFACT_KEY = [Convert]::ToBase64String([Security.Cryptography.RandomNumberGenerator]::GetBytes(32))
    Expect-Failure { & $script -Mode decrypt -Directory "$temp/wrong-key" -ArchivePath "$temp/plan.enc" }
    $env:PLAN_ARTIFACT_KEY = [Convert]::ToBase64String([byte[]]::new(16))
    Expect-Failure { & $script -Mode encrypt -Directory "$temp/source" -ArchivePath "$temp/bad-key.enc" }
    Write-Host 'Artifact tests passed: byte round trip, tamper rejection, wrong/short key and nonempty destination.'
} finally {
    $env:PLAN_ARTIFACT_KEY = $oldKey
    Remove-Item -LiteralPath $temp -Recurse -Force -ErrorAction SilentlyContinue
}
