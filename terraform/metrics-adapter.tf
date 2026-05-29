resource "google_service_account" "metrics" {
  account_id   = "metrics-adapter"
  display_name = "metrics-monitoring-reader"
}

# give the sa to read the metrics

resource "google_project_iam_member" "metrics_monitoring_viewer" {
  project = var.project_id
  role    = "roles/monitoring.viewer"
  member  = "serviceAccount:${google_service_account.metrics.email}"
}
# give the k8s sa to impersonate the SA 
resource "google_service_account_iam_member" "metrics_wi" {
  service_account_id = google_service_account.metrics.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.project_id}.svc.id.goog[custom-metrics/custom-metrics-stackdriver-adapter]"
}