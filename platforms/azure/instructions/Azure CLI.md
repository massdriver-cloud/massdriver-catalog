# Creating an Azure service principal using Azure CLI

## Install Azure CLI

To get started, you'll need the [Azure CLI](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli) installed locally on your machine. The Azure Cloud Shell available in the Azure Portal does **not** have the ability to grant the service principal the required permissions.

1. Paste this script into the command-line to list your subscriptions:

```Bash
az account list --output table
```

2. Copy the value of the `SubscriptionId` and `TenantId` you want to use and paste it into Massdriver under **Subscription ID** and **Tenant ID**, and also store the `SubscriptionId` for the next step.

3. Paste this script in the command-line to create an Azure service principal, and replace `<mySubscriptionID>` with the subscription ID you copied from the last step:

```Bash
az ad sp create-for-rbac --name massdriver-service-principal \
                         --role owner \
                         --scopes /subscriptions/<mySubscriptionID>
```

4. Copy the following attributes and paste them into Massdriver:

- appId &rarr; **Client ID**
- password &rarr; **Client Secret**

Click `Create` and head to the [projects page](/projects) to start building your infrastructure.
