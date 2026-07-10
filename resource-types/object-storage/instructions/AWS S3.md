# Register an existing S3 bucket

Use this form to register an S3 bucket that was created outside Massdriver so applications can request access to it.

1. Open the [S3 console](https://console.aws.amazon.com/s3/).
2. Click the bucket you want to register.

## Bucket ID

The bucket's ARN — the **Properties** tab shows it, or build it yourself: `arn:aws:s3:::YOUR_BUCKET_NAME`.

## Bucket Name

The bucket name exactly as shown in the console.

## Region

The **AWS Region** from the **Properties** tab, like `us-east-1`.

## Access Policies

List the IAM policies applications can request. Each entry's **Policy ID** should be the ARN of an IAM policy granting that access level to this bucket, for example:

| Policy ID | Policy Name |
|-----------|-------------|
| `arn:aws:iam::123456789012:policy/my-bucket-read` | Read |
| `arn:aws:iam::123456789012:policy/my-bucket-read-write` | Read/Write |

Application bundles attach the selected policy to their workload's IAM role at deploy time.
