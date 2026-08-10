# Changelog

## 0.1.0

Initial release. Derived from the `aws-lambda` template.

- Lambda function loading code from a private, versioned, KMS-encrypted S3 code bucket
- Placeholder function deployed on first provision so the bundle stands up before code exists
- Optional virtual network connection; when linked, the function runs in private subnets
- Optional asset bucket connection with policy selection driven by the bucket's own policies
- Encrypted log group, optional SQS dead-letter queue, optional X-Ray tracing
- Publishes a `serverless-function` resource
