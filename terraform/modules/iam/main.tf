variable "project_id" {
  type = string
}

locals {
  service_accounts = {
    "cerebro-runner" = {
      display_name = "CEREBRO Runner"
      description  = "Cloud Run and Functions execution"
      roles = [
        "roles/run.invoker",
        "roles/cloudfunctions.invoker",
        "roles/pubsub.publisher",
        "roles/pubsub.subscriber",
        "roles/logging.logWriter",
        "roles/monitoring.metricWriter",
        "roles/secretmanager.secretAccessor",
      ]
    }
    "cerebro-data" = {
      display_name = "CEREBRO Data"
      description  = "BigQuery, Storage, Pub/Sub access"
      roles = [
        "roles/bigquery.dataEditor",
        "roles/bigquery.jobUser",
        "roles/storage.objectAdmin",
        "roles/pubsub.publisher",
        "roles/pubsub.subscriber",
        "roles/logging.logWriter",
      ]
    }
    "cerebro-build" = {
      display_name = "CEREBRO Build"
      description  = "Cloud Build and Artifact Registry"
      roles = [
        "roles/cloudbuild.builds.editor",
        "roles/artifactregistry.writer",
        "roles/run.admin",
        "roles/iam.serviceAccountUser",
        "roles/logging.logWriter",
      ]
    }
    "cerebro-ai" = {
      display_name = "CEREBRO AI"
      description  = "Vertex AI and ML model access"
      roles = [
        "roles/aiplatform.user",
        "roles/secretmanager.secretAccessor",
        "roles/storage.objectViewer",
        "roles/logging.logWriter",
      ]
    }
  }
}

resource "google_service_account" "sa" {
  for_each = local.service_accounts

  account_id   = each.key
  display_name = each.value.display_name
  description  = each.value.description
  project      = var.project_id
}

locals {
  # Flatten SA -> role bindings for iteration
  sa_role_bindings = flatten([
    for sa_name, sa in local.service_accounts : [
      for role in sa.roles : {
        sa_name = sa_name
        role    = role
        key     = "${sa_name}-${replace(role, "/", "-")}"
      }
    ]
  ])
}

resource "google_project_iam_member" "sa_roles" {
  for_each = { for binding in local.sa_role_bindings : binding.key => binding }

  project = var.project_id
  role    = each.value.role
  member  = "serviceAccount:${google_service_account.sa[each.value.sa_name].email}"
}

output "service_account_emails" {
  value = { for k, v in google_service_account.sa : k => v.email }
}
