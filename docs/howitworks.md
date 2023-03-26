## How it Works

### Module's framework

The modules are the logic apps which run on a time trigger (every 15 minutes) and are looking for specific events and activities to notify the users on.

Each module is based on the following logic:

<img width="610" alt="image" src="https://user-images.githubusercontent.com/22434561/224199705-acdd3034-fa7c-4ead-80a2-5898e32a05ce.png">

The modules are always composed of 4 sections delimited in [scopes](https://learn.microsoft.com/en-us/azure/logic-apps/logic-apps-control-flow-run-steps-group-scopes).
1.	**Config** is initializing the module, get its timestamp for the query and get its configuration from the Config logic app.
2.	**Query** is where the KQL query is defined and executed.
3.	**Notification** is where the results of the query are parsed, and an email is sent to the final recipients according to the module’s config.
4.	**Exit** is to update the timestamp for the next execution.

The **Config LA** is designed to retrieve the configuration for the caller module. It will get this configuration by reader the configuration files from the storage account. The config is also retrieve the email template for the caller module.

The **Notification LA** sole purpose is to send email. Tracked properties allow statistics gathering if the integration to Log Analytics is enabled.

### List of current modules

You can click on the module's name to explore its documentation.
- The [Multi Factor Authenticatation module](mfa.md) is designed to notify end-users of changes of their MFA methods on ther accounts.    
- The [Temporary Access Pass module](tap.md) is designed to notify end-users of TAP creations and usages on their accounts.    
- The [Atypical travel module](travel.md) is designed to notify end-users of signins of their accounts from unusual locations.

Modules are using trackers stored in storage account tables. Trackers are timestamps which allow the modules to know from what starting time they need to start their lookup when they run. That way, there are no blind spots between modules executions. The setup script is initializing the trackers with the timestamp of the installation's time of the solution.  

### Permission managements

Each module has the following permissions:

- Read and modify their trackers in the storage tables, the setup script is giving these permissions to the module's managed identity by giving the RBAC role **Storage Table Data Contributor** on the resource group where the storage account is.
- Read the log analytics workspace where the data is, the setup script is giving these permissions to the module's managed identity by giving the RBAC role **Log Analytics Reader** on the resource group where the log analytics workspace is.

The other logic apps also need access to some aspect of the solution:
- The config logic app needs to be able to initialize the trackers and is given **Storage Table Data Contributor** on the resource group where the storage account by the setup script. It also needs to install and udpate the templates and the configuration file itself, and it is given **Storage Blob Data Contributor** on the resource group where the storage account by the setup script.

## Solution management

Once the solution is installed, the entire management is done through the SEEN workbook.


---
[Documentation Home](readme.md)