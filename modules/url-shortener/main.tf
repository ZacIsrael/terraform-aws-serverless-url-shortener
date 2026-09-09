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
