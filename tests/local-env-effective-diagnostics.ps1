param(
    [string]$EnvFile = '.env.local-live',
    [string]$ServiceName = 'conan',
    [string]$ExpectedServerName = 'WickedServerContianer',
    [string]$ExpectedServerRegion = '1',
    [switch]$AllowBlankPasswords
)

$ErrorActionPreference = 'Continue'
$ProgressPreference = 'SilentlyContinue'

$script:RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$script:FailureCount = 0
$script:WarningCount = 0

function Add-Result {
    param([string]$Status, [string]$Name, [string]$Detail)
    Write-Host "$Status $Name - $Detail"
}

function Add-Pass { param([string]$Name, [string]$Detail) Add-Result 'PASS' $Name $Detail }
function Add-Info { param([string]$Name, [string]$Detail) Add-Result 'INFO' $Name $Detail }
function Add-Warn { param([string]$Name, [string]$Detail) $script:WarningCount++; Add-Result 'WARN' $Name $Detail }
function Add-Fail { param([string]$Name, [string]$Detail) $script:FailureCount++; Add-Result 'FAIL' $Name $Detail }

function Read-EnvFile {
    param([string]$Path)

    $values = @{}
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        return $values
    }

    foreach ($line in Get-Content -LiteralPath $Path) {
        if ($line -match '^\s*#' -or $line -match '^\s*$') {
            continue
        }
        if ($line -match '^\s*([^=\s]+)\s*=\s*(.*)\s*$') {
            $values[$matches[1]] = $matches[2]
        }
    }
    return $values
}

function Get-MapValue {
    param([hashtable]$Map, [string]$Name)
    if ($Map.ContainsKey($Name)) {
        return $Map[$Name]
    }
    return $null
}

function Get-ObjectValue {
    param([object]$Object, [string]$Name)
    if ($null -eq $Object) {
        return $null
    }
    $property = $Object.PSObject.Properties[$Name]
    if ($null -eq $property) {
        return $null
    }
    return [string]$property.Value
}

function Convert-ServerRegionValue {
    param([string]$Value)

    if ([string]::IsNullOrWhiteSpace($Value)) {
        return '1'
    }

    $normalized = $Value.ToLowerInvariant() -replace '[\s_-]', ''
    switch ($normalized) {
        '0' { return '0' }
        'europe' { return '0' }
        'eu' { return '0' }
        '1' { return '1' }
        'america' { return '1' }
        'northamerica' { return '1' }
        'na' { return '1' }
        'us' { return '1' }
        'usa' { return '1' }
        'unitedstates' { return '1' }
        '2' { return '2' }
        'asia' { return '2' }
        '3' { return '3' }
        'australia' { return '3' }
        'oceania' { return '3' }
        '4' { return '4' }
        'southamerica' { return '4' }
        'sa' { return '4' }
        '5' { return '5' }
        'japan' { return '5' }
        'jp' { return '5' }
        default { return $null }
    }
}

function Format-EnvValue {
    param([string]$Name, [string]$Value)
    if ($null -eq $Value) {
        return '<missing>'
    }
    if ($Name -match 'PASSWORD') {
        if ([string]::IsNullOrEmpty($Value)) {
            return '<blank>'
        }
        return '<set>'
    }
    if ([string]::IsNullOrEmpty($Value)) {
        return '<blank>'
    }
    return $Value
}

function Test-RequiredValue {
    param([string]$Scope, [string]$Name, [string]$Value)
    if ($null -eq $Value) {
        Add-Fail "$Scope.$Name" 'Missing.'
        return
    }
    if (($Name -match 'PASSWORD') -and -not $AllowBlankPasswords -and [string]::IsNullOrEmpty($Value)) {
        Add-Fail "$Scope.$Name" 'Blank during password-protected local live test.'
        return
    }
    Add-Pass "$Scope.$Name" (Format-EnvValue -Name $Name -Value $Value)
}

