## Permissions details

Here are the application permissions and RBAC roles required by each logic app:

|Module|API|Permissions|Resource/RBAC|
|---|---|---|---|
|config|-|-|Storage account / `Storage Blob Data Contributor` and `Storage Table Data Contributor`|
|notification|Microsoft Graph API|`Mail.Send`|-|
|testtemplates|-|-|-|
|mfa|Microsoft Graph API|`User.Read.All`|Storage account / `Storage Table Data Contributor` <br /> Log Analytics workspace / `Log Analytics Reader`|
|tap|Microsoft Graph API|`User.Read.All`|Storage account / `Storage Table Data Contributor` <br /> Log Analytics workspace / `Log Analytics Reader`|