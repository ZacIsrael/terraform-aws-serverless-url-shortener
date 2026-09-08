# DynamoDB Design

## Item Structure

Each shortened link is stored as a single DynamoDB item with the following attributes:

- `short_code` — Short code used to identify the link.
- `target_url` — Original HTTPS URL to which the client is redirected.
- `expires_at` — Expiration timestamp used by application logic and DynamoDB TTL.
- `created_at` — Timestamp indicating when the shortened link was created.

## Primary Key

- Partition key: `code`

The `code` attribute is used as the partition key because `GET /{code}` provides the exact value needed to retrieve the item.

## TTL Strategy

- TTL attribute: `expires_at`

The `expires_at` attribute determines when the item is considered expired and eligible for DynamoDB TTL deletion.

The application must still check `expires_at` because DynamoDB TTL deletion is asynchronous. An expired item may remain in the table temporarily and should return `410 Gone`.

## Access Patterns

### Create Link

`POST /links`

- Generate a unique short code.
- Store the shortened-link item using a conditional write.
- Do not overwrite an existing item if the generated code already exists.

### Resolve Link

`GET /{code}`

- Retrieve the item directly using `short_code`.
- Return `302 Found` if the link exists and has not expired.
- Return `404 Not Found` if the code does not exist.
- Return `410 Gone` if the link has expired.