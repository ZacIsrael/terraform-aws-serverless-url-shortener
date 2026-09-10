import type {
  APIGatewayProxyEventV2,
  APIGatewayProxyResultV2,
} from "aws-lambda";

import { DynamoDBClient } from "@aws-sdk/client-dynamodb";
import { DynamoDBDocumentClient, PutCommand } from "@aws-sdk/lib-dynamodb";

export const handler = async (
  event: APIGatewayProxyEventV2
): Promise<APIGatewayProxyResultV2> => {
  // parse POST /links
  // Log the incoming API Gateway event for debugging.
  console.log("event = ", event);

  // Reject requests that do not contain a body.
  if (event.body === undefined) {
    return {
      statusCode: 400,
    };
  }

  // Parse the request body and reject malformed JSON.
  let body;

  try {
    body = JSON.parse(event.body);
  } catch {
    return {
      statusCode: 400,
    };
  }

  // Reject request bodies that are not JSON objects.
  if (body === null || typeof body !== "object" || Array.isArray(body)) {
    return {
      statusCode: 400,
    };
  }

  // Extract the required URL and optional expiration period.
  const { url, expires_in_days } = body;

  // Reject requests that do not include a URL.
  if (url === undefined) {
    return {
      statusCode: 400,
    };
  }

  // Reject URLs that are not strings.
  if (typeof url !== "string") {
    return {
      statusCode: 400,
    };
  }

  // Reject URLs that exceed the maximum supported length.
  if (url.length > 2048) {
    return {
      statusCode: 400,
    };
  }

  // Validate that the supplied value is a valid HTTPS URL.
  try {
    const parsedUrl = new URL(url);

    if (parsedUrl.protocol !== "https:") {
      return {
        statusCode: 400,
      };
    }
  } catch {
    return {
      statusCode: 400,
    };
  }

  // Validate expires_in_days only when the caller provides it.
  if (expires_in_days !== undefined) {
    // Reject values that are not numeric integers.
    if (
      typeof expires_in_days !== "number" ||
      !Number.isInteger(expires_in_days)
    ) {
      return {
        statusCode: 400,
      };
    }

    // Reject expiration periods outside the supported 1–30 day range.
    if (expires_in_days < 1 || expires_in_days > 30) {
      return {
        statusCode: 400,
      };
    }
  }

  // Use the caller-provided expiration period or default to seven days.
  const expiresInDays = expires_in_days ?? 7;

  // Capture the current time in milliseconds for timestamp calculations.
  const now = Date.now();

  // Store the creation time as an ISO 8601 UTC timestamp.
  const created_at = new Date(now).toISOString();

  // Calculate the expiration time and convert it to whole Unix epoch seconds for DynamoDB TTL.
  const expires_at = Math.floor(
    (now + expiresInDays * 24 * 60 * 60 * 1000) / 1000
  );

  // Retrieve the DynamoDB table name supplied by the Lambda environment configuration.
  const dynamodbTableName = process.env.DYNAMODB_TABLE_NAME;

  // Fail if the Lambda was deployed without its required DynamoDB table configuration.
  if (dynamodbTableName === undefined) {
    throw new Error(
      "DYNAMODB_TABLE_NAME environment variable is not configured."
    );
  }
  // write the item to DynamoDB
  // Create the low-level AWS SDK client used to communicate with DynamoDB.
  const dynamodbClient = new DynamoDBClient({});

  // Wrap the base client with the Document Client so normal JavaScript
  // values can be written without manually constructing DynamoDB AttributeValues.
  const dynamodbDocumentClient = DynamoDBDocumentClient.from(dynamodbClient);

  const MAX_COLLISION_RETRIES = 5;

  // Store the successfully generated short code for the API response.
  // Store the short code only after DynamoDB successfully accepts the write.
  let short_code: string | undefined;
  for (let attempt = 0; attempt < MAX_COLLISION_RETRIES; attempt++) {
    // Generate a new 8-character URL-safe code for this write attempt.
    const generatedShortCode = crypto
      .randomUUID()
      .replace(/-/g, "")
      .slice(0, 8);

    // Only create the item if this short code does not already exist.
    const putLinkCommand = new PutCommand({
      TableName: dynamodbTableName,
      Item: {
        short_code: generatedShortCode,
        target_url: url,
        created_at,
        expires_at,
      },

      // Prevent an existing shortened link from being overwritten.
      ConditionExpression: "attribute_not_exists(short_code)",
    });

    try {
      // Attempt to persist the shortened-link record in DynamoDB.
      await dynamodbDocumentClient.send(putLinkCommand);

      // Save the successfully persisted code for the API response.
      short_code = generatedShortCode;

      // Stop retrying as soon as a unique short code is successfully stored.
      break;
    } catch (error) {
      // Retry only when DynamoDB reports that the generated short code already exists.
      if (
        error instanceof Error &&
        error.name === "ConditionalCheckFailedException"
      ) {
        if (attempt === MAX_COLLISION_RETRIES - 1) {
          throw error;
        }

        continue;
      }

      // Re-throw unexpected DynamoDB or AWS SDK errors.
      throw error;
    }
  }

  // Guard against reaching the response without a successfully stored short code.
  if (short_code === undefined) {
    throw new Error("Failed to generate and store a unique short code.");
  }

  // Return the newly created short code and its expiration timestamp to the caller.
  return {
    statusCode: 201,
    headers: {
      "content-type": "application/json",
    },
    body: JSON.stringify({
      short_code,
      expires_at,
    }),
  };
};
