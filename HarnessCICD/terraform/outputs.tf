output "cluster_name" {
  value = google_container_cluster.main.name
}

output "cluster_location" {
  value = google_container_cluster.main.location
}

output "artifact_registry_host" {
  value = "${var.region}-docker.pkg.dev"
}

output "artifact_repository" {
  value = google_artifact_registry_repository.app.repository_id
}

output "image_repository" {
  value = "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.app.repository_id}/python-demo"
}

output "network_name" {
  value = google_compute_network.main.name
}
