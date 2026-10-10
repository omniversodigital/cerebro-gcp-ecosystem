variable "project_id" {
  type = string
}

variable "region" {
  type = string
}

# ── BigQuery Dataset ──
resource "google_bigquery_dataset" "cerebro" {
  dataset_id    = "cerebro_ecosystem"
  friendly_name = "CEREBRO Ecosystem"
  description   = "Data warehouse for the CEREBRO ecosystem"
  location      = "US"
  project       = var.project_id

  default_table_expiration_ms = null

  labels = {
    environment = "production"
    managed_by  = "terraform"
  }
}

# ── BigQuery Tables ──
resource "google_bigquery_table" "skill_executions" {
  dataset_id = google_bigquery_dataset.cerebro.dataset_id
  table_id   = "skill_executions"
  project    = var.project_id

  time_partitioning {
    type  = "DAY"
    field = "received_at"
  }

  schema = file("${path.module}/../../../data/bigquery/schema/skill_executions.json")
}

resource "google_bigquery_table" "market_signals" {
  dataset_id = google_bigquery_dataset.cerebro.dataset_id
  table_id   = "market_signals"
  project    = var.project_id

  time_partitioning {
    type  = "DAY"
    field = "received_at"
  }

  schema = file("${path.module}/../../../data/bigquery/schema/market_signals.json")
}

resource "google_bigquery_table" "ecosystem_metrics" {
  dataset_id = google_bigquery_dataset.cerebro.dataset_id
  table_id   = "ecosystem_metrics"
  project    = var.project_id

  time_partitioning {
    type  = "DAY"
    field = "recorded_at"
  }

  schema = file("${path.module}/../../../data/bigquery/schema/ecosystem_metrics.json")
}

resource "google_bigquery_table" "security_events" {
  dataset_id = google_bigquery_dataset.cerebro.dataset_id
  table_id   = "security_events"
  project    = var.project_id

  time_partitioning {
    type  = "DAY"
    field = "received_at"
  }

  schema = file("${path.module}/../../../data/bigquery/schema/security_events.json")
}

resource "google_bigquery_table" "ai_interactions" {
  dataset_id = google_bigquery_dataset.cerebro.dataset_id
  table_id   = "ai_interactions"
  project    = var.project_id

  time_partitioning {
    type  = "DAY"
    field = "recorded_at"
  }

  schema = file("${path.module}/../../../data/bigquery/schema/ai_interactions.json")
}

# ── Pub/Sub Topics ──
locals {
  topics = {
    "cerebro-commands"   = "Operator commands to the ecosystem"
    "market-signals"     = "Trading signals from all sources"
    "security-alerts"    = "Security events and alerts"
    "ecosystem-events"   = "General ecosystem lifecycle events"
    "skill-results"      = "Results from skill executions"
  }
}

resource "google_pubsub_topic" "topics" {
  for_each = local.topics

  name    = each.key
  project = var.project_id

  message_retention_duration = "604800s" # 7 days

  labels = {
    managed_by = "terraform"
  }
}

# ── Cloud Storage Buckets ──
resource "google_storage_bucket" "artifacts" {
  name          = "cerebro-artifacts-${var.project_id}"
  location      = "US"
  project       = var.project_id
  force_destroy = false

  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"

  versioning {
    enabled = true
  }

  lifecycle_rule {
    condition {
      age = 90
    }
    action {
      type          = "SetStorageClass"
      storage_class = "NEARLINE"
    }
  }
}

resource "google_storage_bucket" "data_lake" {
  name          = "cerebro-data-lake-${var.project_id}"
  location      = "US"
  project       = var.project_id
  force_destroy = false

  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"

  lifecycle_rule {
    condition {
      age = 30
    }
    action {
      type          = "SetStorageClass"
      storage_class = "COLDLINE"
    }
  }
}

resource "google_storage_bucket" "backups" {
  name          = "cerebro-backups-${var.project_id}"
  location      = "US"
  project       = var.project_id
  force_destroy = false

  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"

  versioning {
    enabled = true
  }

  lifecycle_rule {
    condition {
      age = 365
    }
    action {
      type          = "SetStorageClass"
      storage_class = "ARCHIVE"
    }
  }
}

resource "google_storage_bucket" "models" {
  name          = "cerebro-models-${var.project_id}"
  location      = "US"
  project       = var.project_id
  force_destroy = false

  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"

  versioning {
    enabled = true
  }
}
