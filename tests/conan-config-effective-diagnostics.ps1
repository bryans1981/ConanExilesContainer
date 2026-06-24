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
    param([hashtable]$Map, [string]$Name, [string]$Default)
    if ($Map.ContainsKey($Name) -and -not [string]::IsNullOrEmpty($Map[$Name])) {
        return $Map[$Name]
    }
    return $Default
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
            $value = $matches[2]
            $values["$section`n$key"] = $value
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

function Format-ConfigValue {
    param([string]$Key, [string]$Value)
    if ($null -eq $Value) {
        return '<missing>'
    }
    if ($Key -match 'Password') {
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
    } elseif (-not $AllowBlankPasswords -and [string]::IsNullOrEmpty($Value)) {
        Add-Fail $Name 'Blank during password-protected local live test.'
    } else {
        Add-Pass $Name (Format-ConfigValue -Key $Name -Value $Value)
    }
}

Push-Location $script:RepoRoot
try {
    Write-Host 'Conan config effective diagnostics'
    Write-Host ''

    $envValues = Read-EnvFile -Path $EnvFile
    $expectedName = Get-MapValue -Map $envValues -Name 'SERVER_NAME' -Default $ExpectedServerName
    $expectedRegionRaw = Get-MapValue -Map $envValues -Name 'SERVER_REGION' -Default $ExpectedServerRegion
    $expectedRegion = Convert-ServerRegionValue $expectedRegionRaw
    if ($null -eq $expectedRegion) {
        Add-Fail 'env.SERVER_REGION' "Invalid value: $expectedRegionRaw."
        $expectedRegion = $expectedRegionRaw
    }
    $gamePort = Get-MapValue -Map $envValues -Name 'GAME_PORT' -Default '7777'
    $pingerPort = Get-MapValue -Map $envValues -Name 'PINGER_PORT' -Default '7778'
    $queryPort = Get-MapValue -Map $envValues -Name 'QUERY_PORT' -Default '27015'
    $maxPlayers = Get-MapValue -Map $envValues -Name 'MAX_PLAYERS' -Default '40'
    $rconPort = Get-MapValue -Map $envValues -Name 'RCON_PORT' -Default '25575'

    $composeArgs = @()
    if (Test-Path -LiteralPath $EnvFile -PathType Leaf) {
        $composeArgs = @('--env-file', (Resolve-Path -LiteralPath $EnvFile).Path)
        Add-Pass 'env-file' (Resolve-Path -LiteralPath $EnvFile).Path
    } else {
        Add-Fail 'env-file' "Missing env file: $EnvFile"
    }

    $containerId = $null
    if ($composeArgs.Count -gt 0) {
        $containerOutput = & docker compose @composeArgs ps -q $ServiceName 2>$null
        if ($LASTEXITCODE -eq 0) {
            $containerId = ($containerOutput | Where-Object { -not [string]::IsNullOrWhiteSpace($_.ToString()) } | Select-Object -First 1).ToString().Trim()
        }
    }

    if ([string]::IsNullOrWhiteSpace($containerId)) {
        Add-Fail 'active-config' "Cannot determine active config path because service $ServiceName has no compose container."
    } else {
        Add-Pass 'container' $containerId.Substring(0, [Math]::Min(12, $containerId.Length))
        $activePath = (& docker exec $containerId bash -lc 'readlink -f /serverdata/serverfiles/ConanSandbox/Saved/Config/LinuxServer 2>/dev/null || true' 2>$null) -join ''
        if ([string]::IsNullOrWhiteSpace($activePath)) {
            Add-Fail 'active-config.container-path' 'Could not resolve /serverdata/serverfiles/ConanSandbox/Saved/Config/LinuxServer inside the container.'
        } else {
            Add-Pass 'active-config.container-path' $activePath
        }
    }

    $configRoot = Join-Path $script:RepoRoot 'data\config\ConanSandbox\Saved\Config\LinuxServer'
    $serverSettingsPath = Join-Path $configRoot 'ServerSettings.ini'
    $enginePath = Join-Path $configRoot 'Engine.ini'
    $gamePath = Join-Path $configRoot 'Game.ini'

    if (-not (Test-Path -LiteralPath $configRoot -PathType Container)) {
        Add-Fail 'active-config.host-path' "Missing expected persistent config directory: $configRoot"
    } else {
        Add-Pass 'active-config.host-path' $configRoot
    }

    foreach ($path in @($serverSettingsPath, $enginePath, $gamePath)) {
        if (Test-Path -LiteralPath $path -PathType Leaf) {
            Add-Pass 'config-file' $path
        } else {
            Add-Fail 'config-file' "Missing $path"
        }
    }

    $serverSettings = Read-IniFile -Path $serverSettingsPath
    $engine = Read-IniFile -Path $enginePath
    $game = Read-IniFile -Path $gamePath

    Test-ExpectedValue 'Engine.ini [OnlineSubsystem] ServerName' (Get-IniValue -Ini $engine -Section 'OnlineSubsystem' -Key 'ServerName') $expectedName
    Test-SecretPresent 'Engine.ini [OnlineSubsystem] ServerPassword' (Get-IniValue -Ini $engine -Section 'OnlineSubsystem' -Key 'ServerPassword')
    Test-ExpectedValue 'Engine.ini [URL] Port' (Get-IniValue -Ini $engine -Section 'URL' -Key 'Port') $gamePort
    Test-ExpectedValue 'Engine.ini [OnlineSubsystemSteam] GameServerQueryPort' (Get-IniValue -Ini $engine -Section 'OnlineSubsystemSteam' -Key 'GameServerQueryPort') $queryPort

    Test-ExpectedValue 'ServerSettings.ini [ServerSettings] ServerName' (Get-IniValue -Ini $serverSettings -Section 'ServerSettings' -Key 'ServerName') $expectedName
    Test-SecretPresent 'ServerSettings.ini [ServerSettings] ServerPassword' (Get-IniValue -Ini $serverSettings -Section 'ServerSettings' -Key 'ServerPassword')
    Test-SecretPresent 'ServerSettings.ini [ServerSettings] AdminPassword' (Get-IniValue -Ini $serverSettings -Section 'ServerSettings' -Key 'AdminPassword')
    Test-ExpectedValue 'ServerSettings.ini [ServerSettings] serverRegion' (Get-IniValue -Ini $serverSettings -Section 'ServerSettings' -Key 'serverRegion') $expectedRegion
    Test-ExpectedValue 'ServerSettings.ini [ServerSettings] Port' (Get-IniValue -Ini $serverSettings -Section 'ServerSettings' -Key 'Port') $gamePort
    Test-ExpectedValue 'ServerSettings.ini [ServerSettings] PingerPort' (Get-IniValue -Ini $serverSettings -Section 'ServerSettings' -Key 'PingerPort') $pingerPort
    Test-ExpectedValue 'ServerSettings.ini [ServerSettings] QueryPort' (Get-IniValue -Ini $serverSettings -Section 'ServerSettings' -Key 'QueryPort') $queryPort
    Test-ExpectedValue 'ServerSettings.ini [ServerSettings] RconPort' (Get-IniValue -Ini $serverSettings -Section 'ServerSettings' -Key 'RconPort') $rconPort
    Test-ExpectedValue 'Game.ini [/Script/Engine.GameSession] MaxPlayers' (Get-IniValue -Ini $game -Section '/Script/Engine.GameSession' -Key 'MaxPlayers') $maxPlayers

    Write-Host ''
    Write-Host 'Config key inventory:'
    $scanRoots = @(
        (Join-Path $script:RepoRoot 'data\config'),
        (Join-Path $script:RepoRoot 'data\serverfiles\ConanSandbox\Saved\Config')
    )
    $seen = @{}
    foreach ($root in $scanRoots) {
        if (-not (Test-Path -LiteralPath $root -PathType Container)) {
            continue
        }
        Get-ChildItem -LiteralPath $root -Recurse -File -Filter '*.ini' -ErrorAction SilentlyContinue | ForEach-Object {
            if ($seen.ContainsKey($_.FullName)) {
                return
            }
            $seen[$_.FullName] = $true
            $matches = Select-String -LiteralPath $_.FullName -Pattern '^(ServerName|ServerPassword|AdminPassword|serverRegion|GameServerQueryPort|Port|PingerPort|QueryPort|MaxPlayers|RconEnabled|RconPort|RconPassword)\s*=' -ErrorAction SilentlyContinue
            if ($matches) {
                Add-Info 'inventory.file' $_.FullName
                foreach ($match in $matches) {
                    $name, $value = $match.Line -split '=', 2
                    Add-Info "inventory.$name" (Format-ConfigValue -Key $name -Value $value)
                }
            }
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
