param(
    [string]$LogRoot,
    [switch]$StrictSteamFailures,
    [switch]$SkipDnsOverride,
    [switch]$SkipAppUpdateAttempt,
    [switch]$SkipHostNetwork
)

$ErrorActionPreference = 'Continue'
$ProgressPreference = 'SilentlyContinue'

$script:RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
if ([string]::IsNullOrWhiteSpace($LogRoot)) {
    $stamp = (Get-Date).ToUniversalTime().ToString('yyyyMMddTHHmmssZ')
    $LogRoot = Join-Path $script:RepoRoot "test-results\steamcmd-connectivity\$stamp-$PID"
}

New-Item -ItemType Directory -Force -Path $LogRoot | Out-Null
$script:SummaryPath = Join-Path $LogRoot 'summary.txt'
$script:InconclusiveCount = 0
$script:SteamFailureCount = 0
$script:FailureCount = 0
$script:ProjectImage = 'conan-exiles-container:local'
$script:SteamcmdImage = 'steamcmd/steamcmd:ubuntu-24'
$script:AppId = '443030'

function Add-SummaryLine {
    param([string]$Line)
    Add-Content -LiteralPath $script:SummaryPath -Value $Line
}

function Invoke-DiagnosticCheck {
    param(
        [string]$Name,
        [string]$Description,
        [scriptblock]$Command,
        [switch]$AllowInconclusive,
        [switch]$SteamCheck
    )

    $logPath = Join-Path $LogRoot "$Name.raw.log"
    Write-Host ""
    Write-Host "== $Name =="
    Write-Host $Description

    Set-Content -LiteralPath $logPath -Value @(
        "Name: $Name"
        "Description: $Description"
        "StartedUtc: $((Get-Date).ToUniversalTime().ToString('o'))"
        ""
    )

    $global:LASTEXITCODE = 0
    $commandSucceeded = $true
    try {
        $output = & $Command 2>&1
        $commandSucceeded = $?
    } catch {
        $output = $_
        $commandSucceeded = $false
    }
    $exitCode = if ($global:LASTEXITCODE -ne 0) {
        [int]$global:LASTEXITCODE
    } elseif ($commandSucceeded) {
        0
    } else {
        1
    }
    foreach ($line in $output) {
        $text = $line.ToString()
        Add-Content -LiteralPath $logPath -Value $text
    }

    if ($exitCode -eq 0) {
        $status = 'PASS'
    } elseif ($AllowInconclusive) {
        $status = 'INCONCLUSIVE'
        $script:InconclusiveCount++
        if ($SteamCheck) {
            $script:SteamFailureCount++
        }
    } else {
        $status = 'FAIL'
        $script:FailureCount++
    }

    Write-Host "$status exit=$exitCode log=$logPath"
    Add-SummaryLine "$status $Name exit=$exitCode log=$logPath"
}

function Add-Skip {
    param([string]$Name, [string]$Reason)
    Write-Host ""
    Write-Host "== $Name =="
    Write-Host "INCONCLUSIVE $Reason"
    Add-SummaryLine "INCONCLUSIVE $Name skipped: $Reason"
    $script:InconclusiveCount++
}

