
# Importing your GCP service account for Massdriver to assume

## Step 1

### Log in to the Google Cloud Console and navigate to the IAM/Service Accounts page

![select-iam](/iam.png)

&nbsp;

## Step 2

### Click Create service account

![select-iam](/create-service-account.png)

&nbsp;

## Step 3

 Give your service account a name, ID, and description.

&nbsp;

## Step 4

### Click "Create and continue"

![sa-details](/sa-details.png)

&nbsp;

## Step 5

Give your new service account owner permissions so Massdriver can manage your infrastructure.

&nbsp;

## Step 6

### Click continue

![grant-role](/grant-role.png)

&nbsp;

## Step 7

### Leave the grant users section blank. Click done

![grant-user](/grant-user.png)

&nbsp;

## Step 8

### Back on the service account page click the ID of the newly created service account

![details-select](/details-select.png)

&nbsp;

## Step 9

Click the keys tab

&nbsp;

## Step 10

### Using the add key dropdown, select Create new key

![keys-page](/keys-page.png)

&nbsp;

## Step 11

### Select JSON and click Create

![export-key](/export-key.png)

&nbsp;

## Step 12

In the form to the left, give your role a name and drag the JSON file created in the previous step into the dropzone.

&nbsp;

## Step 13

Click **Create** and head to the [projects page](/projects) to start building your infrastructure.
