# Creates the API Gateway HTTP API that exposes the URL-shortener endpoints.
resource "aws_apigatewayv2_api" "url_shortener_api" {
  # Use the caller-provided name for the HTTP API.
  name = var.api_gateway_name

  # Configure API Gateway to use the HTTP API protocol.
  protocol_type = "HTTP"

  # Apply the caller-provided tags to the API.
  tags = var.tags
}

# Connects the POST /links route to the create-link Lambda function.
resource "aws_apigatewayv2_integration" "create_link" {
  # Associate this integration with the URL-shortener HTTP API.
  api_id = aws_apigatewayv2_api.url_shortener_api.id

  # Use Lambda proxy integration so requests are forwarded directly to Lambda.
  integration_type = "AWS_PROXY"

  # Invoke the create-link Lambda function for this integration.
  integration_uri = aws_lambda_function.create_link.invoke_arn

  # Use the HTTP API version 2.0 Lambda event format.
  payload_format_version = "2.0"
}

# Routes authenticated POST /links requests to the create-link Lambda integration.
resource "aws_apigatewayv2_route" "create_link" {
  # Associate this route with the URL-shortener HTTP API.
  api_id = aws_apigatewayv2_api.url_shortener_api.id

  # Match POST requests sent to /links.
  route_key = "POST /links"

  # Require AWS IAM authorization for link creation.
  authorization_type = "AWS_IAM"

  # Send matching requests to the create-link Lambda integration.
  target = "integrations/${aws_apigatewayv2_integration.create_link.id}"
}



# Connects the GET /{code} route to the get_link_record Lambda function.
resource "aws_apigatewayv2_integration" "get_link_record" {
  # Associate this integration with the URL-shortener HTTP API.
  api_id = aws_apigatewayv2_api.url_shortener_api.id

  # Use Lambda proxy integration so requests are forwarded directly to Lambda.
  integration_type = "AWS_PROXY"

  # Invoke the get_link_record Lambda function for this integration.
  integration_uri = aws_lambda_function.get_link_record.invoke_arn

  # Use the HTTP API version 2.0 Lambda event format.
  payload_format_version = "2.0"
}

# Routes public GET /{code} requests to the get_link_record Lambda integration.
resource "aws_apigatewayv2_route" "get_link_record" {
  # Associate this route with the URL-shortener HTTP API.
  api_id = aws_apigatewayv2_api.url_shortener_api.id

  # Match GET requests sent to /{code}.
  route_key = "GET /{code}"

  # Send matching requests to the get_link_record Lambda integration.
  target = "integrations/${aws_apigatewayv2_integration.get_link_record.id}"
}

# Creates the default API Gateway stage used to serve the URL-shortener API.
# Deploys the API so its routes can actually receive requests.
# Using $default makes the API accessible without a stage name in the URL.
resource "aws_apigatewayv2_stage" "default" {
  # Associate this stage with the URL-shortener HTTP API.
  api_id = aws_apigatewayv2_api.url_shortener_api.id

  # Use the special $default stage so requests do not require a stage prefix.
  name = "$default"

  # Automatically deploy API changes to the default stage.
  auto_deploy = true

  # Apply default throttling limits to all routes to control excessive API traffic.
  default_route_settings {
    # Limit the sustained request rate across routes in the default stage.
    throttling_rate_limit = 50

    # Allow short traffic bursts up to this request limit.
    throttling_burst_limit = 100
  }

  # Sends structured API Gateway access logs to the designated CloudWatch log group.
  access_log_settings {
    # Specify the CloudWatch log group that receives the API access logs.
    destination_arn = aws_cloudwatch_log_group.api_gateway_access_logs.arn

    # Format each access log entry as structured JSON without sensitive request data.
    format = jsonencode({
      # Record the unique identifier assigned to the API request.
      request_id = "$context.requestId"

      # Record when API Gateway received the request.
      request_time = "$context.requestTime"

      # Record the HTTP method used for the request.
      http_method = "$context.httpMethod"

      # Record the API route that handled the request.
      route_key = "$context.routeKey"

      # Record the HTTP status code returned to the client.
      status = "$context.status"

      # Record the size of the response returned to the client.
      response_length = "$context.responseLength"
    })
  }
}

# Allows API Gateway to invoke the create-link Lambda function.
resource "aws_lambda_permission" "allow_api_gateway_create_link" {
  # Assign a unique identifier to this Lambda resource-based policy statement.
  statement_id = "AllowAPIGatewayInvokeCreateLink"

  # Permit API Gateway to invoke the Lambda function.
  action = "lambda:InvokeFunction"

  # Grant the permission on the create-link Lambda function.
  function_name = aws_lambda_function.create_link.function_name

  # Grant invocation permission specifically to the API Gateway service.
  principal = "apigateway.amazonaws.com"

  # Restrict API Gateway invocation to the POST /links route only.
  source_arn = "${aws_apigatewayv2_api.url_shortener_api.execution_arn}/*/POST/links"
}

# Allows API Gateway to invoke the resolve-link Lambda function.
resource "aws_lambda_permission" "allow_api_gateway_get_record_link" {
  # Assign a unique identifier to this Lambda resource-based policy statement.
  statement_id = "AllowAPIGatewayInvokeGetRecordLink"

  # Permit API Gateway to invoke the Lambda function.
  action = "lambda:InvokeFunction"

  # Grant the permission on the resolve-link Lambda function.
  function_name = aws_lambda_function.get_link_record.function_name

  # Grant invocation permission specifically to the API Gateway service.
  principal = "apigateway.amazonaws.com"

  # Restrict API Gateway invocation to GET requests handled by the /{code} route.
  source_arn = "${aws_apigatewayv2_api.url_shortener_api.execution_arn}/*/GET/*"
}
