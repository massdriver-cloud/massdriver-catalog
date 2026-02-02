# Creating OVH API Credentials

## Step 1

Log in to your OVH account at [ovh.com](https://www.ovh.com)

&nbsp;

## Step 2

Navigate to the API token creation page for your region:
- **EU**: [eu.api.ovh.com/createToken](https://eu.api.ovh.com/createToken)
- **US**: [api.us.ovhcloud.com/createToken](https://api.us.ovhcloud.com/createToken)
- **CA**: [ca.api.ovh.com/createToken](https://ca.api.ovh.com/createToken)

&nbsp;

## Step 3

Fill in the application details:
- **Application name**: A descriptive name (e.g., "Massdriver Provisioning")
- **Application description**: Brief description of the integration

&nbsp;

## Step 4

### Configure API Access Rights

Set the required permissions. For full infrastructure management, add:
- `GET /*`
- `POST /*`
- `PUT /*`
- `DELETE /*`

Or scope to specific services as needed.

&nbsp;

## Step 5

Set the token validity period or leave unlimited

&nbsp;

## Step 6

Click **Create** to generate your credentials

&nbsp;

## Step 7

You will receive three values:
- **Application Key (AK)**
- **Application Secret (AS)**
- **Consumer Key (CK)**

Save these immediately as the Application Secret won't be shown again.

&nbsp;

## Step 8

Fill in the form with:
- **Endpoint**: Select your OVH region
- **Application Key**: Your AK value
- **Application Secret**: Your AS value
- **Consumer Key**: Your CK value

&nbsp;

## Step 9

Click **Create** and head to the [projects page](/projects) to start building your infrastructure.
