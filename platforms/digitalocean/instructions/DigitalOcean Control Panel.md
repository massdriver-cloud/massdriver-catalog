# Creating a DigitalOcean API Token

## Step 1

Log in to your DigitalOcean account at [cloud.digitalocean.com](https://cloud.digitalocean.com)

&nbsp;

## Step 2

Navigate to **API** in the left sidebar or go directly to [cloud.digitalocean.com/account/api/tokens](https://cloud.digitalocean.com/account/api/tokens)

&nbsp;

## Step 3

Click **Generate New Token**

&nbsp;

## Step 4

Configure the token:
- **Token name**: A descriptive name (e.g., "Massdriver Provisioning")
- **Expiration**: Select an expiration period or "No expiry"
- **Scopes**: Select **Full Access** (both Read and Write)

&nbsp;

## Step 5

Click **Generate Token**

&nbsp;

## Step 6

Copy the generated token immediately. It starts with `dop_v1_` and won't be shown again.

&nbsp;

## Step 7

### Optional: Spaces Credentials

If you need to manage DigitalOcean Spaces (object storage):

1. Navigate to **Spaces** → **Manage Keys**
2. Click **Generate New Key**
3. Copy both the Access Key ID and Secret Key

&nbsp;

## Step 8

Fill in the form with:
- **API Token**: Your personal access token
- **Spaces Access Key ID** (optional): For Spaces management
- **Spaces Secret Key** (optional): For Spaces management

&nbsp;

## Step 9

Click **Create** and head to the [projects page](/projects) to start building your infrastructure.
