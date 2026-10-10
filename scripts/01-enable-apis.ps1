<#
.SYNOPSIS
    Enables all required GCP APIs for the CEREBRO ecosystem.
#>

param(
    [string]$Project = "gen-lang-client-0722648923",
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"

$apis = @(
    "run.googleapis.com",
    "cloudfunctions.googleapis.com",
    "cloudscheduler.googleapis.com",
    "cloudtasks.googleapis.com",
    "eventarc.googleapis.com",
    "vpcaccess.googleapis.com",
    "bigquery.googleapis.com",
    "bigquerydatatransfer.googleapis.com",
    "pubsub.googleapis.com",
    "firestore.googleapis.com",
    "redis.googleapis.com",
    "dataflow.googleapis.com",
    "cloudbuild.googleapis.com",
    "artifactregistry.googleapis.com",
    "clouddeploy.googleapis.com",
    "sourcerepo.googleapis.com",
    "secretmanager.googleapis.com",
    "cloudkms.googleapis.com",
    "discoveryengine.googleapis.com",
    "speech.googleapis.com",
    "vision.googleapis.com",
    "translate.googleapis.com",
    "language.googleapis.com",
    "servicenetworking.googleapis.com",
    "containerregistry.googleapis.com"
)

Write-Host "=== CEREBRO OMEGA - GCP API Enablement ===" -ForegroundColor Cyan
Write-Host "Project: $Project" -ForegroundColor Cyan
Write-Host ""

# Get currently enabled APIs
Write-Host "[*] Fetching currently enabled APIs..." -ForegroundColor Yellow
$enabledRaw = gcloud services list --enabled --project=$Project --format="value(config.name)" 2>&1
$enabled = @($enabledRaw -split "`r?`n" | Where-Object { $_ -match '\.googleapis\.com$' })

$toEnable = @()
$alreadyEnabled = @()

foreach ($api in $apis) {
    if ($enabled -contains $api) {
        $alreadyEnabled += $api
    } else {
        $toEnable += $api
    }
}

Write-Host ""
Write-Host "[OK] Already enabled: $($alreadyEnabled.Count)" -ForegroundColor Green
foreach ($api in $alreadyEnabled) {
    Write-Host "    OK $api" -ForegroundColor DarkGreen
}

Write-Host ""
if ($toEnable.Count -eq 0) {
    Write-Host "[OK] All APIs already enabled. Nothing to do." -ForegroundColor Green
    exit 0
}

Write-Host "[->] APIs to enable: $($toEnable.Count)" -ForegroundColor Yellow
foreach ($api in $toEnable) {
    Write-Host "    -> $api" -ForegroundColor Yellow
}

if ($DryRun) {
    Write-Host ""
    Write-Host "[DRY RUN] No changes made." -ForegroundColor Magenta
    exit 0
}

Write-Host ""
Write-Host "[*] Enabling APIs in batch..." -ForegroundColor Cyan

$apiList = $toEnable -join " "
try {
    $output = gcloud services enable $apiList --project=$Project 2>&1
    $output | ForEach-Object { Write-Host "    $_" -ForegroundColor DarkGray }
    Write-Host ""
    Write-Host "[OK] All APIs enabled successfully." -ForegroundColor Green
} catch {
    Write-Host "[!] Batch failed, falling back to individual..." -ForegroundColor Yellow
    $failed = @()
    foreach ($api in $toEnable) {
        Write-Host "    Enabling $api..." -ForegroundColor Yellow -NoNewline
        try {
            gcloud services enable $api --project=$Project 2>&1 | Out-Null
            Write-Host " OK" -ForegroundColor Green
        } catch {
            Write-Host " FAIL" -ForegroundColor Red
            $failed += $api
        }
    }
    if ($failed.Count -gt 0) {
        Write-Host "[FAIL] Could not enable: $($failed -join ', ')" -ForegroundColor Red
        exit 1
    }
}

Write-Host ""
Write-Host "=== API Enablement Complete ===" -ForegroundColor Green
Write-Host "Enabled: $($toEnable.Count) new | Total: $($apis.Count) APIs" -ForegroundColor Green
