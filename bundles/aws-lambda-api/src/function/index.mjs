// A tiny TODO API — demo code meant to be replaced with your own application.
//
// Routes:
//   GET    /todos        list all todos
//   POST   /todos        create a todo: {"text": "buy milk"}
//   DELETE /todos/{id}   delete a todo
//
// The AWS SDK v3 ships inside the nodejs20.x runtime, so there's no
// package.json and no npm install step — this one file is the whole app.

import { DynamoDBClient } from "@aws-sdk/client-dynamodb";
import {
  DynamoDBDocumentClient,
  ScanCommand,
  PutCommand,
  DeleteCommand,
} from "@aws-sdk/lib-dynamodb";
import { randomUUID } from "node:crypto";

const TABLE_NAME = process.env.TABLE_NAME;
const db = DynamoDBDocumentClient.from(new DynamoDBClient({}));

const json = (statusCode, body) => ({
  statusCode,
  headers: { "Content-Type": "application/json" },
  body: JSON.stringify(body),
});

async function listTodos() {
  const { Items } = await db.send(new ScanCommand({ TableName: TABLE_NAME }));
  return json(200, { todos: Items ?? [] });
}

async function createTodo(event) {
  let text;
  try {
    ({ text } = JSON.parse(event.body ?? "{}"));
  } catch {
    return json(400, { error: "Request body must be JSON." });
  }
  if (!text || typeof text !== "string") {
    return json(400, { error: 'Provide a todo as {"text": "..."}.' });
  }

  const todo = {
    id: randomUUID(),
    text,
    created_at: new Date().toISOString(),
  };
  await db.send(new PutCommand({ TableName: TABLE_NAME, Item: todo }));
  return json(201, todo);
}

async function deleteTodo(id) {
  await db.send(new DeleteCommand({ TableName: TABLE_NAME, Key: { id } }));
  return json(200, { deleted: id });
}

export const handler = async (event) => {
  const method = event.requestContext?.http?.method;
  const path = event.rawPath ?? "/";

  if (method === "GET" && path === "/todos") return listTodos();
  if (method === "POST" && path === "/todos") return createTodo(event);

  const idMatch = path.match(/^\/todos\/([^/]+)$/);
  if (method === "DELETE" && idMatch) {
    return deleteTodo(decodeURIComponent(idMatch[1]));
  }

  return json(404, { error: `No route for ${method} ${path}` });
};
