# Register an existing ECR repository

Use this form to register an ECR repository that was created outside Massdriver.

1. Open the [ECR console](https://console.aws.amazon.com/ecr/) and select your region.
2. Click the repository you want to register.

## Repository ID

Copy the **ARN** from the repository details (looks like `arn:aws:ecr:us-east-1:123456789012:repository/my-app`).

## Registry URL

The hostname portion of the repository URI — everything before the first `/`:

`123456789012.dkr.ecr.us-east-1.amazonaws.com`

## Repository URL

The full **URI** shown in the repository list:

`123456789012.dkr.ecr.us-east-1.amazonaws.com/my-app`

## Repository Name

The repository **Name** (the part after the `/`), like `my-app`.

## Region

The region code from the console's region picker, like `us-east-1`.
