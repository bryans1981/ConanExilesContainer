param(
    [string]$LogRoot,
    [switch]$StrictDepotDownloaderFailures,
    [switch]$SkipAppUpdateAttempt
)

$ErrorActionPreference = 'Continue'
$ProgressPreference = 'SilentlyContinue'

$script:RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
if ([string]::IsNullOrWhiteSpace($LogRoot)) {
    $stamp = (Get-Date).ToUniversalTime().ToString('yyyyMMddTHHmmssZ')
    $LogRoot = Join-Path $script:RepoRoot "test-results\depotdownloader-connectivity\$stamp-$PID"
}

New-Item -ItemType Directory -Force -Path $LogRoot | Out-Null
$script:SummaryPath = Join-Path $LogRoot 'summary.txt'
$script:InconclusiveCount = 0
$script:DepotDownloaderFailureCount = 0
$script:FailureCount = 0
$script:ProjectImage = 'conan-exiles-container:local'
$script:AppId = '443030'
$script:DepotDownloaderVersion = 'DepotDownloader_3.4.0'
$script:DepotDownloaderReleaseUrl = 'https://github.com/SteamRE/DepotDownloader/releases/download/DepotDownloader_3.4.0/DepotDownloader-linux-x64.zip'

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
        [switch]$DepotDownloaderCheck
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
        if ($DepotDownloaderCheck) {
            $script:DepotDownloaderFailureCount++
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
        "DepotDownloader connectivity diagnostics"
        "StartedUtc=$((Get-Date).ToUniversalTime().ToString('o'))"
        "RepoRoot=$script:RepoRoot"
        "LogRoot=$LogRoot"
        "AppId=$script:AppId"
        "DepotDownloaderVersion=$script:DepotDownloaderVersion"
        ""
    )

    Invoke-DiagnosticCheck 'host-dns' 'Resolve public hostnames from the Codex host. No LAN hosts are contacted.' {
        if (Get-Command Resolve-DnsName -ErrorAction SilentlyContinue) {
            Resolve-DnsName github.com
            Resolve-DnsName steamcommunity.com
        } else {
            [System.Net.Dns]::GetHostAddresses('github.com')
            [System.Net.Dns]::GetHostAddresses('steamcommunity.com')
        }
    } -AllowInconclusive

    Invoke-DiagnosticCheck 'host-release-https' 'Fetch the pinned DepotDownloader release URL from the host.' {
        Invoke-WebRequest -Uri $script:DepotDownloaderReleaseUrl -Method Head -UseBasicParsing -TimeoutSec 30 | Select-Object -ExpandProperty StatusCode
    } -AllowInconclusive

    Invoke-DiagnosticCheck 'docker-version' 'Verify Docker client/server are available.' {
        docker version
    }

    Invoke-DiagnosticCheck 'container-release-https' 'Fetch the pinned DepotDownloader release URL from a simple container.' {
        docker run --rm curlimages/curl:8.10.1 sh -lc "curl -fsSIL --max-time 30 '$script:DepotDownloaderReleaseUrl' >/dev/null"
    } -AllowInconclusive

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
        Invoke-DiagnosticCheck 'depotdownloader-version' 'Run the image-installed DepotDownloader binary and print version/runtime.' {
            docker compose run --rm -v $volumeArg conan /opt/depotdownloader/DepotDownloader --version
        } -AllowInconclusive -DepotDownloaderCheck

        Invoke-DiagnosticCheck 'depotdownloader-app-manifest-only' 'Try DepotDownloader manifest-only access for AppID 443030 using anonymous access.' {
            docker compose run --rm -v $volumeArg `
                -e SERVER_DIR=/diagnostics/serverfiles `
                -e STEAM_DIR=/diagnostics/steam `
                -e LOG_DIR=/diagnostics/logs `
                conan timeout 300s gosu conan env HOME=/diagnostics/home /opt/depotdownloader/DepotDownloader `
                -app $script:AppId -os linux -dir /diagnostics/manifest-only -manifest-only
        } -AllowInconclusive -DepotDownloaderCheck

        if (-not $SkipAppUpdateAttempt) {
            Invoke-DiagnosticCheck 'depotdownloader-project-app-update' 'Try project update-server.sh with DOWNLOAD_BACKEND=depotdownloader using disposable diagnostic paths.' {
                docker compose run --rm -v $volumeArg `
                    -e DOWNLOAD_BACKEND=depotdownloader `
                    -e SERVER_DIR=/diagnostics/serverfiles `
                    -e STEAM_DIR=/diagnostics/steam `
                    -e LOG_DIR=/diagnostics/logs `
                    conan timeout 600s gosu conan env HOME=/diagnostics/home /scripts/update-server.sh
            } -AllowInconclusive -DepotDownloaderCheck
        } else {
            Add-Skip 'depotdownloader-project-app-update' 'Skipped by -SkipAppUpdateAttempt.'
        }
    }

    Add-SummaryLine ""
    Add-SummaryLine "InconclusiveCount=$script:InconclusiveCount"
    Add-SummaryLine "DepotDownloaderFailureCount=$script:DepotDownloaderFailureCount"
    Add-SummaryLine "FailureCount=$script:FailureCount"
    Write-Host ""
    Write-Host "Summary: inconclusive=$script:InconclusiveCount depotdownloader_failures=$script:DepotDownloaderFailureCount failures=$script:FailureCount"
    Write-Host "Summary file: $script:SummaryPath"

    if ($script:FailureCount -gt 0) {
        exit 1
    }
    if ($StrictDepotDownloaderFailures -and $script:DepotDownloaderFailureCount -gt 0) {
        exit 2
    }
    exit 0
} finally {
    Pop-Location
}
