resource "massdriver_artifact" "bucket" {
  field = "bucket"
  name  = "Demo Bucket ${var.md_metadata.name_prefix}"
  artifact = jsonencode({
    infrastructure = {
      bucket_id   = random_pet.main.id
      bucket_name = local.bucket_name
      endpoint    = "https://storage.example.com/${local.bucket_name}"
    }
  })
}
