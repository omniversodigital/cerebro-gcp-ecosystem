<#
.SYNOPSIS
    Creates Pub/Sub topics and subscriptions for the CEREBRO ecosystem.
#>

param(
    [string]$Project = "gen-lang-client-0722648923"
)

$ErrorActionPreference = "Continue"

Write-Host "=== CEREBRO - Pub/Sub Messaging Infrastructure ===" -ForegroundColor Cyan
Write-Host "Project: $Project" -ForegroundColor Cyan
Write-Host ""

# Topic definitions: name -> (description, subscriptions[])
$topics = @{
    "cerebro-commands" = @{
        Description = "Operator commands to the ecosystem"
        Subscriptions = @(
            @{ Name = "cerebro-commands-gateway"; AckDeadline = 60 },
            @{ Name = "cerebro-commands-executor"; AckDeadline = 120 }
        )
    }
    "market-signals" = @{
        Description = "Trading signals from all sources"
        Subscriptions = @(
            @{ Name = "market-signals-processor"; AckDeadline = 30 },
            @{ Name = "market-signals-risk"; AckDeadline = 30 },
            @{ Name = "market-signals-bigquery"; AckDeadline = 60 }
        )
    }
    "security-alerts" = @{
        Description = "Security events and alerts"
        Subscriptions = @(
            @{ Name = "security-alerts-handler"; AckDeadline = 30 },
            @{ Name = "security-alerts-bigquery"; AckDeadline = 60 }
        )
    }
    "ecosystem-events" = @{
        Description = "General ecosystem lifecycle events"
        Subscriptions = @(
            @{ Name = "ecosystem-events-logger"; AckDeadline = 60 },
            @{ Name = "ecosystem-events-bigquery"; AckDeadline = 60 }
        )
    }
    "skill-results" = @{
        Description = "Results from skill executions"
        Subscriptions = @(
            @{ Name = "skill-results-gateway"; AckDeadline = 60 }
        )
    }
}

# Create topics
Write-Host "[1/2] Creating topics..." -ForegroundColor Yellow
foreach ($topicName in $topics.Keys) {
    $topic = $topics[$topicName]
    Write-Host "  Topic: $topicName" -ForegroundColor Yellow -NoNewline
    
    $result = gcloud pubsub topics create $topicName --project=$Project --message-retention-duration=7d 2>&1
    if ($result -match "already exists") {
        Write-Host " EXISTS" -ForegroundColor DarkGreen
    } elseif ($result -match "error" -or $result -match "ERROR") {
        Write-Host " ERROR: $result" -ForegroundColor Red
    } else {
        Write-Host " CREATED" -ForegroundColor Green
    }
}

# Create subscriptions
Write-Host ""
Write-Host "[2/2] Creating subscriptions..." -ForegroundColor Yellow
foreach ($topicName in $topics.Keys) {
    $topic = $topics[$topicName]
    foreach ($sub in $topic.Subscriptions) {
        Write-Host "  Sub: $($sub.Name) -> $topicName" -ForegroundColor Yellow -NoNewline
        
        $result = gcloud pubsub subscriptions create $sub.Name `
            --topic=$topicName `
            --project=$Project `
            --ack-deadline=$($sub.AckDeadline) `
            --message-retention-duration=7d `
            --expiration-period=never 2>&1
        
        if ($result -match "already exists") {
            Write-Host " EXISTS" -ForegroundColor DarkGreen
        } elseif ($result -match "error" -or $result -match "ERROR") {
            Write-Host " ERROR: $result" -ForegroundColor Red
        } else {
            Write-Host " CREATED" -ForegroundColor Green
        }
    }
}

Write-Host ""
Write-Host "=== Pub/Sub Setup Complete ===" -ForegroundColor Green

$totalSubs = ($topics.Values | ForEach-Object { $_.Subscriptions.Count } | Measure-Object -Sum).Sum
Write-Host "Topics: $($topics.Count) | Subscriptions: $totalSubs" -ForegroundColor Green
