# Requires PowerShell 7.4+ (.NET 8). Never pass the key as a command argument.
[CmdletBinding()]
param(
    [Parameter(Mandatory)][ValidateSet('encrypt','decrypt')][string]$Mode,
    [Parameter(Mandatory)][string]$Directory,
    [Parameter(Mandatory)][string]$ArchivePath
)
$ErrorActionPreference = 'Stop'
$key = [Convert]::FromBase64String($env:PLAN_ARTIFACT_KEY)
if ($key.Length -ne 32) { throw 'PLAN_ARTIFACT_KEY must encode exactly 32 random bytes.' }
$header = [Text.Encoding]::ASCII.GetBytes('AAPLAN01')
$names = @('platform.tfplan','plan.txt','manifest.json')
$memory = [IO.MemoryStream]::new()
$aes = [Security.Cryptography.AesGcm]::new($key,16)
try {
    if ($Mode -eq 'encrypt') {
        $zip = [IO.Compression.ZipArchive]::new($memory,[IO.Compression.ZipArchiveMode]::Create,$true)
        try {
            foreach ($name in $names) {
                $path = Join-Path $Directory $name
                if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Missing plan file: $name" }
                if ((Get-Item -LiteralPath $path).Length -gt 268435456) { throw 'Plan file exceeds the 256 MiB bound.' }
                $entry = $zip.CreateEntry($name)
                $stream = $entry.Open()
                try {
                    $bytes = [IO.File]::ReadAllBytes($path)
                    $stream.Write($bytes,0,$bytes.Length)
                } finally { $stream.Dispose() }
            }
        } finally { $zip.Dispose() }
        $plain = $memory.ToArray()
        $nonce = [Security.Cryptography.RandomNumberGenerator]::GetBytes(12)
        $cipher = [byte[]]::new($plain.Length)
        $tag = [byte[]]::new(16)
        $aes.Encrypt($nonce,$plain,$cipher,$tag,$header)
        [IO.Directory]::CreateDirectory((Split-Path ([IO.Path]::GetFullPath($ArchivePath)) -Parent)) | Out-Null
        [IO.File]::WriteAllBytes($ArchivePath,([byte[]]($header+$nonce+$tag+$cipher)))
    } else {
        $packed = [IO.File]::ReadAllBytes($ArchivePath)
        if ($packed.Length -lt 37 -or [Text.Encoding]::ASCII.GetString($packed,0,8) -ne 'AAPLAN01') { throw 'Invalid encrypted plan format.' }
        $nonce = [byte[]]$packed[8..19]
        $tag = [byte[]]$packed[20..35]
        $cipher = [byte[]]$packed[36..($packed.Length-1)]
        $plain = [byte[]]::new($cipher.Length)
        $aes.Decrypt($nonce,$cipher,$tag,$plain,$header)
        $memory.Write($plain,0,$plain.Length)
        $memory.Position = 0
        $zip = [IO.Compression.ZipArchive]::new($memory,[IO.Compression.ZipArchiveMode]::Read,$true)
        try {
            if ($zip.Entries.Count -ne 3) { throw 'Unexpected plan bundle contents.' }
            foreach ($name in $names) {
                $entries = @($zip.Entries | Where-Object { $_.FullName -ceq $name })
                if ($entries.Count -ne 1 -or $entries[0].Length -gt 268435456) { throw 'Invalid or oversized plan bundle entry.' }
            }
            if ((Test-Path -LiteralPath $Directory) -and @(Get-ChildItem -LiteralPath $Directory -Force).Count -ne 0) { throw 'Decrypt only into an empty directory.' }
            [IO.Directory]::CreateDirectory($Directory) | Out-Null
            foreach ($entry in $zip.Entries) {
                $stream = $entry.Open()
                $output = [IO.File]::Create((Join-Path $Directory $entry.FullName))
                try { $stream.CopyTo($output) } finally { $stream.Dispose();$output.Dispose() }
            }
        } finally { $zip.Dispose() }
    }
    Write-Host "Plan bundle $Mode completed."
} finally {
    $aes.Dispose();$memory.Dispose()
    [Array]::Clear($key,0,$key.Length)
    if ($plain) { [Array]::Clear($plain,0,$plain.Length) }
}
