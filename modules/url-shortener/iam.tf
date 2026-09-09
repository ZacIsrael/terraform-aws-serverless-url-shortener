# Builds the resource-based policy attached to the customer-managed KMS key.
data "aws_iam_policy_document" "dynamodb_kms" {
  # Preserve an administrative recovery path and enable IAM-based delegation.
  statement {
    # Give this policy statement a clear identifier.
    sid = "EnableIAMUserPermissions"

    # Allow the permissions defined in this statement.
    effect = "Allow"

    # Grant the AWS account principal authority over the KMS key.
    principals {
      type = "AWS"

      # Reference the root principal of the current AWS account.
      identifiers = [
        "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
      ]
    }

    # Allow full KMS administration through the account's IAM permissions.
    actions = [
      "kms:*"
    ]

    # Apply this statement to the KMS key represented by this key policy.
    resources = ["*"]
  }

  # Allow authorized application roles to use this key only through DynamoDB.
  statement {
    # Give this DynamoDB-specific key usage statement a clear identifier.
    sid = "AllowDynamoDBKeyUsage"

    # Allow the permissions defined in this statement.
    effect = "Allow"

    # Grant key usage to the two Lambda execution roles.
    principals {
      type = "AWS"

      # Restrict key usage to the create-link and resolve-link Lambda roles.
      identifiers = [
        aws_iam_role.create_link_lambda_role.arn,
        aws_iam_role.get_link_record_lambda_role.arn
      ]
    }

    # Allow only the KMS operations DynamoDB may require for encrypted table access.
    actions = [
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:DescribeKey",
      "kms:CreateGrant"
    ]

    # Apply this statement to the KMS key represented by this key policy.
    resources = ["*"]

    # Prevent the Lambda roles from using the key directly outside DynamoDB.
    condition {
      # Match DynamoDB service endpoints across AWS regions.
      test = "StringLike"

      # Restrict key usage based on the AWS service making the KMS request.
      variable = "kms:ViaService"

      # Permit key usage only when the request is made through DynamoDB.
      values = ["dynamodb.*.amazonaws.com"]
    }
  }
}

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
