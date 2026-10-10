variable "project_id" {
  type = string
}

variable "region" {
  type = string
}

# ── Cloud Run: API Gateway ──
resource "google_cloud_run_v2_service" "api_gateway" {
  name     = "cerebro-api-gateway"
  location = var.region
  project  = var.project_id

  template {
    containers {
      image = "${var.region}-docker.pkg.dev/${var.project_id}/cerebro-docker/api-gateway:latest"

      ports {
        container_port = 8080
      }

      env {
        name  = "NODE_ENV"
        value = "production"
      }

      env {
        name  = "GCP_PROJECT"
        value = var.project_id
      }

      resources {
        limits = {
          cpu    = "1"
          memory = "512Mi"
        }
      }

      startup_probe {
        http_get {
          path = "/health"
        }
        initial_delay_seconds = 5
        period_seconds        = 10
      }

      liveness_probe {
        http_get {
          path = "/health"
        }
        period_seconds = 30
      }
    }

    scaling {
      min_instance_count = 0
      max_instance_count = 10
    }

    service_account = "cerebro-runner@${var.project_id}.iam.gserviceaccount.com"
    timeout         = "300s"
  }

  traffic {
    type    = "TRAFFIC_TARGET_ALLOCATION_TYPE_LATEST"
    percent = 100
  }
}

# Allow unauthenticated access to API Gateway
resource "google_cloud_run_v2_service_iam_member" "api_gateway_public" {
  project  = var.project_id
  location = var.region
  name     = google_cloud_run_v2_service.api_gateway.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}

# ── Cloud Scheduler Jobs ──
resource "google_cloud_scheduler_job" "nightly_audit" {
  name        = "cerebro-nightly-audit"
  description = "Nightly ecosystem audit and skill synthesis"
  schedule    = "0 3 * * *"
  time_zone   = "UTC"
  project     = var.project_id
  region      = var.region

  pubsub_target {
    topic_name = "projects/${var.project_id}/topics/ecosystem-events"
    data       = base64encode("{\"eventType\":\"scheduled_nightly_audit\",\"source\":\"scheduler\"}")
  }
}

resource "google_cloud_scheduler_job" "hourly_health" {
  name        = "cerebro-hourly-health"
  description = "Hourly ecosystem health check"
  schedule    = "0 * * * *"
  time_zone   = "UTC"
  project     = var.project_id
  region      = var.region

  pubsub_target {
    topic_name = "projects/${var.project_id}/topics/ecosystem-events"
    data       = base64encode("{\"eventType\":\"scheduled_health_check\",\"source\":\"scheduler\"}")
  }
}

resource "google_cloud_scheduler_job" "daily_backup" {
  name        = "cerebro-daily-backup"
  description = "Daily configuration backup"
  schedule    = "0 2 * * *"
  time_zone   = "UTC"
  project     = var.project_id
  region      = var.region

  pubsub_target {
    topic_name = "projects/${var.project_id}/topics/ecosystem-events"
    data       = base64encode("{\"eventType\":\"scheduled_backup\",\"source\":\"scheduler\"}")
  }
}

output "api_gateway_url" {
  value = google_cloud_run_v2_service.api_gateway.uri
}
