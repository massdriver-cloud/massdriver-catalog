# Importing your GCP service account for Massdriver to assume

&nbsp;

## Step 1

Paste the following command in a terminal to create a service account for Massdriver to use.

&nbsp;

## Step 2

Replace the following values:

* SERVICE_ACCOUNT_ID: The ID for the service account.
* DESCRIPTION: Optional. A description of the service account.
* DISPLAY_NAME: A service account name to display in the Cloud Console.

```bash
$ gcloud iam service-accounts create SERVICE_ACCOUNT_ID \
    --description="DESCRIPTION" \
    --display-name="DISPLAY_NAME"
```

&nbsp;

## Step 3

Massdriver needs the owner role in order to manage infrastructure and projects. Paste the following command in a terminal to assign the owner role to the massdriver service account

&nbsp;

## Step 4

Replace the following values:

* PROJECT_ID: The project id.
* SERVICE_ACCOUNT_ID: The service account ID.

```bash
gcloud projects add-iam-policy-binding PROJECT_ID \
    --member="serviceAccount:SERVICE_ACCOUNT_ID@PROJECT_ID.iam.gserviceaccount.com" \
    --role="roles/owner"
```

&nbsp;

## Step 5

Massdriver needs a service account key to access the GCP api. To create one paste the following command into a terminal

&nbsp;

## Step 6

Replace the following values:

* `key-file`: The path to a new output file for the private key—for example, `~/sa-private-key.json`.
* `sa-name`: The name of the service account to create a key for.
* `project-id`: Your Google Cloud project ID.

```bash
gcloud iam service-accounts keys create key-file \
    --iam-account=sa-name@project-id.iam.gserviceaccount.com
```

&nbsp;

## Step 7

In the form on the left give your service account a friendly name for Massdriver.

&nbsp;

## Step 8

Drag the `.json` file created in the above command in to the drag n' drop target on the form.

&nbsp;

## Step 9

Click **Create** and head to the [projects page](/projects) to start building your infrastructure.
