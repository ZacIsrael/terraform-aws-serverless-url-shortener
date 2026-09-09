# Retrieves the AWS account ID of the identity running Terraform.
data "aws_caller_identity" "current" {}

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

# Creates the customer-managed KMS key used to encrypt the DynamoDB table.
resource "aws_kms_key" "dynamodb" {
  # Describe the purpose of the key for easier identification in AWS.
  description = "Customer-managed KMS key for URL shortener DynamoDB encryption."

  # Enable automatic annual rotation of the KMS key material.
  enable_key_rotation = true

  # Require a waiting period before AWS permanently deletes the KMS key.
  deletion_window_in_days = 7

  # Attach the generated KMS key policy to this key to control who can administer
  # and use it, including restricting application key usage to DynamoDB.
  policy = data.aws_iam_policy_document.dynamodb_kms.json

  # Apply the caller-provided tags to the KMS key.
  tags = var.tags
}

# Creates a friendly alias for the customer-managed KMS key.
resource "aws_kms_alias" "dynamodb" {
  # Use the caller-provided alias name for the KMS key.
  name = var.kms_alias

  # Associate the alias with the URL shortener DynamoDB encryption key.
  target_key_id = aws_kms_key.dynamodb.key_id
}
