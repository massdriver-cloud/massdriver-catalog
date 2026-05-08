resource "massdriver_artifact" "bucket" {
  field = "bucket"
  name  = "AWS S3 ${var.md_metadata.name_prefix}"
  artifact = jsonencode({
    id           = local.bucket_arn
    name         = local.bucket_name
    region       = local.region
    endpoint     = local.endpoint
    domain_name  = local.domain_name
    kms_key_arn  = local.kms_key_arn
    cors_origins = var.cors_origins
    policies     = local.policies
  })
}
