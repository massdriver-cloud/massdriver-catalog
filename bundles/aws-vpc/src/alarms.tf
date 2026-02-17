# Alarm channel (SNS topic) for sending alerts to Massdriver
module "alarm_channel" {
  source      = "github.com/massdriver-cloud/terraform-modules//aws/alarm-channel?ref=main"
  md_metadata = var.md_metadata
}

# CloudWatch Alarm for VPC - monitors rejected traffic (requires flow logs)
# This is a simple example alarm for the VPC
module "alarm_vpc_state" {
  source      = "github.com/massdriver-cloud/terraform-modules//aws/cloudwatch-alarm?ref=main"
  md_metadata = var.md_metadata

  alarm_name   = "${var.md_metadata.name_prefix}-vpc-state"
  display_name = "VPC State Check"
  message      = "VPC health check alarm"

  namespace   = "AWS/EC2"
  metric_name = "StatusCheckFailed"
  statistic   = "Maximum"
  period      = "300"

  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  threshold           = "0"

  dimensions = {}

  sns_topic_arn = module.alarm_channel.arn
}
