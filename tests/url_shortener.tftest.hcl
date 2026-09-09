# Configures the AWS provider used during the Terraform test.
provider "aws" {
  # Runs the test against the same AWS region used by the basic example.
  region = "us-east-1"
}

# Supplies test-only values for the URL-shortener module's required inputs.
variables {
  create_lambda_name  = "test-url-shortener-create-link"
  resolve_lambda_name = "test-url-shortener-get-link-record"
  dynamodb_table_name = "test-url-shortener-links"
  api_gateway_name    = "test-url-shortener-api"
  kms_alias           = "alias/test-url-shortener"
}

# Generates and validates the planned URL-shortener infrastructure configuration.
run "url_shortener_configuration" {
  # Generate a Terraform plan without creating or modifying real AWS resources.
  command = plan

  # Specify the reusable module configuration that this test evaluates.
  module {
    # Load the reusable URL-shortener module from the repository.
    source = "./modules/url-shortener"
  }

  # Verify that the module plans both required Lambda functions.
  assert {
    # Create a list of the Lambda resources and confirm exactly two are defined.
    condition = length([
      aws_lambda_function.create_link,
      aws_lambda_function.get_link_record
    ]) == 2

    # Display this message if the expected Lambda function count is incorrect.
    error_message = "Expected two Lambda functions to be created."
  }

  # Verify that both Lambda functions use the project's required Node.js runtime.
  assert {
    # Confirm the create-link and get-link-record functions both use Node.js 22.x.
    condition = (
      aws_lambda_function.create_link.runtime == "nodejs22.x" &&
      aws_lambda_function.get_link_record.runtime == "nodejs22.x"
    )

    # Display this message if either Lambda uses an unexpected runtime.
    error_message = "Expected both Lambda functions to use the nodejs22.x runtime."
  }

  # Verify that the DynamoDB table uses the expected short-code partition key.
  assert {
    # Confirm short_code is configured as the table's hash key.
    condition = aws_dynamodb_table.link_records.hash_key == "short_code"

    # Display this message if the table uses an unexpected partition key.
    error_message = "Expected the DynamoDB partition key to be short_code."
  }

  # Verify that DynamoDB uses on-demand capacity instead of provisioned capacity.
  assert {
    # Confirm the table uses pay-per-request billing to avoid provisioned throughput.
    condition = aws_dynamodb_table.link_records.billing_mode == "PAY_PER_REQUEST"

    # Display this message if the table is configured with another billing mode.
    error_message = "Expected the DynamoDB table to use PAY_PER_REQUEST billing."
  }

  # Verify that DynamoDB TTL is configured using the expires_at attribute.
  assert {
    # Confirm expiration cleanup is enabled and tied to the expected TTL attribute.
    condition = (
      aws_dynamodb_table.link_records.ttl[0].enabled == true &&
      aws_dynamodb_table.link_records.ttl[0].attribute_name == "expires_at"
    )

    # Display this message if the expected DynamoDB TTL configuration is missing.
    error_message = "Expected DynamoDB TTL to be enabled using the expires_at attribute."
  }

  # Verify that server-side encryption is enabled for the DynamoDB table.
  assert {
    # Confirm DynamoDB server-side encryption is explicitly enabled.
    condition = aws_dynamodb_table.link_records.server_side_encryption[0].enabled == true

    # Display this message if DynamoDB server-side encryption is disabled.
    error_message = "Expected DynamoDB server-side encryption to be enabled."
  }

  # Verify that automatic rotation is enabled for the customer-managed KMS key.
  assert {
    # Confirm the DynamoDB encryption key has automatic key rotation enabled.
    condition = aws_kms_key.dynamodb.enable_key_rotation == true

    # Display this message if automatic KMS key rotation is disabled.
    error_message = "Expected automatic rotation to be enabled for the DynamoDB KMS key."
  }

  # Verify that both API Gateway integrations use Lambda proxy payload format 2.0.
  assert {
    # Confirm both Lambda integrations use AWS_PROXY and HTTP API payload format 2.0.
    condition = (
      aws_apigatewayv2_integration.create_link.integration_type == "AWS_PROXY" &&
      aws_apigatewayv2_integration.create_link.payload_format_version == "2.0" &&
      aws_apigatewayv2_integration.get_link_record.integration_type == "AWS_PROXY" &&
      aws_apigatewayv2_integration.get_link_record.payload_format_version == "2.0"
    )

    # Display this message if either Lambda integration has an unexpected configuration.
    error_message = "Expected both API Gateway integrations to use AWS_PROXY with payload format 2.0."
  }

  # Verify that the API exposes the expected POST and GET route keys.
  assert {
    # Confirm the create and resolve routes match the public API contract.
    condition = (
      aws_apigatewayv2_route.create_link.route_key == "POST /links" &&
      aws_apigatewayv2_route.get_link_record.route_key == "GET /{code}"
    )

    # Display this message if either expected API route is configured incorrectly.
    error_message = "Expected API routes POST /links and GET /{code}."
  }

  # Verify that only the link-creation route requires AWS IAM authorization.
  assert {
    # Confirm POST requires SigV4/IAM authorization while GET remains publicly accessible.
    condition = (
      aws_apigatewayv2_route.create_link.authorization_type == "AWS_IAM" &&
      aws_apigatewayv2_route.get_link_record.authorization_type == "NONE"
    )

    # Display this message if the API route authorization model changes unexpectedly.
    error_message = "Expected POST /links to use AWS_IAM authorization and GET /{code} to remain public."
  }

  # Verify that the default API stage enforces the configured traffic limits.
  assert {
    # Confirm sustained traffic is limited to 50 RPS with a burst capacity of 100 requests.
    condition = (
      aws_apigatewayv2_stage.default.default_route_settings[0].throttling_rate_limit == 50 &&
      aws_apigatewayv2_stage.default.default_route_settings[0].throttling_burst_limit == 100
    )

    # Display this message if the API throttling configuration changes unexpectedly.
    error_message = "Expected API throttling limits of 50 requests per second and a burst limit of 100."
  }

  # Verify that Lambda application logs are retained for only seven days.
  assert {
    # Confirm both explicitly managed Lambda log groups use the required retention period.
    condition = (
      aws_cloudwatch_log_group.create_link.retention_in_days == 7 &&
      aws_cloudwatch_log_group.resolve_link.retention_in_days == 7
    )

    # Display this message if either Lambda log group has an unexpected retention period.
    error_message = "Expected both Lambda log groups to retain logs for seven days."
  }

  # Verify that API Gateway access logs also use the required seven-day retention period.
  assert {
    # Confirm the API access-log group does not retain logs indefinitely.
    condition = aws_cloudwatch_log_group.api_gateway_access_logs.retention_in_days == 7

    # Display this message if API access-log retention differs from the project requirement.
    error_message = "Expected API Gateway access logs to be retained for seven days."
  }

  # Verify that both Lambda error alarms trigger after at least one execution error.
  assert {
    # Confirm both alarms monitor the Lambda Errors metric with a threshold of one.
    condition = (
      aws_cloudwatch_metric_alarm.create_link_lambda_error_alarm.metric_name == "Errors" &&
      aws_cloudwatch_metric_alarm.create_link_lambda_error_alarm.threshold == 1 &&
      aws_cloudwatch_metric_alarm.get_link_record_lambda_error_alarm.metric_name == "Errors" &&
      aws_cloudwatch_metric_alarm.get_link_record_lambda_error_alarm.threshold == 1
    )

    # Display this message if either Lambda error alarm no longer matches the expected policy.
    error_message = "Expected both Lambda error alarms to trigger when at least one execution error occurs."
  }

  # Verify that the API Gateway alarm monitors server-side HTTP API failures.
  assert {
    # Confirm the alarm watches the API Gateway 5xx metric with a threshold of one.
    condition = (
      aws_cloudwatch_metric_alarm.api_gateway_5xx_alarm.namespace == "AWS/ApiGateway" &&
      aws_cloudwatch_metric_alarm.api_gateway_5xx_alarm.metric_name == "5xx" &&
      aws_cloudwatch_metric_alarm.api_gateway_5xx_alarm.threshold == 1
    )

    # Display this message if the API 5XX monitoring configuration changes unexpectedly.
    error_message = "Expected the API Gateway alarm to trigger when at least one 5XX response occurs."
  }
}
