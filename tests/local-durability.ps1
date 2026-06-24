param(
    [string]$EnvFile = '.env.local-live',
    [switch]$Quick,
    [switch]$KeepRunning,
    [switch]$SkipClientReminder
)

$ErrorActionPreference = 'Continue'
$ProgressPreference = 'SilentlyContinue'

$script:RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$script:FailureCount = 0
$script:WarningCount = 0
$script:ServiceName = 'conan'
$script:LogTail = if ($Quick) { 600 } else { 1200 }
$script:ReadyTimeoutSeconds = if ($Quick) { 300 } else { 600 }

function Add-Result {
    param([string]$Status, [string]$Name, [string]$Detail)
    Write-Host "$Status $Name - $Detail"
}

function Add-Pass { param([string]$Name, [string]$Detail) Add-Result 'PASS' $Name $Detail }
function Add-Info { param([string]$Name, [string]$Detail) Add-Result 'INFO' $Name $Detail }
function Add-Warn { param([string]$Name, [string]$Detail) $script:WarningCount++; Add-Result 'WARN' $Name $Detail }
function Add-Fail { param([string]$Name, [string]$Detail) $script:FailureCount++; Add-Result 'FAIL' $Name $Detail }

function Invoke-Quiet {
    param([string]$Name, [string[]]$Command)

    $global:LASTEXITCODE = 0
    $output = & $Command[0] @($Command | Select-Object -Skip 1) 2>&1
    $exitCode = $LASTEXITCODE
    if ($exitCode -eq 0) {
        Add-Pass $Name 'Command succeeded.'
    } else {
        Add-Fail $Name "Command failed with exit code $exitCode. Output withheld to avoid leaking secrets."
    }
    return @{ ExitCode = $exitCode; Output = $output }
}

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
    param([hashtable]$Map, [string]$Name, [string]$Default)
    if ($Map.ContainsKey($Name) -and -not [string]::IsNullOrWhiteSpace($Map[$Name])) {
        return $Map[$Name]
    }
    return $Default
}

function Test-Truthy {
    param([string]$Value)
    if ([string]::IsNullOrWhiteSpace($Value)) {
        return $false
    }
    return @('true', 'yes', '1', 'on') -contains $Value.ToLowerInvariant()
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

function Read-IniFile {
    param([string]$Path)

    $values = @{}
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        return $values
    }

    $section = ''
    foreach ($line in Get-Content -LiteralPath $Path) {
        $trimmed = $line.Trim()
        if ($trimmed -match '^\s*[;#]' -or $trimmed -eq '') {
            continue
        }
        if ($trimmed -match '^\[(.+)\]\s*$') {
            $section = $matches[1]
            continue
        }
        if ($trimmed -match '^([^=]+?)\s*=\s*(.*)$') {
            $key = $matches[1].Trim()
            $values["$section`n$key"] = $matches[2]
        }
    }
    return $values
}

function Get-IniValue {
    param([hashtable]$Ini, [string]$Section, [string]$Key)
    $mapKey = "$Section`n$Key"
    if ($Ini.ContainsKey($mapKey)) {
        return $Ini[$mapKey]
    }
    return $null
}

function Get-ContainerId {
    param([string[]]$ComposeArgs)

    $global:LASTEXITCODE = 0
    $output = & docker compose @ComposeArgs ps -q $script:ServiceName 2>$null
    if ($LASTEXITCODE -ne 0) {
        return $null
    }
    $first = $output | Where-Object { -not [string]::IsNullOrWhiteSpace($_.ToString()) } | Select-Object -First 1
    if ($null -eq $first) {
        return $null
    }
    $containerId = $first.ToString().Trim()
    if ([string]::IsNullOrWhiteSpace($containerId)) {
        return $null
    }
    return $containerId
}

function Get-ContainerState {
    param([string]$ContainerId)

    if ([string]::IsNullOrWhiteSpace($ContainerId)) {
        return $null
    }

    $global:LASTEXITCODE = 0
    $json = (& docker inspect $ContainerId --format '{{json .State}}' 2>$null) -join "`n"
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($json)) {
        return $null
    }
    return $json | ConvertFrom-Json
}

