## 👀 Security End-user Notification (SEEN) 

### ❓ What is **SEEN**?

**SEEN** allows you to send automatic email notifications to end-users when specific security events are detected on their Azure AD accounts. Events such as:
- a Multi Factor Authentication method was added, updated or removed
- a Temporary Access Pass ([TAP](https://learn.microsoft.com/en-us/azure/active-directory/authentication/howto-authentication-temporary-access-pass)) was created or used
- a atypical tracel was detected by [Azure AD Identity Protection](https://learn.microsoft.com/en-us/azure/active-directory/identity-protection/overview-identity-protection)

**SEEN** let you customize the emails sent to inform the users of these events and encourage them to reach out to your security team or support. 

**SEEN** is leveraging a combination of Logic Apps to automate the detection of the security events and the notification to end users with many customizable options. **SEEN** read the Azure AD sign-in logs and audit logs from a Log Analytics workspace (`SigninLogs` and `AuditLogs` tables). 

### ⚙️ Deployment

The full solution is available for deployment in the [Deployment](/deploy/) section and additional documentation can be found in [Docs](/docs/).

If you have any questions about this project or would like to provide suggestions to the **SEEN** project maintainers please open an [issue](https://github.com/piaudonn/SecurityNotifications/issues/new/choose).
