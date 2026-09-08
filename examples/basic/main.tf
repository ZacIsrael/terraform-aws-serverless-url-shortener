# Deploys a basic URL-shortener configuration using the reusable module.
module "url_shortener" {
  # Load the URL-shortener module from the local modules directory.
  source = "../../modules/url-shortener"

  # Configure names for the AWS resources created by the module.
  create_lambda_name  = "url-shortener-prod-create-link"
  resolve_lambda_name = "url-shortener-prod-resolve-link"
  dynamodb_table_name = "url-shortener-prod-links"
  api_gateway_name    = "url-shortener-prod-api"

  # Assign a human-readable alias to the customer-managed DynamoDB KMS key.
  kms_alias = "alias/url-shortener-prod-dynamodb"

  # tags does not need to be defined because it contains a default value
}
