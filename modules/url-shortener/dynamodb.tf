# Creates the DynamoDB table used to store shortened-link records.
resource "aws_dynamodb_table" "link_records" {
  # Use the caller-provided name for the DynamoDB table.
  name = var.dynamodb_table_name

  # Use on-demand capacity so DynamoDB automatically handles request throughput.
  billing_mode = "PAY_PER_REQUEST"

  # Use the generated short code as the table's partition key.
  hash_key = "short_code"

  # Define the string attribute used as the partition key.
  attribute {
    name = "short_code"
    type = "S"
  }

  # Enable automatic cleanup of expired items using the expiration timestamp.
  ttl {
    attribute_name = "expires_at"
    enabled        = true
  }

  # Apply the caller-provided tags to the DynamoDB table.
  tags = var.tags

  # Encrypt all DynamoDB table data at rest using a customer-managed KMS key.
  server_side_encryption {
    # Enable server-side encryption for the DynamoDB table.
    enabled = true

    # Use this project's customer-managed KMS key instead of an AWS-owned key.
    kms_key_arn = aws_kms_key.dynamodb.arn
  }
}
