## 👀 Security End-user Notification (SEEN) - Deployment

The deployment has 3 steps:

1. Deploy the ARM template in your subscription
2. Run the setup script to set the permissions and trigger the initial configuration
3. Use the provided workbook to customize and enable the modules

Make sure you have met the prerequisites outlined in this page prior deploying the solution. 

## Prerequisites

### Azure AD logs

To use this solution, you need an existing Log Analytics Workspace with the `SigninLogs` and `AuditLogs` data connected from Azure AD.

If that's currently not the case, refer to the following documentation to set it up: [Integrate Azure AD logs with Log Analytics](https://learn.microsoft.com/azure/active-directory/reports-monitoring/howto-integrate-activity-logs-with-log-analytics).

### Deployment permissions

To deploy the ARM template you will need to be a contributor on the targeted resource group. The deployment will create the following resource types:

<img width="11" alt="image" src=https://user-images.githubusercontent.com/22434561/224331040-c33e21ed-dbe7-4399-900b-907d7dc339df.png> Logic apps   
<img width="11" alt="image" src=https://user-images.githubusercontent.com/22434561/224331040-c33e21ed-dbe7-4399-900b-907d7dc339df.png> Azure Monitor workbook   
<img width="11" alt="image" src=https://user-images.githubusercontent.com/22434561/224331104-e95a32cf-34ee-40e7-b7ed-e026bfbbf105.png> API connections   
<img width="11" alt="image" src=https://user-images.githubusercontent.com/22434561/224331172-5c9c68c0-7ff4-41d9-92a9-d60129808f24.png> Storage account

All modules are using system managed identities and do not require the creation of generic accounts or any type of other user accounts in your Azure AD tenant.

### Setup script permissions

The setup script needs to be executed AFTER you deployed the ARM template. It will be used for the following tasks:
- grant permissions to the system managed identities
- populate the storage account table with starter values for trackers
- trigger the config logic to install the templates in your storage account

To run the script, you will need the following permissions:
- Azure AD Global Administrator or an Azure AD Privileged Role Administrator to set permission for the managed identities
- Resource Group Owner or User Access Administrator on the resource groups hosting the logic app and the storage account to set RBAC roles

## Deployment template

You can deploy the ARM templates to your Azure Subscription using the link below:

[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://aka.ms/seendeploy)

## Execute setup.ps1 script

You can download the script [here](https://raw.githubusercontent.com/piaudonn/SecurityNotifications/main/deploy/setup.ps1).
To run the script you will to provide the following parameters:

- `TenantId` the Azure AD tenant ID of your environment
- `AzureSubscriptionId` the Azure subscription ID of your deployment 
- `StorageAccountResourceGroupName` the name of the resource group where the storage account deployed for the solution is
- `WorkspaceResourceGroupName` the name of the resource group where the log analytic workspace is
- `SEENResourceGroupName` the name of the resource group where the logic apps modules are

Example:

```powershell
.\Setup.ps1 `
     -TenantId "120cd98f-1002-45b7-80ff-69fc68bdd027" `
     -AzureSubscriptionId "e893f408-3d86-419f-c1a6-9c91c6872761" `
     -StorageAccountResourceGroupName "default-1" `
     -WorkspaceResourceGroupName "default-1" `
     -SEENResourceGroupName "default-1"
```

For advanced script parameters, refer to the [script documentation](/docs/setupscript.md).

At the end of the script execution, you are given a hyper link to the workbook to customize and enable the solution. Note that you can also access this workbook directly from the Azure portal in the resource group used for the deployment.

## Post deployment

By default, all the modules are disabled. It means that the end users will not receive emails yet. You must use the workbook to customize and enable the modules.

In the **SEEN-Manage and monitor** workbook, make sure you are in the **Configuration** tab and scroll until you see the **SEEN Configuration** section:
- Replace the **Mail From** value with the email address of the account from which you want to send notifications
- Replace the **Test Email** value with the email address to who you want to send the notification when the solution runs in **Test Mode**.
- Leave the modules in **Test Mode**. All emails will be sent to the TestEmail you specified instead of the end-user.

Validate the configuration by clicking the **Save the configuration** button and confirming.

Then in the list of Logic App at the top of the workbook, start the two modules which are disabled by default. Note that it takes few seconds for the modules to start. You can refresh the module until you confirmed the modules are started.

👏 **The solution is now running in test mode.**

Refer to the documentation for detailed explanations of customization options and templates.

Note that you will need to switch the **Test Mode** from **Enabled** to **Disabled** once you are familiar with the solution to start sending notifications to end-users. Refer to the [Disable Test Mode](/docs/faq.md) documentation.

