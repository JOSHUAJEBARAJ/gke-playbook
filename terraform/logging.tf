resource "google_logging_metric" "frontend_5xx" {
  name = "frontend_5xx"

  filter = <<-EOT
      resource.type="k8s_container"
      resource.labels.namespace_name="app"
      labels."k8s-pod/app"="frontend"
      jsonPayload."http.resp.status">=500
    EOT

  metric_descriptor {
    metric_kind = "DELTA"
    value_type  = "INT64"
    unit        = "1"
  }
}

# Counter: total frontend requests → denominator for the availability SLO.
# (good_total_ratio needs a numeric metric for `total`; a DISTRIBUTION won't do.)
resource "google_logging_metric" "frontend_requests" {
  name = "frontend_requests"

  filter = <<-EOT
      resource.type="k8s_container"
      resource.labels.namespace_name="app"
      labels."k8s-pod/app"="frontend"
      jsonPayload."http.resp.took_ms">=0
    EOT

  metric_descriptor {
    metric_kind = "DELTA"
    value_type  = "INT64"
    unit        = "1"
  }
}

# Distribution: frontend request latency → p95 SLI
resource "google_logging_metric" "frontend_latency" {
  name = "frontend_latency"

  filter = <<-EOT
      resource.type="k8s_container"
      resource.labels.namespace_name="app"
      labels."k8s-pod/app"="frontend"
      jsonPayload."http.resp.took_ms">=0
    EOT

  value_extractor = "EXTRACT(jsonPayload.\"http.resp.took_ms\")"

  metric_descriptor {
    metric_kind = "DELTA"
    value_type  = "DISTRIBUTION"
    unit        = "ms"
  }

  bucket_options {
    exponential_buckets {
      num_finite_buckets = 30
      growth_factor      = 1.5
      scale              = 1
    }
  }
}