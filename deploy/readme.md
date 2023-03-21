# SEcurity End-user Notification 👀 - Deployment

## Prerequisites

To deploy the ARM template you will need to be a contributor on the targeted resource group. The deployement will create the following resrouce types:

<img width="11" alt="image" src="https://user-images.githubusercontent.com/22434561/224331040-c33e21ed-dbe7-4399-900b-907d7dc339df.png"> Logic apps   
<img width="11" alt="image" src="https://user-images.githubusercontent.com/22434561/224331104-e95a32cf-34ee-40e7-b7ed-e026bfbbf105.png"> API connections   
<img width="11" alt="image" src="https://user-images.githubusercontent.com/22434561/224331172-5c9c68c0-7ff4-41d9-92a9-d60129808f24.png"> Storage account

All modules are using system managed identities and do not require the creation of generic accounts or any type of other user accounts in your Azure AD tenant.

To use this solution you will also need an existing Log Analytics Workspace with the SigninLogs and AuditLogs data connected from Azure AD.

> More information on setting up SigninLogs and AuditLogs connections can be found [here](https://learn.microsoft.com/azure/active-directory/reports-monitoring/howto-integrate-activity-logs-with-log-analytics)

## Azure Resource Manager Template Deployment

After you have met the pre-requisites, you can deploy the ARM templates to your Azure Subscription using the link below:

[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://aka.ms/seendeploy)

## Setup script

The setup script needs to be executed AFTER you deployed the ARM template. It will be used for the following tasks:
- grant permissions to the system managed identities
- populate the storage account table with starter values for trackers
- import the default email templates into a blob container
- import the configuration file for the solution into a blob container
- prompt the operator for custom values to set in the configuration file

To run the script, you will need the following permissions:
- Azure AD Global Administrator or an Azure AD Privileged Role Administrator to set permission for the managed indei
- Resource Group Owner or User Access Administrator on the resource groups hosting the logic app and the storage account to execute the Set-RBACPermissions function
- Storage Blob Data Contributor on the resource group of your storage account
- Storage Table Data Contributor on the resource group of your storage account
This script also creates temporary files in the temp folder of your machine using the [New-TemporaryFile cmdLet](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.utility/new-temporaryfile).

You can downlaod the script [here](https://raw.githubusercontent.com/piaudonn/SecurityNotifications/main/deploy/setup.ps1).
To run the script you will to provide the following parameters:

- `TenantId` the Azure AD tenant ID of your environment
- `AzureSubscriptionId` the Azure subscriptipn ID of your deployement 
- `StorageAccountName` the name of the starage account you selecetd for the deployement of the soluton
- `StorageAccountResourceGroupName` the name of the resource group where the storage account deployed for the solution is
- `WorkspaceResourceGroupName` the name of the resource group where the log analytic workspace is
- `SEENResourceGroupName` the name of the resource group where the logic apps modules are
- `SupportEmail` the email address of the support team the users can contact
- `SupportPhoneNumber` the phone number of your support
- `MailFrom` the email of the mailbox the notifications are sent from 
- `TestEmail` the email address used when the modules run in test mode (modules run in test mode by default)
- `TimeZone` with the timezone information in the [Kusto timezone supported format](https://learn.microsoft.com/en-us/azure/data-explorer/kusto/query/timezone)

Example:

```
.\setup.ps1 -TenantId "754c4d9d-1191-466d-804f-923361eab7cd `
    -AzureSubscriptionId "122bfa03-e8e0-4b1b-bc58-62b4791082be" ` 
    -StorageAccountName "SeenSA" `
    -StorageAccountResourceGroupName "SEEN-RG" `
    -WorkspaceResourceGroupName "SEEN-RG" `
    -SEENResourceGroupName "SEEN-RG" `
    -SupportEmail = "support@contoso.com" `
    -SupportPhoneNumber = "(555) 123-1234" `
    -MailFrom "security@contoso.com" `
    -TestEmail "test@security.contoso.com" `
    -TimeZone = "Canada/Eastern"
```

## Post deployment operation

After you deployed the templates and ran the script, the solution will be running in **test mode**. It means that the end users will not receive emails yet. All emails will be sent to the TestEmail you specificed in the script input.
For the solution to start sending emails to the end-users, you will need to edit the configuration file to set the `testMode` to `false`.

## Permissions details

Here are the application permissions and RBAC roles required by each logic app:

|Module|API|Permissions|Resource/RBAC|
|---|---|---|---|
|config|-|-|Storage account / `Storage Blob Data Contributor` and `Storage Table Data Contributor`|
|notification|Microsoft Graph API|`Mail.Send`|-|
|testtemplates|-|-|-|
|mfa|Microsoft Graph API|`User.Read.All`|Storage account / `Storage Table Data Contributor` <br /> Log Analytics workspace / `Log Analytics Reader`|
|tap|Microsoft Graph API|`User.Read.All`|Storage account / `Storage Table Data Contributor` <br /> Log Analytics workspace / `Log Analytics Reader`|

## Restrict Mail.Send permission

When an identity is granted the application permission `Mail.Send` on the Microsoft Graph API, it can send emails on behalf any users in the organization. It is recommended to restrict this permission by configuring an [Application Access Policy](https://learn.microsoft.com/en-us/graph/auth-limit-mailbox-access) in Exchange Online. 
