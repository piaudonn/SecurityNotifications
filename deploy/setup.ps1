# Required Permissions
#  - Azure AD Global Administrator or an Azure AD Privileged Role Administrator to execute the Set-APIPermissions function
#  - Resource Group Owner or User Access Administrator on the resource groups hosting the logic app and the storage account to execute the Set-RBACPermissions function

# Required PowerShell modules:
#  - MgGraph to grant MSI permissions using the Microsoft Graph API
#  - Az grant permissons on Azure resources and trigger the config logic app

#Requires -Modules Microsoft.Graph.Applications, Az.Resources, Az.LogicApp

param(
    $TenantId,
    $AzureSubscriptionId,
    $WorkspaceResourceGroupName,
    $SEENResourceGroupName,
    $StorageAccountResourceGroupName = $SEENResourceGroupName,
    $ConfigLogicAppName = "SEEN-Config",
    $SendEmailLogicAppName = "SEEN-SendEmail",
    $MFAMethodsLogicAppName = "SEEN-MFAMethods",
    $TravelLogicAppName = "SEEN-Travel",
    $TAPLogicAppName = "SEEN-TemporaryAccessPass"
)

#region Connection
Write-Host "⚙️ Connect to the Azure AD tenant: $TenantId"
Connect-MgGraph -TenantId $TenantId -Scopes AppRoleAssignment.ReadWrite.All, Application.Read.All | Out-Null
Write-Host "⚙️ Connecting to  to the Azure subscription: $AzureSubscriptionId"
try
{
    Login-AzAccount -Subscription $AzureSubscriptionId -Tenant $TenantId -ErrorAction Stop | Out-Null
    $Domain = (Get-AzTenant | Where-Object { $_.Id -eq "550a9b78-cb2e-43e0-9c5b-db194784b875" }).Domains[0]
}
catch
{
    Write-Host "⛔ Login to Azure Management failed. $($error[0])"
}
#endregion

#region Functions
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
    #Start-Sleep -Milliseconds 500 # Wait in case the MSI identity creation tool some time
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
#endregion

#region Permissions
#Config Logic App
Set-RBACPermissions -MSIName $ConfigLogicAppName -Role "Storage Blob Data Contributor" -ResourceGroup $StorageAccountResourceGroupName
Set-RBACPermissions -MSIName $ConfigLogicAppName -Role "Storage Table Data Contributor" -ResourceGroup $StorageAccountResourceGroupName

#Send Email Logic App
Set-APIPermissions -MSIName $SendEmailLogicAppName -AppId "00000003-0000-0000-c000-000000000000" -PermissionName "Mail.Send"

#MFA Methods Logic APp
Set-APIPermissions -MSIName $MFAMethodsLogicAppName -AppId "00000003-0000-0000-c000-000000000000" -PermissionName "User.Read.All"
Set-RBACPermissions -MSIName $MFAMethodsLogicAppName -Role "Storage Table Data Contributor" -ResourceGroup $StorageAccountResourceGroupName
Set-RBACPermissions -MSIName $MFAMethodsLogicAppName -Role "Log Analytics Reader" -ResourceGroup $WorkspaceResourceGroupName

#TAP Logic APp
Set-APIPermissions -MSIName $TAPLogicAppName -AppId "00000003-0000-0000-c000-000000000000" -PermissionName "User.Read.All"
Set-RBACPermissions -MSIName $TAPLogicAppName -Role "Storage Table Data Contributor" -ResourceGroup $StorageAccountResourceGroupName
Set-RBACPermissions -MSIName $TAPLogicAppName -Role "Log Analytics Reader" -ResourceGroup $WorkspaceResourceGroupName

#TAP Logic APp
Set-APIPermissions -MSIName $TravelLogicAppName -AppId "00000003-0000-0000-c000-000000000000" -PermissionName "User.Read.All"
Set-RBACPermissions -MSIName $TravelLogicAppName -Role "Storage Table Data Contributor" -ResourceGroup $StorageAccountResourceGroupName
Set-RBACPermissions -MSIName $TravelLogicAppName -Role "Log Analytics Reader" -ResourceGroup $WorkspaceResourceGroupName
#endregion

#region Config LA in setup mode
Write-Host "⚙️ Triggering the $ConfigLogicAppName logic app to provision the storage account used for SEEN."
try
{
    Start-AzLogicApp -ResourceGroupName $SEENResourceGroupName -Name $ConfigLogicAppName -TriggerName "manual"
}
catch
{
    Write-Host "⛔ Cannot trigger the logic app. The configuration is not finished.`n$($_.Exception.Message)"
}
#endregion

Write-Host "⚙️ End of the script. Please review the output and check for potential failures."
Write-Host "`n👏 You can now open the ""Manage and monitor"" workbook in the $SEENResourceGroupName resource group to configure and enable the modules. `n`n`t🔗 Click here: " -NoNewline
Write-Host "https://portal.azure.com/#@$($Domain)/resource/subscriptions/$($AzureSubscriptionId)/resourceGroups/$($SEENResourceGroupName)/providers/microsoft.insights/workbooks/7bea244d-869b-45a8-996a-2472c0d7bc5f/workbook `n`n"
