# Terraform AWS Serverless URL Shortener

A secure, observable, and low-cost serverless URL-shortener API on AWS,
provisioned with Terraform. The project demonstrates modular
infrastructure as code, TypeScript Lambda functions, API Gateway
routing, DynamoDB TTL, customer-managed AWS KMS encryption,
least-privilege IAM, CloudWatch observability, automated testing, and
controlled failure/recovery validation.

## Business Scenario

A client needs a small URL-shortening service that can create temporary
short links and resolve them without managing servers.

- `POST /links` creates a short code for a valid HTTPS URL. Link
  creation is protected with AWS IAM authorization and requires a
  SigV4-signed request.
- `GET /{code}` is public and resolves a valid short code with an HTTP
  `302 Found` redirect.

The design separates creation from resolution: creation is restricted to
authorized callers, while resolution remains simple for end users.

## Architecture

![Serverless URL Shortener
Architecture](docs/url-shortener-architecture-diagram.png)

Request flow:

1.  A client sends a SigV4-signed `POST /links` request to Amazon API
    Gateway.
2.  API Gateway invokes the create-link Lambda.
3.  The function validates the request, generates an eight-character
    hexadecimal code, calculates expiration, and stores the record in
    DynamoDB.
4.  A client sends `GET /{code}` to the public resolve route.
5.  API Gateway invokes the resolve-link Lambda.
6.  The resolver retrieves the DynamoDB item.
7.  A valid, unexpired record returns `302 Found` with the destination
    in the `Location` header.
8.  Invalid, unknown, and expired codes return explicit error responses.

Core services: Amazon API Gateway HTTP API, AWS Lambda (Node.js 22.x),
Amazon DynamoDB, AWS KMS, AWS IAM, Amazon CloudWatch, and Terraform.

## Repository Structure

``` text
.
├── docs/
│   ├── adr/
│   ├── dynamodb-design.md
│   ├── security-model.md
│   ├── url-shortener-architecture-diagram.drawio
│   └── url-shortener-architecture-diagram.png
├── examples/basic/
├── modules/url-shortener/
├── openapi/openapi.yaml
├── src/
│   ├── create-link/
│   └── resolve-link/
├── package.json
├── package-lock.json
└── tsconfig.json
```

Runtime verification screenshots are intentionally kept out of the
public repository.

## API

The contract is documented in
[`openapi/openapi.yaml`](openapi/openapi.yaml).

### POST `/links`

Creates a shortened link. **Authorization:** AWS IAM / SigV4.

``` json
{
  "url": "https://example.com",
  "expires_in_days": 7
}
```

`url` is required, must be a string containing a valid HTTPS URL, and
may not exceed 2,048 characters. `expires_in_days` is optional; when
provided, it must be an integer from 1 through 30.

Successful response:

``` json
{
  "short_code": "32a63c80",
  "expires_at": 1789662690
}
```

The generated code is eight hexadecimal characters. Separate requests
for the same destination URL may produce separate short codes;
destination URLs are not deduplicated.

| Scenario | Status |
| --- | --- |
| Signed, valid request | `201 Created` |
| Unsigned request | `403 Forbidden` |
| Malformed/invalid request | `400 Bad Request` |
| Invalid or non-HTTPS URL | `400 Bad Request` |
| Expiration outside 1–30 days | `400 Bad Request` |

### GET `/{code}`

Resolves a short code. **Authorization:** Public.

| Scenario | Status | Behavior |
| --- | --- | --- |
| Existing, unexpired code | `302 Found` | Redirect via `Location` header |
| Invalid code format | `400 Bad Request` | Descriptive JSON error |
| Validly formatted unknown code | `404 Not Found` | No link exists |
| Expired code | `410 Gone` | Link has expired |

Codes must be exactly eight hexadecimal characters.

## DynamoDB Data Model

Each shortened link is stored as one item. The deployed table uses
`short_code` as its partition key.

| Attribute | Purpose |
| --- | --- |
| `short_code` | Eight-character code and partition key |
| `target_url` | Original HTTPS destination |
| `created_at` | Creation timestamp |
| `expires_at` | Unix expiration timestamp used by application logic and TTL |

The create-link path uses a conditional write so a generated code cannot
overwrite an existing record. Additional rationale is in
[`docs/dynamodb-design.md`](docs/dynamodb-design.md).

### TTL Behavior

DynamoDB TTL is enabled on `expires_at`. Because TTL deletion is
asynchronous, the resolver checks `expires_at` itself rather than
relying on physical deletion: an unexpired record returns `302 Found`,
while an expired record returns `410 Gone`.

## KMS Encryption and Key Management

The table uses server-side encryption with a **customer-managed AWS KMS
key**. Terraform creates the key and alias, configures DynamoDB to use
it, enables automatic rotation, and configures a seven-day deletion
window.

The KMS key policy preserves an administrative recovery path while
limiting application key usage. Application roles may use the key only
through DynamoDB via the `kms:ViaService` condition, preventing
unrestricted direct use of the key by the Lambda roles.

Deployment validation confirmed that the table referenced the intended
customer-managed key, the alias targeted that key, and automatic
rotation was enabled.

## Least-Privilege IAM Design

The functions use separate execution roles.

