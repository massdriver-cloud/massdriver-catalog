# Creating Scaleway API Credentials

## Step 1

Log in to your Scaleway account at [console.scaleway.com](https://console.scaleway.com)

&nbsp;

## Step 2

Click on your **Organization** name in the top right, then select **Credentials**

Or navigate directly to: **Identity and Access Management** → **API Keys**

&nbsp;

## Step 3

Click **Generate API Key**

&nbsp;

## Step 4

Configure the API key:
- **Description**: A descriptive name (e.g., "Massdriver Provisioning")
- **Expiration**: Set an expiration date or select "No expiration"
- **Preferred Project**: Select the project to associate with this key

&nbsp;

## Step 5

Click **Generate API Key**

&nbsp;

## Step 6

You will receive:
- **Access Key**: Starts with "SCW" (e.g., SCWXXXXXXXXXXXXXXXXX)
- **Secret Key**: A UUID value

Save the Secret Key immediately as it won't be shown again.

&nbsp;

## Step 7

### Find your Project ID

Navigate to **Project Dashboard** → **Settings** to find your Project ID (UUID format)

&nbsp;

## Step 8

Fill in the form with:
- **Access Key**: Your SCW access key
- **Secret Key**: Your secret key UUID
- **Project ID**: Your project UUID
- **Region** (optional): Default region for resources
- **Zone** (optional): Default availability zone

&nbsp;

## Step 9

Click **Create** and head to the [projects page](/projects) to start building your infrastructure.
