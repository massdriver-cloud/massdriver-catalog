# aws-lambda-todo-api

AWS Lambda TODO REST API with API Gateway HTTP endpoint and DynamoDB backend.

## Overview

Deploys a Node.js Lambda function from an S3 zip package, exposed publicly via API Gateway HTTP API (v2). Uses a pre-existing DynamoDB table for storage via the Massdriver connection system.

## Connections

| Name | Type | Required | Description |
|------|------|----------|-------------|
| `aws_authentication` | `aws-catalog/aws-iam-role` | Yes | AWS IAM role for Massdriver to assume |
| `dynamodb_table` | `aws-catalog/dynamodb` | Yes | DynamoDB table for todo storage |

## Artifacts Produced

| Name | Type | Description |
|------|------|-------------|
| `api` | `aws-catalog/application` | API Gateway invoke URL and metadata |

## Deployment Package

The example app is at `examples/apps/todoapi/`. To package it:

```bash
cd examples/apps/todoapi
npm install
zip -r todoapi.zip index.mjs node_modules package.json
aws s3 cp todoapi.zip s3://<your-bucket>/todoapi/todoapi.zip
```

Then set `s3_bucket` and `s3_key` in the bundle parameters.
