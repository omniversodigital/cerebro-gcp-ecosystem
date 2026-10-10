<#
.SYNOPSIS
    Creates Service Accounts and IAM bindings for the CEREBRO ecosystem.
.DESCRIPTION
    Sets up least-privilege Service Accounts for each domain:
    - cerebro-runner: Cloud Run / Functions execution
    - cerebro-data: BigQuery / Storage / Pub/Sub
    - cerebro-build: Cloud Build / Artifact Registry
    - cerebro-ai: Vertex AI / Gemini API
#>

param(
    [string]$Project = "gen-lang-client-0722648923",
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"

# Service Account definitions: name → (display name, description, roles[])
$serviceAccounts = @{
    "cerebro-runner" = @{
        DisplayName = "CEREBRO Runner"
        Description = "Executes Cloud Run services and Cloud Functions for the CEREBRO ecosystem"
        Roles = @(
            "roles/run.invoker",
            "roles/cloudfunctions.invoker",
            "roles/pubsub.publisher",
            "roles/pubsub.subscriber",
            "roles/logging.logWriter",
            "roles/monitoring.metricWriter",
            "roles/cloudtrace.agent",
            "roles/secretmanager.secretAccessor"
        )
    }
    "cerebro-data" = @{
        DisplayName = "CEREBRO Data"
        Description = "Accesses BigQuery, Cloud Storage, and Pub/Sub for data operations"
        Roles = @(
            "roles/bigquery.dataEditor",
            "roles/bigquery.jobUser",
            "roles/storage.objectAdmin",
            "roles/pubsub.publisher",
            "roles/pubsub.subscriber",
            "roles/logging.logWriter"
        )
    }
    "cerebro-build" = @{
        DisplayName = "CEREBRO Build"
        Description = "Cloud Build and Artifact Registry for CI/CD pipelines"
        Roles = @(
            "roles/cloudbuild.builds.editor",
            "roles/artifactregistry.writer",
            "roles/run.admin",
            "roles/iam.serviceAccountUser",
            "roles/logging.logWriter",
            "roles/storage.objectViewer"
        )
    }
    "cerebro-ai" = @{
        DisplayName = "CEREBRO AI"
        Description = "Vertex AI, Gemini API, and ML model access"
        Roles = @(
            "roles/aiplatform.user",
            "roles/secretmanager.secretAccessor",
            "roles/storage.objectViewer",
            "roles/logging.logWriter"
        )
    }
}

Write-Host "╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║       CEREBRO OMEGA — IAM Setup                           ║" -ForegroundColor Cyan
Write-Host "║       Project: $Project                ║" -ForegroundColor Cyan
Write-Host "╚══════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

# Get existing service accounts
Write-Host "[*] Checking existing service accounts..." -ForegroundColor Yellow
$existingRaw = gcloud iam service-accounts list --project=$Project --format="value(email)" 2>&1
$existing = $existingRaw -split "`r?`n" | Where-Object { $_ -match '@' }

foreach ($saName in $serviceAccounts.Keys) {
    $sa = $serviceAccounts[$saName]
    $email = "$saName@$Project.iam.gserviceaccount.com"
    
    Write-Host ""
    Write-Host "── Service Account: $saName ──" -ForegroundColor Cyan
    
    # Create SA if not exists
    if ($existing -contains $email) {
        Write-Host "  [✓] Already exists: $email" -ForegroundColor Green
    } else {
        Write-Host "  [→] Creating: $email" -ForegroundColor Yellow
        if (-not $DryRun) {
            gcloud iam service-accounts create $saName `
                --display-name="$($sa.DisplayName)" `
                --description="$($sa.Description)" `
                --project=$Project 2>&1 | ForEach-Object { Write-Host "      $_" -ForegroundColor DarkGray }
            Write-Host "  [✓] Created." -ForegroundColor Green
        } else {
            Write-Host "  [DRY RUN] Would create $email" -ForegroundColor Magenta
        }
    }
    
    # Bind roles
    Write-Host "  [*] Binding roles:" -ForegroundColor Yellow
    foreach ($role in $sa.Roles) {
        Write-Host "      → $role" -ForegroundColor Yellow -NoNewline
        if (-not $DryRun) {
            try {
                gcloud projects add-iam-policy-binding $Project `
                    --member="serviceAccount:$email" `
                    --role="$role" `
                    --condition=None `
                    --quiet 2>&1 | Out-Null
                Write-Host " ✓" -ForegroundColor Green
            } catch {
                Write-Host " ✗ (may already exist)" -ForegroundColor DarkYellow
            }
        } else {
            Write-Host " [DRY RUN]" -ForegroundColor Magenta
        }
    }
}

Write-Host ""
Write-Host "╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "║       IAM Setup Complete                                   ║" -ForegroundColor Green
Write-Host "║       Service Accounts: $($serviceAccounts.Count)                              ║" -ForegroundColor Green
Write-Host "╚══════════════════════════════════════════════════════════════╝" -ForegroundColor Green
