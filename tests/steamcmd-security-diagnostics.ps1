param(
    [string]$LogRoot,
    [switch]$StrictSteamFailures,
    [switch]$SkipAppInfo,
    [switch]$SkipHostNetwork,
    [switch]$SkipProjectImage
)

$ErrorActionPreference = 'Continue'
$ProgressPreference = 'SilentlyContinue'

$script:RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
if ([string]::IsNullOrWhiteSpace($LogRoot)) {
    $stamp = (Get-Date).ToUniversalTime().ToString('yyyyMMddTHHmmssZ')
    $LogRoot = Join-Path $script:RepoRoot "test-results\steamcmd-security-diagnostics\$stamp-$PID"
}

New-Item -ItemType Directory -Force -Path $LogRoot | Out-Null
$script:SummaryPath = Join-Path $LogRoot 'summary.txt'
$script:InconclusiveCount = 0
$script:SteamFailureCount = 0
$script:FailureCount = 0
$script:AppId = '443030'
$script:ProjectImage = 'conan-exiles-container:local'
$script:SteamcmdImage = 'steamcmd/steamcmd:ubuntu-24'
$script:CustomSeccompProfile = Join-Path $script:RepoRoot 'docker\seccomp\steamcmd-diagnostic.json'

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
        Add-Content -LiteralPath $logPath -Value $line.ToString()
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

function Invoke-DockerSteamCmd {
    param(
        [string]$Image,
        [string[]]$DockerArgs,
        [string]$SteamCommand
    )

    $args = @('run', '--rm')
    if ($DockerArgs) {
        $args += $DockerArgs
    }
    $args += @('--entrypoint', 'bash', $Image, '-lc', "timeout 240s steamcmd $SteamCommand")
    & docker @args
}

function Test-HostNetworkAvailable {
    $global:LASTEXITCODE = 0
    docker network inspect host *> $null
    if ($LASTEXITCODE -ne 0) {
        return $false
    }
    docker run --rm --network host busybox:1.36 true *> $null
    return ($LASTEXITCODE -eq 0)
}

