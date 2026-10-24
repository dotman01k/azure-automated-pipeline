# Only issuer, audience and subject are printed. Never print the JWT or request token.
$ErrorActionPreference = 'Stop'
$separator = if ($env:ACTIONS_ID_TOKEN_REQUEST_URL.Contains('?')) { '&' } else { '?' }
$url = $env:ACTIONS_ID_TOKEN_REQUEST_URL + $separator + 'audience=api%3A%2F%2FAzureADTokenExchange'
try {
    $response = Invoke-RestMethod -Uri $url -Headers @{ Authorization = "Bearer $env:ACTIONS_ID_TOKEN_REQUEST_TOKEN" }
    $part = $response.value.Split('.')[1].Replace('-','+').Replace('_','/')
    $part = $part.PadRight($part.Length + ((4 - $part.Length % 4) % 4),'=')
    $claims = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($part)) | ConvertFrom-Json
    [pscustomobject]@{issuer=$claims.iss;subject=$claims.sub;audience=$claims.aud} | ConvertTo-Json
} catch { throw 'Cannot read the GitHub federated subject. Check id-token permission and runner access.' }
