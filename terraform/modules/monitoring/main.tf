variable "project_id" {
  type = string
}

# ── Log-Based Metrics ──
resource "google_logging_metric" "cerebro_errors" {
  name    = "cerebro_errors"
  project = var.project_id
  filter  = "resource.type=\"cloud_run_revision\" AND severity>=ERROR"

  metric_descriptor {
    metric_kind = "DELTA"
    value_type  = "INT64"
    unit        = "1"
  }
}

resource "google_logging_metric" "skill_executions" {
  name    = "cerebro_skill_executions"
  project = var.project_id
  filter  = "resource.type=\"cloud_run_revision\" AND jsonPayload.event=\"skill_execution\""

  metric_descriptor {
    metric_kind = "DELTA"
    value_type  = "INT64"
    unit        = "1"
  }
}

# ── Monitoring Notification Channel ──
resource "google_monitoring_notification_channel" "email" {
  display_name = "CEREBRO Admin Email"
  type         = "email"
  project      = var.project_id

  labels = {
    email_address = "omniverso.digital@gmail.com"
  }
}

# ── Alert Policies ──
resource "google_monitoring_alert_policy" "high_error_rate" {
  display_name = "CEREBRO High Error Rate"
  project      = var.project_id
  combiner     = "OR"

  conditions {
    display_name = "Error rate > 5% in 5 minutes"

    condition_threshold {
      filter          = "metric.type=\"logging.googleapis.com/user/cerebro_errors\" AND resource.type=\"cloud_run_revision\""
      duration        = "300s"
      comparison      = "COMPARISON_GT"
      threshold_value = 5

      aggregations {
        alignment_period   = "300s"
        per_series_aligner = "ALIGN_RATE"
      }
    }
  }

  notification_channels = [google_monitoring_notification_channel.email.id]

  alert_strategy {
    auto_close = "1800s"
  }
}

# ── Log Sink to BigQuery ──
resource "google_logging_project_sink" "bigquery_sink" {
  name        = "cerebro-bigquery-sink"
  project     = var.project_id
  destination = "bigquery.googleapis.com/projects/${var.project_id}/datasets/cerebro_ecosystem"
  filter      = "resource.type=\"cloud_run_revision\" OR resource.type=\"cloud_function\""

  unique_writer_identity = true

  bigquery_options {
    use_partitioned_tables = true
  }
}