Push-Location $script:RepoRoot
try {
    Set-Content -LiteralPath $script:SummaryPath -Value @(
        "SteamCMD Docker security diagnostics"
        "StartedUtc=$((Get-Date).ToUniversalTime().ToString('o'))"
        "RepoRoot=$script:RepoRoot"
        "LogRoot=$LogRoot"
        "AppId=$script:AppId"
        "ProjectImage=$script:ProjectImage"
        "SteamcmdImage=$script:SteamcmdImage"
        ""
    )

    Invoke-DiagnosticCheck 'docker-version' 'Capture Docker client, Engine, containerd, and runc versions.' {
        docker version
    }

    Invoke-DiagnosticCheck 'docker-info' 'Capture Docker Engine security options, runtime, context, proxy, and kernel details.' {
        docker info
    }

    Invoke-DiagnosticCheck 'docker-context' 'Capture current Docker context.' {
        docker context show
        docker context inspect
    }

    Invoke-DiagnosticCheck 'docker-desktop-version' 'Capture Docker Desktop version if available from the Docker CLI plugin.' {
        docker desktop version
    } -AllowInconclusive

    Invoke-DiagnosticCheck 'upstream-default-login' 'Upstream Linux SteamCMD anonymous login with Docker default security profile.' {
        Invoke-DockerSteamCmd -Image $script:SteamcmdImage -DockerArgs @() -SteamCommand '+@ShutdownOnFailedCommand 1 +@NoPromptForPassword 1 +login anonymous +quit'
    } -AllowInconclusive -SteamCheck

    Invoke-DiagnosticCheck 'upstream-unconfined-login' 'Upstream Linux SteamCMD anonymous login with diagnostic seccomp=unconfined.' {
        Invoke-DockerSteamCmd -Image $script:SteamcmdImage -DockerArgs @('--security-opt', 'seccomp=unconfined') -SteamCommand '+@ShutdownOnFailedCommand 1 +@NoPromptForPassword 1 +login anonymous +quit'
    } -AllowInconclusive -SteamCheck

    if (-not $SkipAppInfo) {
        Invoke-DiagnosticCheck 'upstream-default-app-info' 'Upstream Linux SteamCMD AppID 443030 app info with Docker default security profile.' {
            Invoke-DockerSteamCmd -Image $script:SteamcmdImage -DockerArgs @() -SteamCommand "+@ShutdownOnFailedCommand 1 +@NoPromptForPassword 1 +login anonymous +app_info_print $script:AppId +quit"
        } -AllowInconclusive -SteamCheck

        Invoke-DiagnosticCheck 'upstream-unconfined-app-info' 'Upstream Linux SteamCMD AppID 443030 app info with diagnostic seccomp=unconfined.' {
            Invoke-DockerSteamCmd -Image $script:SteamcmdImage -DockerArgs @('--security-opt', 'seccomp=unconfined') -SteamCommand "+@ShutdownOnFailedCommand 1 +@NoPromptForPassword 1 +login anonymous +app_info_print $script:AppId +quit"
        } -AllowInconclusive -SteamCheck
    } else {
        Add-Skip 'upstream-app-info' 'Skipped by -SkipAppInfo.'
    }

    if (Test-Path -LiteralPath $script:CustomSeccompProfile -PathType Leaf) {
        Invoke-DiagnosticCheck 'upstream-custom-seccomp-login' 'Upstream Linux SteamCMD anonymous login with project custom seccomp profile.' {
            Invoke-DockerSteamCmd -Image $script:SteamcmdImage -DockerArgs @('--security-opt', "seccomp=$script:CustomSeccompProfile") -SteamCommand '+@ShutdownOnFailedCommand 1 +@NoPromptForPassword 1 +login anonymous +quit'
        } -AllowInconclusive -SteamCheck
    } else {
        Add-Skip 'upstream-custom-seccomp-login' 'No verified custom seccomp profile exists at docker/seccomp/steamcmd-diagnostic.json.'
    }

    if (-not $SkipProjectImage) {
        $global:LASTEXITCODE = 0
        docker image inspect $script:ProjectImage *> $null
        if ($LASTEXITCODE -eq 0) {
            Invoke-DiagnosticCheck 'project-default-login' 'Project image Linux SteamCMD anonymous login with Docker default security profile.' {
                Invoke-DockerSteamCmd -Image $script:ProjectImage -DockerArgs @() -SteamCommand '+@ShutdownOnFailedCommand 1 +@NoPromptForPassword 1 +login anonymous +quit'
            } -AllowInconclusive -SteamCheck

            Invoke-DiagnosticCheck 'project-unconfined-login' 'Project image Linux SteamCMD anonymous login with diagnostic seccomp=unconfined.' {
                Invoke-DockerSteamCmd -Image $script:ProjectImage -DockerArgs @('--security-opt', 'seccomp=unconfined') -SteamCommand '+@ShutdownOnFailedCommand 1 +@NoPromptForPassword 1 +login anonymous +quit'
            } -AllowInconclusive -SteamCheck
        } else {
            Add-Skip 'project-image-present' "Project image $script:ProjectImage is not available. Run docker compose build first."
        }
    } else {
        Add-Skip 'project-image-tests' 'Skipped by -SkipProjectImage.'
    }

    if (-not $SkipHostNetwork) {
        if (Test-HostNetworkAvailable) {
            Invoke-DiagnosticCheck 'upstream-host-network-login' 'Upstream Linux SteamCMD anonymous login with Docker host networking and default security.' {
                Invoke-DockerSteamCmd -Image $script:SteamcmdImage -DockerArgs @('--network', 'host') -SteamCommand '+@ShutdownOnFailedCommand 1 +@NoPromptForPassword 1 +login anonymous +quit'
            } -AllowInconclusive -SteamCheck
        } else {
            Add-Skip 'upstream-host-network-login' 'Docker host networking is not available or not enabled.'
        }
    } else {
        Add-Skip 'upstream-host-network-login' 'Skipped by -SkipHostNetwork.'
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
