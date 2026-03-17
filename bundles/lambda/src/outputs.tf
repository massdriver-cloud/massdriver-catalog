output "function_url" {
  description = "Public URL for the TODO API"
  value       = aws_lambda_function_url.todo_api.function_url
}

output "function_arn" {
  description = "ARN of the Lambda function"
  value       = aws_lambda_function.todo_api.arn
}

output "function_name" {
  description = "Name of the Lambda function"
  value       = aws_lambda_function.todo_api.function_name
}

output "log_group_name" {
  description = "CloudWatch Log Group for Lambda logs"
  value       = aws_cloudwatch_log_group.lambda_logs.name
}

output "dynamodb_table_name" {
  description = "Connected DynamoDB table name"
  value       = local.table_name
}

output "dynamodb_policy" {
  description = "DynamoDB access policy level"
  value       = var.dynamodb_policy
}
