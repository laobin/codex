param(
    [string]$Project,
    [string]$WorkspacePath = (Get-Location).Path,
    [string]$BaseUrl = $env:DEPLOY_API_BASE_URL,
    [switch]$Health,
    [int]$TimeoutSeconds = 30
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($BaseUrl)) {
    $BaseUrl = "http://120.79.75.254:888"
}

$BaseUrl = $BaseUrl.TrimEnd("/")
$SkillRoot = Split-Path -Parent $PSScriptRoot
$AliasFile = Join-Path $SkillRoot "project-aliases.json"

function Normalize-PathKey {
    param([string]$Path)

    if ([string]::IsNullOrWhiteSpace($Path)) {
        return $null
    }

    try {
        return ([System.IO.Path]::GetFullPath($Path.Trim()) -replace '/', '\').TrimEnd('\').ToLowerInvariant()
    } catch {
        return ($Path.Trim() -replace '/', '\').TrimEnd('\').ToLowerInvariant()
    }
}

function Get-ProjectAliases {
    if (-not (Test-Path -LiteralPath $AliasFile -PathType Leaf)) {
        return [pscustomobject]@{
            pathAliases = @{}
            nameAliases = @{}
        }
    }

    $raw = Get-Content -LiteralPath $AliasFile -Raw -Encoding UTF8 | ConvertFrom-Json
    $pathAliases = @{}
    $nameAliases = @{}

    if ($raw.pathAliases) {
        foreach ($prop in $raw.pathAliases.PSObject.Properties) {
            $key = Normalize-PathKey $prop.Name
            if ($key -and -not [string]::IsNullOrWhiteSpace([string]$prop.Value)) {
                $pathAliases[$key] = [string]$prop.Value
            }
        }
    }

    if ($raw.nameAliases) {
        foreach ($prop in $raw.nameAliases.PSObject.Properties) {
            $key = $prop.Name.ToLowerInvariant()
            if ($key -and -not [string]::IsNullOrWhiteSpace([string]$prop.Value)) {
                $nameAliases[$key] = [string]$prop.Value
            }
        }
    }

    return [pscustomobject]@{
        pathAliases = $pathAliases
        nameAliases = $nameAliases
    }
}

function Resolve-ProjectFromWorkspace {
    param([string]$Path)

    $aliases = Get-ProjectAliases
    $current = [System.IO.DirectoryInfo]::new([System.IO.Path]::GetFullPath($Path))

    while ($null -ne $current) {
        $pathKey = Normalize-PathKey $current.FullName
        if ($aliases.pathAliases.ContainsKey($pathKey)) {
            return $aliases.pathAliases[$pathKey]
        }

        $nameKey = $current.Name.ToLowerInvariant()
        if ($aliases.nameAliases.ContainsKey($nameKey)) {
            return $aliases.nameAliases[$nameKey]
        }

        $current = $current.Parent
    }

    return $null
}

function New-Md5Hex {
    param([string]$Value)

    $md5 = [System.Security.Cryptography.MD5]::Create()
    try {
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($Value)
        $hash = $md5.ComputeHash($bytes)
        return -join ($hash | ForEach-Object { $_.ToString("x2") })
    } finally {
        $md5.Dispose()
    }
}

function New-DeploySign {
    param(
        [hashtable]$Params,
        [string]$Secret
    )

    $parts = foreach ($key in ($Params.Keys | Sort-Object)) {
        $value = $Params[$key]
        if ($key -ne "sign" -and $null -ne $value) {
            "{0}={1}" -f $key, ([string]$value)
        }
    }
    return New-Md5Hex (($parts -join "&") + $Secret)
}

function Invoke-DeployApi {
    param(
        [ValidateSet("GET", "POST")]
        [string]$Method,
        [string]$Uri,
        [object]$Body = $null
    )

    $handler = [System.Net.Http.HttpClientHandler]::new()
    $handler.UseProxy = $false
    $client = [System.Net.Http.HttpClient]::new($handler)
    $client.Timeout = [TimeSpan]::FromSeconds($TimeoutSeconds)

    try {
        if ($Method -eq "GET") {
            $response = $client.GetAsync($Uri).GetAwaiter().GetResult()
        } else {
            $json = $Body | ConvertTo-Json -Compress
            $content = [System.Net.Http.StringContent]::new(
                $json,
                [System.Text.Encoding]::UTF8,
                "application/json"
            )
            $response = $client.PostAsync($Uri, $content).GetAwaiter().GetResult()
        }

        $text = $response.Content.ReadAsStringAsync().GetAwaiter().GetResult()
        if (-not $response.IsSuccessStatusCode) {
            throw ("HTTP {0}: {1}" -f [int]$response.StatusCode, $text)
        }
        if ([string]::IsNullOrWhiteSpace($text)) {
            return $null
        }
        return $text | ConvertFrom-Json
    } finally {
        $client.Dispose()
        $handler.Dispose()
    }
}

if ($Health) {
    $result = Invoke-DeployApi -Method GET -Uri "$BaseUrl/api/health"
    $result | ConvertTo-Json -Depth 8
    exit 0
}

if ([string]::IsNullOrWhiteSpace($Project)) {
    $Project = Resolve-ProjectFromWorkspace -Path $WorkspacePath
}

if ([string]::IsNullOrWhiteSpace($Project)) {
    throw "Project is required or must be resolvable from project-aliases.json. Example: -Project cms"
}

if ($Project.Contains("/") -or $Project.Contains("\") -or $Project.Contains("..")) {
    throw "Invalid project name: $Project"
}

$secret = $env:DEPLOY_API_SECRET
if ([string]::IsNullOrWhiteSpace($secret)) {
    $secret = [Environment]::GetEnvironmentVariable("DEPLOY_API_SECRET", "User")
}
if ([string]::IsNullOrWhiteSpace($secret)) {
    $secret = [Environment]::GetEnvironmentVariable("DEPLOY_API_SECRET", "Machine")
}
if ([string]::IsNullOrWhiteSpace($secret)) {
    throw "DEPLOY_API_SECRET is not set in the environment."
}

$timestamp = [int][DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
$params = @{
    project = $Project
    timestamp = $timestamp
}
$sign = New-DeploySign -Params $params -Secret $secret
$body = @{
    project = $Project
    timestamp = $timestamp
    sign = $sign
}

$result = Invoke-DeployApi -Method POST -Uri "$BaseUrl/api/update" -Body $body
$result | ConvertTo-Json -Depth 8