Push-Location $script:RepoRoot
try {
    $envNames = @(
        'SERVER_NAME',
        'SERVER_PASSWORD',
        'ADMIN_PASSWORD',
        'SERVER_REGION',
        'GAME_PORT',
        'PINGER_PORT',
        'QUERY_PORT',
        'RCON_ENABLED',
        'RCON_PORT',
        'RCON_PASSWORD',
        'DOWNLOAD_BACKEND',
        'MOD_DOWNLOAD_BACKEND',
        'WORKSHOP_MOD_IDS',
        'FORCE_QUERY_PORT_ARG',
        'MULTIHOME_IP',
        'MULTIHOME_HTTP_IP',
        'EXTRA_ARGS'
    )

    Write-Host 'Local env effective diagnostics'
    Write-Host ''

    $resolvedEnvFile = $null
    $composeArgs = @()
    if (Test-Path -LiteralPath $EnvFile -PathType Leaf) {
        $resolvedEnvFile = (Resolve-Path -LiteralPath $EnvFile).Path
        $composeArgs = @('--env-file', $resolvedEnvFile)
        Add-Pass 'env-file' $resolvedEnvFile
    } else {
        Add-Fail 'env-file' "Missing env file: $EnvFile"
    }

    $envFileValues = Read-EnvFile -Path $EnvFile
    foreach ($name in $envNames) {
        $value = Get-MapValue -Map $envFileValues -Name $name
        Add-Info "env-file.$name" (Format-EnvValue -Name $name -Value $value)
    }

    $composeEnvironment = $null
    if ($resolvedEnvFile) {
        $configRaw = (& docker compose @composeArgs config --format json 2>$null) -join "`n"
        if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($configRaw)) {
            try {
                $config = $configRaw | ConvertFrom-Json
                $service = $config.services.PSObject.Properties[$ServiceName].Value
                if ($service -and $service.environment) {
                    $composeEnvironment = $service.environment
                    Add-Pass 'compose-config' "Read service environment for $ServiceName."
                } else {
                    Add-Fail 'compose-config' "Service environment for $ServiceName was not found."
                }
            } catch {
                Add-Fail 'compose-config' "Could not parse docker compose config JSON: $($_.Exception.Message)"
            }
        } else {
            Add-Fail 'compose-config' 'docker compose config --format json failed.'
        }
    }

    if ($composeEnvironment) {
        foreach ($name in $envNames) {
            $value = Get-ObjectValue -Object $composeEnvironment -Name $name
            Add-Info "compose.$name" (Format-EnvValue -Name $name -Value $value)
        }
    }

    $containerId = $null
    if ($resolvedEnvFile) {
        $containerOutput = & docker compose @composeArgs ps -q $ServiceName 2>$null
        if ($LASTEXITCODE -eq 0) {
            $containerId = ($containerOutput | Where-Object { -not [string]::IsNullOrWhiteSpace($_.ToString()) } | Select-Object -First 1).ToString().Trim()
        }
    }

    if ([string]::IsNullOrWhiteSpace($containerId)) {
        Add-Fail 'container' "No running or created compose container found for service $ServiceName."
    } else {
        Add-Pass 'container' $containerId.Substring(0, [Math]::Min(12, $containerId.Length))

        $labelsRaw = (& docker inspect $containerId --format '{{json .Config.Labels}}' 2>$null) -join ''
        $labelEnvFile = ''
        if (-not [string]::IsNullOrWhiteSpace($labelsRaw)) {
            try {
                $labels = $labelsRaw | ConvertFrom-Json
                $labelProperty = $labels.PSObject.Properties['com.docker.compose.project.environment_file']
                if ($labelProperty) {
                    $labelEnvFile = [string]$labelProperty.Value
                }
            } catch {
                $labelEnvFile = ''
            }
        }
        if ([string]::IsNullOrWhiteSpace($labelEnvFile)) {
            Add-Warn 'container.env-file-label' 'Compose did not record an environment file label.'
        } else {
            Add-Info 'container.env-file-label' $labelEnvFile
        }

        $containerEnvLines = & docker inspect $containerId --format '{{range .Config.Env}}{{println .}}{{end}}' 2>$null
        $containerEnv = @{}
        foreach ($line in $containerEnvLines) {
            if ($line -match '^([^=]+)=(.*)$') {
                $containerEnv[$matches[1]] = $matches[2]
            }
        }

        foreach ($name in $envNames) {
            $value = Get-MapValue -Map $containerEnv -Name $name
            if ($name -in @('SERVER_NAME', 'SERVER_PASSWORD', 'ADMIN_PASSWORD', 'SERVER_REGION', 'GAME_PORT', 'PINGER_PORT', 'QUERY_PORT')) {
                Test-RequiredValue -Scope 'container-env' -Name $name -Value $value
            } else {
                Add-Info "container-env.$name" (Format-EnvValue -Name $name -Value $value)
            }
        }

        $containerServerName = Get-MapValue -Map $containerEnv -Name 'SERVER_NAME'
        if ($containerServerName -eq 'Conan Exiles Server') {
            Add-Fail 'container-env.SERVER_NAME' 'Still using default server name during local live test.'
        } elseif ($containerServerName -ne $ExpectedServerName) {
            Add-Fail 'container-env.SERVER_NAME' "Expected $ExpectedServerName but found $containerServerName."
        } else {
            Add-Pass 'container-env.SERVER_NAME.expected' $ExpectedServerName
        }

        $containerServerRegion = Get-MapValue -Map $containerEnv -Name 'SERVER_REGION'
        $containerServerRegionNormalized = Convert-ServerRegionValue $containerServerRegion
        $expectedServerRegionNormalized = Convert-ServerRegionValue $ExpectedServerRegion
        if ($null -eq $containerServerRegionNormalized) {
            Add-Fail 'container-env.SERVER_REGION.expected' "Invalid SERVER_REGION value: $containerServerRegion."
        } elseif ($null -eq $expectedServerRegionNormalized) {
            Add-Fail 'container-env.SERVER_REGION.expected' "Invalid expected SERVER_REGION value: $ExpectedServerRegion."
        } elseif ($containerServerRegionNormalized -ne $expectedServerRegionNormalized) {
            Add-Fail 'container-env.SERVER_REGION.expected' "Expected $ExpectedServerRegion but found $(if ($null -eq $containerServerRegion) { '<missing>' } else { $containerServerRegion })."
        } else {
            Add-Pass 'container-env.SERVER_REGION.expected' "$containerServerRegion -> $containerServerRegionNormalized"
        }
    }

    Write-Host ''
    Write-Host "Summary: failures=$script:FailureCount warnings=$script:WarningCount"
    if ($script:FailureCount -gt 0) {
        exit 1
    }
    exit 0
} finally {
    Pop-Location
}
