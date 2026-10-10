variable "project_id" {
  type = string
}

# ── KMS Keyring ──
resource "google_kms_key_ring" "cerebro" {
  name     = "cerebro-keyring"
  location = "global"
  project  = var.project_id
}

# ── KMS Keys ──
resource "google_kms_crypto_key" "data_key" {
  name            = "cerebro-data-key"
  key_ring        = google_kms_key_ring.cerebro.id
  rotation_period = "7776000s" # 90 days
  purpose         = "ENCRYPT_DECRYPT"
}

resource "google_kms_crypto_key" "secrets_key" {
  name            = "cerebro-secrets-key"
  key_ring        = google_kms_key_ring.cerebro.id
  rotation_period = "7776000s" # 90 days
  purpose         = "ENCRYPT_DECRYPT"
}

# ── Secret Manager Secrets ──
locals {
  secrets = {
    "cerebro-mt5-credentials"    = { domain = "trading", rotation = "90d" }
    "cerebro-telegram-bot-token" = { domain = "communication", rotation = "manual" }
    "cerebro-stripe-api-key"     = { domain = "fintech", rotation = "90d" }
    "cerebro-openrouter-api-key" = { domain = "ai", rotation = "manual" }
    "cerebro-hermes-config"      = { domain = "ecosystem", rotation = "manual" }
    "cerebro-polymarket-keys"    = { domain = "trading", rotation = "30d" }
    "cerebro-database-url"       = { domain = "data", rotation = "manual" }
    "cerebro-webhook-signing-key" = { domain = "security", rotation = "90d" }
  }
}

resource "google_secret_manager_secret" "secrets" {
  for_each = local.secrets

  secret_id = each.key
  project   = var.project_id

  replication {
    auto {}
  }

  labels = {
    domain     = each.value.domain
    rotation   = each.value.rotation
    managed_by = "terraform"
  }
}
