# KMS/IAM Security Model

## Purpose

This document defines the least-privilege IAM and KMS access model for the
serverless URL-shortener application before the corresponding policies are
implemented in Terraform.

## Security Model

| Principal/Component | Needs Permission To | Should NOT Be Able To |
| --- | --- | --- |
| Create-link Lambda | `dynamodb:PutItem` on the URL-shortener DynamoDB table | Read, update, or delete records; access unrelated DynamoDB tables |
| Resolve-link Lambda | `dynamodb:GetItem` on the URL-shortener DynamoDB table | Create, update, or delete records; access unrelated DynamoDB tables |
| Authorized API caller | `execute-api:Invoke` on `POST /links` | Invoke unrelated API routes or receive unnecessary AWS permissions |
| DynamoDB/KMS relationship | Use the customer-managed KMS key as required to encrypt the URL-shortener table | Use unrelated KMS keys |
| Lambda execution roles | Write application logs to their respective CloudWatch log groups | Access unrelated AWS resources |

## Resource Scoping

Application IAM policies will reference specific resource ARNs rather than
using wildcard (`*`) resources wherever the AWS service supports resource-level
permissions.

DynamoDB permissions will be restricted to the URL-shortener table.

API invocation permission will be restricted to the `POST /links` route.

KMS permissions will be restricted to the customer-managed key used by the
URL-shortener DynamoDB table.

## Separation of Responsibilities

The create-link and resolve-link Lambda functions use separate IAM execution
roles so that each function receives only the permissions required for its
specific responsibility.

The create-link Lambda requires write access to DynamoDB but does not require
read access.

The resolve-link Lambda requires read access to DynamoDB but does not require
write access.

The public `GET /{code}` route does not require AWS IAM authentication.

The `POST /links` route requires AWS IAM authentication and a SigV4-signed
request from a principal authorized to perform `execute-api:Invoke`.

## KMS Key Controls

The DynamoDB table uses a customer-managed KMS key for encryption at rest.

Automatic KMS key rotation is enabled.

A KMS alias provides a human-readable identifier for the key.

Access to the KMS key will follow least-privilege principles and will not grant
application principals unrestricted access to unrelated KMS keys.

## Logging

Lambda execution roles receive only the CloudWatch Logs permissions required
for application logging.

API Gateway access logs use structured JSON and exclude request bodies,
authorization headers, destination URLs, and other unnecessary sensitive data.