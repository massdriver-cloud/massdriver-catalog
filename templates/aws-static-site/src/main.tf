data "aws_caller_identity" "current" {}

data "aws_canonical_user_id" "current" {}

resource "random_id" "suffix" {
  byte_length = 4

  keepers = {
    name = var.md_metadata.name_prefix
  }
}

locals {
  name         = var.md_metadata.name_prefix
  bucket_name  = substr("${var.md_metadata.name_prefix}-site-${random_id.suffix.hex}", 0, 63)
  logs_name    = substr("${var.md_metadata.name_prefix}-cflogs-${random_id.suffix.hex}", 0, 63)
  index_object = "index.html"

  # Every file under src/site is uploaded as-is. Browsers pick how to treat a
  # file from its content type, so a wrong or missing one shows the page as
  # plain text instead of rendering it.
  site_files = fileset("${path.module}/site", "**")

  content_types = {
    html  = "text/html; charset=utf-8"
    htm   = "text/html; charset=utf-8"
    css   = "text/css; charset=utf-8"
    js    = "text/javascript; charset=utf-8"
    mjs   = "text/javascript; charset=utf-8"
    json  = "application/json"
    map   = "application/json"
    svg   = "image/svg+xml"
    png   = "image/png"
    jpg   = "image/jpeg"
    jpeg  = "image/jpeg"
    gif   = "image/gif"
    webp  = "image/webp"
    avif  = "image/avif"
    ico   = "image/x-icon"
    txt   = "text/plain; charset=utf-8"
    xml   = "application/xml"
    pdf   = "application/pdf"
    woff  = "font/woff"
    woff2 = "font/woff2"
    ttf   = "font/ttf"
  }
}

################################################################################
# Content bucket
#
# Private. Nothing reaches it directly from the internet — CloudFront is the
# only reader, which is what the origin access control below enforces.
################################################################################

resource "aws_s3_bucket" "site" {
  bucket = local.bucket_name

  tags = {
    Name = local.bucket_name
  }
}

