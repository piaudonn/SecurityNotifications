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

### Permissions details

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