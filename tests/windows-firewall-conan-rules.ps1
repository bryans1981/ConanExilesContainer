param(
    [string]$EnvFile = '.env.local-live',
    [switch]$Apply,
    [switch]$Remove,
    [switch]$IncludeRcon
)

$ErrorActionPreference = 'Continue'
$ProgressPreference = 'SilentlyContinue'

$script:RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path

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

function Test-Truthy {
    param([string]$Value)

    if ([string]::IsNullOrWhiteSpace($Value)) {
        return $false
    }
    return @('true', 'yes', '1') -contains $Value.ToLowerInvariant()
}

function Test-Administrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Get-DesiredRules {
    param([hashtable]$EnvValues)

    $rules = @(
        [pscustomobject]@{ Name = 'ConanExilesContainer UDP 7777'; Protocol = 'UDP'; Port = (Get-MapValue $EnvValues 'GAME_PORT' '7777'); Required = $true },
        [pscustomobject]@{ Name = 'ConanExilesContainer UDP 7778'; Protocol = 'UDP'; Port = (Get-MapValue $EnvValues 'PINGER_PORT' '7778'); Required = $true },
        [pscustomobject]@{ Name = 'ConanExilesContainer UDP 27015'; Protocol = 'UDP'; Port = (Get-MapValue $EnvValues 'QUERY_PORT' '27015'); Required = $true }
    )

    if ($IncludeRcon -or (Test-Truthy (Get-MapValue $EnvValues 'RCON_ENABLED' 'false'))) {
        $rules += [pscustomobject]@{ Name = 'ConanExilesContainer TCP 25575 RCON'; Protocol = 'TCP'; Port = (Get-MapValue $EnvValues 'RCON_PORT' '25575'); Required = $false }
    }

    return $rules
}

function Get-RuleReport {
    param([pscustomobject]$Desired)

    $rule = Get-NetFirewallRule -DisplayName $Desired.Name -ErrorAction SilentlyContinue
    if (-not $rule) {
        return [pscustomobject]@{
            Name = $Desired.Name
            Status = 'MISSING'
            Enabled = ''
            Direction = ''
            Action = ''
            Profile = ''
            Protocol = $Desired.Protocol
            Port = $Desired.Port
        }
    }

    $portFilter = $rule | Get-NetFirewallPortFilter -ErrorAction SilentlyContinue
    return [pscustomobject]@{
        Name = $rule.DisplayName
        Status = 'PRESENT'
        Enabled = $rule.Enabled
        Direction = $rule.Direction
        Action = $rule.Action
        Profile = $rule.Profile
        Protocol = $portFilter.Protocol
        Port = $portFilter.LocalPort
    }
}

Push-Location $script:RepoRoot
try {
    if ($Apply -and $Remove) {
        throw 'Use either -Apply or -Remove, not both.'
    }

    if ((($Apply -or $Remove) -and -not (Test-Administrator))) {
        throw 'Run PowerShell as Administrator when using -Apply or -Remove.'
    }

    $envValues = Read-EnvFile -Path $EnvFile
    $desiredRules = Get-DesiredRules -EnvValues $envValues

    if ($Apply) {
        foreach ($desired in $desiredRules) {
            Get-NetFirewallRule -DisplayName $desired.Name -ErrorAction SilentlyContinue | Remove-NetFirewallRule -ErrorAction SilentlyContinue
            New-NetFirewallRule `
                -DisplayName $desired.Name `
                -Direction Inbound `
                -Action Allow `
                -Protocol $desired.Protocol `
                -LocalPort $desired.Port `
                -Profile Any `
                -Description 'ConanExilesContainer local LAN live-test rule' | Out-Null
            Write-Host "APPLIED $($desired.Name) protocol=$($desired.Protocol) port=$($desired.Port)"
        }
    } elseif ($Remove) {
        foreach ($desired in $desiredRules) {
            $existing = Get-NetFirewallRule -DisplayName $desired.Name -ErrorAction SilentlyContinue
            if ($existing) {
                $existing | Remove-NetFirewallRule
                Write-Host "REMOVED $($desired.Name)"
            } else {
                Write-Host "ABSENT $($desired.Name)"
            }
        }
    }

    Write-Host ''
    Write-Host 'Firewall rule status:'
    $desiredRules | ForEach-Object { Get-RuleReport -Desired $_ } | Format-Table -AutoSize

    if (-not $Apply -and -not $Remove) {
        Write-Host ''
        Write-Host 'Check-only mode. No firewall rules were changed.'
        Write-Host 'Run from an Administrator PowerShell with -Apply to create/update only these named inbound allow rules.'
        Write-Host 'Run from an Administrator PowerShell with -Remove to delete only these named rules.'
    }
} finally {
    Pop-Location
}
