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
  region = var.sagemaker_domain.region
  assume_role {
    role_arn    = var.aws_authentication.arn
    external_id = try(var.aws_authentication.external_id, null)
  }
  default_tags {
    tags = var.md_metadata.default_tags
  }
}

locals {
  endpoint_name = "${var.md_metadata.name_prefix}-${var.endpoint_name}"
  use_poc_model = var.model_source == "poc-sklearn"

  # AWS Deep Learning Container for scikit-learn inference
  sklearn_image = "683313688378.dkr.ecr.${var.sagemaker_domain.region}.amazonaws.com/sagemaker-scikit-learn:1.2-1-cpu-py3"
}

# For POC: Upload pre-built mock model to S3
# The model.tar.gz is bundled with the terraform code
resource "aws_s3_object" "poc_model" {
  count  = local.use_poc_model ? 1 : 0
  bucket = var.sagemaker_domain.default_bucket
  key    = "models/poc-iris-classifier/model.tar.gz"
  source = "${path.module}/model.tar.gz"
  etag   = filemd5("${path.module}/model.tar.gz")
}

# Get the model S3 path
locals {
  model_data_url = local.use_poc_model ? "s3://${var.sagemaker_domain.default_bucket}/models/poc-iris-classifier/model.tar.gz" : var.custom_model_s3_uri
}

# SageMaker Model
resource "aws_sagemaker_model" "main" {
  name               = local.endpoint_name
  execution_role_arn = var.sagemaker_domain.execution_role_arn

  primary_container {
    image          = local.sklearn_image
    model_data_url = local.model_data_url
    environment = {
      SAGEMAKER_PROGRAM             = "inference.py"
      SAGEMAKER_SUBMIT_DIRECTORY    = local.model_data_url
      SAGEMAKER_CONTAINER_LOG_LEVEL = "20"
    }
  }

  vpc_config {
    subnets            = var.sagemaker_domain.subnet_ids
    security_group_ids = [var.sagemaker_domain.security_group_id]
  }

  tags = {
    Name = local.endpoint_name
  }

  depends_on = [aws_s3_object.poc_model]
}

# SageMaker Endpoint Configuration
resource "aws_sagemaker_endpoint_configuration" "main" {
  name = local.endpoint_name

  production_variants {
    variant_name           = "primary"
    model_name             = aws_sagemaker_model.main.name
    instance_type          = var.instance_type
    initial_instance_count = var.initial_instance_count
    initial_variant_weight = 1
  }

  tags = {
    Name = local.endpoint_name
  }
}

# SageMaker Endpoint
resource "aws_sagemaker_endpoint" "main" {
  name                 = local.endpoint_name
  endpoint_config_name = aws_sagemaker_endpoint_configuration.main.name

  tags = {
    Name = local.endpoint_name
  }
}

# CloudWatch alarm for endpoint errors
module "alarm_channel" {
  source      = "github.com/massdriver-cloud/terraform-modules//aws/alarm-channel?ref=main"
  md_metadata = var.md_metadata
}

module "alarm_endpoint_errors" {
  source      = "github.com/massdriver-cloud/terraform-modules//aws/cloudwatch-alarm?ref=main"
  md_metadata = var.md_metadata

  alarm_name   = "${var.md_metadata.name_prefix}-endpoint-errors"
  display_name = "Endpoint Invocation Errors"
  message      = "SageMaker endpoint has invocation errors"

  namespace   = "AWS/SageMaker"
  metric_name = "Invocation4XXErrors"
  statistic   = "Sum"
  period      = "300"

  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  threshold           = "10"

  dimensions = {
    EndpointName = aws_sagemaker_endpoint.main.name
    VariantName  = "primary"
  }

  sns_topic_arn = module.alarm_channel.arn
}

# Outputs for the operator guide
output "endpoint_name" {
  value = aws_sagemaker_endpoint.main.name
}

output "endpoint_arn" {
  value = aws_sagemaker_endpoint.main.arn
}

output "model_name" {
  value = aws_sagemaker_model.main.name
}
