# Alarm channel (SNS topic) for sending alerts to Massdriver
module "alarm_channel" {
  source      = "github.com/massdriver-cloud/terraform-modules//aws/alarm-channel?ref=main"
  md_metadata = var.md_metadata
}

# CloudWatch Alarm for high CPU utilization
module "alarm_high_cpu" {
  source      = "github.com/massdriver-cloud/terraform-modules//aws/cloudwatch-alarm?ref=main"
  md_metadata = var.md_metadata

  alarm_name   = "${var.md_metadata.name_prefix}-high-cpu"
  display_name = "High CPU Utilization"
  message      = "RDS MySQL CPU utilization is above 80%"

  namespace   = "AWS/RDS"
  metric_name = "CPUUtilization"
  statistic   = "Average"
  period      = "300"

  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  threshold           = "80"

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.main.identifier
  }

  sns_topic_arn = module.alarm_channel.arn
}
