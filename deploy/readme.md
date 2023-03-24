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
- trigger the config logic to install the templates in your storage account

To run the script, you will need the following permissions:
- Azure AD Global Administrator or an Azure AD Privileged Role Administrator to set permission for the managed indei
- Resource Group Owner or User Access Administrator on the resource groups hosting the logic app and the storage account to execute the Set-RBACPermissions function

You can downlaod the script [here](https://raw.githubusercontent.com/piaudonn/SecurityNotifications/main/deploy/setup.ps1).
To run the script you will to provide the following parameters:

- `TenantId` the Azure AD tenant ID of your environment
- `AzureSubscriptionId` the Azure subscriptipn ID of your deployement 
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

## Post deployment operation

After you deployed the templates and ran the script, the solution will be running in **test mode**. It means that the end users will not receive emails yet. All emails will be sent to the TestEmail you specificed in the script input.
For the solution to start sending emails to the end-users, you will to edit the configuration from the workbook. A link to the workbook should be in the output of the setup script. 

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

When an identity is granted the application permission `Mail.Send` on the Microsoft Graph API, it can send emails on behalf any users in the organization. It is recommended to restrict this permission by configuring an [Application Access Policy](https://learn.microsoft.com/en-us/graph/auth-limit-mailbox-access) in Exchange Online. To restrict the managed identity permission to send emails only from the account you want, follow these steps:

1. Create a mail-enabled security group (i.e. Seen-Notifications@contoso.com).
2. Add the user from which you want to send email from (the mailFrom from the configuration) into the group (i.e. security@contoso.com).
3. Create an access policy to allow the managed identity to send email only on behalf the member of the group. You can find the application ID of the SEEN-SendEmail managed identity in the Azure AD portal (go to the Enterprise application blade, select Managed Identities in the application type filter and look for your SEEN-SendEmail application, take note of the Application ID - not the Object ID).

Example:

```powershell
#Install-Module ExchangeOnlineManagement
Connect-ExchangeOnline -UserPrincipalName admin@contoso.com

New-DistributionGroup -Name "SEEN Notifications" -Alias "Seen-Notifications" -Type security
Add-DistributionGroupMember -Identity "Seen-Notifications@contoso.com" -Member "security@contoso.com"

New-ApplicationAccessPolicy `
    -AppId 4f0c7083-49f1-43fc-bae4-8f3dd788fefa `
    -PolicyScopeGroupId Seen-Notifications@contoso.com `
    -AccessRight RestrictAccess `
    -Description "Restrict SEEN managed identity"
```
