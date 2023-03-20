# Required PowerShell modules:
#  - MgGraph to grant MSI permissions using the Microsoft Graph API
#  - Az grant permissons on Azure resources
# To install the pre-requisites, uncomment the following two lines:
#  Install-Module Microsoft.Graph.Applications -Scope CurrentUser -Force
#  Install-Module -Name Az.Resources -Scope CurrentUser -Repository PSGallery -Force

# Required Permissions
#  - Azure AD Global Administrator or an Azure AD Privileged Role Administrator to execute the Set-APIPermissions function
#  - Resource Group Owner or User Access Administrator on the Microsoft Sentinel resource group to execute the Set-RBACPermissions function

# Enter your tenant and subscrition details below:
$TenantId = ""
$AzureSubscriptionId = ""
$SentinelResourceGroupName = "" # Resource Group Name where the Sentinel workspace is
$SEENResourceGroupName = "" # Resource Group Name where the SEEN solution is deployed

# If you have changed the default name of the logic apps, update the names below:
$ConfigLogicAppName = "SEEN-Config" # SEEN Config Logic App Name
$SendEmailLogicAppName = "SEEN-SendEmail"  # SEEN Send Email Logic App Name
$MFAMethodsLogicAppName = "SEEN-MFAMethods" # SEEN MFA Methods Logic App Name
$TAPLogicAppName = "SEEN-TemporaryAccessPass" # SEEN TAP Logic App Name

# Additional options
$LogicAppPrefix = ""                               # Adds a prefix to all Logic App names

# Connect to the Microsoft Graph API and Azure Management API
Write-Host "⚙️ Connect to the Azure AD tenant: $TenantId"
Connect-MgGraph -TenantId $TenantId -Scopes AppRoleAssignment.ReadWrite.All, Application.Read.All | Out-Null
Write-Host "⚙️ Connecting to  to the Azure subscription: $AzureSubscriptionId"
try
{
    Login-AzAccount -Subscription $AzureSubscriptionId -Tenant $TenantId -ErrorAction Stop | Out-Null
}
catch
{
    Write-Host "⛔ Login to Azure Management failed. $($error[0])"
}

function Set-APIPermissions ($MSIName, $AppId, $PermissionName) {
    Write-Host "⚙️ Setting permission $PermissionName on $MSIName"
    $MSI = Get-AppIds -AppName $MSIName
    if ( $MSI.count -gt 1 )
    {
        Write-Host "❌ Found multiple principals with the same name." -ForegroundColor Red
        return 
    } elseif ( $MSI.count -eq 0 ) {
        Write-Host "❌ Principal not found." -ForegroundColor Red
        return 
    }
    Start-Sleep -Seconds 2 # Wait in case the MSI identity creation tool some time
    $GraphServicePrincipal = Get-MgServicePrincipal -Filter "appId eq '$AppId'"
    $AppRole = $GraphServicePrincipal.AppRoles | Where-Object {$_.Value -eq $PermissionName -and $_.AllowedMemberTypes -contains "Application"}
    try
    {
        New-MgServicePrincipalAppRoleAssignment -ServicePrincipalId $MSI.Id -PrincipalId $MSI.Id -ResourceId $GraphServicePrincipal.Id -AppRoleId $AppRole.Id -ErrorAction Stop | Out-Null
    }
    catch
    {
        if ( $_.Exception.Message -eq "Permission being assigned already exists on the object" )
        {
            Write-Host "ℹ️ $($_.Exception.Message)"
        } else {
            Write-Host "❌ $($_.Exception.Message)" -ForegroundColor Red
        }
        return
    }
    Write-Host "✅ Permission granted" -ForegroundColor Green
}

function Get-AppIds ($AppName) {
    Get-MgServicePrincipal -Filter "displayName eq '$AppName'"
}

function Set-RBACPermissions ($MSIName, $Role, $ResourceGroup) {
    Write-Host "⚙️ Adding $Role to $MSIName"
    $MSI = Get-AppIds -AppName $MSIName
    if ( $MSI.count -gt 1 )
    {
        Write-Host "❌ Found multiple principals with the same name." -ForegroundColor Red
        return 
    } elseif ( $MSI.count -eq 0 ) {
        Write-Host "❌ Principal not found." -ForegroundColor Red
        return 
    }
    $Assign = New-AzRoleAssignment -ApplicationId $MSI.AppId -Scope "/subscriptions/$($AzureSubscriptionId)/resourceGroups/$($ResourceGroup)" -RoleDefinitionName $Role -ErrorAction SilentlyContinue -ErrorVariable AzError
    if ( $Assign )
    {
        Write-Host "✅ Role added" -ForegroundColor Green
    } elseif ( $AzError[0].Exception.Message -like "*Conflict*" ) {
        Write-Host "ℹ️ Role already assigned"
    } else {
        Write-Host "❌ $($AzError[0].Exception.Message)" -ForegroundColor Red
    }
}

#Config Logic App
Set-RBACPermissions -MSIName $LogicAppPrefix$ConfigLogicAppName -Role "Storage Blob Data Contributor" -ResourceGroup $SEENResourceGroupName
Set-RBACPermissions -MSIName $LogicAppPrefix$ConfigLogicAppName -Role "Storage Table Data Contributor" -ResourceGroup $SEENResourceGroupName

#Send Email Logic App
Set-APIPermissions -MSIName $LogicAppPrefix$SendEmailLogicAppName -AppId "00000003-0000-0000-c000-000000000000" -PermissionName "Mail.Send"

#MFA Methods Logic APp
Set-APIPermissions -MSIName $LogicAppPrefix$MFAMethodsLogicAppName -AppId "00000003-0000-0000-c000-000000000000" -PermissionName "User.Read.All"
Set-RBACPermissions -MSIName $LogicAppPrefix$MFAMethodsLogicAppName -Role "Storage Table Data Contributor" -ResourceGroup $SEENResourceGroupName
Set-RBACPermissions -MSIName $LogicAppPrefix$MFAMethodsLogicAppName -Role "Log Analytics Reader" -ResourceGroup $SentinelResourceGroupName

#TAP Logic APp
Set-APIPermissions -MSIName $LogicAppPrefix$TAPLogicAppName -AppId "00000003-0000-0000-c000-000000000000" -PermissionName "User.Read.All"
Set-RBACPermissions -MSIName $LogicAppPrefix$TAPLogicAppName -Role "Storage Table Data Contributor" -ResourceGroup $SEENResourceGroupName
Set-RBACPermissions -MSIName $LogicAppPrefix$TAPLogicAppName -Role "Log Analytics Reader" -ResourceGroup $SentinelResourceGroupName

Write-Host "⚙️ End of the script. Please review the output and check for potential failures."