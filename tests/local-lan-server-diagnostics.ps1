param(
    [string]$EnvFile = '.env.local-live',
    [int]$LogTail = 1200
)

$ErrorActionPreference = 'Continue'
$ProgressPreference = 'SilentlyContinue'

$script:RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$script:FailureCount = 0
$script:WarningCount = 0
$script:ServiceName = 'conan'

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
    return @('true', 'yes', '1') -contains $Value.ToLowerInvariant()
}

function Format-Bytes {
    param([long]$Bytes)
    if ($Bytes -ge 1GB) { return '{0:N2} GiB' -f ($Bytes / 1GB) }
    if ($Bytes -ge 1MB) { return '{0:N2} MiB' -f ($Bytes / 1MB) }
    if ($Bytes -ge 1KB) { return '{0:N2} KiB' -f ($Bytes / 1KB) }
    return "$Bytes B"
}

function Get-DirectorySize {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path -PathType Container)) {
        return 0
    }
    $sum = 0
    Get-ChildItem -LiteralPath $Path -Recurse -File -Force -ErrorAction SilentlyContinue | ForEach-Object { $sum += $_.Length }
    return $sum
}

function Sanitize-Text {
    param([string]$Text, [hashtable]$EnvValues)
    foreach ($key in @('SERVER_PASSWORD', 'ADMIN_PASSWORD', 'RCON_PASSWORD')) {
        if ($EnvValues.ContainsKey($key) -and -not [string]::IsNullOrEmpty($EnvValues[$key])) {
            $Text = $Text.Replace($EnvValues[$key], '<redacted>')
        }
    }
    return $Text
}

function Get-FirewallStatus {
    param([string]$Protocol, [string]$Port)
    $filters = Get-NetFirewallPortFilter -ErrorAction SilentlyContinue | Where-Object { $_.Protocol -eq $Protocol -and $_.LocalPort -eq $Port }
    $rules = @()
    foreach ($filter in $filters) {
        $rule = $filter | Get-NetFirewallRule -ErrorAction SilentlyContinue
        if ($rule) {
            $rules += $rule
        }
    }
    return $rules
}

function Convert-HexPort {
    param([string]$HexPort)
    return [Convert]::ToInt32($HexPort, 16)
}

