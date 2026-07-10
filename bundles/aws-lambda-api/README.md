# AWS Lambda API

An AWS Lambda function with a public function URL and its own DynamoDB table. It deploys a small, working TODO API out of the box so you have something to curl the moment the first deploy finishes — then you replace the handler with your own application. This is the serverless answer to "how do I run my own compute as a bundle?"

## What it shows

- **Your own code, published as a bundle** — the handler lives in `src/function/`, gets zipped at plan time, and ships with the bundle. No container registry, no build pipeline: edit the file, publish, deploy.
- **Self-service experience** — Development / Production presets, an immutable `region`, memory options with cost guidance in the labels, and a timeout field that warns you when your ambitions outgrow a synchronous API.
- **Operator guide** (`operator.md`) — a 2am runbook templated with the live function's URL and ARN.
- **Compliance** — an IAM role scoped to exactly one DynamoDB table, log retention enforced from the first invoke, and `Errors` / `Throttles` alarms on the instance health panel. The deliberately public function URL is documented as a skipped Checkov check, not hidden.
- **IaC code** (`src/`) — real, minimal OpenTofu: function, function URL, DynamoDB table, IAM, log group.

## Try it

The instance's **API** resource shows the live URL. Substitute it below:

```bash
API="{{artifacts.app.url}}"   # copy the real URL from the API resource

# List todos (also the health check path)
curl "$API/todos"

# Create one
curl -X POST "$API/todos" -d '{"text": "replace this handler with my app"}'

# Delete it (use the id from the create response)
curl -X DELETE "$API/todos/<id>"
```

## Replace the handler

The TODO API is placeholder cargo. To ship your own app:

1. Edit `src/function/index.mjs` (or replace it — the Lambda entrypoint is `index.handler`).
2. Keep it dependency-free, or vendor dependencies into `src/function/` — everything in that directory is zipped and deployed. The AWS SDK v3 is already in the `nodejs20.x` runtime.
3. If your app doesn't need the DynamoDB table, delete `aws_dynamodb_table` and the table IAM policy from `src/main.tf`.
4. Publish and deploy. The function URL and alarms carry over unchanged.

## What it produces

An `application` resource: the function ARN as `id`, the function URL as `url`, and `/todos` as the health check path.

## Costs to know about

Everything here is pay-per-request: Lambda bills per invocation and GB-second, DynamoDB per read/write, and both have generous free tiers. At demo scale this bundle is effectively free; there is nothing that bills while idle.

See the [catalog README](../../README.md) and [Bundle YAML Spec](https://docs.massdriver.cloud/guides/bundle-yaml-spec) for more.
