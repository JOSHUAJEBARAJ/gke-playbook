resource "google_service_account" "grafana" {
  account_id   = "grafana-monitoring"
  display_name = "grafana-monitoring-reader"
}

# give the sa to read the metrics

resource "google_project_iam_member" "grafana_monitoring_viewer" {
  project = var.project_id
  role    = "roles/monitoring.viewer"
  member  = "serviceAccount:${google_service_account.grafana.email}"
}
# give the k8s sa to impersonate the SA 
resource "google_service_account_iam_member" "grafana_wi" {
  service_account_id = google_service_account.grafana.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.project_id}.svc.id.goog[monitoring/grafana]"
}


# password generation 

resource "random_string" "password" {
  length  = 12
  special = false
  upper   = false
}

# Create secret
resource "google_secret_manager_secret" "grafana_password" {
  secret_id = "grafana-password"

  replication {
    auto {}
  }
}

# Store generated username as secret value
resource "google_secret_manager_secret_version" "password" {
  secret      = google_secret_manager_secret.grafana_password.id
  secret_data = random_string.password.result
}

# let the grafana SA read the grafana password secret (scoped to this one secret)
resource "google_secret_manager_secret_iam_member" "grafana_secret_access" {
  secret_id = google_secret_manager_secret.grafana_password.secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.grafana.email}"
}

