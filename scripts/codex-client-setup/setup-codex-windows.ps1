param(
  [string]$BaseUrl = "https://bigmodeltoken.zeabur.app",
  [string]$ApiKey
)

$ErrorActionPreference = "Stop"

function Write-Info([string]$msg) {
  Write-Host "[codex-setup] $msg"
}

function Normalize-BaseUrl([string]$url) {
  $u = $url.Trim().TrimEnd("/")
  if (-not ($u.ToLower().StartsWith("http://") -or $u.ToLower().StartsWith("https://"))) {
    $u = "https://$u"
  }
  return $u
}

function To-V1Url([string]$url) {
  $u = Normalize-BaseUrl $url
  if ($u.ToLower().EndsWith("/v1")) {
    return $u
  }
  return "$u/v1"
}

if ([string]::IsNullOrWhiteSpace($ApiKey)) {
  $ApiKey = Read-Host "Enter OPENAI_API_KEY"
}

if ([string]::IsNullOrWhiteSpace($ApiKey)) {
  throw "OPENAI_API_KEY is required."
}

$apiKeyTrimmed = $ApiKey.Trim()
$baseUrlNormalized = Normalize-BaseUrl $BaseUrl
$baseUrlV1 = To-V1Url $BaseUrl

[Environment]::SetEnvironmentVariable("OPENAI_API_KEY", $apiKeyTrimmed, "User")
[Environment]::SetEnvironmentVariable("OPENAI_BASE_URL", $baseUrlNormalized, "User")
[Environment]::SetEnvironmentVariable("MYPROXY_API_KEY", $apiKeyTrimmed, "User")
[Environment]::SetEnvironmentVariable("MYPROXY_BASE_URL", $baseUrlV1, "User")

$env:OPENAI_API_KEY = $apiKeyTrimmed
$env:OPENAI_BASE_URL = $baseUrlNormalized

Write-Info "Setup complete."
Write-Info "OPENAI_BASE_URL=$baseUrlNormalized"
Write-Info "Close and restart PowerShell/CMD."
Write-Info "Test with: codex --provider openai"
Write-Info "Backup provider: codex --provider MYPROXY"
