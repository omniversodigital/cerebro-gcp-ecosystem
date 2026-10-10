<#
.SYNOPSIS
    Creates BigQuery dataset, tables, and views for the CEREBRO ecosystem.
#>

param(
    [string]$Project = "gen-lang-client-0722648923",
    [string]$Location = "US",
    [string]$Dataset = "cerebro_ecosystem"
)

$ErrorActionPreference = "Continue"
$SchemaDir = "$PSScriptRoot\..\data\bigquery\schema"
$ViewsDir = "$PSScriptRoot\..\data\bigquery\views"

Write-Host "=== CEREBRO - BigQuery Data Infrastructure ===" -ForegroundColor Cyan
Write-Host "Project: $Project | Location: $Location | Dataset: $Dataset" -ForegroundColor Cyan
Write-Host ""

# 1. Create dataset
Write-Host "[1/3] Creating dataset: $Dataset" -ForegroundColor Yellow
bq --project_id=$Project mk --dataset --location=$Location --description="CEREBRO Ecosystem Data Warehouse" "$Dataset" 2>&1 | ForEach-Object {
    if ($_ -match "already exists") {
        Write-Host "  OK - Dataset already exists" -ForegroundColor Green
    } elseif ($_ -match "error" -or $_ -match "Error") {
        Write-Host "  WARN - $_" -ForegroundColor DarkYellow
    } else {
        Write-Host "  OK - Created" -ForegroundColor Green
    }
}

# 2. Create tables from schema files
Write-Host ""
Write-Host "[2/3] Creating tables..." -ForegroundColor Yellow

$tables = @(
    @{ Name = "skill_executions"; Schema = "$SchemaDir\skill_executions.json" },
    @{ Name = "market_signals";   Schema = "$SchemaDir\market_signals.json" },
    @{ Name = "ecosystem_metrics"; Schema = "$SchemaDir\ecosystem_metrics.json" },
    @{ Name = "security_events";  Schema = "$SchemaDir\security_events.json" },
    @{ Name = "ai_interactions";  Schema = "$SchemaDir\ai_interactions.json" }
)

foreach ($table in $tables) {
    $fullName = "${Dataset}.$($table.Name)"
    Write-Host "  Creating $fullName..." -ForegroundColor Yellow -NoNewline
    
    $result = bq --project_id=$Project mk --table --description="CEREBRO $($table.Name)" "$fullName" "$($table.Schema)" 2>&1
    if ($result -match "already exists") {
        Write-Host " EXISTS" -ForegroundColor DarkGreen
    } elseif ($result -match "error" -or $result -match "Error") {
        Write-Host " WARN: $result" -ForegroundColor DarkYellow
    } else {
        Write-Host " CREATED" -ForegroundColor Green
    }
}

# 3. Create views
Write-Host ""
Write-Host "[3/3] Creating views..." -ForegroundColor Yellow

$viewFiles = Get-ChildItem -Path $ViewsDir -Filter "*.sql" -ErrorAction SilentlyContinue
foreach ($viewFile in $viewFiles) {
    $viewName = $viewFile.BaseName
    Write-Host "  Creating view: $viewName..." -ForegroundColor Yellow -NoNewline
    
    $sql = Get-Content $viewFile.FullName -Raw
    # Replace dataset references with fully qualified names
    $sql = $sql -replace 'cerebro_ecosystem\.', "$Project.$Dataset."
    
    $result = bq --project_id=$Project query --use_legacy_sql=false "$sql" 2>&1
    if ($result -match "error" -or $result -match "Error") {
        Write-Host " WARN: $result" -ForegroundColor DarkYellow
    } else {
        Write-Host " CREATED" -ForegroundColor Green
    }
}

Write-Host ""
Write-Host "=== BigQuery Setup Complete ===" -ForegroundColor Green
Write-Host "Dataset: $Dataset | Tables: $($tables.Count) | Views: $($viewFiles.Count)" -ForegroundColor Green
