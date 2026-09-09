# Defines the least-privilege DynamoDB permissions required by the create-link Lambda.
data "aws_iam_policy_document" "create_link_dynamodb" {
  statement {
    # Allow the create-link Lambda to perform the permitted DynamoDB action.
    effect = "Allow"

    # Permit only item creation; the create-link Lambda does not need read or delete access.
    actions = [
      "dynamodb:PutItem",
    ]

    # Restrict write access to this project's URL-shortener table.
    resources = [
      aws_dynamodb_table.link_records.arn,
    ]
  }
}

# Defines the least-privilege DynamoDB permissions required by the resolve-link Lambda.
data "aws_iam_policy_document" "resolve_link_dynamodb" {
  statement {
    # Allow the resolve-link Lambda to perform the permitted DynamoDB action.
    effect = "Allow"

    # Permit only direct item reads; the resolver does not need write or delete access.
    actions = [
      "dynamodb:GetItem",
    ]

    # Restrict read access to this project's URL-shortener table.
    resources = [
      aws_dynamodb_table.link_records.arn,
    ]
  }
}
