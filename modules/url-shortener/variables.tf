# Name of the Lambda function that creates and stores new shortened-link records in DynamoDB.
variable "create_lambda_name" {
  description = "Name of the Lambda function that creates a new shortened-link record in DynamoDB."
  type        = string
}

# Name of the Lambda function that resolves short codes to their destination URLs.
variable "resolve_lambda_name" {
  description = "Name of the Lambda function that retrieves a shortened-link record from DynamoDB using its short code."
  type        = string
}

# Name of the DynamoDB table that stores shortened-link records.
variable "dynamodb_table_name" {
  description = "Name of the DynamoDB table that stores short codes, destination URLs, expiration timestamps, and creation timestamps."
  type        = string
}

# Name of the API Gateway HTTP API that exposes the URL-shortener routes.
variable "api_gateway_name" {
  description = "Name of the API Gateway HTTP API that routes requests to the appropriate Lambda function."
  type        = string
}

# Alias assigned to the customer-managed KMS key used to encrypt the DynamoDB table.
variable "kms_alias" {
  description = "Alias for the customer-managed KMS key used to encrypt the DynamoDB table at rest."
  type        = string
}

# Tags applied consistently to supported AWS resources created by this module.
variable "tags" {
  description = "Map of tags to apply to supported AWS resources created by this module."
  type        = map(string)
  default     = {}
}