resource "aws_s3_bucket_public_access_block" "site" {
  bucket = aws_s3_bucket.site.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "site" {
  bucket = aws_s3_bucket.site.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

# The files here are served to anyone who visits the site, so a customer-managed
# key would protect nothing. S3-managed encryption keeps the data encrypted at
# rest without adding a key that CloudFront would then need grants on.
resource "aws_s3_bucket_server_side_encryption_configuration" "site" {
  bucket = aws_s3_bucket.site.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_versioning" "site" {
  bucket = aws_s3_bucket.site.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_logging" "site" {
  bucket = aws_s3_bucket.site.id

  target_bucket = aws_s3_bucket.logs.id
  target_prefix = "s3/"
}

resource "aws_s3_bucket_lifecycle_configuration" "site" {
  bucket = aws_s3_bucket.site.id

  rule {
    id     = "housekeeping"
    status = "Enabled"

    filter {}

    noncurrent_version_expiration {
      noncurrent_days = 30
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }

  depends_on = [aws_s3_bucket_versioning.site]
}

resource "aws_s3_object" "site" {
  for_each = local.site_files

  bucket = aws_s3_bucket.site.id
  key    = each.value
  source = "${path.module}/site/${each.value}"

  source_hash  = filemd5("${path.module}/site/${each.value}")
  content_type = lookup(local.content_types, lower(element(split(".", each.value), length(split(".", each.value)) - 1)), "application/octet-stream")

  depends_on = [aws_s3_bucket_server_side_encryption_configuration.site]
}

################################################################################
# Log bucket
#
# CloudFront delivers its logs using an ACL grant rather than a bucket policy,
# so this bucket has to allow ACLs. The content bucket does not.
################################################################################

resource "aws_s3_bucket" "logs" {
  bucket = local.logs_name

  tags = {
    Name = local.logs_name
  }
}

resource "aws_s3_bucket_public_access_block" "logs" {
  bucket = aws_s3_bucket.logs.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "logs" {
  bucket = aws_s3_bucket.logs.id

  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_acl" "logs" {
  bucket = aws_s3_bucket.logs.id

  access_control_policy {
    owner {
      id = data.aws_canonical_user_id.current.id
    }

    grant {
      grantee {
        type = "CanonicalUser"
        id   = data.aws_canonical_user_id.current.id
      }
      permission = "FULL_CONTROL"
    }

    # The fixed canonical id of the CloudFront log delivery account.
    grant {
      grantee {
        type = "CanonicalUser"
        id   = "c4c1ede66af53448b93c283ce9448c4ba468c9432aa01d700d3878632f77d2d0"
      }
      permission = "FULL_CONTROL"
    }
  }

  depends_on = [aws_s3_bucket_ownership_controls.logs]
}

resource "aws_s3_bucket_server_side_encryption_configuration" "logs" {
  bucket = aws_s3_bucket.logs.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_versioning" "logs" {
  bucket = aws_s3_bucket.logs.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_logging" "logs" {
  bucket = aws_s3_bucket.logs.id

  target_bucket = aws_s3_bucket.logs.id
  target_prefix = "self/"
}

resource "aws_s3_bucket_lifecycle_configuration" "logs" {
  bucket = aws_s3_bucket.logs.id

  rule {
    id     = "expire-logs"
    status = "Enabled"

    filter {}

    expiration {
      days = 90
    }

    noncurrent_version_expiration {
      noncurrent_days = 30
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }

  depends_on = [aws_s3_bucket_versioning.logs]
}

################################################################################
# Delivery network
################################################################################

resource "aws_cloudfront_origin_access_control" "site" {
  name                              = local.name
  description                       = "Lets only this distribution read ${local.bucket_name}"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_cloudfront_distribution" "site" {
  enabled             = true
  is_ipv6_enabled     = true
  comment             = local.name
  default_root_object = local.index_object
  price_class         = var.price_class

  origin {
    origin_id                = "site"
    domain_name              = aws_s3_bucket.site.bucket_regional_domain_name
    origin_access_control_id = aws_cloudfront_origin_access_control.site.id
  }

  default_cache_behavior {
    target_origin_id = "site"
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD"]

    # Anyone arriving over plain HTTP is redirected to HTTPS rather than served.
    viewer_protocol_policy = "redirect-to-https"
    compress               = true

    min_ttl     = 0
    default_ttl = var.cache_seconds
    max_ttl     = max(var.cache_seconds, 86400)

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }
  }

  # A single page app handles its own addresses, so an unknown path must return
  # the index page rather than an error for the app to route it.
  dynamic "custom_error_response" {
    for_each = var.single_page_app ? [403, 404] : []

    content {
      error_code            = custom_error_response.value
      response_code         = 200
      response_page_path    = "/${local.index_object}"
      error_caching_min_ttl = 10
    }
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  # The default CloudFront certificate covers *.cloudfront.net, which is why
  # this works without owning a domain or requesting a certificate.
  viewer_certificate {
    cloudfront_default_certificate = true
    minimum_protocol_version       = "TLSv1.2_2021"
  }

  logging_config {
    bucket          = aws_s3_bucket.logs.bucket_domain_name
    prefix          = "cloudfront/"
    include_cookies = false
  }

  depends_on = [aws_s3_bucket_acl.logs]
}

# Only this distribution may read the bucket. Written after the distribution
# exists so the condition can name it exactly.
resource "aws_s3_bucket_policy" "site" {
  bucket = aws_s3_bucket.site.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AllowCloudFrontRead"
        Effect    = "Allow"
        Principal = { Service = "cloudfront.amazonaws.com" }
        Action    = "s3:GetObject"
        Resource  = "${aws_s3_bucket.site.arn}/*"
        Condition = {
          StringEquals = {
            "AWS:SourceArn" = aws_cloudfront_distribution.site.arn
          }
        }
      },
      {
        Sid       = "DenyInsecureTransport"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource = [
          aws_s3_bucket.site.arn,
          "${aws_s3_bucket.site.arn}/*",
        ]
        Condition = {
          Bool = { "aws:SecureTransport" = "false" }
        }
      },
    ]
  })

  depends_on = [aws_s3_bucket_public_access_block.site]
}
