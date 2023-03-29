## Frequently Asked Questions

### Sentinel requirements

The solution does not require Microsoft Sentinel, only to send Azure AD logs (`SigninLogs` and `AuditLog`) to Log Analtics workspace.
The solution is deployed and used the same way whether Microsoft Sentinel is present in the environment or not. There is no interaction.

### Log Analytics workspace retention

The calls to the workspace are usually only looking at the last 15 minutes. However, they capped the query to one day of data. So, as ong as you have **one day** of retention, the detection will work.  

### Restrict Mail.Send permission

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

### Detecting atypical travels

This notification relies on having Azure AD Identity Protection with Azure AD Premium P2 licences. If you enabled this module but do not have this level of license, the module will not trigger an notification.