**Create-link Lambda:** `dynamodb:PutItem` on the URL-shortener table
plus required CloudWatch Logs permissions. It does not need DynamoDB
read, update, or delete access.

**Resolve-link Lambda:** `dynamodb:GetItem` on the URL-shortener table
plus required CloudWatch Logs permissions. It does not need DynamoDB
write or delete access.

`POST /links` uses API Gateway `AWS_IAM` authorization, so unsigned
requests are rejected. `GET /{code}` is intentionally public.

See [`docs/security-model.md`](docs/security-model.md) for the detailed
security model.

## Logging, Alarms, and Cost Controls

API Gateway writes structured access logs to CloudWatch containing
operational metadata such as request ID, request time, HTTP method,
route, status, and response length. The format intentionally excludes
request bodies, authorization headers, and destination URLs.

Lambda functions write execution logs to CloudWatch, and CloudWatch
error alarms make Lambda execution failures observable.

Cost-conscious choices include DynamoDB `PAY_PER_REQUEST`,
invocation-based Lambda, API Gateway HTTP API, DynamoDB TTL cleanup,
seven-day API access-log retention, and no NAT Gateway, EC2 instance,
load balancer, or continuously running application server.

AWS usage can still incur charges, so destroy test resources when they
are no longer needed.

## Testing and Verification

Final quality checks:

``` bash
npm run build
npm test
terraform fmt -check -recursive
terraform validate
terraform test
terraform plan
```

The final healthy plan reported:

``` text
No changes. Your infrastructure matches the configuration.
```

### API Validation

Test Expected Verified

| --- | --- | --- |

Unsigned `POST /links` `403` Yes Signed valid `POST /links` `201` Yes
Valid `GET /{code}` `302` Yes Invalid input `400` Yes Validly formatted
unknown code `404` Yes Expired code `410` Yes

### KMS / DynamoDB Validation

AWS CLI checks verified the DynamoDB encryption configuration, KMS alias
target, and automatic key rotation.

### Controlled IAM Failure and Recovery

A controlled failure test proved that the resolver's DynamoDB permission
boundary was enforced:

1.  Temporarily change the resolver's `dynamodb:GetItem` statement from
    `Allow` to explicit `Deny`.
2.  Run `terraform plan` and confirm only the intended IAM policy
    change.
3.  Apply the temporary configuration.
4.  Execute a known-good `GET /{code}` request and confirm failure.
5.  Inspect resolver Lambda logs and confirm `AccessDeniedException` for
    `dynamodb:GetItem`.
6.  Restore `Allow` through Terraform and reapply.
7.  Confirm the same GET request returns `302 Found`.
8.  Finish with a no-change `terraform plan`.

Verification screenshots remain local and Git-ignored because runtime
evidence can contain deployment-specific AWS identifiers.

## Deployment

### Prerequisites

- Terraform
- Node.js and npm
- AWS CLI
- Configured AWS credentials with sufficient provisioning permissions

Use a development/test AWS account and review every Terraform plan
before applying it.

### Build and Test

``` bash
npm ci
npm run build
npm test
```

### Initialize and Validate

``` bash
cd examples/basic
terraform init
terraform fmt -check -recursive
terraform validate
terraform test
terraform plan
```

### Deploy

``` bash
terraform apply
```

Review the proposed changes before entering `yes`. After deployment, use
the Terraform outputs and appropriately authorized AWS credentials to
test the API.

Never commit AWS credentials, SigV4 authorization headers,
account-specific runtime evidence, Terraform state, plan files, or
sensitive outputs.

## Teardown

``` bash
cd examples/basic
terraform plan -destroy
terraform destroy
```

Review the destroy plan before approval. The customer-managed KMS key
uses a deletion window, so teardown schedules the key for deletion
rather than immediately erasing its key material. After teardown, verify
that the intended project resources are removed or scheduled for
deletion.

## Terragrunt Decision

Terragrunt was evaluated but **not introduced into this
implementation**. The project currently has one reusable Terraform
module and one basic deployment example; adding Terragrunt at this scale
would add another abstraction and dependency without enough repeated
multi-environment configuration to justify it.

The decision is recorded in the [`docs/adr/`](docs/adr/) directory.
Terragrunt can be reconsidered if the project expands to multiple
environments, regions, accounts, or repeated root configurations.

## Security Notes

Do not commit AWS credentials/access keys, SigV4 authorization headers,
Terraform state/backups, sensitive `.tfvars`, saved plan files,
generated deployment archives, or raw verification screenshots
containing deployment-specific information. Local verification evidence
remains Git-ignored.

## Design Documentation

- [DynamoDB design](docs/dynamodb-design.md)
- [KMS/IAM security model](docs/security-model.md)
- [Architecture diagram](docs/url-shortener-architecture-diagram.png)
- [OpenAPI contract](openapi/openapi.yaml)
- [Architecture Decision Records](docs/adr/)

## Project Outcome

The final deployment demonstrated authenticated link creation, public
link resolution, explicit input validation and client-facing error
responses, TTL-aware expiration handling, customer-managed KMS
encryption with automatic rotation, least-privilege IAM separation
between read and write workloads, structured logging and Lambda error
monitoring, automated Terraform/application checks, controlled IAM
failure/recovery validation, and a final drift-free Terraform state.

The infrastructure was restored to its healthy configuration with
Terraform reporting no changes.