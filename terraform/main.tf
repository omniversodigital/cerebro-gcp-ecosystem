terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

variable "project_id" {
  type    = string
  default = "gen-lang-client-0722648923"
}

variable "region" {
  type    = string
  default = "us-central1"
}

# Core Service Accounts
resource "google_service_account" "cerebro_core_sa" {
  account_id   = "cerebro-core-sa"
  display_name = "CEREBRO Core Service Account"
}

# Example Cloud Run Service definition (API Gateway)
# In a real environment, this imports the existing gcloud state
resource "google_cloud_run_v2_service" "api_gateway" {
  name     = "cerebro-api-gateway"
  location = var.region
  ingress  = "INGRESS_TRAFFIC_ALL"

  template {
    containers {
      image = "us-docker.pkg.dev/cloudrun/container/hello" # Placeholder, overwritten by Cloud Build
    }
    service_account = google_service_account.cerebro_core_sa.email
  }
}

# BigQuery Dataset
resource "google_bigquery_dataset" "cerebro_ecosystem" {
  dataset_id                  = "cerebro_ecosystem"
  friendly_name               = "CEREBRO Ecosystem Data"
  description                 = "Primary dataset for logs, metrics, and quantum memory"
  location                    = "US"
}
