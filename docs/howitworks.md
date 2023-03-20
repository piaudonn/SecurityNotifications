# SEcurity End-user Notification 👀 - How it Works

## Module's framework

Each module is based on the following logic:

<img width="610" alt="image" src="https://user-images.githubusercontent.com/22434561/224199705-acdd3034-fa7c-4ead-80a2-5898e32a05ce.png">

The modules are always composed of 4 sections delimited in [scopes](https://learn.microsoft.com/en-us/azure/logic-apps/logic-apps-control-flow-run-steps-group-scopes).
1.	**Config** is initializing the module, get its timestamp for the query and get its configuration from the Config logic app.
2.	**Query** is where the KQL query is defined and executed.
3.	**Notification** is where the results of the query are parsed, and an email is sent to the final recipients according to the module’s config.
4.	**Exit** is to update the timestamp for the next execution.

The **Config LA** is designed to retrieve the configuration for the caller module. It will get this configuration by reader the configuration files from the storage account. The config is also retrieve the email template for the caller module.

The **Notification LA** sole purpose is to send email. Tracked properties allow statistics gathering if the integration to Log Analytics is enabled.

## List of current modules

You can click on the module's name to explore its documentation.
- The [Multi Factor Authenticatation module](mfa.md) is designed to notify end-users of changes of their MFA methods on ther accounts.    
- The [Temporary Access Pass module](tap.md) is designed to notify end-users of TAP creations and usages on their accounts.    
- The [Password changes module](password.md) is designed to notify end-users of recent password changes and password resets on their accounts.




---
[Documentation Home](readme.md)