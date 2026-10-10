<#
.SYNOPSIS
    Sets up Artifact Registry and CI/CD infrastructure.
#>

param(
    [string]$Project = "gen-lang-client-0722648923",
    [string]$Region = "us-central1"
)

$ErrorActionPreference = "Continue"

Write-Host "=== CEREBRO - CI/CD Infrastructure ===" -ForegroundColor Cyan
Write-Host "Project: $Project | Region: $Region" -ForegroundColor Cyan
Write-Host ""

# 1. Create Artifact Registry repositories
Write-Host "[1/3] Creating Artifact Registry repositories..." -ForegroundColor Yellow

$repos = @(
    @{ Name = "cerebro-docker"; Format = "docker"; Description = "Docker images for CEREBRO services" },
    @{ Name = "cerebro-npm"; Format = "npm"; Description = "NPM packages for CEREBRO skills" },
    @{ Name = "cerebro-python"; Format = "python"; Description = "Python packages for CEREBRO scripts" }
)

foreach ($repo in $repos) {
    Write-Host "  Repo: $($repo.Name) ($($repo.Format))" -ForegroundColor Yellow -NoNewline
    $result = gcloud artifacts repositories create $repo.Name `
        --repository-format=$($repo.Format) `
        --location=$Region `
        --description="$($repo.Description)" `
        --project=$Project 2>&1
    
    if ($result -match "already exists") {
        Write-Host " EXISTS" -ForegroundColor DarkGreen
    } elseif ($result -match "error") {
        Write-Host " WARN: $result" -ForegroundColor DarkYellow
    } else {
        Write-Host " CREATED" -ForegroundColor Green
    }
}

# 2. Create Cloud Scheduler jobs
Write-Host ""
Write-Host "[2/3] Creating Cloud Scheduler jobs..." -ForegroundColor Yellow

$jobs = @(
    @{
        Name = "cerebro-nightly-audit"
        Schedule = "0 3 * * *"
        Description = "Nightly ecosystem audit and skill synthesis"
        Uri = "placeholder"
        HttpMethod = "POST"
    },
    @{
        Name = "cerebro-hourly-health"
        Schedule = "0 * * * *"
        Description = "Hourly ecosystem health check"
        Uri = "placeholder"
        HttpMethod = "GET"
    },
    @{
        Name = "cerebro-daily-backup"
        Schedule = "0 2 * * *"
        Description = "Daily configuration backup"
        Uri = "placeholder"
        HttpMethod = "POST"
    },
    @{
        Name = "cerebro-weekly-security"
        Schedule = "0 4 * * 1"
        Description = "Weekly security audit"
        Uri = "placeholder"
        HttpMethod = "POST"
    }
)

Write-Host "  NOTE: Scheduler jobs will use placeholder URIs until Cloud Run services are deployed." -ForegroundColor DarkGray
foreach ($job in $jobs) {
    Write-Host "  Job: $($job.Name) [$($job.Schedule)]" -ForegroundColor Yellow -NoNewline
    
    # Create with Pub/Sub target for now (doesn't require deployed services)
    $result = gcloud scheduler jobs create pubsub $job.Name `
        --schedule="$($job.Schedule)" `
        --topic="ecosystem-events" `
        --message-body="{`"eventType`":`"scheduled_$($job.Name)`",`"source`":`"scheduler`"}" `
        --location=$Region `
        --description="$($job.Description)" `
        --time-zone="UTC" `
        --project=$Project 2>&1
    
    if ($result -match "already exists") {
        Write-Host " EXISTS" -ForegroundColor DarkGreen
    } elseif ($result -match "error") {
        Write-Host " WARN: $result" -ForegroundColor DarkYellow
    } else {
        Write-Host " CREATED" -ForegroundColor Green
    }
}

# 3. Configure Docker auth for Artifact Registry
Write-Host ""
Write-Host "[3/3] Configuring Docker auth..." -ForegroundColor Yellow
$result = gcloud auth configure-docker "$Region-docker.pkg.dev" --quiet 2>&1
Write-Host "  Docker auth configured for $Region-docker.pkg.dev" -ForegroundColor Green

Write-Host ""
Write-Host "=== CI/CD Setup Complete ===" -ForegroundColor Green
Write-Host "Repos: $($repos.Count) | Scheduler Jobs: $($jobs.Count)" -ForegroundColor Green
