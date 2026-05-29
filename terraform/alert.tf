# Burn-rate alert policies for the frontend SLOs (slo.tf).
# Two windows per SLO (Google's multi-window, multi-burn-rate pattern):
#   - FAST burn: 14.4x over 1h  -> page (acute outage)
#   - SLOW burn: 6x   over 6h   -> warn (sustained degradation)

resource "google_monitoring_notification_channel" "email" {
  display_name = "SLO alerts email"
  type         = "email"
  labels = {
    email_address = var.alert_email
  }
}

# ---------- Availability ----------

resource "google_monitoring_alert_policy" "availability_fast_burn" {
  display_name = "Frontend availability - FAST burn (page)"
  combiner     = "OR"

  conditions {
    display_name = "burn rate > 14.4x over 1h"
    condition_threshold {
      filter          = "select_slo_burn_rate(\"${google_monitoring_slo.availability.name}\", \"3600s\")"
      comparison      = "COMPARISON_GT"
      threshold_value = 14.4
      duration        = "0s"
      aggregations {
        alignment_period   = "300s"
        per_series_aligner = "ALIGN_MEAN"
      }
    }
  }

  notification_channels = [google_monitoring_notification_channel.email.id]
}

resource "google_monitoring_alert_policy" "availability_slow_burn" {
  display_name = "Frontend availability - SLOW burn (warn)"
  combiner     = "OR"

  conditions {
    display_name = "burn rate > 6x over 6h"
    condition_threshold {
      filter          = "select_slo_burn_rate(\"${google_monitoring_slo.availability.name}\", \"21600s\")"
      comparison      = "COMPARISON_GT"
      threshold_value = 6
      duration        = "0s"
      aggregations {
        alignment_period   = "300s"
        per_series_aligner = "ALIGN_MEAN"
      }
    }
  }

  notification_channels = [google_monitoring_notification_channel.email.id]
}

# ---------- Latency ----------

resource "google_monitoring_alert_policy" "latency_fast_burn" {
  display_name = "Frontend latency - FAST burn (page)"
  combiner     = "OR"

  conditions {
    display_name = "burn rate > 14.4x over 1h"
    condition_threshold {
      filter          = "select_slo_burn_rate(\"${google_monitoring_slo.latency.name}\", \"3600s\")"
      comparison      = "COMPARISON_GT"
      threshold_value = 14.4
      duration        = "0s"
      aggregations {
        alignment_period   = "300s"
        per_series_aligner = "ALIGN_MEAN"
      }
    }
  }

  notification_channels = [google_monitoring_notification_channel.email.id]
}

resource "google_monitoring_alert_policy" "latency_slow_burn" {
  display_name = "Frontend latency - SLOW burn (warn)"
  combiner     = "OR"

  conditions {
    display_name = "burn rate > 6x over 6h"
    condition_threshold {
      filter          = "select_slo_burn_rate(\"${google_monitoring_slo.latency.name}\", \"21600s\")"
      comparison      = "COMPARISON_GT"
      threshold_value = 6
      duration        = "0s"
      aggregations {
        alignment_period   = "300s"
        per_series_aligner = "ALIGN_MEAN"
      }
    }
  }

  notification_channels = [google_monitoring_notification_channel.email.id]
}