function Test-ExpectedValue {
    param([string]$Name, [string]$Value, [string]$Expected)
    if ($null -eq $Value) {
        Add-Fail $Name "Missing; expected $Expected."
    } elseif ($Value -ne $Expected) {
        Add-Fail $Name "Expected $Expected but found $Value."
    } else {
        Add-Pass $Name $Expected
    }
}

function Test-SecretPresent {
    param([string]$Name, [string]$Value)
    if ($null -eq $Value) {
        Add-Fail $Name 'Missing.'
    } elseif ([string]::IsNullOrEmpty($Value)) {
        Add-Fail $Name 'Blank; durability test expects password-protected local live config.'
    } else {
        Add-Pass $Name '<set>'
    }
}

function Get-DirectorySnapshot {
    param([string]$Path)

    if (-not (Test-Path -LiteralPath $Path -PathType Container)) {
        return @{ Exists = $false; FileCount = 0; TotalBytes = 0 }
    }

    $count = 0
    $bytes = 0
    Get-ChildItem -LiteralPath $Path -Recurse -File -Force -ErrorAction SilentlyContinue | ForEach-Object {
        $count++
        $bytes += $_.Length
    }
    return @{ Exists = $true; FileCount = $count; TotalBytes = $bytes }
}

function Get-BackupArchives {
    $backupRoot = Join-Path $script:RepoRoot 'data\backups'
    if (-not (Test-Path -LiteralPath $backupRoot -PathType Container)) {
        return @()
    }
    return @(Get-ChildItem -LiteralPath $backupRoot -Filter 'conan-backup-*.tar.gz' -File -ErrorAction SilentlyContinue)
}

function Wait-ForStartPlay {
    param([string[]]$ComposeArgs, [string]$Since, [int]$TimeoutSeconds)

    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    while ((Get-Date) -lt $deadline) {
        $containerId = Get-ContainerId -ComposeArgs $ComposeArgs
        if (-not [string]::IsNullOrWhiteSpace($containerId)) {
            $state = Get-ContainerState -ContainerId $containerId
            if ($null -ne $state -and $state.Running) {
                $logArgs = @('logs', '--tail', "$script:LogTail")
                if (-not [string]::IsNullOrWhiteSpace($Since)) {
                    $logArgs += @('--since', $Since)
                }
                $logArgs += $containerId
                $logs = (& docker @logArgs 2>$null) -join "`n"
                if ($logs -match 'StartPlay') {
                    Add-Pass 'readiness' 'StartPlay marker found.'
                    return $true
                }
            }
        }
        Start-Sleep -Seconds 10
    }

    Add-Fail 'readiness' "StartPlay marker was not found within $TimeoutSeconds seconds."
    return $false
}

function Test-ActiveConfig {
    param([string]$ContainerId)

    $activePath = (& docker exec $ContainerId bash -lc 'readlink -f /serverdata/serverfiles/ConanSandbox/Saved/Config/LinuxServer 2>/dev/null || true' 2>$null) -join ''
    if ([string]::IsNullOrWhiteSpace($activePath)) {
        Add-Fail 'active-config.container-path' 'Could not resolve active LinuxServer config path.'
    } else {
        Add-Pass 'active-config.container-path' $activePath
    }

    $configRoot = Join-Path $script:RepoRoot 'data\config\ConanSandbox\Saved\Config\LinuxServer'
    if (Test-Path -LiteralPath $configRoot -PathType Container) {
        Add-Pass 'active-config.host-path' $configRoot
    } else {
        Add-Fail 'active-config.host-path' "Missing $configRoot"
    }
}

