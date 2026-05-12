param(
    [Parameter(Mandatory = $true)]
    [string]$Prompt
)

$ErrorActionPreference = "Stop"

$preferredRoots = @(
    "D:\code",
    "C:\Users\zhang"
)

$skillRoot = Split-Path -Parent $PSScriptRoot
$aliasFile = Join-Path $skillRoot "workspace-aliases.json"

$stopNames = @(
    "repo", "repository", "workspace", "project", "dir", "folder", "code"
)

function Normalize-Separators {
    param([string]$Value)
    $normalized = ($Value -replace '/', '\').Trim()

    # Support inputs like "d:code\repo" by normalizing them to "D:\code\repo".
    if ($normalized -match '^(?i)([A-Z]):(?!\\)(.+)$') {
        return ("{0}:\{1}" -f $matches[1].ToUpperInvariant(), $matches[2].TrimStart('\'))
    }

    return $normalized
}

function Get-AbsolutePathFromPrompt {
    param([string]$Text)

    $match = [regex]::Match($Text, '(?i)([A-Z]:[^\s,;"''\r\n]+)')
    if ($match.Success) {
        return (Normalize-Separators $match.Groups[1].Value).TrimEnd('\')
    }
    return $null
}

function Get-RelativePathHints {
    param([string]$Text)

    $matches = [regex]::Matches($Text, '(?i)\b([A-Za-z][A-Za-z0-9._-]*[\\/][A-Za-z0-9._\\/-]+)\b')
    foreach ($match in $matches) {
        $value = (Normalize-Separators $match.Groups[1].Value).TrimEnd('\')
        if ($value) {
            $value
        }
    }
}

function Convert-ParentHintToPath {
    param([string]$Hint)

    if (-not $Hint) {
        return $null
    }

    if ($Hint -match '^[A-Z]:\\') {
        return $Hint
    }

    if ($Hint -match '^(?i)d\\code$') {
        return "D:\code"
    }

    foreach ($root in $preferredRoots) {
        $candidate = Join-Path $root $Hint
        if (Test-Path -LiteralPath $candidate -PathType Container) {
            return $candidate
        }
    }

    return $null
}

function Get-ProjectNameHints {
    param([string]$Text)

    $results = New-Object System.Collections.Generic.List[string]

    $inlineMatches = [regex]::Matches($Text, '(?i)(?:进入|进到|进|到|去|切到|切换到)([A-Za-z0-9]+(?:[._-][A-Za-z0-9]+)*)(?:项目|工程|目录|文件夹|仓库|repo|repository|workspace|工作空间)')
    foreach ($match in $inlineMatches) {
        $value = $match.Groups[1].Value
        if ($value) {
            $results.Add($value)
        }
    }

    $matches = [regex]::Matches($Text, '(?i)\b([A-Za-z0-9]+(?:[._-][A-Za-z0-9]+)*)\b')
    foreach ($match in $matches) {
        $value = $match.Groups[1].Value
        if ($stopNames -contains $value.ToLowerInvariant()) {
            continue
        }
        if ($value.Length -eq 1 -and $value -match '^[A-Za-z]$') {
            continue
        }
        $results.Add($value)
    }
    return $results
}

function Get-WorkspaceAliases {
    if (-not (Test-Path -LiteralPath $aliasFile -PathType Leaf)) {
        return @{}
    }

    $raw = Get-Content -LiteralPath $aliasFile -Raw -Encoding UTF8 | ConvertFrom-Json -AsHashtable
    if ($null -eq $raw) {
        return @{}
    }

    $aliases = @{}
    foreach ($entry in $raw.GetEnumerator()) {
        if ([string]::IsNullOrWhiteSpace($entry.Key) -or [string]::IsNullOrWhiteSpace([string]$entry.Value)) {
            continue
        }

        $aliases[$entry.Key.ToLowerInvariant()] = (Normalize-Separators ([string]$entry.Value)).TrimEnd('\')
    }

    return $aliases
}

function Resolve-AliasPath {
    param(
        [string]$Text,
        [hashtable]$Aliases
    )

    if ($Aliases.Count -eq 0) {
        return $null
    }

    $lowerText = $Text.ToLowerInvariant()
    $matched = $Aliases.Keys |
        Where-Object { $lowerText.Contains($_) } |
        Sort-Object Length -Descending |
        Select-Object -First 1

    if (-not $matched) {
        return $null
    }

    return $Aliases[$matched]
}

function Find-ExistingProject {
    param([string]$Name)

    $nameVariants = [System.Collections.Generic.List[string]]::new()
    $nameVariants.Add($Name.ToLowerInvariant())
    if ($Name -ieq "ai") {
        $nameVariants.Add("all-in-ai")
    }

    $matches = foreach ($root in $preferredRoots) {
        if (-not (Test-Path -LiteralPath $root -PathType Container)) {
            continue
        }

        Get-ChildItem -LiteralPath $root -Directory -Recurse -ErrorAction SilentlyContinue |
            Where-Object { $nameVariants -contains $_.Name.ToLowerInvariant() } |
            Select-Object -ExpandProperty FullName
    }

    if (-not $matches) {
        return $null
    }

    return $matches |
        Sort-Object @{ Expression = { ($_ -split '[\\/]').Length } }, @{ Expression = { $_.Length } } |
        Select-Object -First 1
}

$aliases = Get-WorkspaceAliases
$resolvedPath = Resolve-AliasPath -Text $Prompt -Aliases $aliases
$mode = "alias"

if (-not $resolvedPath) {
    $resolvedPath = Get-AbsolutePathFromPrompt -Text $Prompt
    $mode = "absolute"
}

if (-not $resolvedPath) {
    $parentPath = $null
    foreach ($hint in (Get-RelativePathHints -Text $Prompt)) {
        $parentPath = Convert-ParentHintToPath -Hint $hint
        if ($parentPath) {
            break
        }
    }

    $projectNames = @(Get-ProjectNameHints -Text $Prompt)
    $projectName = $null
    if ($projectNames.Count -gt 0) {
        $projectName = $projectNames[-1]
    }

    if ($parentPath -and $projectName) {
        $resolvedPath = Join-Path $parentPath $projectName
        $mode = "parent-plus-name"
    } elseif ($projectName) {
        $resolvedPath = Find-ExistingProject -Name $projectName
        $mode = "existing-match"
        if (-not $resolvedPath) {
            $resolvedPath = Join-Path $preferredRoots[0] $projectName
            $mode = "missing-match"
        }
    } else {
        throw "Unable to resolve a target directory from prompt: $Prompt"
    }
}

$resolvedPath = [System.IO.Path]::GetFullPath($resolvedPath)
$exists = Test-Path -LiteralPath $resolvedPath -PathType Container

[pscustomobject]@{
    prompt = $Prompt
    targetPath = $resolvedPath
    exists = $exists
    mode = $mode
} | ConvertTo-Json -Compress
