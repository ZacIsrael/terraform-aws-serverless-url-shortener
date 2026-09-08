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


# Exposes the API Gateway ID for service-specific configuration and lookups.
output "api_gateway_id" {
  description = "ID of the API Gateway HTTP API that exposes the URL-shortener routes."
  value       = aws_apigatewayv2_api.url_shortener_api.id
}

# Exposes the base API endpoint used by clients to send requests to the URL-shortener API.
output "api_endpoint" {
  description = "Base endpoint URL of the API Gateway HTTP API."
  value       = aws_apigatewayv2_api.url_shortener_api.api_endpoint
}

# Exposes the API execution ARN for use in IAM policies that control API invocation.
output "api_execution_arn" {
  description = "Execution ARN of the API Gateway HTTP API for constructing execute-api IAM resource permissions."
  value       = aws_apigatewayv2_api.url_shortener_api.execution_arn
}
