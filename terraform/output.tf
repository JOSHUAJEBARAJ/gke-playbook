output "cluster_name" { value = google_container_cluster.primary.name }
output "region" { value = var.region }
output "grafana_service_account_email" { value = google_service_account.grafana.email }
output "metrics_service_account_email" { value = google_service_account.metrics.email }