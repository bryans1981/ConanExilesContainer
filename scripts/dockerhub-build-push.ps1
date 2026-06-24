param(
    [string]$Repository = 'docker.io/bryans1981/conanexilescontainer',
    [string]$VersionTag = '',
    [switch]$Build,
    [switch]$Push
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path

function Write-Step {
    param([string]$Message)
    Write-Host "INFO $Message"
}

function Invoke-Step {
    param([string[]]$Command)

    Write-Host ('RUN  ' + ($Command -join ' '))
    & $Command[0] @($Command | Select-Object -Skip 1)
}

function Get-DockerLoginHint {
    $configPath = Join-Path $env:USERPROFILE '.docker\config.json'
    if (-not (Test-Path -LiteralPath $configPath -PathType Leaf)) {
        return 'No Docker CLI config file was found.'
    }

    try {
        $config = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json
    } catch {
        return 'Docker CLI config exists but could not be parsed.'
    }

    $authNames = @()
    if ($null -ne $config.auths) {
        $authNames = @($config.auths.PSObject.Properties.Name)
    }

    $hasDockerHubAuth = $false
    foreach ($name in $authNames) {
        if ($name -match '^(https://index\.docker\.io/v1/|docker\.io|index\.docker\.io)$') {
            $hasDockerHubAuth = $true
        }
    }

    if ($hasDockerHubAuth) {
        return 'Docker Hub auth entry is present in Docker CLI config.'
    }
    if (-not [string]::IsNullOrWhiteSpace($config.credsStore)) {
        return "Docker credential store '$($config.credsStore)' is configured; Docker Hub login cannot be fully verified without pushing."
    }
    if ($authNames.Count -gt 0) {
        return 'Docker CLI config has auth entries, but none are clearly Docker Hub.'
    }
    return 'Docker CLI config has no auth entries.'
}

Push-Location $repoRoot
try {
    $dockerVersion = (& docker version --format '{{.Client.Version}}' 2>$null) -join ''
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($dockerVersion)) {
        throw 'Docker CLI is not installed or Docker is not reachable.'
    }
    Write-Step "Docker client version: $dockerVersion"

    $shortSha = (& git rev-parse --short=12 HEAD 2>$null) -join ''
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($shortSha)) {
        throw 'Could not determine git short SHA.'
    }

    $tags = @(
        "${Repository}:latest",
        "${Repository}:${shortSha}"
    )
    if (-not [string]::IsNullOrWhiteSpace($VersionTag)) {
        $tags += "${Repository}:${VersionTag}"
    }

    Write-Step "Target repository: $Repository"
    Write-Step 'Tags:'
    foreach ($tag in $tags) {
        Write-Host "TAG  $tag"
    }

    $loginHint = Get-DockerLoginHint
    Write-Step "Docker Hub login check: $loginHint"

    $willExecute = $Build -or $Push
    if (-not $willExecute) {
        Write-Step 'Dry run only. Pass -Build to build/tag locally or -Push to build/tag/push.'
        Write-Host 'PLAN docker build with all listed tags .'
        if ($Push) {
            foreach ($tag in $tags) {
                Write-Host "PLAN docker push $tag"
            }
        }
        exit 0
    }

    $buildArgs = @('docker', 'build')
    foreach ($tag in $tags) {
        $buildArgs += @('-t', $tag)
    }
    $buildArgs += '.'
    Invoke-Step $buildArgs

    Write-Step 'Built image tags:'
    foreach ($tag in $tags) {
        Write-Host "TAG  $tag"
    }

    if ($Push) {
        if ($loginHint -match '^No Docker CLI config|no auth entries|none are clearly Docker Hub') {
            throw 'Docker Hub login was not verified. Run docker login docker.io, confirm the repository target, then retry -Push.'
        }
        foreach ($tag in $tags) {
            Invoke-Step @('docker', 'push', $tag)
        }
        Write-Step 'Push complete.'
    } else {
        Write-Step 'Push skipped because -Push was not passed.'
    }
} finally {
    Pop-Location
}
