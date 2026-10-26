variable "project_id" {
  description = "Existing GCP project ID"
  type        = string
  default     = "project-b21965c0-60b2-4525-a12"
}

variable "region" {
  description = "GCP region"
  type        = string
  default     = "us-central1"
}

variable "cluster_name" {
  description = "GKE cluster name"
  type        = string
  default     = "harness-gke"
}

variable "machine_type" {
  description = "GKE node machine type"
  type        = string
  default     = "e2-standard-2"
}

variable "artifact_repository" {
  description = "Artifact Registry Docker repository"
  type        = string
  default     = "harness-app"
}

variable "network_name" {
  type    = string
  default = "harness-gke-vpc"
}

variable "subnet_name" {
  type    = string
  default = "harness-gke-subnet"
}

variable "pods_range_name" {
  type    = string
  default = "gke-pods"
}

variable "services_range_name" {
  type    = string
  default = "gke-services"
}