Push-Location $script:RepoRoot
try {
    $envValues = Read-EnvFile -Path $EnvFile
    $gamePort = Get-MapValue $envValues 'GAME_PORT' '7777'
    $pingerPort = Get-MapValue $envValues 'PINGER_PORT' '7778'
    $queryPort = Get-MapValue $envValues 'QUERY_PORT' '27015'
    $rconPort = Get-MapValue $envValues 'RCON_PORT' '25575'
    $rconEnabled = Test-Truthy (Get-MapValue $envValues 'RCON_ENABLED' 'true')
    $serverName = Get-MapValue $envValues 'SERVER_NAME' 'Conan Exiles Server'
    $serverPassword = Get-MapValue $envValues 'SERVER_PASSWORD' ''
    $adminPassword = Get-MapValue $envValues 'ADMIN_PASSWORD' ''
    $composeArgs = @('--env-file', (Resolve-Path -LiteralPath $EnvFile).Path)

    Write-Host 'Local LAN Conan Exiles diagnostics'
    Write-Host ''

    if ($serverName -eq 'Conan Exiles Server') {
        Add-Fail 'env.SERVER_NAME' 'Still using default server name during local live test.'
    } else {
        Add-Pass 'env.SERVER_NAME' $serverName
    }
    if ([string]::IsNullOrEmpty($serverPassword)) {
        Add-Fail 'env.SERVER_PASSWORD' 'Blank during password-protected local live test.'
    } else {
        Add-Pass 'env.SERVER_PASSWORD' '<set>'
    }
    if ([string]::IsNullOrEmpty($adminPassword)) {
        Add-Fail 'env.ADMIN_PASSWORD' 'Blank during admin password local live test.'
    } else {
        Add-Pass 'env.ADMIN_PASSWORD' '<set>'
    }

    $lanAddresses = Get-NetIPConfiguration | Where-Object {
        $_.IPv4Address -and
        $_.NetAdapter.Status -eq 'Up' -and
        $_.InterfaceAlias -notmatch 'vEthernet|WSL|Loopback|Docker'
    } | ForEach-Object {
        [pscustomobject]@{
            InterfaceAlias = $_.InterfaceAlias
            IPv4 = $_.IPv4Address.IPAddress
            PrefixLength = $_.IPv4Address.PrefixLength
        }
    }

    if ($lanAddresses) {
        foreach ($addr in $lanAddresses) {
            Add-Info 'lan-ipv4' "$($addr.InterfaceAlias) $($addr.IPv4)/$($addr.PrefixLength)"
        }
    } else {
        Add-Warn 'lan-ipv4' 'No non-virtual active LAN IPv4 address was detected.'
    }

    Add-Info 'docker-context' ((docker context show 2>$null) -join ' ')

    $global:LASTEXITCODE = 0
    $containerOutput = & docker compose @composeArgs ps -q $script:ServiceName 2>&1
    $containerExit = $LASTEXITCODE
    $containerId = ($containerOutput | Where-Object { -not [string]::IsNullOrWhiteSpace($_.ToString()) } | Select-Object -First 1).ToString().Trim()
    if ($containerExit -ne 0 -or [string]::IsNullOrWhiteSpace($containerId)) {
        Add-Fail 'compose-service' 'No compose container ID was returned.'
    } else {
        Add-Pass 'compose-service' "Container ID $($containerId.Substring(0, [Math]::Min(12, $containerId.Length)))"
        $stateJson = (& docker inspect $containerId --format '{{json .State}}' 2>$null) -join "`n"
        if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($stateJson)) {
            $state = $stateJson | ConvertFrom-Json
            if ($state.Running) {
                Add-Pass 'container-state' "Running; health=$($state.Health.Status)"
            } else {
                Add-Fail 'container-state' "Not running; status=$($state.Status), exit_code=$($state.ExitCode)"
            }
        }

        $portsJson = (& docker inspect $containerId --format '{{json .NetworkSettings.Ports}}' 2>$null) -join "`n"
        if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($portsJson)) {
            $ports = $portsJson | ConvertFrom-Json
            $required = @("$gamePort/udp", "$pingerPort/udp", "$queryPort/udp")
            if ($rconEnabled) { $required += "$rconPort/tcp" }
            foreach ($port in $required) {
                $property = $ports.PSObject.Properties[$port]
                if ($null -eq $property -or $null -eq $property.Value) {
                    Add-Fail 'docker-published-port' "$port is not published."
                } else {
                    $mapping = @($property.Value)[0]
                    Add-Pass 'docker-published-port' "$port -> $($mapping.HostIp):$($mapping.HostPort)"
                }
            }
        }

        $activeConfigPath = (& docker exec $containerId bash -lc 'readlink -f /serverdata/serverfiles/ConanSandbox/Saved/Config/LinuxServer 2>/dev/null || true' 2>$null) -join ''
        if ([string]::IsNullOrWhiteSpace($activeConfigPath)) {
            Add-Fail 'active-config' 'Could not determine active LinuxServer config path inside the container.'
        } else {
            Add-Pass 'active-config' $activeConfigPath
        }

        $socketRaw = @{}
        foreach ($proto in @('udp', 'udp6', 'tcp', 'tcp6')) {
            $socketRaw[$proto] = (& docker exec $containerId cat "/proc/net/$proto" 2>$null) -join "`n"
        }
        foreach ($expected in @(
            [pscustomobject]@{ Protocol = 'udp'; Port = [int]$gamePort },
            [pscustomobject]@{ Protocol = 'udp'; Port = [int]$pingerPort },
            [pscustomobject]@{ Protocol = 'udp'; Port = [int]$queryPort },
            [pscustomobject]@{ Protocol = 'tcp'; Port = [int]$rconPort }
        )) {
            if ($expected.Protocol -eq 'tcp' -and -not $rconEnabled) { continue }
            $found = $false
            foreach ($proto in @($expected.Protocol, "$($expected.Protocol)6")) {
                foreach ($line in ($socketRaw[$proto] -split "`n")) {
                    $columns = $line -split '\s+' | Where-Object { $_ -ne '' }
                    if ($columns.Count -lt 4 -or $columns[1] -notmatch ':') { continue }
                    $portHex = ($columns[1] -split ':')[-1]
                    if ((Convert-HexPort $portHex) -eq $expected.Port) {
                        $found = $true
                        Add-Pass 'in-container-socket' "$proto port=$($expected.Port) state=$($columns[3]) local=$($columns[1])"
                    }
                }
            }
            if (-not $found) {
                if ($expected.Protocol -eq 'tcp' -and $expected.Port -eq [int]$rconPort) {
                    Add-Warn 'in-container-socket' "TCP RCON port $($expected.Port) was published by Docker but not observed listening inside the container."
                } else {
                    Add-Fail 'in-container-socket' "$($expected.Protocol) port $($expected.Port) was not observed inside the container."
                }
            }
        }
    }

    $configRoot = Join-Path $script:RepoRoot 'data\config\ConanSandbox\Saved\Config\LinuxServer'
    $engineIni = Join-Path $configRoot 'Engine.ini'
    $serverSettingsIni = Join-Path $configRoot 'ServerSettings.ini'
    if (-not (Test-Path -LiteralPath $configRoot -PathType Container)) {
        Add-Fail 'active-config-host' "Missing expected local config path: $configRoot"
    } else {
        Add-Pass 'active-config-host' $configRoot
        $engine = Read-IniFile -Path $engineIni
        $serverSettings = Read-IniFile -Path $serverSettingsIni

        $engineName = Get-IniValue -Ini $engine -Section 'OnlineSubsystem' -Key 'ServerName'
        if ($engineName -eq $serverName) {
            Add-Pass 'config.Engine.OnlineSubsystem.ServerName' $engineName
        } else {
            if ($null -eq $engineName) {
                Add-Fail 'config.Engine.OnlineSubsystem.ServerName' "Expected $serverName but found <missing>."
            } else {
                Add-Fail 'config.Engine.OnlineSubsystem.ServerName' "Expected $serverName but found $engineName."
            }
        }

        $enginePassword = Get-IniValue -Ini $engine -Section 'OnlineSubsystem' -Key 'ServerPassword'
        if ([string]::IsNullOrEmpty($enginePassword)) {
            Add-Fail 'config.Engine.OnlineSubsystem.ServerPassword' 'Missing or blank during password-protected local live test.'
        } else {
            Add-Pass 'config.Engine.OnlineSubsystem.ServerPassword' '<set>'
        }

        $adminConfigPassword = Get-IniValue -Ini $serverSettings -Section 'ServerSettings' -Key 'AdminPassword'
        if ([string]::IsNullOrEmpty($adminConfigPassword)) {
            Add-Fail 'config.ServerSettings.AdminPassword' 'Missing or blank during admin password local live test.'
        } else {
            Add-Pass 'config.ServerSettings.AdminPassword' '<set>'
        }
    }

    foreach ($endpoint in @(
        [pscustomobject]@{ Protocol = 'UDP'; Port = $gamePort },
        [pscustomobject]@{ Protocol = 'UDP'; Port = $pingerPort },
        [pscustomobject]@{ Protocol = 'UDP'; Port = $queryPort },
        [pscustomobject]@{ Protocol = 'TCP'; Port = $rconPort }
    )) {
        if ($endpoint.Protocol -eq 'TCP' -and -not $rconEnabled) { continue }
        if ($endpoint.Protocol -eq 'UDP') {
            $matches = Get-NetUDPEndpoint -LocalPort ([int]$endpoint.Port) -ErrorAction SilentlyContinue
        } else {
            $matches = Get-NetTCPConnection -LocalPort ([int]$endpoint.Port) -State Listen -ErrorAction SilentlyContinue
        }
        if ($matches) {
            foreach ($match in $matches) {
                $processName = (Get-Process -Id $match.OwningProcess -ErrorAction SilentlyContinue).ProcessName
                Add-Pass 'host-port-owner' "$($endpoint.Protocol) $($endpoint.Port) owned_by=$processName pid=$($match.OwningProcess)"
            }
        } else {
            Add-Warn 'host-port-owner' "$($endpoint.Protocol) $($endpoint.Port) has no visible host endpoint."
        }

        $rules = Get-FirewallStatus -Protocol $endpoint.Protocol -Port $endpoint.Port
        if ($rules) {
            foreach ($rule in $rules) {
                Add-Info 'firewall-rule' "$($endpoint.Protocol) $($endpoint.Port) $($rule.DisplayName) enabled=$($rule.Enabled) action=$($rule.Action) direction=$($rule.Direction)"
            }
        } else {
            Add-Warn 'firewall-rule' "$($endpoint.Protocol) $($endpoint.Port) has no specific Windows Firewall rule."
        }
    }

    $launcherCandidates = Get-Process | Where-Object { $_.ProcessName -match 'Conan|DedicatedServer|steamcmd' }
    if ($launcherCandidates) {
        foreach ($process in $launcherCandidates) {
            Add-Warn 'host-process' "Potential old host process: $($process.ProcessName) pid=$($process.Id)"
        }
    } else {
        Add-Pass 'host-process' 'No old Conan/SteamCMD/DedicatedServerLauncher host process candidates found.'
    }

    $rawLogs = (& docker compose @composeArgs logs --no-color --tail $LogTail $script:ServiceName 2>&1) -join "`n"
    $leakFound = $false
    foreach ($key in @('SERVER_PASSWORD', 'ADMIN_PASSWORD', 'RCON_PASSWORD')) {
        if ($envValues.ContainsKey($key) -and -not [string]::IsNullOrEmpty($envValues[$key]) -and $rawLogs.Contains($envValues[$key])) {
            $leakFound = $true
        }
    }

    $logs = Sanitize-Text -Text $rawLogs -EnvValues $envValues
    if ($logs -match 'StartPlay') {
        Add-Pass 'readiness' 'StartPlay marker found in recent logs.'
    } else {
        Add-Fail 'readiness' 'StartPlay marker not found in recent logs.'
    }

    foreach ($pattern in @('unable to register server', 'SteamSockets: Disabled', 'Started SourceServerQueries', 'Startup report', 'Created socket for bind address', 'IpNetDriver listening')) {
        $count = ([regex]::Matches($logs, [regex]::Escape($pattern), 'IgnoreCase')).Count
        if ($count -gt 0) {
            Add-Info 'log-finding' "$pattern count=$count"
        }
    }

    $startupReports = [regex]::Matches($logs, 'Startup report\..*?Name=(.*?)\s+Map=', 'IgnoreCase')
    if ($startupReports.Count -gt 0) {
        $startupName = $startupReports[$startupReports.Count - 1].Groups[1].Value
        if ($startupName -eq $serverName) {
            Add-Pass 'log-startup-report-name' $startupName
        } else {
            Add-Fail 'log-startup-report-name' "Expected $serverName but startup report showed $startupName."
        }
    } else {
        Add-Warn 'log-startup-report-name' 'No Startup report name found in recent logs.'
    }

    $interesting = $logs -split "`n" | Where-Object {
        $_ -match 'StartPlay|SteamSockets|unable to register server|SourceServerQueries|Startup report|Created socket for bind address|IpNetDriver listening|GameServerQueryPort|QueryPort|OnlineSubsystem|multihome'
    } | Select-Object -Last 40
    if ($interesting) {
        Write-Host ''
        Write-Host 'Recent listing/query-related log lines:'
        $interesting
    }

    if ($leakFound) {
        Add-Fail 'password-leak-scan' 'A password value from the env file appeared in recent logs.'
    } else {
        Add-Pass 'password-leak-scan' 'No env password values found in recent Docker logs.'
    }

    $dataRoot = Join-Path $script:RepoRoot 'data'
    foreach ($name in @('serverfiles', 'steam', 'config', 'logs', 'backups')) {
        $path = Join-Path $dataRoot $name
        Add-Info 'disk-usage' "$name=$(Format-Bytes (Get-DirectorySize -Path $path))"
    }

    Write-Host ''
    Write-Host 'User test steps from the other LAN client system:'
    foreach ($addr in $lanAddresses) {
        Write-Host "  Direct connect: $($addr.IPv4):$gamePort"
        Write-Host "  Steam/query favorite if supported: $($addr.IPv4):$queryPort"
    }
    Write-Host "  Server browser search: $serverName"
    Write-Host '  Enable: Show Invalid, Show Private, Show With Mods'

    Write-Host ''
    Write-Host "Summary: failures=$script:FailureCount warnings=$script:WarningCount"
    if ($script:FailureCount -gt 0) {
        exit 1
    }
    exit 0
} finally {
    Pop-Location
}
