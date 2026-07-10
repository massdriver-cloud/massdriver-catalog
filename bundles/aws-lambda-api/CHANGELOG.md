# Changelog

All notable changes to the `aws-lambda-api` bundle are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this bundle follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] — 2026-07-10

### Added
- Real OpenTofu Lambda API: function (`nodejs20.x`), public function URL, DynamoDB table, IAM role, log group.
- Working TODO API handler in `src/function/index.mjs` (GET/POST/DELETE `/todos`), zipped at plan time — meant to be replaced with your own app.
- DynamoDB table scoped to the bundle's lifecycle (pay-per-request, dies with the instance).
- IAM policy scoped to exactly the bundle's table (Get/Put/Delete/Scan) plus `AWSLambdaBasicExecutionRole`.
- Explicit log group with `log_retention_days` so retention applies from the first invoke.
- `params.examples`: Development / Production presets; `$md.immutable` on `region`; memory options with cost guidance in the labels.
- `Errors` and `Throttles` alarms (`AWS/Lambda`, Sum > 1 per 5 minutes) on the instance health panel.
- Emits an `application` resource: function ARN, function URL, `/todos` health path.
