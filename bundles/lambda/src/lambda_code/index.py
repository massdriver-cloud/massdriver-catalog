import json
import os
import uuid
from datetime import datetime
from typing import Any, Dict, Optional

import boto3
from botocore.exceptions import ClientError

# Initialize DynamoDB client
dynamodb = boto3.resource("dynamodb")
table_name = os.environ["DYNAMODB_TABLE_NAME"]
table = dynamodb.Table(table_name)


def create_response(status_code: int, body: Any) -> Dict[str, Any]:
    """Create a standardized HTTP response."""
    return {
        "statusCode": status_code,
        "headers": {
            "Content-Type": "application/json",
            "Access-Control-Allow-Origin": "*",
            "Access-Control-Allow-Methods": "GET, POST, PUT, DELETE, OPTIONS",
            "Access-Control-Allow-Headers": "Content-Type",
        },
        "body": json.dumps(body),
    }


def list_todos() -> Dict[str, Any]:
    """List all TODO items."""
    try:
        response = table.scan()
        items = response.get("Items", [])
        # Sort by created_at descending
        items.sort(key=lambda x: x.get("created_at", ""), reverse=True)
        return create_response(200, {"todos": items, "count": len(items)})
    except ClientError as e:
        return create_response(500, {"error": str(e)})


def get_todo(todo_id: str) -> Dict[str, Any]:
    """Get a single TODO item by ID."""
    try:
        response = table.get_item(Key={"id": todo_id})
        item = response.get("Item")
        if not item:
            return create_response(404, {"error": "TODO not found"})
        return create_response(200, item)
    except ClientError as e:
        return create_response(500, {"error": str(e)})


def create_todo(body: Dict[str, Any]) -> Dict[str, Any]:
    """Create a new TODO item."""
    try:
        title = body.get("title")
        if not title:
            return create_response(400, {"error": "title is required"})

        todo_id = str(uuid.uuid4())
        now = datetime.utcnow().isoformat() + "Z"

        item = {
            "id": todo_id,
            "title": title,
            "description": body.get("description", ""),
            "completed": False,
            "created_at": now,
            "updated_at": now,
        }

        table.put_item(Item=item)
        return create_response(201, item)
    except ClientError as e:
        return create_response(500, {"error": str(e)})


def update_todo(todo_id: str, body: Dict[str, Any]) -> Dict[str, Any]:
    """Update an existing TODO item."""
    try:
        # Check if item exists
        response = table.get_item(Key={"id": todo_id})
        if "Item" not in response:
            return create_response(404, {"error": "TODO not found"})

        now = datetime.utcnow().isoformat() + "Z"
        update_expr = "SET updated_at = :updated_at"
        expr_values = {":updated_at": now}
        expr_names = {}

        if "title" in body:
            update_expr += ", title = :title"
            expr_values[":title"] = body["title"]

        if "description" in body:
            update_expr += ", description = :description"
            expr_values[":description"] = body["description"]

        if "completed" in body:
            update_expr += ", completed = :completed"
            expr_values[":completed"] = body["completed"]

        response = table.update_item(
            Key={"id": todo_id},
            UpdateExpression=update_expr,
            ExpressionAttributeValues=expr_values,
            ReturnValues="ALL_NEW",
        )

        return create_response(200, response["Attributes"])
    except ClientError as e:
        return create_response(500, {"error": str(e)})


def delete_todo(todo_id: str) -> Dict[str, Any]:
    """Delete a TODO item."""
    try:
        # Check if item exists
        response = table.get_item(Key={"id": todo_id})
        if "Item" not in response:
            return create_response(404, {"error": "TODO not found"})

        table.delete_item(Key={"id": todo_id})
        return create_response(204, {})
    except ClientError as e:
        return create_response(500, {"error": str(e)})


def lambda_handler(event: Dict[str, Any], context: Any) -> Dict[str, Any]:
    """Main Lambda handler for TODO REST API."""
    print(f"Event: {json.dumps(event)}")

    # Handle OPTIONS for CORS
    http_method = event.get("requestContext", {}).get("http", {}).get("method", "")
    if http_method == "OPTIONS":
        return create_response(200, {})

    # Parse path and method
    raw_path = event.get("rawPath", "/")
    path_parts = [p for p in raw_path.split("/") if p]

    try:
        # Route requests
        if http_method == "GET":
            if len(path_parts) == 0 or path_parts[0] == "todos":
                # GET /todos or GET /
                if len(path_parts) == 1 or len(path_parts) == 0:
                    return list_todos()
                # GET /todos/{id}
                elif len(path_parts) == 2:
                    return get_todo(path_parts[1])

        elif http_method == "POST" and (len(path_parts) == 0 or path_parts[0] == "todos"):
            # POST /todos or POST /
            body = json.loads(event.get("body", "{}"))
            return create_todo(body)

        elif http_method == "PUT" and len(path_parts) >= 1:
            # PUT /todos/{id} or PUT /{id}
            todo_id = path_parts[1] if len(path_parts) > 1 else path_parts[0]
            body = json.loads(event.get("body", "{}"))
            return update_todo(todo_id, body)

        elif http_method == "DELETE" and len(path_parts) >= 1:
            # DELETE /todos/{id} or DELETE /{id}
            todo_id = path_parts[1] if len(path_parts) > 1 else path_parts[0]
            return delete_todo(todo_id)

        # Route not found
        return create_response(404, {"error": "Route not found"})

    except json.JSONDecodeError:
        return create_response(400, {"error": "Invalid JSON in request body"})
    except Exception as e:
        print(f"Unexpected error: {str(e)}")
        return create_response(500, {"error": "Internal server error"})
