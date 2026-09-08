# ARNs identify resources for IAM policies and cross-resource references,
# while IDs identify resources for service-specific configuration and lookups.

# Exposes the create-link Lambda ARN for use by callers and dependent resources.
output "create_lambda_arn" {
  description = "ARN of the Lambda function that creates a new shortened-link record in DynamoDB."
  value       = aws_lambda_function.create_link.arn
}

# Exposes the resolve-link Lambda ARN for use by callers and dependent resources.
output "resolve_lambda_arn" {
  description = "ARN of the Lambda function that retrieves a shortened-link record from DynamoDB using its short code."
  value       = aws_lambda_function.get_link_record.arn
}

# Exposes the DynamoDB table ARN for use by callers and dependent resources.
output "dynamodb_table_arn" {
  description = "ARN of the DynamoDB table that stores shortened-link records."
  value       = aws_dynamodb_table.link_records.arn
}