locals {
  name_prefix    = var.md_metadata.name_prefix
  queues_by_name = { for q in var.queues : q.name => q }
  dlq_queues     = { for q in var.queues : q.name => q if coalesce(q.enable_dlq, false) }
}

resource "aws_sqs_queue" "dlq" {
  for_each = local.dlq_queues

  name                      = "${local.name_prefix}-${each.key}-dlq"
  message_retention_seconds = each.value.message_retention_seconds
  sqs_managed_sse_enabled   = true

  tags = merge(var.md_metadata.default_tags, { Name = "${local.name_prefix}-${each.key}-dlq" })
}

resource "aws_sqs_queue" "main" {
  for_each = local.queues_by_name

  name                       = "${local.name_prefix}-${each.key}"
  visibility_timeout_seconds = each.value.visibility_timeout_seconds
  message_retention_seconds  = each.value.message_retention_seconds
  sqs_managed_sse_enabled    = true

  redrive_policy = coalesce(each.value.enable_dlq, false) ? jsonencode({
    deadLetterTargetArn = aws_sqs_queue.dlq[each.key].arn
    maxReceiveCount     = coalesce(each.value.max_receive_count, 5)
  }) : null

  tags = merge(var.md_metadata.default_tags, { Name = "${local.name_prefix}-${each.key}" })
}

# --- Scoped IAM policies a consuming app attaches to its IRSA role, per queue ---

resource "aws_iam_policy" "send" {
  for_each    = aws_sqs_queue.main
  name_prefix = "${local.name_prefix}-${each.key}-send-"
  description = "Send-only access to the ${each.key} queue"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["sqs:SendMessage", "sqs:GetQueueAttributes", "sqs:GetQueueUrl"]
      Resource = each.value.arn
    }]
  })
}

resource "aws_iam_policy" "consume" {
  for_each    = aws_sqs_queue.main
  name_prefix = "${local.name_prefix}-${each.key}-consume-"
  description = "Send + receive + delete access to the ${each.key} queue"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "sqs:SendMessage",
        "sqs:ReceiveMessage",
        "sqs:DeleteMessage",
        "sqs:GetQueueAttributes",
        "sqs:GetQueueUrl",
        "sqs:ChangeMessageVisibility",
      ]
      Resource = each.value.arn
    }]
  })
}
