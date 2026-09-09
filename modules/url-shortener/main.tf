# Execution role assumed by the create-link Lambda function.
resource "aws_iam_role" "create_link_lambda_role" {
  # Assign a descriptive name to the Lambda execution role.
  name = "create_link_lambda_execution_role"

  # Allow the AWS Lambda service to assume this execution role.
  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"

        # Restrict role assumption to the AWS Lambda service.
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

# Grants the create-link Lambda permission to write logs to CloudWatch.
resource "aws_iam_role_policy_attachment" "create_link_lambda_logs" {
  # Attach the policy to the create-link Lambda execution role.
  role = aws_iam_role.create_link_lambda_role.name

  # AWS-managed policy providing the basic permissions required for Lambda logging.
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Execution role assumed by the resolve-link Lambda function.
resource "aws_iam_role" "get_link_record_lambda_role" {
  # Assign a descriptive name to the Lambda execution role.
  name = "get_link_record_lambda_execution_role"

  # Allow the AWS Lambda service to assume this execution role.
  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"

        # Restrict role assumption to the AWS Lambda service.
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

# Grants the resolve-link Lambda permission to write logs to CloudWatch.
resource "aws_iam_role_policy_attachment" "get_link_record_lambda_logs" {
  # Attach the policy to the resolve-link Lambda execution role.
  role = aws_iam_role.get_link_record_lambda_role.name

  # AWS-managed policy providing the basic permissions required for Lambda logging.
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Stores API Gateway access logs so requests and responses can be monitored.
resource "aws_cloudwatch_log_group" "api_gateway_access_logs" {
  # Use a descriptive name for the API Gateway access log group.
  name = "/aws/apigateway/url-shortener-api-access-logs"

  # Retain API access logs for seven days before CloudWatch deletes them.
  retention_in_days = 7

  # Apply the caller-provided tags to the CloudWatch log group.
  tags = var.tags
}

# Creates the IAM policy containing the create-link Lambda's DynamoDB permissions.
resource "aws_iam_policy" "create_link_dynamodb" {
  # Convert the generated IAM policy document into the JSON required by AWS IAM.
  policy = data.aws_iam_policy_document.create_link_dynamodb.json
}

# Attaches the DynamoDB write policy to the create-link Lambda execution role.
resource "aws_iam_role_policy_attachment" "create_link_dynamodb" {
  # Attach the policy only to the execution role used by the create-link Lambda.
  role = aws_iam_role.create_link_lambda_role.name

  # Grant the role the least-privilege DynamoDB write policy defined above.
  policy_arn = aws_iam_policy.create_link_dynamodb.arn
}

# Creates the IAM policy containing the resolve-link Lambda's DynamoDB permissions.
resource "aws_iam_policy" "resolve_link_dynamodb" {
  # Convert the generated IAM policy document into the JSON required by AWS IAM.
  policy = data.aws_iam_policy_document.resolve_link_dynamodb.json
}

# Attaches the DynamoDB read policy to the resolve-link Lambda execution role.
resource "aws_iam_role_policy_attachment" "resolve_link_dynamodb" {
  # Attach the policy only to the execution role used by the resolve-link Lambda.
  role = aws_iam_role.get_link_record_lambda_role.name

  # Grant the role the least-privilege DynamoDB read policy defined above.
  policy_arn = aws_iam_policy.resolve_link_dynamodb.arn
}

# Explicitly manage the create-link Lambda log group so Terraform controls
# log retention instead of leaving the default indefinite retention period.
resource "aws_cloudwatch_log_group" "create_link" {
  # Match Lambda's standard CloudWatch log group naming convention.
  name = "/aws/lambda/${var.create_lambda_name}"

  # Retain application logs for seven days to limit unnecessary log storage.
  retention_in_days = 7

  # Apply the module's common resource tags.
  tags = var.tags
}

# Explicitly manage the resolve-link Lambda log group so Terraform controls
# log retention instead of leaving the default indefinite retention period.
resource "aws_cloudwatch_log_group" "resolve_link" {
  # Match Lambda's standard CloudWatch log group naming convention.
  name = "/aws/lambda/${var.resolve_lambda_name}"

  # Retain application logs for seven days to limit unnecessary log storage.
  retention_in_days = 7

  # Apply the module's common resource tags.
  tags = var.tags
}


# Monitors the create-link Lambda function for execution failures.
resource "aws_cloudwatch_metric_alarm" "create_link_lambda_error_alarm" {
  # Give the alarm a unique name based on the Lambda function being monitored.
  alarm_name = "lambda-error-count-${aws_lambda_function.create_link.function_name}"

  # Enter the ALARM state when the error count reaches or exceeds the threshold.
  comparison_operator = "GreaterThanOrEqualToThreshold"

  # Require one evaluation period to breach the threshold before triggering the alarm.
  evaluation_periods = 1

  # Trigger the alarm when at least one Lambda execution error occurs.
  threshold = 1

  # Evaluate the Lambda error metric over 60-second intervals.
  period = 60

  # Monitor the built-in Lambda metric that records failed function invocations.
  metric_name = "Errors"

  # Use the AWS Lambda CloudWatch metric namespace.
  namespace = "AWS/Lambda"

  # Sum all execution errors that occur during each evaluation period.
  statistic = "Sum"

  # Describe the condition that causes this CloudWatch alarm to trigger.
  alarm_description = "Triggers when the create-link Lambda function reports one or more errors within a 60-second period."

  # Treat periods without metric data as healthy instead of triggering the alarm.
  treat_missing_data = "notBreaching"

  # Restrict the Errors metric to the create-link Lambda function.
  dimensions = {
    FunctionName = aws_lambda_function.create_link.function_name
  }
}

# Monitors the get-link-record Lambda function for execution failures.
resource "aws_cloudwatch_metric_alarm" "get_link_record_lambda_error_alarm" {
  # Give the alarm a unique name based on the Lambda function being monitored.
  alarm_name = "lambda-error-count-${aws_lambda_function.get_link_record.function_name}"

  # Enter the ALARM state when the error count reaches or exceeds the threshold.
  comparison_operator = "GreaterThanOrEqualToThreshold"

  # Require one evaluation period to breach the threshold before triggering the alarm.
  evaluation_periods = 1

  # Trigger the alarm when at least one Lambda execution error occurs.
  threshold = 1

  # Evaluate the Lambda error metric over 60-second intervals.
  period = 60

  # Monitor the built-in Lambda metric that records failed function invocations.
  metric_name = "Errors"

  # Use the AWS Lambda CloudWatch metric namespace.
  namespace = "AWS/Lambda"

  # Sum all execution errors that occur during each evaluation period.
  statistic = "Sum"

  # Describe the condition that causes this CloudWatch alarm to trigger.
  alarm_description = "Triggers when the get-link-record Lambda function reports one or more errors within a 60-second period."

  # Treat periods without metric data as healthy instead of triggering the alarm.
  treat_missing_data = "notBreaching"

  # Restrict the Errors metric to the get-link-record Lambda function.
  dimensions = {
    FunctionName = aws_lambda_function.get_link_record.function_name
  }
}


# Monitors the URL-shortener HTTP API for server-side 5XX responses.
resource "aws_cloudwatch_metric_alarm" "api_gateway_5xx_alarm" {
  # Give the alarm a unique name based on the API being monitored.
  alarm_name = "api-gateway-5xx-${aws_apigatewayv2_api.url_shortener_api.name}"

  # Describe the condition that causes the alarm to enter the ALARM state.
  alarm_description = "Triggers when the URL-shortener API reports one or more 5XX errors within a 60-second period."

  # Trigger when the observed 5XX count reaches or exceeds the configured threshold.
  comparison_operator = "GreaterThanOrEqualToThreshold"

  # Require one breaching evaluation period before entering the ALARM state.
  evaluation_periods = 1

  # Monitor API Gateway's built-in metric for HTTP API server-side errors.
  metric_name = "5xx"

  # Use the CloudWatch namespace that contains API Gateway metrics.
  namespace = "AWS/ApiGateway"

  # Evaluate the 5XX metric over 60-second intervals.
  period = 60

  # Sum all 5XX responses that occur during each evaluation period.
  statistic = "Sum"

  # Trigger the alarm when at least one 5XX response occurs.
  threshold = 1

  # Treat periods without API metric data as healthy rather than breaching.
  treat_missing_data = "notBreaching"

  # Restrict the metric to this project's HTTP API and its default stage.
  dimensions = {
    ApiId = aws_apigatewayv2_api.url_shortener_api.id
    Stage = aws_apigatewayv2_stage.default.name
  }
}
