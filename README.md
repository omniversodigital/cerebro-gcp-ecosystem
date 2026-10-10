# CEREBRO GCP Ecosystem

Cloud-native infrastructure for the CEREBRO OMEGA ecosystem on Google Cloud Platform.

## Architecture

```
cerebro-gcp-ecosystem/
├── scripts/                    # PowerShell provisioning scripts
│   ├── deploy.ps1              # Master orchestrator (run this first)
│   ├── 01-enable-apis.ps1      # GCP API enablement
│   ├── 02-iam-setup.ps1        # Service Accounts & IAM
│   ├── 03-bigquery-setup.ps1   # BigQuery dataset, tables, views
│   ├── 04-pubsub-setup.ps1     # Pub/Sub topics & subscriptions
│   ├── 05-storage-setup.ps1    # Cloud Storage buckets
│   ├── 06-monitoring-setup.ps1 # Monitoring, alerts, log sinks
│   ├── 07-security-setup.ps1   # Secret Manager & KMS
│   └── 08-cicd-setup.ps1       # Artifact Registry & Scheduler
│
├── services/                   # Cloud Run microservices
│   └── api-gateway/            # Central API Gateway
│       ├── server.js           # Express server
│       ├── Dockerfile          # Container image
│       ├── cloudbuild.yaml     # CI/CD pipeline
│       └── package.json
│
├── functions/                  # Cloud Functions (event-driven)
│   ├── on-market-alert/        # Market signal processing
│   ├── on-skill-synthesis/     # Nightly ecosystem audit
│   └── on-security-event/      # Security event handling
│
├── data/                       # Data infrastructure definitions
│   ├── bigquery/
│   │   ├── schema/             # Table schemas (JSON)
│   │   └── views/              # SQL views
│   ├── pubsub/
│   └── storage/
│
├── monitoring/                 # Observability configs
│   ├── dashboards/
│   ├── alerts/
│   └── logging/
│
├── security/                   # Security configs
│
├── ai/                         # AI/ML services
│   ├── model-router/           # Intelligent model selection
│   └── embeddings-pipeline/
│
├── cicd/                       # CI/CD configs
│
└── terraform/                  # Infrastructure as Code
    ├── main.tf                 # Root config
    └── modules/                # Terraform modules
        ├── apis/
        ├── iam/
        ├── compute/
        ├── data/
        ├── monitoring/
        ├── cicd/
        ├── security/
        └── ai/
```

## Quick Start

```powershell
# Deploy everything
.\scripts\deploy.ps1

# Deploy specific phase
.\scripts\deploy.ps1 -Phase data
.\scripts\deploy.ps1 -Phase security

# Terraform alternative
cd terraform
terraform init
terraform plan
terraform apply
```

## GCP Project

- **Project**: `gen-lang-client-0722648923`
- **Account**: `omniverso.digital@gmail.com`
- **Region**: `us-central1`

## Services

| Service | Type | Trigger |
|---------|------|---------|
| API Gateway | Cloud Run | HTTP |
| Market Alert | Cloud Function | Pub/Sub: market-signals |
| Skill Synthesis | Cloud Function | Cloud Scheduler (03:00 UTC) |
| Security Event | Cloud Function | Pub/Sub: security-alerts |
| Model Router | Cloud Run | HTTP |

## Data Flow

```
Operator/Webhook → API Gateway → Pub/Sub Topics → Cloud Functions → BigQuery
                                                                  → Alerts
Cloud Scheduler → Pub/Sub → Cloud Functions → BigQuery → Dashboards
```
