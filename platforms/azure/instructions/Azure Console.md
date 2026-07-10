# Creating an Azure service principal using the Azure portal

## Registering the service principal app in Azure AD

1. Sign into your Azure account through the [Azure portal](https://portal.azure.com/)
2. Search for and select **Microsoft Entra ID**
3. Select **App registration**
4. Select **New registration**

![Massdriver example 1](/img/mdspcreate1.png "Massdriver example 1")

5. Name your application: `massdriver-service-principal`
6. Select **Accounts in this organization directory only**
7. Leave **Redirect URI** blank

![Massdriver example 2](/img/mdspcreate2.png "Massdriver example 2")

8. Click **Register**
9. On the Overview menu, copy the following values and paste them into Massdriver:

- Application (client) ID &rarr; **Client ID**
- Directory (tenant) ID &rarr; **Tenant ID**

![Massdriver example 3](/img/mdspcreate3.png "Massdriver example 3")

10. Select **Certificates & secrets** on the left
11. Select **New client secret**
12. Set the description, set expiration date, and click **Add**

![Massdriver example 4](/img/mdspcreate4.png "Massdriver example 4")

1. Copy the **Value** password and paste into Massdriver under **Client Secret**. <span style="color:red">**Do not use the Secret ID**</span>.

![Massdriver example 5](/img/mdspcreate6.png "Massdriver example 5")

## Assign subscription Owner the service principal

1. In the Azure portal, search for and select **Subscription**
2. Select the subscription you want to use in Massdriver
3. In the Overview menu, copy your **Subscription ID** and paste it into Massdriver under **Subscription ID**
4. Select **Access control (IAM)**
5. Select **Add** > **Add role assignment**
6. Select **Privileged Administrator Roles** tab and then the **Owner** role and click **Next**
7. Select **Select members**, search for `massdriver-service-principal`, click on the service principal, and then click **Select** at the bottom, then **Next**
8. Select **Allow user to assign all roles except privileged administrator roles** and click **Next** then **Review + assign** twice to finish.

## Adding the Azure service principal to your Massdriver organization

1. In Massdriver, click on the menu on the top left and expand **Organization Settings**
2. Click **Configure Credentials**
3. Select **Azure Service Principal**
4. Set the credential name to a friendly name
5. Fill in the fields as guided below:

- Client ID (appId in Azure CLI)
- Client Secret (service principal password)
- Subscription ID
- Tenant ID (tenant in Azure CLI)

Click **Create** and head to the [projects page](/projects) to start building your infrastructure.

## Troubleshooting credential validation

If your credentials failed to validate, be sure to check the following:

- The **Client ID**, **Client Secret**, **Subscription ID**, and **Tenant ID** are correct and do not contain spaces before or after
