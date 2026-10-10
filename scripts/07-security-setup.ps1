<#
.SYNOPSIS
    Sets up Secret Manager and KMS for the CEREBRO ecosystem.
#>

param(
    [string]$Project = "gen-lang-client-0722648923",
    [string]$Location = "global"
)

$ErrorActionPreference = "Continue"

Write-Host "=== CEREBRO - Security Infrastructure ===" -ForegroundColor Cyan
Write-Host "Project: $Project" -ForegroundColor Cyan
Write-Host ""

# 1. Create KMS keyring and keys
Write-Host "[1/3] Setting up KMS..." -ForegroundColor Yellow

# Create keyring
Write-Host "  Creating keyring: cerebro-keyring" -ForegroundColor Yellow -NoNewline
$result = gcloud kms keyrings create cerebro-keyring --location=$Location --project=$Project 2>&1
if ($result -match "already exists") {
    Write-Host " EXISTS" -ForegroundColor DarkGreen
} elseif ($result -match "error") {
    Write-Host " WARN: $result" -ForegroundColor DarkYellow
} else {
    Write-Host " CREATED" -ForegroundColor Green
}

# Create encryption keys
$keys = @(
    @{ Name = "cerebro-data-key"; Purpose = "encryption"; Rotation = "7776000s" },  # 90 days
    @{ Name = "cerebro-secrets-key"; Purpose = "encryption"; Rotation = "7776000s" }
)

foreach ($key in $keys) {
    Write-Host "  Creating key: $($key.Name)" -ForegroundColor Yellow -NoNewline
    $result = gcloud kms keys create $key.Name `
        --keyring=cerebro-keyring `
        --location=$Location `
        --purpose=$($key.Purpose) `
        --rotation-period=$($key.Rotation) `
        --project=$Project 2>&1
    
    if ($result -match "already exists") {
        Write-Host " EXISTS" -ForegroundColor DarkGreen
    } elseif ($result -match "error") {
        Write-Host " WARN: $result" -ForegroundColor DarkYellow
    } else {
        Write-Host " CREATED" -ForegroundColor Green
    }
}

# 2. Create Secret Manager secrets (empty, ready for values)
Write-Host ""
Write-Host "[2/3] Setting up Secret Manager..." -ForegroundColor Yellow

$secrets = @(
    @{ Name = "cerebro-mt5-credentials"; Labels = "domain=trading,rotation=90d" },
    @{ Name = "cerebro-telegram-bot-token"; Labels = "domain=communication,rotation=manual" },
    @{ Name = "cerebro-stripe-api-key"; Labels = "domain=fintech,rotation=90d" },
    @{ Name = "cerebro-openrouter-api-key"; Labels = "domain=ai,rotation=manual" },
    @{ Name = "cerebro-hermes-config"; Labels = "domain=ecosystem,rotation=manual" },
    @{ Name = "cerebro-polymarket-keys"; Labels = "domain=trading,rotation=30d" },
    @{ Name = "cerebro-database-url"; Labels = "domain=data,rotation=manual" },
    @{ Name = "cerebro-webhook-signing-key"; Labels = "domain=security,rotation=90d" }
)

foreach ($secret in $secrets) {
    Write-Host "  Secret: $($secret.Name)" -ForegroundColor Yellow -NoNewline
    $result = gcloud secrets create $secret.Name `
        --replication-policy=automatic `
        --labels=$($secret.Labels) `
        --project=$Project 2>&1
    
    if ($result -match "already exists") {
        Write-Host " EXISTS" -ForegroundColor DarkGreen
    } elseif ($result -match "error") {
        Write-Host " WARN: $result" -ForegroundColor DarkYellow
    } else {
        Write-Host " CREATED (empty - add value manually)" -ForegroundColor Green
    }
}

# 3. Grant Secret Manager access to service accounts
Write-Host ""
Write-Host "[3/3] Granting Secret Manager access..." -ForegroundColor Yellow

$accessBindings = @(
    @{ SA = "cerebro-runner"; Secrets = @("cerebro-mt5-credentials", "cerebro-telegram-bot-token", "cerebro-webhook-signing-key") },
    @{ SA = "cerebro-ai"; Secrets = @("cerebro-openrouter-api-key", "cerebro-hermes-config") },
    @{ SA = "cerebro-data"; Secrets = @("cerebro-database-url") }
)

foreach ($binding in $accessBindings) {
    $saEmail = "$($binding.SA)@$Project.iam.gserviceaccount.com"
    foreach ($secretName in $binding.Secrets) {
        Write-Host "  $($binding.SA) -> $secretName" -ForegroundColor DarkGray -NoNewline
        $result = gcloud secrets add-iam-policy-binding $secretName `
            --member="serviceAccount:$saEmail" `
            --role="roles/secretmanager.secretAccessor" `
            --project=$Project 2>&1
        
        if ($result -match "error") {
            Write-Host " WARN" -ForegroundColor DarkYellow
        } else {
            Write-Host " OK" -ForegroundColor Green
        }
    }
}

Write-Host ""
Write-Host "=== Security Setup Complete ===" -ForegroundColor Green
Write-Host "KMS Keys: $($keys.Count) | Secrets: $($secrets.Count) (empty - add values)" -ForegroundColor Green
Write-Host ""
Write-Host "NEXT: Add secret values with:" -ForegroundColor Yellow
Write-Host '  echo -n "YOUR_VALUE" | gcloud secrets versions add SECRET_NAME --data-file=-' -ForegroundColor DarkGray
