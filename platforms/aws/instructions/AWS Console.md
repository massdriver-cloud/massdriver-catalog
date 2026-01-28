# Importing your AWS role for Massdriver to assume

## How Massdriver uses your role

To keep your environment secure, Massdriver uses a role with a trust policy to access your AWS account for provisioning and monitoring of your infrastructure. The account that assumes this role is private and has no access from the public internet.

## Step 1

### Go to the IAM management console and select Create Role

![roles](/select-roles.PNG)

&nbsp;

## Step 2

### Select Another AWS account for the role type

![roles](/another-account.PNG)

&nbsp;

## Step 3

For the account ID enter `308878630280`. This is the Massdriver account which contains the role that will use the one you are creating now

&nbsp;

## Step 4

Check the Require external ID box and enter `{{EXTERNAL_ID}}`.

&nbsp;

## Step 5

### Make sure that the Require MFA option is unchecked

![roles](/settings.PNG)

&nbsp;

## Step 6

Click "Next: Permissions"

&nbsp;

## Step 7

### Select the `AdministratorAccess` policy

![roles](/policy.PNG)

&nbsp;

## Step 8

Select "Next: Tags"

&nbsp;

## Step 9

### Add a tag with the key `massdriver`

![roles](/tags.PNG)

&nbsp;

## Step 10

### Add a name and a description to the role. Save the role name for entry in to the form to the left

![roles](/review.PNG)

&nbsp;

## Step 11

In Massdriver, add a friendly name for the role in the form to the left

&nbsp;

## Step 12

Paste the AWS arn for the role in the appropriate field with the format:

```
arn:aws:iam::YOUR_AWS_ACCOUNT_ID:role/ROLE_NAME
```

&nbsp;

## Step 13

If you haven't already paste your external ID in to the appropriate field

&nbsp;

## Step 14

Click **Create** and head to the [projects page](/projects) to start building your infrastructure.
