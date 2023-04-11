## Setup script

### PowerShell requirements

The script requires the following PowerShell modules:
- `Microsoft.Graph.Applications` used to lookup managed identity application IDs and to set API permissions
- `Az.Resources` used to set RBAC roles on resources 
- `Az.LogicApp` used to trigger the config logic app that will then download the config file and template files to the storage account 

The script contains emojies which requires a file encoding with [BOM](https://learn.microsoft.com/en-us/powershell/scripting/dev-cross-plat/vscode/understanding-file-encoding?view=powershell-7.3).

### Permission requirements

You need the following permissions to run the script:

- Azure AD **Global Administrator** or an **Azure AD Privileged Role Administrator** to execute the Set-APIPermissions function
- **Resource Group Owner** or **User Access Administrator** on the resource groups hosting the logic app and the storage account to execute the Set-RBACPermissions function

### Input parameters

|Parameter|Required|Default value|Definition|
|---|---|---|---|
|`TenantId`|`true`||The Azure AD tenant ID|
|`AzureSubscriptionId`|`true`||The ID of the subscription where SEEN is deployed|
|`SEENResourceGroupName`|`true`||The **resource group** where you deployed SEEN|
|`StorageAccountResourceGroupName`|`false`|The value you provided for `SEENResourceGroupName`|The **resource group** where the storage account for SEEN is located|
|`WorkspaceResourceGroupName`|`true`||The **resource group** where your log analytic workspace with the SigninLogs and AuditLogs tables are|
|`ConfigLogicAppName`|`false`|SEEN-Config|The name of the config logic app|
|`SendEmailLogicAppName`|`false`|SEEN-SendEmail|The name of the send email logic app|
|`MFAMethodsLogicAppName`|`false`|SEEN-MFAMethods|The name of the MFA module logic app|
|`TAPLogicAppName`|`false`|SEEN-TAPLogicAppName|The name of the TAP module logic app|
|`TravelLogicAppName`|`false`|SEEN-TravelLogicAppName|The name of the travel module logic app|

### Error management

There is some error management in the script, but it is minimal. The output of the script should be self-explanatory if there is something to fix before re-running it. If that's not obvious, please open an [issue](https://github.com/piaudonn/SecurityNotifications/issues/new/choose). 

### API permissions and RBAC details

The setup.ps1 script configures the permissions for the managed identities. Here are the application permissions and RBAC roles required by each logic apps' managed identities.

|Module|API|Permissions|Resource/RBAC|
|---|---|---|---|
|config|-|-|Storage account / `Storage Blob Data Contributor` and `Storage Table Data Contributor`|
|sendemail|Microsoft Graph API|`Mail.Send`|-|
|mfa|Microsoft Graph API|`User.Read.All`|Storage account / `Storage Table Data Contributor` <br /> Log Analytics workspace / `Log Analytics Reader`|
|tap|Microsoft Graph API|`User.Read.All`|Storage account / `Storage Table Data Contributor` <br /> Log Analytics workspace / `Log Analytics Reader`|
|travel|Microsoft Graph API|`User.Read.All`|Storage account / `Storage Table Data Contributor` <br /> Log Analytics workspace / `Log Analytics Reader`|

### Final step

The final step of the script is run the config logica add (with `Start-AzLogicApp`). Whent the config logic app is called from the setup script, it uses a specific path that will do the following:
- Initialize the trackers on the storage account tables with the installation time timestamp 
- Copy the configuration file to the blob storage account container
- Copy the templates from the repository to the blob storage account container 

⚠️ If that steps fails, the solution cannot be used. 