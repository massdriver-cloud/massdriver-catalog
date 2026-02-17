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

provider "aws" {
  region = var.vpc.region
  assume_role {
    role_arn    = var.aws_authentication.arn
    external_id = try(var.aws_authentication.external_id, null)
  }
  default_tags {
    tags = var.md_metadata.default_tags
  }
}

# S3 bucket for SageMaker artifacts
# checkov:skip=CKV_AWS_145:Using SSE-S3 encryption, KMS optional for this use case
# checkov:skip=CKV_AWS_144:Cross-region replication not required for ML artifacts
# checkov:skip=CKV2_AWS_62:Event notifications not required
# checkov:skip=CKV_AWS_18:Access logging adds cost, optional for dev
# checkov:skip=CKV2_AWS_61:Lifecycle configuration optional
resource "aws_s3_bucket" "sagemaker" {
  bucket = "${var.md_metadata.name_prefix}-sagemaker-artifacts"

  tags = {
    Name = "${var.md_metadata.name_prefix}-sagemaker-artifacts"
  }
}

resource "aws_s3_bucket_versioning" "sagemaker" {
  bucket = aws_s3_bucket.sagemaker.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "sagemaker" {
  bucket = aws_s3_bucket.sagemaker.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "sagemaker" {
  bucket = aws_s3_bucket.sagemaker.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# IAM role for SageMaker execution
resource "aws_iam_role" "sagemaker_execution" {
  name = "${var.md_metadata.name_prefix}-sagemaker-execution"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "sagemaker.amazonaws.com"
      }
    }]
  })

  tags = var.md_metadata.default_tags
}

# Attach AmazonSageMakerFullAccess managed policy
resource "aws_iam_role_policy_attachment" "sagemaker_full_access" {
  role       = aws_iam_role.sagemaker_execution.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSageMakerFullAccess"
}

# S3 access policy for SageMaker
resource "aws_iam_role_policy" "sagemaker_s3" {
  name = "${var.md_metadata.name_prefix}-sagemaker-s3"
  role = aws_iam_role.sagemaker_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.sagemaker.arn,
          "${aws_s3_bucket.sagemaker.arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject"
        ]
        Resource = [
          "arn:aws:s3:::sagemaker-sample-files/*",
          "arn:aws:s3:::jumpstart-cache-prod-*/*"
        ]
      }
    ]
  })
}

# Security group for SageMaker
# checkov:skip=CKV_AWS_382:SageMaker requires outbound for AWS API calls and model downloads
# checkov:skip=CKV2_AWS_5:Security group is attached to SageMaker domain below
resource "aws_security_group" "sagemaker" {
  name        = "${var.md_metadata.name_prefix}-sagemaker-sg"
  description = "Security group for SageMaker Domain"
  vpc_id      = var.vpc.id

  # Allow all traffic within the security group (for distributed training)
  ingress {
    description = "Allow traffic within SageMaker"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    self        = true
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.md_metadata.name_prefix}-sagemaker-sg"
  }
}

# SageMaker Domain
resource "aws_sagemaker_domain" "main" {
  domain_name = "${var.md_metadata.name_prefix}-${var.domain_name}"
  auth_mode   = var.auth_mode
  vpc_id      = var.vpc.id
  subnet_ids  = var.subnet_ids

  default_user_settings {
    execution_role = aws_iam_role.sagemaker_execution.arn

    security_groups = [aws_security_group.sagemaker.id]

    sharing_settings {
      notebook_output_option = "Allowed"
      s3_output_path         = "s3://${aws_s3_bucket.sagemaker.id}/sharing"
    }

    jupyter_server_app_settings {
      default_resource_spec {
        instance_type       = "system"
        sagemaker_image_arn = "arn:aws:sagemaker:${var.vpc.region}:081325390199:image/jupyter-server-3"
      }
    }

    kernel_gateway_app_settings {
      default_resource_spec {
        instance_type       = var.default_instance_type
        sagemaker_image_arn = "arn:aws:sagemaker:${var.vpc.region}:081325390199:image/datascience-1.0"
      }
    }
  }

  default_space_settings {
    execution_role  = aws_iam_role.sagemaker_execution.arn
    security_groups = [aws_security_group.sagemaker.id]
  }

  tags = {
    Name = "${var.md_metadata.name_prefix}-${var.domain_name}"
  }
}

# Create a default user profile for testing
resource "aws_sagemaker_user_profile" "default" {
  domain_id         = aws_sagemaker_domain.main.id
  user_profile_name = "default-user"

  user_settings {
    execution_role = aws_iam_role.sagemaker_execution.arn
  }

  tags = var.md_metadata.default_tags
}
