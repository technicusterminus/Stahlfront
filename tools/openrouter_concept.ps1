[CmdletBinding()]
param(
    [switch]$Generate,
    [string]$OutputPath = (Join-Path (Split-Path -Parent $PSScriptRoot) 'shots/west-infantry-concept.png')
)

$apiKey = [Environment]::GetEnvironmentVariable('OPENROUTER_API_KEY', 'Process')
if ([string]::IsNullOrWhiteSpace($apiKey)) {
    $apiKey = [Environment]::GetEnvironmentVariable('OPENROUTER_API_KEY', 'User')
}
if ([string]::IsNullOrWhiteSpace($apiKey)) {
    throw 'OPENROUTER_API_KEY is missing.'
}
$headers = @{ Authorization = 'Bearer ' + $apiKey.Trim() }

if (-not $Generate) {
    $keyInfo = Invoke-RestMethod -Uri 'https://openrouter.ai/api/v1/key' -Headers $headers -MaximumRedirection 0 -TimeoutSec 20 -ErrorAction Stop
    if ($null -eq $keyInfo.data -or $keyInfo.data.is_management_key -or $keyInfo.data.is_provisioning_key) {
        throw 'OpenRouter must be configured with a regular workspace API key.'
    }
    Write-Output 'OpenRouter API key verified. No image requested.'
    return
}

$path = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($OutputPath)
if ([IO.Path]::GetExtension($path) -ne '.png' -or (Test-Path -LiteralPath $path)) {
    throw 'OutputPath must name a new PNG file.'
}
$parent = [IO.Path]::GetDirectoryName($path)
[IO.Directory]::CreateDirectory($parent) | Out-Null

$request = @{
    model = 'black-forest-labs/flux.2-klein-4b'
    prompt = 'One original Westbund infantry character for the RTS Stahlfront. Front orthographic full-body reference, centered and uncropped, symmetrical neutral A-pose, fingers relaxed, empty hands and all limbs fully visible. Near-future industrial infantry uniform, slate-gray armor, distinctive cool-blue shoulder plates, low helmet with a dark visor, sturdy boots, compact equipment close to the body. Natural adult proportions and a silhouette readable from a high game camera. Neutral studio background and even light. No weapon, props, letters, logos, or pedestal.'
    aspect_ratio = '3:4'
    output_format = 'png'
    n = 1
} | ConvertTo-Json -Compress
$response = Invoke-RestMethod -Method Post -Uri 'https://openrouter.ai/api/v1/images' -Headers $headers -MaximumRedirection 0 -TimeoutSec 120 -ContentType 'application/json' -Body $request -ErrorAction Stop
$encoded = @($response.data)[0].b64_json
if ([string]::IsNullOrWhiteSpace($encoded) -or -not $encoded.StartsWith('iVBORw0KGgo')) {
    throw 'OpenRouter did not return a PNG image.'
}
$bytes = [Convert]::FromBase64String($encoded)
$file = [IO.File]::Open($path, [IO.FileMode]::CreateNew)
try {
    $file.Write($bytes, 0, $bytes.Length)
} finally {
    $file.Dispose()
}
Write-Output $path
