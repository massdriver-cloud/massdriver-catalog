resource "massdriver_resource" "registry" {
  field = "registry"
  name  = "Artifact Registry ${google_artifact_registry_repository.main.repository_id}"
  resource = jsonencode({
    id           = google_artifact_registry_repository.main.id
    name         = google_artifact_registry_repository.main.repository_id
    registry_url = local.registry_url
    location     = google_artifact_registry_repository.main.location
    format       = google_artifact_registry_repository.main.format
    # Policy `id` is the GCP IAM role a consuming bundle binds to its own
    # service account. A Cloud Run service picks `reader` to pull images; a
    # build pipeline picks `writer` to push them.
    policies = [
      {
        id   = "roles/artifactregistry.reader"
        name = "Pull"
      },
      {
        id   = "roles/artifactregistry.writer"
        name = "Push and Pull"
      }
    ]
  })
}
