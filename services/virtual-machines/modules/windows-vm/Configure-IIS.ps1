$ErrorActionPreference = 'Stop'
$result = Install-WindowsFeature -Name Web-Server -IncludeManagementTools
if (-not $result.Success) { throw 'IIS feature installation failed.' }
Set-Service -Name W3SVC -StartupType Automatic
Start-Service -Name W3SVC
$page = '<!doctype html><html><head><title>Azure automated pipeline</title></head><body><h1>Windows VM deployed with Terraform and Azure DevOps</h1><p>IIS configured through the Azure VM extension.</p></body></html>'
Set-Content -LiteralPath 'C:\inetpub\wwwroot\index.html' -Value $page -Encoding UTF8
$response = Invoke-WebRequest -Uri 'http://localhost/index.html' -UseBasicParsing
if ($response.StatusCode -ne 200) { throw 'Local IIS health check failed.' }
Write-Output 'IIS configured and local HTTP check succeeded.'
