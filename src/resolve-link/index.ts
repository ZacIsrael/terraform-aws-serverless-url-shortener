import type {
  APIGatewayProxyEventV2,
  APIGatewayProxyResultV2,
} from "aws-lambda";

import { DynamoDBClient } from "@aws-sdk/client-dynamodb";
import { DynamoDBDocumentClient, GetCommand } from "@aws-sdk/lib-dynamodb";

export const handler = async (
  event: APIGatewayProxyEventV2
): Promise<APIGatewayProxyResultV2> => {
  // Log the incoming API Gateway event for debugging.
  console.log("event = ", event);

  // Read the requested short code from the API Gateway path parameters.
  const requestedCode = event.pathParameters?.code;

  // Reject requests that do not include the required code path parameter.
  if (requestedCode === undefined) {
    return {
      statusCode: 400,
    };
  }

  // Reject codes that are not exactly eight hexadecimal characters.
  if (!/^[a-f0-9]{8}$/i.test(requestedCode)) {
    return {
      statusCode: 400,
    };
  }

  // Read the DynamoDB table name provided through the Lambda environment.
  const dynamodbTableName = process.env.DYNAMODB_TABLE_NAME;

  // Fail if the Lambda was deployed without its required table configuration.
  if (dynamodbTableName === undefined) {
    throw new Error(
      "DYNAMODB_TABLE_NAME environment variable is not configured."
    );
  }

  // Create the low-level AWS SDK client used to communicate with DynamoDB.
  const dynamodbClient = new DynamoDBClient({});

  // Wrap the base client so DynamoDB items use normal JavaScript values.
  const dynamodbDocumentClient = DynamoDBDocumentClient.from(dynamodbClient);

  // Create the command used to retrieve the link record by short code.
  const getLinkCommand = new GetCommand({
    TableName: dynamodbTableName,
    Key: {
      short_code: requestedCode,
    },
  });

  let getLinkResponse;

  try {
    // Retrieve the matching link record from DynamoDB.
    getLinkResponse = await dynamodbDocumentClient.send(getLinkCommand);
  } catch (error) {
    // Re-throw unexpected DynamoDB or AWS SDK errors.
    throw error;
  }

  // Extract the stored link record from the DynamoDB response.
  const linkRecord = getLinkResponse.Item;

  // Return Not Found when no link exists for the requested short code.
  if (linkRecord === undefined) {
    return {
      statusCode: 404,
    };
  }

  // Return Gone when the link has passed its expiration timestamp.
  if (linkRecord.expires_at <= Math.floor(Date.now() / 1000)) {
    return {
      statusCode: 410,
    };
  }

  // Redirect the caller to the original destination URL.
  return {
    statusCode: 302,
    headers: {
      Location: linkRecord.target_url,
    },
  };
};
