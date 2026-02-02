resource "massdriver_artifact" "bucket" {
  field = "bucket"
  name  = "Demo Bucket ${var.md_metadata.name_prefix}"
  artifact = jsonencode({
    id       = random_pet.main.id
    name     = local.bucket_name
    endpoint = "https://storage.example.com/${local.bucket_name}"
    policies = [
      {
        id   = "read-only"
        name = "Read"
      },
      {
        id   = "read-write"
        name = "Write"
      },
      {
        id   = "admin"
        name = "Admin"
      }
    ]
  })
}
