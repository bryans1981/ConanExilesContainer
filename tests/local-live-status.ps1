param(
    [string]$EnvFile = '.env.local-live',
    [int]$LogTail = 800
)

$ErrorActionPreference = 'Continue'
$ProgressPreference = 'SilentlyContinue'

$script:RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$script:FailureCount = 0
$script:WarningCount = 0

function Add-Result {
    param(
        [string]$Status,
        [string]$Name,
        [string]$Detail
    )
    Write-Host "$Status $Name - $Detail"
}

function Add-Fail {
    param([string]$Name, [string]$Detail)
    $script:FailureCount++
    Add-Result 'FAIL' $Name $Detail
}

function Add-Warn {
    param([string]$Name, [string]$Detail)
    $script:WarningCount++
    Add-Result 'WARN' $Name $Detail
}

function Add-Pass {
    param([string]$Name, [string]$Detail)
    Add-Result 'PASS' $Name $Detail
}

function Read-EnvFile {
    param([string]$Path)

    $values = @{}
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

function Test-Truthy {
    param([string]$Value)
    if ([string]::IsNullOrEmpty($Value)) {
        return $false
    }
    return @('true', 'yes', '1') -contains $Value.ToLowerInvariant()
}

function Get-MapValue {
    param(
        [hashtable]$Map,
        [string]$Name,
        [string]$Default
    )

    if ($Map.ContainsKey($Name) -and -not [string]::IsNullOrWhiteSpace($Map[$Name])) {
        return $Map[$Name]
    }
    return $Default
}

function Get-DirectorySize {
    param([string]$Path)

    if (-not (Test-Path -LiteralPath $Path -PathType Container)) {
        return 0
    }

    $sum = 0
    Get-ChildItem -LiteralPath $Path -Recurse -File -Force -ErrorAction SilentlyContinue | ForEach-Object {
        $sum += $_.Length
    }
    return $sum
}

function Format-Bytes {
    param([long]$Bytes)

    if ($Bytes -ge 1GB) {
        return '{0:N2} GiB' -f ($Bytes / 1GB)
    }
    if ($Bytes -ge 1MB) {
        return '{0:N2} MiB' -f ($Bytes / 1MB)
    }
    if ($Bytes -ge 1KB) {
        return '{0:N2} KiB' -f ($Bytes / 1KB)
    }
    return "$Bytes B"
}

Push-Location $script:RepoRoot
try {
    if (-not (Test-Path -LiteralPath $EnvFile -PathType Leaf)) {
        Add-Fail 'env-file' "Missing local env file: $EnvFile"
        exit 1
    }

    $resolvedEnvFile = (Resolve-Path -LiteralPath $EnvFile).Path
    $envValues = Read-EnvFile -Path $resolvedEnvFile
    $composeArgs = @('--env-file', $resolvedEnvFile)
    $service = 'conan'

    Add-Pass 'env-file' "Using ignored local env file: $EnvFile"

    $global:LASTEXITCODE = 0
    $containerOutput = & docker compose @composeArgs ps -q $service 2>&1
    $containerExit = $LASTEXITCODE
    $containerId = ($containerOutput | Where-Object { -not [string]::IsNullOrWhiteSpace($_.ToString()) } | Select-Object -First 1).ToString().Trim()
    if ($containerExit -ne 0 -or [string]::IsNullOrWhiteSpace($containerId)) {
        Add-Fail 'compose-service' 'Compose service is not running or no container ID was returned.'
    } else {
        Add-Pass 'compose-service' "Container ID $($containerId.Substring(0, [Math]::Min(12, $containerId.Length)))"

        $global:LASTEXITCODE = 0
        $stateJson = (& docker inspect $containerId --format '{{json .State}}' 2>$null) -join "`n"
        $stateExit = $LASTEXITCODE
        if ($stateExit -eq 0 -and -not [string]::IsNullOrWhiteSpace($stateJson)) {
            $state = $stateJson | ConvertFrom-Json
            if ($state.Running) {
                Add-Pass 'container-state' "Running since $($state.StartedAt)"
            } else {
                Add-Fail 'container-state' "Not running; status=$($state.Status), exit_code=$($state.ExitCode)"
            }
        } else {
            Add-Fail 'container-state' 'Could not inspect container state.'
        }

        $global:LASTEXITCODE = 0
        $portsJson = (& docker inspect $containerId --format '{{json .NetworkSettings.Ports}}' 2>$null) -join "`n"
        $portsExit = $LASTEXITCODE
        if ($portsExit -eq 0 -and -not [string]::IsNullOrWhiteSpace($portsJson)) {
            $ports = $portsJson | ConvertFrom-Json
            $requiredPorts = @(
                "$(Get-MapValue $envValues 'GAME_PORT' '7777')/udp",
                "$(Get-MapValue $envValues 'PINGER_PORT' '7778')/udp",
                "$(Get-MapValue $envValues 'QUERY_PORT' '27015')/udp"
            )
            if (Test-Truthy (Get-MapValue $envValues 'RCON_ENABLED' 'true')) {
                $requiredPorts += "$(Get-MapValue $envValues 'RCON_PORT' '25575')/tcp"
            }

            foreach ($port in $requiredPorts) {
                $property = $ports.PSObject.Properties[$port]
                if ($null -eq $property -or $null -eq $property.Value) {
                    Add-Fail 'published-port' "$port is not published."
                    continue
                }

                $mapping = @($property.Value)[0]
                Add-Pass 'published-port' "$port -> $($mapping.HostIp):$($mapping.HostPort)"
            }
        } else {
            Add-Fail 'published-port' 'Could not inspect published ports.'
        }
    }

    $global:LASTEXITCODE = 0
    $logs = (& docker compose @composeArgs logs --no-color --tail $LogTail $service 2>&1) -join "`n"
    $logsExit = $LASTEXITCODE
    if ($logsExit -ne 0) {
        Add-Fail 'recent-logs' 'Could not read compose logs.'
    } else {
        Add-Pass 'recent-logs' "Read last $LogTail log lines without printing them."

        if ($logs -match 'StartPlay') {
            Add-Pass 'readiness' 'StartPlay marker found in recent logs.'
        } else {
            Add-Fail 'readiness' 'StartPlay marker was not found in recent logs.'
        }

        if ($logs -match '(?im)\b(Fatal error|Cannot start:|Server process exited with code [1-9]|ERROR: (SteamCMD|DepotDownloader|DOWNLOAD_BACKEND|MOD_DOWNLOAD_BACKEND|Invalid))\b') {
            Add-Warn 'fatal-scan' 'Recent logs contain a fatal/error-looking line; inspect logs manually.'
        } else {
            Add-Pass 'fatal-scan' 'No known fatal startup pattern found in recent logs.'
        }

        $secretKeys = @('SERVER_PASSWORD', 'ADMIN_PASSWORD', 'RCON_PASSWORD')
        $leakFound = $false
        foreach ($key in $secretKeys) {
            $value = $envValues[$key]
            if (-not [string]::IsNullOrEmpty($value) -and $logs.Contains($value)) {
                $leakFound = $true
            }
        }

        $logRoot = Join-Path $script:RepoRoot 'data\logs'
        if (Test-Path -LiteralPath $logRoot -PathType Container) {
            Get-ChildItem -LiteralPath $logRoot -Recurse -File -Force -ErrorAction SilentlyContinue | ForEach-Object {
                $content = Get-Content -LiteralPath $_.FullName -Raw -ErrorAction SilentlyContinue
                foreach ($key in $secretKeys) {
                    $value = $envValues[$key]
                    if (-not [string]::IsNullOrEmpty($value) -and $content.Contains($value)) {
                        $leakFound = $true
                    }
                }
            }
        }

        if ($leakFound) {
            Add-Fail 'password-leak-scan' 'A password value from the env file appeared in retained logs.'
        } else {
            Add-Pass 'password-leak-scan' 'No env password values found in recent Docker logs or retained server logs.'
        }
    }

    $dataRoot = Join-Path $script:RepoRoot 'data'
    foreach ($name in @('serverfiles', 'steam', 'config', 'logs', 'backups')) {
        $path = Join-Path $dataRoot $name
        $size = Get-DirectorySize -Path $path
        Add-Result 'INFO' 'disk-usage' "$name=$(Format-Bytes $size)"
    }

    Write-Host ""
    Write-Host "Summary: failures=$script:FailureCount warnings=$script:WarningCount"
    if ($script:FailureCount -gt 0) {
        exit 1
    }
    exit 0
} finally {
    Pop-Location
}
