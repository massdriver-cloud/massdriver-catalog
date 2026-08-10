# Changelog

## 0.1.0

Initial release.

- HTTP API with a catch-all route proxying to a linked serverless function
- Invoke permission wired from the API to the function
- Per-stage rate and burst throttling
- Structured JSON access logs to an encrypted CloudWatch log group
- Optional CORS configuration for browser callers
- Publishes an `http-api` resource
