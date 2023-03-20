## SEcurity End-user Notification 👀

Public repository for **SEEN** development.

🔗 [Hackathon project](https://hackbox.microsoft.com/hackathons/security-hackathon-2023/project/23249)    

### Project description

Consumer identity platforms are notifying their users when their password has changes, a suspicious logon is detected, or a new MFA method was added. It is also a common practice in the insurance and financial industries. Yet, our enterprise solution Azure AD does not have these capabilities.

This project is leveraging a combination of Logic Apps to enable customers to quickly set up those notifications using ready to go (and customizable) email templates. 

These notifications encourage end-users to contact their support if the action which was detected does not seem to be legitimate. This will help supports and security operations in their investigations and security decisions. 

### Supported scenarios

Here is the list of activities which SEEN can use to trigger end-user notifications:
- Multi Factor Authentication methods updates
- Temporary Access Pass creations and usage
- Password reset and password change operations

Scenarios are implemented through modules (Logic Apps with a Recurrence trigger).

The operators of the solution can customize the email templates that will be used to notify users per scenario.

### Deployment

* Permissions
* Script
