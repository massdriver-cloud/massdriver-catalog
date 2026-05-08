# Optional event notifications: object-created events fan out to an SNS topic
# that downstream consumers (Lambda, SQS subscribers, ML pipelines) can
# subscribe to.

resource "aws_sns_topic" "events" {
  count = var.enable_event_notifications ? 1 : 0

  name              = "${local.bucket_name}-events"
  kms_master_key_id = local.use_kms ? aws_kms_key.bucket[0].id : "alias/aws/sns"
}

data "aws_iam_policy_document" "events" {
  count = var.enable_event_notifications ? 1 : 0

  statement {
    sid    = "AllowS3Publish"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["s3.amazonaws.com"]
    }
    actions   = ["SNS:Publish"]
    resources = [aws_sns_topic.events[0].arn]
    condition {
      test     = "ArnEquals"
      variable = "aws:SourceArn"
      values   = [aws_s3_bucket.main.arn]
    }
  }
}

resource "aws_sns_topic_policy" "events" {
  count = var.enable_event_notifications ? 1 : 0

  arn    = aws_sns_topic.events[0].arn
  policy = data.aws_iam_policy_document.events[0].json
}

resource "aws_s3_bucket_notification" "main" {
  count = var.enable_event_notifications ? 1 : 0

  bucket = aws_s3_bucket.main.id

  topic {
    topic_arn = aws_sns_topic.events[0].arn
    events    = ["s3:ObjectCreated:*", "s3:ObjectRemoved:*"]
  }

  depends_on = [aws_sns_topic_policy.events]
}