Push-Location $script:RepoRoot
try {
    Set-Content -LiteralPath $script:SummaryPath -Value @(
        "SteamCMD connectivity diagnostics"
        "StartedUtc=$((Get-Date).ToUniversalTime().ToString('o'))"
        "RepoRoot=$script:RepoRoot"
        "LogRoot=$LogRoot"
        "AppId=$script:AppId"
        ""
    )

    Invoke-DiagnosticCheck 'host-dns' 'Resolve public hostnames from the Codex host. No LAN hosts are contacted.' {
        if (Get-Command Resolve-DnsName -ErrorAction SilentlyContinue) {
            Resolve-DnsName github.com
            Resolve-DnsName steamcdn-a.akamaihd.net
            Resolve-DnsName steamcommunity.com
        } else {
            [System.Net.Dns]::GetHostAddresses('github.com')
            [System.Net.Dns]::GetHostAddresses('steamcdn-a.akamaihd.net')
            [System.Net.Dns]::GetHostAddresses('steamcommunity.com')
        }
    } -AllowInconclusive

    Invoke-DiagnosticCheck 'host-https' 'Fetch public HTTPS endpoints from the Codex host. No LAN hosts are contacted.' {
        Invoke-WebRequest -Uri 'https://api.github.com' -Method Get -UseBasicParsing -TimeoutSec 20 | Select-Object -ExpandProperty StatusCode
        Invoke-WebRequest -Uri 'https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz' -Method Get -UseBasicParsing -TimeoutSec 20 -OutFile ([System.IO.Path]::GetTempFileName())
    } -AllowInconclusive

    Invoke-DiagnosticCheck 'docker-version' 'Verify Docker client/server are available.' {
        docker version
    }

    Invoke-DiagnosticCheck 'container-dns-default' 'Resolve GitHub, Steam CDN, and Steam community names from a simple container.' {
        docker run --rm busybox:1.36 sh -lc 'nslookup github.com && nslookup steamcdn-a.akamaihd.net && nslookup media.steampowered.com && nslookup steamcommunity.com'
    } -AllowInconclusive

    Invoke-DiagnosticCheck 'container-https-default' 'Check HTTPS access to GitHub API and SteamCMD installer from a simple container.' {
        docker run --rm curlimages/curl:8.10.1 sh -lc 'curl -fsSIL --max-time 20 https://api.github.com >/dev/null && curl -fsSIL --max-time 20 https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz >/dev/null'
    } -AllowInconclusive

    Invoke-DiagnosticCheck 'container-package-repository' 'Check Ubuntu package repository reachability from a container.' {
        docker run --rm ubuntu:24.04 bash -lc 'apt-get update -qq'
    } -AllowInconclusive

    if (-not $SkipDnsOverride) {
        Invoke-DiagnosticCheck 'dns-override-1-1-1-1' 'Repeat DNS checks with Docker --dns 1.1.1.1.' {
            docker run --rm --dns 1.1.1.1 busybox:1.36 sh -lc 'nslookup steamcdn-a.akamaihd.net && nslookup media.steampowered.com && nslookup steamcommunity.com'
        } -AllowInconclusive

        Invoke-DiagnosticCheck 'dns-override-8-8-8-8' 'Repeat DNS checks with Docker --dns 8.8.8.8.' {
            docker run --rm --dns 8.8.8.8 busybox:1.36 sh -lc 'nslookup steamcdn-a.akamaihd.net && nslookup media.steampowered.com && nslookup steamcommunity.com'
        } -AllowInconclusive

        Invoke-DiagnosticCheck 'steamcmd-upstream-login-dns-1-1-1-1' 'Try upstream SteamCMD anonymous login with Docker --dns 1.1.1.1.' {
            docker run --rm --dns 1.1.1.1 $script:SteamcmdImage +@ShutdownOnFailedCommand 1 +@NoPromptForPassword 1 +login anonymous +quit
        } -AllowInconclusive -SteamCheck
    }

    $projectImageAvailable = $false
    $global:LASTEXITCODE = 0
    docker image inspect $script:ProjectImage *> $null
    if ($LASTEXITCODE -eq 0) {
        $projectImageAvailable = $true
        Invoke-DiagnosticCheck 'project-image-present' 'Inspect the local project image.' {
            docker image inspect $script:ProjectImage --format '{{.Id}} {{.Created}}'
        }
    } else {
        Add-Skip 'project-image-present' "Project image $script:ProjectImage is not available. Run docker compose build first."
    }

    if ($projectImageAvailable) {
        $volumeArg = "${LogRoot}:/diagnostics"
        Invoke-DiagnosticCheck 'steamcmd-project-login' 'Try SteamCMD anonymous login through this project image and compose entrypoint.' {
            docker compose run --rm -v $volumeArg conan timeout 180s gosu conan env HOME=/serverdata/steam steamcmd +@ShutdownOnFailedCommand 1 +@NoPromptForPassword 1 +login anonymous +quit
        } -AllowInconclusive -SteamCheck

        Invoke-DiagnosticCheck 'steamcmd-project-app-info' 'Try SteamCMD app info for AppID 443030 through this project image.' {
            docker compose run --rm -v $volumeArg conan timeout 240s gosu conan env HOME=/serverdata/steam steamcmd +@ShutdownOnFailedCommand 1 +@NoPromptForPassword 1 +login anonymous +app_info_print $script:AppId +quit
        } -AllowInconclusive -SteamCheck

        if (-not $SkipAppUpdateAttempt) {
            Invoke-DiagnosticCheck 'steamcmd-project-app-update' 'Try the project update script for AppID 443030 with DOWNLOAD_BACKEND=steamcmd and a 300 second timeout.' {
                docker compose run --rm -v $volumeArg -e DOWNLOAD_BACKEND=steamcmd conan timeout 300s gosu conan env HOME=/serverdata/steam /scripts/update-server.sh
            } -AllowInconclusive -SteamCheck
        } else {
            Add-Skip 'steamcmd-project-app-update' 'Skipped by -SkipAppUpdateAttempt.'
        }
    }

    Invoke-DiagnosticCheck 'steamcmd-upstream-login' 'Try SteamCMD anonymous login with upstream steamcmd/steamcmd:ubuntu-24.' {
        docker run --rm $script:SteamcmdImage +@ShutdownOnFailedCommand 1 +@NoPromptForPassword 1 +login anonymous +quit
    } -AllowInconclusive -SteamCheck

    Invoke-DiagnosticCheck 'steamcmd-upstream-app-info' 'Try SteamCMD app info for AppID 443030 with upstream steamcmd/steamcmd:ubuntu-24.' {
        docker run --rm $script:SteamcmdImage +@ShutdownOnFailedCommand 1 +@NoPromptForPassword 1 +login anonymous +app_info_print $script:AppId +quit
    } -AllowInconclusive -SteamCheck

    if (-not $SkipHostNetwork) {
        $hostNetworkAvailable = $false
        $global:LASTEXITCODE = 0
        docker network inspect host *> $null
        if ($LASTEXITCODE -eq 0) {
            docker run --rm --network host busybox:1.36 true *> $null
            if ($LASTEXITCODE -eq 0) {
                $hostNetworkAvailable = $true
            }
        }

        if ($hostNetworkAvailable) {
            Invoke-DiagnosticCheck 'steamcmd-upstream-login-host-network' 'Try upstream SteamCMD anonymous login using Docker host networking.' {
                docker run --rm --network host $script:SteamcmdImage +@ShutdownOnFailedCommand 1 +@NoPromptForPassword 1 +login anonymous +quit
            } -AllowInconclusive -SteamCheck
        } else {
            Add-Skip 'steamcmd-upstream-login-host-network' 'Docker host networking is not available or not enabled.'
        }
    }

    Add-SummaryLine ""
    Add-SummaryLine "InconclusiveCount=$script:InconclusiveCount"
    Add-SummaryLine "SteamFailureCount=$script:SteamFailureCount"
    Add-SummaryLine "FailureCount=$script:FailureCount"
    Write-Host ""
    Write-Host "Summary: inconclusive=$script:InconclusiveCount steam_failures=$script:SteamFailureCount failures=$script:FailureCount"
    Write-Host "Summary file: $script:SummaryPath"

    if ($script:FailureCount -gt 0) {
        exit 1
    }
    if ($StrictSteamFailures -and $script:SteamFailureCount -gt 0) {
        exit 2
    }
    exit 0
} finally {
    Pop-Location
}
