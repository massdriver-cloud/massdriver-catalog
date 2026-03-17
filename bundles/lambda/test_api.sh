#!/bin/bash
# Test script for Lambda TODO REST API
# Usage: ./test_api.sh <function-url>

set -e

if [ -z "$1" ]; then
  echo "Usage: $0 <function-url>"
  echo "Example: $0 https://abc123.lambda-url.us-east-1.on.aws"
  exit 1
fi

FUNCTION_URL="$1"

echo "Testing TODO REST API at: $FUNCTION_URL"
echo "========================================="
echo ""

# Test 1: Create a TODO
echo "1. Creating a TODO..."
CREATE_RESPONSE=$(curl -s -X POST "$FUNCTION_URL/todos" \
  -H "Content-Type: application/json" \
  -d '{
    "title": "Test TODO Item",
    "description": "This is a test TODO created by test script"
  }')

echo "Response: $CREATE_RESPONSE"
TODO_ID=$(echo "$CREATE_RESPONSE" | grep -o '"id":"[^"]*"' | cut -d'"' -f4)
echo "Created TODO with ID: $TODO_ID"
echo ""

# Test 2: List all TODOs
echo "2. Listing all TODOs..."
LIST_RESPONSE=$(curl -s "$FUNCTION_URL/todos")
echo "Response: $LIST_RESPONSE"
echo ""

# Test 3: Get specific TODO
echo "3. Getting TODO by ID: $TODO_ID..."
GET_RESPONSE=$(curl -s "$FUNCTION_URL/todos/$TODO_ID")
echo "Response: $GET_RESPONSE"
echo ""

# Test 4: Update TODO
echo "4. Updating TODO (marking as completed)..."
UPDATE_RESPONSE=$(curl -s -X PUT "$FUNCTION_URL/todos/$TODO_ID" \
  -H "Content-Type: application/json" \
  -d '{
    "title": "Test TODO Item (Updated)",
    "completed": true
  }')
echo "Response: $UPDATE_RESPONSE"
echo ""

# Test 5: Delete TODO
echo "5. Deleting TODO..."
DELETE_RESPONSE=$(curl -s -X DELETE "$FUNCTION_URL/todos/$TODO_ID")
echo "Response: $DELETE_RESPONSE"
echo ""

# Test 6: Verify deletion
echo "6. Verifying deletion (should return 404)..."
VERIFY_RESPONSE=$(curl -s "$FUNCTION_URL/todos/$TODO_ID")
echo "Response: $VERIFY_RESPONSE"
echo ""

echo "========================================="
echo "All tests completed!"
