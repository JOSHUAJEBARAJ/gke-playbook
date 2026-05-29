resource "google_container_cluster" "primary" {
  name       = var.cluster_name
  location   = var.region
  network    = google_compute_network.vpc.id
  subnetwork = google_compute_subnetwork.subnet.id

  # node pool managemetn
  remove_default_node_pool = true
  # create one and delete it 
  initial_node_count = 1

  # networking 
  networking_mode = "VPC_NATIVE"
  ip_allocation_policy {
    cluster_secondary_range_name  = "pods"
    services_secondary_range_name = "services"
  }
  private_cluster_config {
    enable_private_nodes    = true
    enable_private_endpoint = false
    master_ipv4_cidr_block  = var.master_cidr
  }
  dynamic "master_authorized_networks_config" {
    for_each = length(var.authorized_networks) > 0 ? [1] : []
    content {
      dynamic "cidr_blocks" {
        for_each = var.authorized_networks
        content {
          cidr_block   = cidr_blocks.value.cidr_block
          display_name = cidr_blocks.value.display_name
        }
      }
    }
  }
  # workload identity
  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }

  # secret manager csi driver (managed add-on)
  secret_manager_config {
    enabled = true
  }
  release_channel {
    channel = "RAPID"
  }

  node_config {
    disk_type    = "pd-standard"
    disk_size_gb = 50
  }
  deletion_protection = false

  ## monitoring 
  monitoring_config {
    enable_components = ["SYSTEM_COMPONENTS"]
    managed_prometheus {
      enabled = true
    }
  }
  logging_config {
    enable_components = ["SYSTEM_COMPONENTS", "WORKLOADS"]
  }

  # network policy 

  network_policy {
    enabled  = true
    provider = "CALICO"
  }

  addons_config {
    network_policy_config {
      disabled = false
    }
    gke_backup_agent_config {
      enabled = true
    }
  }
  # vpa 
  vertical_pod_autoscaling {
    enabled = true
  }
  # maintanence

  maintenance_policy {
    recurring_window {
      start_time = "2026-05-30T02:00:00Z"    # anchor: a Saturday, 02:00 UTC
      end_time   = "2026-05-30T06:00:00Z"    # 4-hour window
      recurrence = "FREQ=WEEKLY;BYDAY=SA,SU" # ← weekends only
    }
  }
}

resource "google_gke_backup_backup_plan" "daily" {
  name     = "app-daily"
  cluster  = google_container_cluster.primary.id
  location = var.region # where backups are STORED (regional)

  backup_schedule {
    cron_schedule = "0 2 * * *" # daily at 02:00
  }

  retention_policy {
    backup_delete_lock_days = 0
    backup_retain_days      = 7
  }

  backup_config {
    include_volume_data = true        # capture PersistentVolume data, if any
    include_secrets     = true        # capture Secret objects in the namespace
    selected_namespaces {
      namespaces = ["app"]            # the Online Boutique workloads live here
    }
  }
}