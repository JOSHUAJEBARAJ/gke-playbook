# node pool 
locals {
  oauth_scopes = ["https://www.googleapis.com/auth/cloud-platform"]
}

# system 
resource "google_container_node_pool" "system" {
  name       = "system"
  cluster    = google_container_cluster.primary.id
  location   = var.region
  node_count = 1
  node_config {
    disk_type    = "pd-standard"
    disk_size_gb = 50
    machine_type = "e2-standard-2"
    oauth_scopes = local.oauth_scopes
    labels       = { pool = "system" }

    workload_metadata_config { mode = "GKE_METADATA" } # required for WI

    taint {
      key    = "dedicated"
      value  = "system"
      effect = "NO_SCHEDULE"
    }

  }
  # this is difference because of the quo=ta
  upgrade_settings {
    strategy        = "SURGE"
    max_surge       = 1
    max_unavailable = 0
  }
}


resource "google_container_node_pool" "general" {
  name     = "general"
  cluster  = google_container_cluster.primary.id
  location = var.region

  autoscaling {
    min_node_count = 1
    max_node_count = 5
  }
  upgrade_settings {
    strategy        = "SURGE"
    max_surge       = 1 # add 1 EXTRA new-version node before draining an old one
    max_unavailable = 0 # never let an old node go down before its replacement is Ready
  }
  node_config {
    machine_type = "e2-standard-2"
    disk_type    = "pd-standard"
    disk_size_gb = 50
    oauth_scopes = local.oauth_scopes
    labels       = { pool = "general" }
    workload_metadata_config { mode = "GKE_METADATA" }
  }
}


## Commented out because of the quota
# resource "google_container_node_pool" "spot" {
#   name     = "spot"
#   cluster  = google_container_cluster.primary.id
#   location = var.region

#   autoscaling {
#     min_node_count = 0
#     max_node_count = 5
#   }
#   upgrade_settings {
# strategy        = "SURGE"
# max_surge       = 1   # add 1 EXTRA new-version node before draining an old one
# max_unavailable = 0   # never let an old node go down before its replacement is Ready
# }

#   node_config {
#     disk_type    = "pd-standard"
#     disk_size_gb = 50
#     machine_type = "e2-standard-4"
#     spot         = true
#     oauth_scopes = local.oauth_scopes
#     labels       = { pool = "spot" }
#     workload_metadata_config { mode = "GKE_METADATA" }

#     taint {
#       key    = "cloud.google.com/gke-spot"
#       value  = "true"
#       effect = "NO_SCHEDULE"
#     }
#   }
# }