function Test-ConfigValues {
    param([hashtable]$EnvValues)

    $configRoot = Join-Path $script:RepoRoot 'data\config\ConanSandbox\Saved\Config\LinuxServer'
    $serverSettingsPath = Join-Path $configRoot 'ServerSettings.ini'
    $enginePath = Join-Path $configRoot 'Engine.ini'

    $expectedName = Get-MapValue $EnvValues 'SERVER_NAME' 'Conan Exiles Server'
    $expectedRegionRaw = Get-MapValue $EnvValues 'SERVER_REGION' 'America'
    $expectedRegion = Convert-ServerRegionValue $expectedRegionRaw
    if ($null -eq $expectedRegion) {
        Add-Fail 'env.SERVER_REGION' "Invalid value: $expectedRegionRaw."
        $expectedRegion = $expectedRegionRaw
    }

    foreach ($path in @($serverSettingsPath, $enginePath)) {
        if (Test-Path -LiteralPath $path -PathType Leaf) {
            Add-Pass 'config-file' $path
        } else {
            Add-Fail 'config-file' "Missing $path"
        }
    }

    $serverSettings = Read-IniFile -Path $serverSettingsPath
    $engine = Read-IniFile -Path $enginePath

    Test-ExpectedValue 'Engine.ini ServerName' (Get-IniValue $engine 'OnlineSubsystem' 'ServerName') $expectedName
    Test-SecretPresent 'Engine.ini ServerPassword' (Get-IniValue $engine 'OnlineSubsystem' 'ServerPassword')
    Test-ExpectedValue 'ServerSettings.ini ServerName' (Get-IniValue $serverSettings 'ServerSettings' 'ServerName') $expectedName
    Test-SecretPresent 'ServerSettings.ini ServerPassword' (Get-IniValue $serverSettings 'ServerSettings' 'ServerPassword')
    Test-SecretPresent 'ServerSettings.ini AdminPassword' (Get-IniValue $serverSettings 'ServerSettings' 'AdminPassword')
    Test-ExpectedValue 'ServerSettings.ini serverRegion' (Get-IniValue $serverSettings 'ServerSettings' 'serverRegion') $expectedRegion
}

function Test-PublishedPorts {
    param([string]$ContainerId, [hashtable]$EnvValues)

    $json = (& docker inspect $ContainerId --format '{{json .NetworkSettings.Ports}}' 2>$null) -join "`n"
    if ([string]::IsNullOrWhiteSpace($json)) {
        Add-Fail 'published-port' 'Could not inspect published ports.'
        return
    }

    $ports = $json | ConvertFrom-Json
    $requiredPorts = @(
        "$(Get-MapValue $EnvValues 'GAME_PORT' '7777')/udp",
        "$(Get-MapValue $EnvValues 'PINGER_PORT' '7778')/udp",
        "$(Get-MapValue $EnvValues 'QUERY_PORT' '27015')/udp"
    )
    if (Test-Truthy (Get-MapValue $EnvValues 'RCON_ENABLED' 'false')) {
        $requiredPorts += "$(Get-MapValue $EnvValues 'RCON_PORT' '25575')/tcp"
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
}

function Test-ModList {
    param([string]$ContainerId)

    $script = @'
set -e
modlist="/serverdata/serverfiles/ConanSandbox/Mods/modlist.txt"
if [ ! -f "$modlist" ]; then
  echo "missing"
  exit 2
fi
bad=0
while IFS= read -r pak; do
  [ -z "$pak" ] && continue
  [ -f "$pak" ] || bad=1
done < "$modlist"
if [ "$bad" -ne 0 ]; then
  echo "invalid"
  exit 3
fi
echo "valid"
'@
    $result = (& docker exec $ContainerId bash -lc $script 2>$null) -join ''
    if ($LASTEXITCODE -eq 0 -and $result -eq 'valid') {
        Add-Pass 'modlist' 'ConanSandbox/Mods/modlist.txt exists and non-empty entries point to files.'
    } elseif ($result -eq 'missing') {
        Add-Fail 'modlist' 'ConanSandbox/Mods/modlist.txt is missing.'
    } else {
        Add-Fail 'modlist' 'One or more modlist entries do not point to existing files.'
    }
}

function Test-PasswordLeaks {
    param([string]$ContainerId, [hashtable]$EnvValues)

    $secrets = @()
    foreach ($key in @('SERVER_PASSWORD', 'ADMIN_PASSWORD', 'RCON_PASSWORD')) {
        if ($EnvValues.ContainsKey($key) -and -not [string]::IsNullOrEmpty($EnvValues[$key])) {
            $secrets += [pscustomobject]@{ Key = $key; Value = $EnvValues[$key] }
        }
    }
    if ($secrets.Count -eq 0) {
        Add-Warn 'password-leak-scan' 'No non-empty password values were present in the env file.'
        return
    }

    $leakFound = $false
    $dockerLogs = (& docker logs --tail $script:LogTail $ContainerId 2>$null) -join "`n"
    foreach ($secret in $secrets) {
        if ($dockerLogs.Contains($secret.Value)) {
            $leakFound = $true
        }
    }

    $logRoot = Join-Path $script:RepoRoot 'data\logs'
    if (Test-Path -LiteralPath $logRoot -PathType Container) {
        Get-ChildItem -LiteralPath $logRoot -Recurse -File -Force -ErrorAction SilentlyContinue | ForEach-Object {
            $content = Get-Content -LiteralPath $_.FullName -Raw -ErrorAction SilentlyContinue
            foreach ($secret in $secrets) {
                if ($null -ne $content -and $content.Contains($secret.Value)) {
                    $leakFound = $true
                }
            }
        }
    }

    $trackedFiles = & git ls-files 2>$null
    foreach ($file in $trackedFiles) {
        $path = Join-Path $script:RepoRoot $file
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
            continue
        }
        $content = Get-Content -LiteralPath $path -Raw -ErrorAction SilentlyContinue
        foreach ($secret in $secrets) {
            if ($null -ne $content -and $content.Contains($secret.Value)) {
                $leakFound = $true
            }
        }
    }

    if ($leakFound) {
        Add-Fail 'password-leak-scan' 'A password value from the env file appeared in Docker logs, retained logs, or tracked files.'
    } else {
        Add-Pass 'password-leak-scan' 'No env password values found in Docker logs, retained logs, or tracked files.'
    }
}

