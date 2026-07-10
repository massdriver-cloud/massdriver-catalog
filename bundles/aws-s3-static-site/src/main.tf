terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
    massdriver = {
      source  = "massdriver-cloud/massdriver"
      version = "~> 1.4"
    }
  }
}

provider "aws" {
  region = var.region
  assume_role {
    role_arn    = var.aws_authentication.arn
    external_id = try(var.aws_authentication.external_id, null)
  }
  default_tags {
    tags = var.md_metadata.default_tags
  }
}

resource "random_id" "suffix" {
  byte_length = 4
}

locals {
  # S3 bucket names are globally unique across all AWS accounts, so we append
  # a random suffix. Names must be lowercase and at most 63 characters —
  # truncate the prefix, never the suffix, so uniqueness survives long names.
  # Visitors see the website endpoint, not the bucket, so the name being ugly
  # doesn't matter.
  bucket_name = lower("${substr(var.md_metadata.name_prefix, 0, 54)}-${random_id.suffix.hex}")

  # Content-Type for uploaded files by extension. S3 defaults everything to
  # binary otherwise, and browsers download instead of render.
  mime_types = {
    html = "text/html"
    css  = "text/css"
    js   = "text/javascript"
    json = "application/json"
    png  = "image/png"
    jpg  = "image/jpeg"
    svg  = "image/svg+xml"
    ico  = "image/x-icon"
    txt  = "text/plain"
  }
}

resource "aws_s3_bucket" "main" {
  bucket = local.bucket_name

  # Demo catalog: let decommission succeed even with the site files still in
  # the bucket. The site redeploys from git, so nothing is lost.
  force_destroy = true
}

resource "aws_s3_bucket_website_configuration" "main" {
  bucket = aws_s3_bucket.main.id

  index_document {
    suffix = var.index_document
  }

  error_document {
    key = var.error_document
  }
}

# Public by design: this bucket IS the website. All four blocks stay off so
# the public-read policy below can take effect.
resource "aws_s3_bucket_public_access_block" "main" {
  bucket = aws_s3_bucket.main.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_policy" "public_read" {
  bucket = aws_s3_bucket.main.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "PublicReadObjects"
        Effect    = "Allow"
        Principal = "*"
        Action    = "s3:GetObject"
        Resource  = "${aws_s3_bucket.main.arn}/*"
      }
    ]
  })

  # AWS rejects public policies while BlockPublicPolicy is still true.
  depends_on = [aws_s3_bucket_public_access_block.main]
}

# Upload everything under src/site/ — replace those files with your build
# output and redeploy to publish. etag makes redeploys upload only files
# whose content actually changed.
resource "aws_s3_object" "site" {
  for_each = fileset("${path.module}/site", "**")

  bucket        = aws_s3_bucket.main.id
  key           = each.value
  source        = "${path.module}/site/${each.value}"
  etag          = filemd5("${path.module}/site/${each.value}")
  cache_control = "max-age=${var.cache_max_age_seconds}"
  content_type  = lookup(local.mime_types, lower(reverse(split(".", each.value))[0]), "application/octet-stream")
}
