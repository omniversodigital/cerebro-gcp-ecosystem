<#
.SYNOPSIS
    Creates Cloud Storage buckets for the CEREBRO ecosystem.
#>

param(
    [string]$Project = "gen-lang-client-0722648923",
    [string]$Location = "US"
)

$ErrorActionPreference = "Continue"

Write-Host "=== CEREBRO - Cloud Storage Infrastructure ===" -ForegroundColor Cyan
Write-Host "Project: $Project | Location: $Location" -ForegroundColor Cyan
Write-Host ""

# Bucket definitions
$buckets = @(
    @{
        Name = "cerebro-artifacts-$Project"
        Description = "Compiled skills, scripts, and assets"
        Lifecycle = @{ Age = 90; Action = "SetStorageClass"; StorageClass = "NEARLINE" }
        Versioning = $true
    },
    @{
        Name = "cerebro-data-lake-$Project"
        Description = "Raw data, market feeds, and logs"
        Lifecycle = @{ Age = 30; Action = "SetStorageClass"; StorageClass = "COLDLINE" }
        Versioning = $false
    },
    @{
        Name = "cerebro-backups-$Project"
        Description = "Configuration and state backups"
        Lifecycle = @{ Age = 365; Action = "SetStorageClass"; StorageClass = "ARCHIVE" }
        Versioning = $true
    },
    @{
        Name = "cerebro-models-$Project"
        Description = "Trained AI models and embeddings"
        Lifecycle = $null
        Versioning = $true
    }
)

foreach ($bucket in $buckets) {
    $bucketUri = "gs://$($bucket.Name)"
    Write-Host "Bucket: $($bucket.Name)" -ForegroundColor Yellow -NoNewline
    
    # Create bucket
    $result = gcloud storage buckets create $bucketUri `
        --project=$Project `
        --location=$Location `
        --uniform-bucket-level-access `
        --public-access-prevention 2>&1
    
    if ($result -match "already exists") {
        Write-Host " EXISTS" -ForegroundColor DarkGreen
    } elseif ($result -match "error" -or $result -match "ERROR") {
        Write-Host " ERROR: $result" -ForegroundColor Red
        continue
    } else {
        Write-Host " CREATED" -ForegroundColor Green
    }
    
    # Enable versioning if requested
    if ($bucket.Versioning) {
        gcloud storage buckets update $bucketUri --versioning 2>&1 | Out-Null
        Write-Host "  Versioning: enabled" -ForegroundColor DarkGray
    }
    
    # Set lifecycle if defined
    if ($bucket.Lifecycle) {
        $lifecycleJson = @{
            rule = @(@{
                action = @{
                    type = $bucket.Lifecycle.Action
                    storageClass = $bucket.Lifecycle.StorageClass
                }
                condition = @{
                    age = $bucket.Lifecycle.Age
                }
            })
        } | ConvertTo-Json -Depth 5
        
        $tempFile = [System.IO.Path]::GetTempFileName()
        $lifecycleJson | Out-File -FilePath $tempFile -Encoding UTF8
        
        gcloud storage buckets update $bucketUri --lifecycle-file=$tempFile 2>&1 | Out-Null
        Remove-Item $tempFile -ErrorAction SilentlyContinue
        Write-Host "  Lifecycle: $($bucket.Lifecycle.Age)d -> $($bucket.Lifecycle.StorageClass)" -ForegroundColor DarkGray
    }
}

Write-Host ""
Write-Host "=== Storage Setup Complete ===" -ForegroundColor Green
Write-Host "Buckets: $($buckets.Count)" -ForegroundColor Green
