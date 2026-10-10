<#
.SYNOPSIS
    Configures Cloud Monitoring dashboards and alerting for the CEREBRO ecosystem.
#>

param(
    [string]$Project = "gen-lang-client-0722648923",
    [string]$Region = "us-central1"
)

$ErrorActionPreference = "Continue"
$DashboardDir = "$PSScriptRoot\..\monitoring\dashboards"
$AlertDir = "$PSScriptRoot\..\monitoring\alerts"

Write-Host "=== CEREBRO - Monitoring & Observability ===" -ForegroundColor Cyan
Write-Host "Project: $Project" -ForegroundColor Cyan
Write-Host ""

# 1. Create notification channel (email)
Write-Host "[1/4] Creating notification channels..." -ForegroundColor Yellow

$emailChannel = @{
    type = "email"
    displayName = "CEREBRO Admin Email"
    labels = @{
        email_address = "omniverso.digital@gmail.com"
    }
} | ConvertTo-Json -Depth 3

$tempChannel = [System.IO.Path]::GetTempFileName() + ".json"
$emailChannel | Out-File -FilePath $tempChannel -Encoding UTF8

$channelResult = gcloud monitoring channels create --channel-content-from-file=$tempChannel --project=$Project --format="value(name)" 2>&1
Remove-Item $tempChannel -ErrorAction SilentlyContinue

if ($channelResult -match "projects/") {
    $channelId = $channelResult.Trim()
    Write-Host "  Email channel created: $channelId" -ForegroundColor Green
} else {
    Write-Host "  Channel creation note: $channelResult" -ForegroundColor DarkYellow
    $channelId = ""
}

# 2. Create log-based metrics
Write-Host ""
Write-Host "[2/4] Creating log-based metrics..." -ForegroundColor Yellow

$logMetrics = @(
    @{
        Name = "cerebro_errors"
        Description = "Count of error-level logs across CEREBRO services"
        Filter = 'resource.type="cloud_run_revision" AND severity>=ERROR'
    },
    @{
        Name = "cerebro_skill_executions"
        Description = "Count of skill execution requests"
        Filter = 'resource.type="cloud_run_revision" AND jsonPayload.event="skill_execution"'
    },
    @{
        Name = "cerebro_security_events"
        Description = "Count of security-related events"
        Filter = 'resource.type="cloud_function" AND jsonPayload.event="security_alert"'
    }
)

foreach ($metric in $logMetrics) {
    Write-Host "  Metric: $($metric.Name)" -ForegroundColor Yellow -NoNewline
    $result = gcloud logging metrics create $metric.Name `
        --description="$($metric.Description)" `
        --log-filter="$($metric.Filter)" `
        --project=$Project 2>&1
    
    if ($result -match "already exists") {
        Write-Host " EXISTS" -ForegroundColor DarkGreen
    } elseif ($result -match "error") {
        Write-Host " WARN: $result" -ForegroundColor DarkYellow
    } else {
        Write-Host " CREATED" -ForegroundColor Green
    }
}

# 3. Create log sink to BigQuery
Write-Host ""
Write-Host "[3/4] Creating log sink to BigQuery..." -ForegroundColor Yellow

$sinkResult = gcloud logging sinks create cerebro-bigquery-sink `
    "bigquery.googleapis.com/projects/$Project/datasets/cerebro_ecosystem" `
    --log-filter='resource.type="cloud_run_revision" OR resource.type="cloud_function"' `
    --project=$Project 2>&1

if ($sinkResult -match "already exists") {
    Write-Host "  Sink already exists" -ForegroundColor DarkGreen
} elseif ($sinkResult -match "error") {
    Write-Host "  Sink note: $sinkResult" -ForegroundColor DarkYellow
} else {
    Write-Host "  Sink created" -ForegroundColor Green
}

# 4. Create uptime checks
Write-Host ""
Write-Host "[4/4] Creating uptime checks..." -ForegroundColor Yellow
Write-Host "  NOTE: Uptime checks require Cloud Run services to be deployed first." -ForegroundColor DarkGray
Write-Host "  Will be configured after service deployment." -ForegroundColor DarkGray

Write-Host ""
Write-Host "=== Monitoring Setup Complete ===" -ForegroundColor Green
