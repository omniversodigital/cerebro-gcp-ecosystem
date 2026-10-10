variable "project_id" {
  type = string
}

variable "region" {
  type = string
}

# ── Artifact Registry Repositories ──
resource "google_artifact_registry_repository" "docker" {
  location      = var.region
  repository_id = "cerebro-docker"
  description   = "Docker images for CEREBRO services"
  format        = "DOCKER"
  project       = var.project_id
}

resource "google_artifact_registry_repository" "npm" {
  location      = var.region
  repository_id = "cerebro-npm"
  description   = "NPM packages for CEREBRO skills"
  format        = "NPM"
  project       = var.project_id
}

resource "google_artifact_registry_repository" "python" {
  location      = var.region
  repository_id = "cerebro-python"
  description   = "Python packages for CEREBRO scripts"
  format        = "PYTHON"
  project       = var.project_id
}

# ── Cloud Build Trigger ──
# Note: Requires a connected repository (GitHub, Cloud Source Repos, etc.)
# Uncomment and configure after repository connection
#
# resource "google_cloudbuild_trigger" "deploy_api_gateway" {
#   name     = "deploy-api-gateway"
#   project  = var.project_id
#   location = var.region
#
#   github {
#     owner = "YOUR_GITHUB_ORG"
#     name  = "cerebro-gcp-ecosystem"
#     push {
#       branch = "^main$"
#     }
#   }
#
#   filename = "services/api-gateway/cloudbuild.yaml"
#
#   substitutions = {
#     _REGION = var.region
#   }
# }
