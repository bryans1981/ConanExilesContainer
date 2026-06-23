param(
    [string]$LogRoot,
    [switch]$StrictSteamFailures,
    [switch]$RunAppUpdateProbe,
    [switch]$KeepAppUpdateTemp
)

$ErrorActionPreference = 'Continue'
$ProgressPreference = 'SilentlyContinue'

$script:RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
if ([string]::IsNullOrWhiteSpace($LogRoot)) {
    $stamp = (Get-Date).ToUniversalTime().ToString('yyyyMMddTHHmmssZ')
    $LogRoot = Join-Path $script:RepoRoot "test-results\windows-steamcmd-comparison\$stamp-$PID"
}

New-Item -ItemType Directory -Force -Path $LogRoot | Out-Null
$script:SummaryPath = Join-Path $LogRoot 'summary.txt'
$script:InconclusiveCount = 0
$script:SteamFailureCount = 0
$script:FailureCount = 0
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

function Add-Candidate {
    param(
        [System.Collections.Generic.List[string]]$Candidates,
        [string]$Path
    )
    if (-not [string]::IsNullOrWhiteSpace($Path) -and -not $Candidates.Contains($Path)) {
        $Candidates.Add($Path)
    }
}

function Get-SteamCmdCandidate {
    $candidates = [System.Collections.Generic.List[string]]::new()

    Add-Candidate $candidates $env:WINDOWS_STEAMCMD_EXE

    $command = Get-Command steamcmd.exe -ErrorAction SilentlyContinue
    if ($command) {
        Add-Candidate $candidates $command.Source
    }

    $knownPaths = @(
        'C:\Conan Exiles Server\DedicatedServerLauncher\steamcmd.exe',
        'C:\Conan Exiles Server\steamcmd.exe',
        'C:\steamcmd\steamcmd.exe',
        'C:\SteamCMD\steamcmd.exe',
        'C:\Program Files (x86)\Steam\steamcmd.exe',
        'C:\Program Files\Steam\steamcmd.exe',
        (Join-Path $env:LOCALAPPDATA 'SteamCMD\steamcmd.exe')
    )

    if ($env:ProgramFiles) {
        $knownPaths += (Join-Path $env:ProgramFiles 'Conan Exiles Dedicated Server Launcher\steamcmd\steamcmd.exe')
    }
    if (${env:ProgramFiles(x86)}) {
        $knownPaths += (Join-Path ${env:ProgramFiles(x86)} 'Conan Exiles Dedicated Server Launcher\steamcmd\steamcmd.exe')
    }

    foreach ($path in $knownPaths) {
        Add-Candidate $candidates $path
    }

    $searchRoots = @(
        'C:\Conan Exiles Server',
        'C:\steamcmd',
        'C:\SteamCMD'
    )

    foreach ($root in $searchRoots) {
        if (Test-Path -LiteralPath $root) {
            Get-ChildItem -LiteralPath $root -Filter steamcmd.exe -File -Recurse -ErrorAction SilentlyContinue |
                Select-Object -First 5 |
                ForEach-Object { Add-Candidate $candidates $_.FullName }
        }
    }

    Add-SummaryLine "SteamCMD candidates checked:"
    foreach ($candidate in $candidates) {
        Add-SummaryLine "  $candidate"
        if (Test-Path -LiteralPath $candidate -PathType Leaf) {
            return (Resolve-Path -LiteralPath $candidate).Path
        }
    }

    return $null
}

Push-Location $script:RepoRoot
try {
    Set-Content -LiteralPath $script:SummaryPath -Value @(
        "Windows host SteamCMD comparison"
        "StartedUtc=$((Get-Date).ToUniversalTime().ToString('o'))"
        "RepoRoot=$script:RepoRoot"
        "LogRoot=$LogRoot"
        "AppId=$script:AppId"
        ""
    )

    $steamcmdExe = Get-SteamCmdCandidate
    if ([string]::IsNullOrWhiteSpace($steamcmdExe)) {
        Add-Skip 'windows-steamcmd-detect' 'Windows SteamCMD was not found. Set WINDOWS_STEAMCMD_EXE to the full path of steamcmd.exe and rerun.'
    } else {
        Add-SummaryLine "SelectedSteamCmd=$steamcmdExe"
        Write-Host "Selected Windows SteamCMD: $steamcmdExe"

        Invoke-DiagnosticCheck 'windows-steamcmd-version' 'Run Windows SteamCMD with +quit to verify startup.' {
            & $steamcmdExe +@ShutdownOnFailedCommand 1 +@NoPromptForPassword 1 +quit
        } -AllowInconclusive -SteamCheck

        Invoke-DiagnosticCheck 'windows-steamcmd-login' 'Run Windows SteamCMD anonymous login.' {
            & $steamcmdExe +@ShutdownOnFailedCommand 1 +@NoPromptForPassword 1 +login anonymous +quit
        } -AllowInconclusive -SteamCheck

        Invoke-DiagnosticCheck 'windows-steamcmd-app-info' 'Run Windows SteamCMD anonymous AppID 443030 app info check.' {
            & $steamcmdExe +@ShutdownOnFailedCommand 1 +@NoPromptForPassword 1 +login anonymous +app_info_print $script:AppId +quit
        } -AllowInconclusive -SteamCheck

        if ($RunAppUpdateProbe) {
            $tempRoot = Join-Path $LogRoot 'app-update-temp'
            New-Item -ItemType Directory -Force -Path $tempRoot | Out-Null
            Add-SummaryLine "AppUpdateTemp=$tempRoot"
            Invoke-DiagnosticCheck 'windows-steamcmd-app-update-probe' 'Optional Windows SteamCMD app_update probe using a disposable diagnostic temp folder.' {
                & $steamcmdExe +@ShutdownOnFailedCommand 1 +@NoPromptForPassword 1 +force_install_dir $tempRoot +login anonymous +app_update $script:AppId validate +quit
            } -AllowInconclusive -SteamCheck

            if (-not $KeepAppUpdateTemp -and (Test-Path -LiteralPath $tempRoot)) {
                Remove-Item -LiteralPath $tempRoot -Recurse -Force
                Add-SummaryLine "RemovedAppUpdateTemp=$tempRoot"
            }
        } else {
            Add-Skip 'windows-steamcmd-app-update-probe' 'Skipped by default. Use -RunAppUpdateProbe to download into a disposable diagnostic folder.'
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
