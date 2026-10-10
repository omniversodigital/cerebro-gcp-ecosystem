<#
.SYNOPSIS
    Securely uploads local .env values to GCP Secret Manager.
    Reads from .env file to prevent secret leakage in shell history.
#>

param(
    [string]$Project = "gen-lang-client-0722648923",
    [string]$EnvFile = "..\.env"
)

$ErrorActionPreference = "Stop"
$ScriptDir = $PSScriptRoot
$EnvPath = Join-Path -Path $ScriptDir -ChildPath $EnvFile

Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "  CEREBRO OMEGA - Secret Manager Upload" -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan

if (-not (Test-Path $EnvPath)) {
    Write-Host "[!] Error: File not found -> $EnvPath" -ForegroundColor Red
    Write-Host "Please copy .env.template to .env and fill in your secrets." -ForegroundColor Yellow
    exit 1
}

Write-Host "Reading secrets from $EnvPath..." -ForegroundColor DarkGray

$secretsMap = @{
    "CEREBRO_MT5_CREDENTIALS" = "cerebro-mt5-credentials"
    "CEREBRO_TELEGRAM_BOT_TOKEN" = "cerebro-telegram-bot-token"
    "CEREBRO_STRIPE_API_KEY" = "cerebro-stripe-api-key"
    "CEREBRO_OPENROUTER_API_KEY" = "cerebro-openrouter-api-key"
    "CEREBRO_HERMES_CONFIG" = "cerebro-hermes-config"
    "CEREBRO_POLYMARKET_KEYS" = "cerebro-polymarket-keys"
    "CEREBRO_DATABASE_URL" = "cerebro-database-url"
    "CEREBRO_WEBHOOK_SIGNING_KEY" = "cerebro-webhook-signing-key"
    "ALPACA_LIVE_API_KEY" = "cerebro-alpaca-live-key"
    "ALPACA_LIVE_SECRET_KEY" = "cerebro-alpaca-live-secret"
}

$envLines = Get-Content $EnvPath
$uploaded = 0

foreach ($line in $envLines) {
    if ([string]::IsNullOrWhiteSpace($line) -or $line.StartsWith("#")) { continue }

    $parts = $line.Split('=', 2)
    if ($parts.Length -eq 2) {
        $key = $parts[0].Trim()
        $value = $parts[1].Trim()
        
        # Remove surrounding quotes if present
        if ($value.StartsWith('"') -and $value.EndsWith('"')) {
            $value = $value.Substring(1, $value.Length - 2)
        }

        if ($secretsMap.ContainsKey($key)) {
            $secretName = $secretsMap[$key]
            
            # Skip placeholders
            if ($value -match "your_.*_here") {
                Write-Host "  [SKIP] $secretName (Placeholder value detected)" -ForegroundColor DarkYellow
                continue
            }

            Write-Host "  [UPLOAD] $secretName... " -NoNewline
            
            # Use a temporary file to pipe the secret securely
            $tempFile = New-TemporaryFile
            Set-Content -Path $tempFile.FullName -Value $value -NoNewline
            
            try {
                gcloud secrets versions add $secretName --data-file=$($tempFile.FullName) --project=$Project 2>&1 | Out-Null
                Write-Host "OK" -ForegroundColor Green
                $uploaded++
            } catch {
                Write-Host "FAIL" -ForegroundColor Red
                Write-Host $_.Exception.Message -ForegroundColor Red
            } finally {
                Remove-Item -Path $tempFile.FullName -Force
            }
        }
    }
}

Write-Host ""
Write-Host "Uploaded $uploaded secret payloads to Secret Manager." -ForegroundColor Cyan
