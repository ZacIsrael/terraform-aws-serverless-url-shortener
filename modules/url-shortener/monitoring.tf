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

# Stores API Gateway access logs so requests and responses can be monitored.
resource "aws_cloudwatch_log_group" "api_gateway_access_logs" {
  # Use a descriptive name for the API Gateway access log group.
  name = "/aws/apigateway/url-shortener-api-access-logs"

  # Retain API access logs for seven days before CloudWatch deletes them.
  retention_in_days = 7

  # Apply the caller-provided tags to the CloudWatch log group.
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
