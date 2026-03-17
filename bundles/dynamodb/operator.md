# AWS DynamoDB Table

This bundle provisions an AWS DynamoDB table with configurable partition and sort keys, DynamoDB Streams, and compliance features.

## Features

- **Pay-per-request billing**: Automatically scales based on usage
- **DynamoDB Streams**: Capture item-level changes for event-driven architectures
- **Point-in-time recovery**: Continuous backups for data protection
- **Server-side encryption**: Data encrypted at rest using AWS managed keys
- **Deletion protection**: Optional safeguard against accidental deletion

## Configuration

### Keys

- **Partition Key**: The primary key for the table (required)
  - Supports String (S), Number (N), or Binary (B) types
- **Sort Key**: Optional secondary key for composite primary keys
  - Enables range queries when combined with partition key

### Streams

DynamoDB Streams can be configured to capture different types of information:

- **KEYS_ONLY**: Only the key attributes of modified items
- **NEW_IMAGE**: The entire item after modification
- **OLD_IMAGE**: The entire item before modification
- **NEW_AND_OLD_IMAGES**: Both old and new images of the item

### Compliance

- **Point-in-time recovery**: Enabled by default for data protection
- **Server-side encryption**: Always enabled using AWS managed keys
- **Deletion protection**: Configurable per environment (recommended for production)

## Use Cases

- Application state storage
- Session management
- Real-time event processing with Streams
- Serverless application data layer
- Caching layer with TTL support

## Outputs

The bundle publishes a `dynamodb` artifact containing:

- Table ARN
- Table name
- AWS region
- Stream ARN (for event processing)
- IAM policies (read-only, read-write, admin)
