# Changelog

## 0.2.0

Routing moved out of this bundle and into the functions behind it.

- Removed the `function` dependency; the gateway now deploys on its own
- Removed the integration, route, and invoke permission — each function creates
  its own against the `http-api` resource this bundle publishes
- One gateway can now serve many functions, each owning a distinct route
- Removing a function no longer forces the gateway, and its URL, to be replaced

## 0.1.0

Initial release.

- HTTP API with a catch-all route proxying to a linked serverless function
- Invoke permission wired from the API to the function
- Per-stage rate and burst throttling
- Structured JSON access logs to an encrypted CloudWatch log group
- Optional CORS configuration for browser callers
- Publishes an `http-api` resource
