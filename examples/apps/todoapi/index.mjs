import { DynamoDBClient } from "@aws-sdk/client-dynamodb";
import {
  DynamoDBDocumentClient,
  PutCommand,
  GetCommand,
  DeleteCommand,
  ScanCommand,
} from "@aws-sdk/lib-dynamodb";
import { randomUUID } from "crypto";

const client = new DynamoDBClient({});
const ddb = DynamoDBDocumentClient.from(client);
const TABLE_NAME = process.env.DYNAMODB_TABLE;

export const handler = async (event) => {
  const method = event.httpMethod || event.requestContext?.http?.method;
  const path = event.path || event.rawPath || "/";
  const pathParts = path.split("/").filter(Boolean);
  // Expect routes: /todos and /todos/{id}
  const id = pathParts.length > 1 ? pathParts[1] : null;

  try {
    if (pathParts[0] !== "todos") {
      return response(404, { error: "Not found" });
    }

    switch (method) {
      case "GET":
        return id ? getTodo(id) : listTodos();
      case "POST":
        return createTodo(JSON.parse(event.body));
      case "PUT":
        return updateTodo(id, JSON.parse(event.body));
      case "DELETE":
        return deleteTodo(id);
      default:
        return response(405, { error: "Method not allowed" });
    }
  } catch (err) {
    console.error(err);
    return response(500, { error: "Internal server error" });
  }
};

async function listTodos() {
  const result = await ddb.send(new ScanCommand({ TableName: TABLE_NAME }));
  return response(200, result.Items);
}

async function getTodo(id) {
  const result = await ddb.send(
    new GetCommand({ TableName: TABLE_NAME, Key: { pk: id } })
  );
  if (!result.Item) return response(404, { error: "Todo not found" });
  return response(200, result.Item);
}

async function createTodo(body) {
  const item = {
    pk: randomUUID(),
    title: body.title,
    completed: false,
    createdAt: new Date().toISOString(),
  };
  await ddb.send(new PutCommand({ TableName: TABLE_NAME, Item: item }));
  return response(201, item);
}

async function updateTodo(id, body) {
  const existing = await ddb.send(
    new GetCommand({ TableName: TABLE_NAME, Key: { pk: id } })
  );
  if (!existing.Item) return response(404, { error: "Todo not found" });

  const item = {
    ...existing.Item,
    title: body.title ?? existing.Item.title,
    completed: body.completed ?? existing.Item.completed,
    updatedAt: new Date().toISOString(),
  };
  await ddb.send(new PutCommand({ TableName: TABLE_NAME, Item: item }));
  return response(200, item);
}

async function deleteTodo(id) {
  await ddb.send(
    new DeleteCommand({ TableName: TABLE_NAME, Key: { pk: id } })
  );
  return response(204, null);
}

function response(statusCode, body) {
  return {
    statusCode,
    headers: { "Content-Type": "application/json" },
    body: body ? JSON.stringify(body) : "",
  };
}
