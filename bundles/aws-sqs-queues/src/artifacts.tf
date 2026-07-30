# One massdriver_resource per named queue, all under the same `queues` field —
# this is the "named set" the queue bundle exists for: a consuming app links
# to whichever named queue resources it needs out of this one deploy.
resource "massdriver_resource" "queues" {
  for_each = aws_sqs_queue.main

  field = "queues"
  name  = "${each.key} (${var.md_metadata.name_prefix})"
  resource = jsonencode(merge(
    {
      id     = each.value.arn
      name   = each.key
      url    = each.value.id
      arn    = each.value.arn
      region = var.network.region
      policies = [
        { id = aws_iam_policy.send[each.key].arn, name = "send-only" },
        { id = aws_iam_policy.consume[each.key].arn, name = "send-receive" },
      ]
    },
    contains(keys(aws_sqs_queue.dlq), each.key) ? {
      dlq_url = aws_sqs_queue.dlq[each.key].id
      dlq_arn = aws_sqs_queue.dlq[each.key].arn
    } : {}
  ))
}