Push-Location $script:RepoRoot
try {
    Write-Host 'Conan local durability test'
    Write-Host ''

    $dockerCheck = Invoke-Quiet 'docker.version' @('docker', 'version')
    if ($dockerCheck.ExitCode -ne 0) {
        exit 1
    }

    Invoke-Quiet 'compose.config.default' @('docker', 'compose', 'config', '--quiet') | Out-Null

    if (-not (Test-Path -LiteralPath $EnvFile -PathType Leaf)) {
        Add-Fail 'env-file' "Missing env file: $EnvFile"
        exit 1
    }

    $resolvedEnvFile = (Resolve-Path -LiteralPath $EnvFile).Path
    $envValues = Read-EnvFile -Path $resolvedEnvFile
    $composeArgs = @('--env-file', $resolvedEnvFile)
    Add-Pass 'env-file' "Using $EnvFile"

    Invoke-Quiet 'compose.config.env-file' @('docker', 'compose', '--env-file', $resolvedEnvFile, 'config', '--quiet') | Out-Null

    $initialContainerId = Get-ContainerId -ComposeArgs $composeArgs
    $initialState = Get-ContainerState -ContainerId $initialContainerId
    $initialWasRunning = $false
    if ($null -ne $initialState -and $initialState.Running) {
        $initialWasRunning = $true
        Add-Pass 'container.status.before' "Running since $($initialState.StartedAt)."
    } elseif ($null -ne $initialState) {
        Add-Warn 'container.status.before' "Container exists but is $($initialState.Status); starting for durability test."
        Invoke-Quiet 'compose.up.before' @('docker', 'compose', '--env-file', $resolvedEnvFile, 'up', '-d') | Out-Null
    } else {
        Add-Warn 'container.status.before' 'No compose container was present; creating one for durability test.'
        Invoke-Quiet 'compose.up.before' @('docker', 'compose', '--env-file', $resolvedEnvFile, 'up', '-d') | Out-Null
    }

    $containerId = Get-ContainerId -ComposeArgs $composeArgs
    if ([string]::IsNullOrWhiteSpace($containerId)) {
        Add-Fail 'container' 'Could not determine compose container ID.'
        exit 1
    }
    Add-Pass 'container' $containerId.Substring(0, [Math]::Min(12, $containerId.Length))

    Wait-ForStartPlay -ComposeArgs $composeArgs -Since '' -TimeoutSeconds $script:ReadyTimeoutSeconds | Out-Null
    Test-ActiveConfig -ContainerId $containerId
    Test-ConfigValues -EnvValues $envValues
    Test-PublishedPorts -ContainerId $containerId -EnvValues $envValues

    $configBefore = Get-DirectorySnapshot -Path (Join-Path $script:RepoRoot 'data\config')
    $saveBefore = Get-DirectorySnapshot -Path (Join-Path $script:RepoRoot 'data\serverfiles\ConanSandbox\Saved')
    if ($configBefore.Exists) {
        Add-Pass 'persist.config.before' "files=$($configBefore.FileCount)"
    } else {
        Add-Fail 'persist.config.before' 'Persistent config directory is missing.'
    }
    if ($saveBefore.Exists) {
        Add-Pass 'persist.saves.before' "files=$($saveBefore.FileCount)"
    } else {
        Add-Fail 'persist.saves.before' 'Persistent Saved directory is missing.'
    }

    $backupBefore = Get-BackupArchives
    $global:LASTEXITCODE = 0
    & docker compose @composeArgs exec -T $script:ServiceName /scripts/backup.sh durability 2>&1 | Out-Null
    if ($LASTEXITCODE -eq 0) {
        $backupAfter = Get-BackupArchives
        if ($backupAfter.Count -gt $backupBefore.Count) {
            Add-Pass 'backup.create' 'A new backup archive was created.'
        } else {
            Add-Fail 'backup.create' 'Backup command succeeded but no new archive was detected.'
        }
    } else {
        Add-Fail 'backup.create' 'Backup command failed.'
    }

    Test-ModList -ContainerId $containerId

    Add-Info 'restart' 'Stopping compose service gracefully.'
    Invoke-Quiet 'compose.stop' @('docker', 'compose', '--env-file', $resolvedEnvFile, 'stop', '-t', '120', $script:ServiceName) | Out-Null

    $restartSince = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
    Add-Info 'restart' 'Starting compose service again to verify update-on-start durability.'
    Invoke-Quiet 'compose.start' @('docker', 'compose', '--env-file', $resolvedEnvFile, 'start', $script:ServiceName) | Out-Null

    Wait-ForStartPlay -ComposeArgs $composeArgs -Since $restartSince -TimeoutSeconds $script:ReadyTimeoutSeconds | Out-Null

    $containerId = Get-ContainerId -ComposeArgs $composeArgs
    Test-ActiveConfig -ContainerId $containerId
    Test-ConfigValues -EnvValues $envValues
    Test-ModList -ContainerId $containerId

    $configAfter = Get-DirectorySnapshot -Path (Join-Path $script:RepoRoot 'data\config')
    $saveAfter = Get-DirectorySnapshot -Path (Join-Path $script:RepoRoot 'data\serverfiles\ConanSandbox\Saved')
    if ($configAfter.Exists -and $configAfter.FileCount -ge $configBefore.FileCount) {
        Add-Pass 'persist.config.after' "files=$($configAfter.FileCount)"
    } else {
        Add-Fail 'persist.config.after' 'Config directory did not persist as expected.'
    }
    if ($saveAfter.Exists -and $saveAfter.FileCount -ge $saveBefore.FileCount) {
        Add-Pass 'persist.saves.after' "files=$($saveAfter.FileCount)"
    } else {
        Add-Fail 'persist.saves.after' 'Saved directory did not persist as expected.'
    }

    Test-PasswordLeaks -ContainerId $containerId -EnvValues $envValues

    if (-not $KeepRunning -and -not $initialWasRunning) {
        Add-Info 'final-state' 'Initial state was not running; stopping service after test.'
        Invoke-Quiet 'compose.final-stop' @('docker', 'compose', '--env-file', $resolvedEnvFile, 'stop', '-t', '120', $script:ServiceName) | Out-Null
    } else {
        Add-Pass 'final-state' 'Service left running for continued local/client testing.'
    }

    if (-not $SkipClientReminder) {
        Write-Host ''
        Write-Host 'Reminder: final server-browser, password, admin-password, region, and login claims still require a real Conan Exiles client check.'
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
