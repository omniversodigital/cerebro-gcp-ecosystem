<#
.SYNOPSIS
    Master deployment script for the CEREBRO GCP Ecosystem.
    Orchestrates all setup scripts in correct dependency order.
#>

param(
    [string]$Project = "gen-lang-client-0722648923",
    [string]$Region = "us-central1",
    [ValidateSet("all", "apis", "iam", "data", "pubsub", "storage", "monitoring", "security", "cicd")]
    [string]$Phase = "all",
    [switch]$DryRun
)

$ErrorActionPreference = "Continue"
$ScriptDir = $PSScriptRoot

Write-Host ""
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "  CEREBRO OMEGA - GCP Ecosystem Deployment" -ForegroundColor Cyan
Write-Host "  Project: $Project" -ForegroundColor Cyan
Write-Host "  Region:  $Region" -ForegroundColor Cyan
Write-Host "  Phase:   $Phase" -ForegroundColor Cyan
Write-Host "  DryRun:  $DryRun" -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host ""

$startTime = Get-Date

function Run-Phase {
    param([string]$Name, [string]$Script, [hashtable]$Params)
    
    Write-Host ""
    Write-Host "--- Phase: $Name ---" -ForegroundColor Magenta
    
    if (-not (Test-Path $Script)) {
        Write-Host "  SKIP - Script not found: $Script" -ForegroundColor DarkYellow
        return
    }
    
    $phaseStart = Get-Date
    try {
        & $Script @Params
        $elapsed = ((Get-Date) - $phaseStart).TotalSeconds
        Write-Host "  DONE ($([math]::Round($elapsed, 1))s)" -ForegroundColor Green
    } catch {
        $elapsed = ((Get-Date) - $phaseStart).TotalSeconds
        Write-Host "  WARN: $_ ($([math]::Round($elapsed, 1))s)" -ForegroundColor DarkYellow
    }
}

$commonParams = @{ Project = $Project }

# Phase execution order (dependencies respected)
$phases = @(
    @{ Name = "APIs";        Script = "$ScriptDir\01-enable-apis.ps1";      Params = $commonParams;                     Key = "apis" },
    @{ Name = "IAM";         Script = "$ScriptDir\02-iam-setup.ps1";        Params = $commonParams;                     Key = "iam" },
    @{ Name = "BigQuery";    Script = "$ScriptDir\03-bigquery-setup.ps1";   Params = ($commonParams + @{Location="US"}); Key = "data" },
    @{ Name = "Pub/Sub";     Script = "$ScriptDir\04-pubsub-setup.ps1";     Params = $commonParams;                     Key = "pubsub" },
    @{ Name = "Storage";     Script = "$ScriptDir\05-storage-setup.ps1";    Params = ($commonParams + @{Location="US"}); Key = "storage" },
    @{ Name = "Monitoring";  Script = "$ScriptDir\06-monitoring-setup.ps1";  Params = ($commonParams + @{Region=$Region}); Key = "monitoring" },
    @{ Name = "Security";    Script = "$ScriptDir\07-security-setup.ps1";    Params = $commonParams;                     Key = "security" },
    @{ Name = "CI/CD";       Script = "$ScriptDir\08-cicd-setup.ps1";        Params = ($commonParams + @{Region=$Region}); Key = "cicd" }
)

foreach ($phase in $phases) {
    if ($Phase -eq "all" -or $Phase -eq $phase.Key) {
        Run-Phase -Name $phase.Name -Script $phase.Script -Params $phase.Params
    }
}

$totalElapsed = ((Get-Date) - $startTime).TotalSeconds

Write-Host ""
Write-Host "================================================================" -ForegroundColor Green
Write-Host "  Deployment Complete" -ForegroundColor Green
Write-Host "  Total Time: $([math]::Round($totalElapsed, 1))s" -ForegroundColor Green
Write-Host "================================================================" -ForegroundColor Green
Write-Host ""
Write-Host "Next Steps:" -ForegroundColor Yellow
Write-Host "  1. Add secret values:  echo -n 'VALUE' | gcloud secrets versions add SECRET --data-file=-" -ForegroundColor DarkGray
Write-Host "  2. Build API Gateway:  cd services/api-gateway && gcloud builds submit" -ForegroundColor DarkGray
Write-Host "  3. Deploy Functions:   gcloud functions deploy FUNCTION --gen2 --trigger-topic=TOPIC" -ForegroundColor DarkGray
Write-Host "  4. Terraform:          cd terraform && terraform init && terraform plan" -ForegroundColor DarkGray
