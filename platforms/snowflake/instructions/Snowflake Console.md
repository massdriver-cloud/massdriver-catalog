# Configuring Snowflake Credentials

## Step 1

Log in to your Snowflake account at [app.snowflake.com](https://app.snowflake.com)

&nbsp;

## Step 2

### Find your Account Identifier

Your account identifier is in the URL when logged in. It follows the format:
- `<orgname>-<account_name>` (new format)
- `<account_locator>.<region>` (legacy format)

You can also find it under **Admin** → **Accounts**

&nbsp;

## Step 3

### Create a User (if needed)

Navigate to **Admin** → **Users & Roles** → **Users**

Click **+ User** to create a new user for Massdriver

&nbsp;

## Step 4

Assign the user a role with appropriate permissions:
- **ACCOUNTADMIN** for full access
- **SYSADMIN** for infrastructure management
- Or create a custom role with specific grants

&nbsp;

## Step 5

Set a password for the user or use key-pair authentication

&nbsp;

## Step 6

Fill in the form with:
- **Account**: Your Snowflake account identifier
- **Username**: The Snowflake username
- **Password**: The user's password
- **Role** (optional): Default role for operations
- **Warehouse** (optional): Default compute warehouse

&nbsp;

## Step 7

Click **Create** and head to the [projects page](/projects) to start building your infrastructure.
