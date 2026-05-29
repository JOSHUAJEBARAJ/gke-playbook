locals {
  frontend_latency_metric = "logging.googleapis.com/user/frontend_latency"
  frontend_5xx_metric     = "logging.googleapis.com/user/frontend_5xx"
}

## Custom service 
resource "google_monitoring_custom_service" "frontend" {
  service_id   = "frontend"
  display_name = "Frontend"
}

## availability Slo 

resource "google_monitoring_slo" "availability" {
  service      = google_monitoring_custom_service.frontend.service_id
  slo_id       = "frontend-availability"
  display_name = "99.9% non-5xx over 28 days"

  goal                = 0.999
  rolling_period_days = 28

  request_based_sli {
    good_total_ratio {
      total_service_filter = "metric.type=\"logging.googleapis.com/user/frontend_requests\" resource.type=\"k8s_container\""
      bad_service_filter   = "metric.type=\"logging.googleapis.com/user/frontend_5xx\" resource.type=\"k8s_container\""
    }
  }
}


resource "google_monitoring_slo" "latency" {
  service      = google_monitoring_custom_service.frontend.service_id
  slo_id       = "frontend-latency"
  display_name = "99.5% of requests < 1s over 28 days"

  goal                = 0.995
  rolling_period_days = 28

  request_based_sli {
    distribution_cut {
      distribution_filter = "metric.type=\"logging.googleapis.com/user/frontend_latency\" resource.type=\"k8s_container\""
      range {
        max = 1000
      }
    }
  }
}