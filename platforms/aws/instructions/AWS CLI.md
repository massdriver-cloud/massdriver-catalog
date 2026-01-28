# Importing your AWS role for Massdriver to assume

## How Massdriver uses your role

To keep your environment secure, Massdriver uses a role with a trust policy to access your AWS account for provisioning and monitoring of your infrastructure. The account that assumes this role is private and has no access from the public internet.

## Create a role with a trust policy

Run the following command with the [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html) to create a role with a trust policy that allows Massdriver to assume the role:

```bash
aws iam create-role --role-name={{ROLE_NAME}} --description="Massdriver Cloud Provisioning Role" --assume-role-policy-document='{"Version":"2012-10-17","Statement":[{"Sid":"MassdriverCloudProvisioner","Effect":"Allow","Principal":{"AWS":["308878630280"]},"Action":"sts:AssumeRole","Condition":{"StringEquals":{ "sts:ExternalId":"{{EXTERNAL_ID}}"}}}]}'
```

## Assign the role administrator privileges

Run this command to give Massdriver administrator privileges:

```bash
aws iam attach-role-policy --role-name={{ROLE_NAME}} --policy-arn arn:aws:iam::aws:policy/AdministratorAccess
```

## Import role to Massdriver

Fill in the AWS ARN as `arn:aws:iam::YOUR_AWS_ACCOUNT_ID:role/{{ROLE_NAME}}`. Click `Create` and head to the [projects page](/projects) to start building your infrastructure.
