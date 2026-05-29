variable "project_id" {
  type = string
}

variable "region" {
  type    = string
  default = "us-central1"
}

variable "cluster_name" {
  type    = string
  default = "gke-test"
}

## network 

variable "subnet_cidr" {
  type    = string
  default = "10.10.0.0/20"
}

variable "pods_cidr" {
  type    = string
  default = "10.20.0.0/16"
}


variable "services_cidr" {
  type    = string
  default = "10.30.0.0/20"
}

variable "master_cidr" {
  type    = string
  default = "172.16.0.0/28"
}


variable "authorized_networks" {
  type    = list(object({ cidr_block = string, display_name = string }))
  default = []
}

# variable for the email id 

variable "alert_email" {
  type        = string
  description = "Email address for SLO burn-rate alerts."
}