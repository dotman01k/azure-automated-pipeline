[CmdletBinding()]
param([string]$Version = '1.13.0')
$ErrorActionPreference = 'Stop'
if ($Version -ne '1.13.0') { throw 'This repository validates Terraform 1.13.0 only.' }
$platform = if ($IsWindows) { 'windows' } else { 'linux' }
$name = "terraform_${Version}_${platform}_amd64.zip"
$directory = Join-Path ([IO.Path]::GetTempPath()) ([guid]::NewGuid().ToString())
New-Item -ItemType Directory -Path $directory | Out-Null
try {
    $base = "https://releases.hashicorp.com/terraform/$Version"
    Invoke-WebRequest "$base/$name" -OutFile (Join-Path $directory $name)
    Invoke-WebRequest "$base/terraform_${Version}_SHA256SUMS" -OutFile (Join-Path $directory 'checksums.txt')
    $line = Get-Content (Join-Path $directory 'checksums.txt') | Where-Object { $_ -match "  $([regex]::Escape($name))$" }
    if (@($line).Count -ne 1) { throw 'Cannot identify exactly one vendor checksum.' }
    $expected = ($line -split '\s+')[0]
    if ((Get-FileHash (Join-Path $directory $name) -Algorithm SHA256).Hash -ne $expected) { throw 'Terraform checksum mismatch.' }
    $target = Join-Path $env:AGENT_TEMPDIRECTORY 'terraform-1.13.0'
    New-Item -ItemType Directory -Path $target -Force | Out-Null
    Expand-Archive -LiteralPath (Join-Path $directory $name) -DestinationPath $target -Force
    if (-not $IsWindows) { & chmod +x (Join-Path $target 'terraform'); if ($LASTEXITCODE) { throw 'chmod failed' } }
    Write-Host "##vso[task.prependpath]$target"
} finally { Remove-Item -LiteralPath $directory -Recurse -Force }
