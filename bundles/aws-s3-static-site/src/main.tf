terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    massdriver = {
      source  = "massdriver-cloud/massdriver"
      version = "~> 1.3"
    }
  }
}

locals {
  bucket_name = "${var.md_metadata.name_prefix}-${var.site_name}"
}

provider "aws" {
  region = "us-east-1" # S3 website hosting works from any region
  assume_role {
    role_arn    = var.aws_authentication.arn
    external_id = try(var.aws_authentication.external_id, null)
  }
  default_tags {
    tags = var.md_metadata.default_tags
  }
}

# S3 bucket for static website
resource "aws_s3_bucket" "website" {
  bucket = local.bucket_name

  tags = {
    Name = local.bucket_name
  }
}

# Enable static website hosting
resource "aws_s3_bucket_website_configuration" "website" {
  bucket = aws_s3_bucket.website.id

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "error.html"
  }
}

# Versioning - enables recovery of previous content
resource "aws_s3_bucket_versioning" "website" {
  bucket = aws_s3_bucket.website.id

  versioning_configuration {
    status = var.enable_versioning ? "Enabled" : "Suspended"
  }
}

# Allow public access (required for static website hosting)
resource "aws_s3_bucket_public_access_block" "website" {
  bucket = aws_s3_bucket.website.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

# Bucket policy to allow public read
resource "aws_s3_bucket_policy" "website" {
  bucket = aws_s3_bucket.website.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "PublicReadGetObject"
        Effect    = "Allow"
        Principal = "*"
        Action    = "s3:GetObject"
        Resource  = "${aws_s3_bucket.website.arn}/*"
      }
    ]
  })

  depends_on = [aws_s3_bucket_public_access_block.website]
}

# Upload index.html from params
resource "aws_s3_object" "index" {
  bucket       = aws_s3_bucket.website.id
  key          = "index.html"
  content      = var.html_content
  content_type = "text/html"
  etag         = md5(var.html_content)
}

# Upload error.html from params
resource "aws_s3_object" "error" {
  bucket       = aws_s3_bucket.website.id
  key          = "error.html"
  content      = var.error_page
  content_type = "text/html"
  etag         = md5(var.error_page)
}

# Outputs for operator guide
output "website_url" {
  value       = aws_s3_bucket_website_configuration.website.website_endpoint
  description = "The public URL of the static website"
}

output "bucket_name" {
  value       = aws_s3_bucket.website.id
  description = "The S3 bucket name"
}
