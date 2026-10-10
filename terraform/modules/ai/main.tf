variable "project_id" {
  type = string
}

variable "region" {
  type = string
}

# Placeholder module for AI/ML resources
# Vertex AI endpoints, model deployments, and embeddings pipelines
# will be added here once the base infrastructure is operational.

# ── Vertex AI Model Registry ──
# resource "google_vertex_ai_endpoint" "cerebro_endpoint" {
#   display_name = "cerebro-model-endpoint"
#   location     = var.region
#   project      = var.project_id
# }
