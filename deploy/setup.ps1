
# Required Permissions
#  - Azure AD Global Administrator or an Azure AD Privileged Role Administrator to execute the Set-APIPermissions function
#  - Resource Group Owner or User Access Administrator on the resource groups hosting the logic app and the storage account to execute the Set-RBACPermissions function
#  - Storage Blob Data Contributor on the resource group of your storage account
#  - Storage Table Data Contributor on the resource group of your storage account
# This script also creates temporary files in the temp folder of your machne using the New-TemporaryFile cmdLet

# Required PowerShell modules:
#  - MgGraph to grant MSI permissions using the Microsoft Graph API
#  - Az grant permissons on Azure resources and provisiong the config and templates 

#Requires -Modules Microsoft.Graph.Applications, Az.Resources, Az.Storage, Az.LogicApp, AzTable

param(
    $TenantId,
    $AzureSubscriptionId,
    $StorageAccountName,
    $StorageAccountResourceGroupName,
    $WorkspaceResourceGroupName,
    $SEENResourceGroupName,
    $SupportEmail = "support@contoso.com",
    $SupportPhoneNumber = "(555) 123-1234",
    $MailFrom,
    $ReplyTo = $MailFrom,
    $TestEmail,
    $TimeZone = "UTC", #https://learn.microsoft.com/en-us/azure/data-explorer/kusto/query/timezone
    $ConfigLogicAppName = "SEEN-Config",
    $SendEmailLogicAppName = "SEEN-SendEmail",
    $MFAMethodsLogicAppName = "SEEN-MFAMethods",
    $TAPLogicAppName = "SEEN-TemporaryAccessPass",
    $SourceBranch = "main"
)

#region Connection
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
#endregion

#region Config file
Write-Host "⚙️ Setting up the configuration"
$ConfigUrl = "https://raw.githubusercontent.com/piaudonn/SecurityNotifications/$SourceBranch/config/seen.config"
try
{
    $GetConfigFile = Invoke-WebRequest -Uri $ConfigUrl
    $ConfigFile = $GetConfigFile.Content | ConvertFrom-Json
}
catch {
    Write-Host "⛔ Cannot download the config file from $ConfigUrl.`nCheck the branch and retry."
}

$ConfigFile.contact.supportEmail = $SupportEmail
$ConfigFile.contact.supportPhone = $SupportPhoneNumber
$ConfigFile.mailFrom = $MailFrom
$ConfigFile.replyTo = $ReplyTo
$ConfigFile.timeZone = $TimeZone
$ConfigFile.link = $ConfigUrl
$ConfigFile.testEmail = $TestEmail
Write-Host "📃 Creating a temporary file for config storage"
$TempConfigFile = New-TemporaryFile
$ConfigFile | ConvertTo-Json | Out-File -LiteralPath $TempConfigFile -Force

$StorageContext = New-AzStorageContext -UseConnectedAccount -BlobEndpoint  "https://$StorageAccountName.blob.core.windows.net/" -TableEndpoint "https://$StorageAccountName.table.core.windows.net/"
$CurrentConfig = Get-AzStorageBlob -Container seen -Blob seen.config -Context $StorageContext -ErrorAction SilentlyContinue
if( !$CurrentConfig )
{
    $ConfigOldFile = (Get-Date -f yyyyMMddHHmmss) + "-seen.config"
    Write-Host "⚠️ A config file last modified at $($_.LastModified) was found. " -NoNewline
    $OldConfigFile = New-TemporaryFile
    Write-Host "A copy of that file can be found here: $OldConfigFile."
    #Copy-AzStorageBlob -SrcContainer "seen" -SrcBlob "seen.config" -DestContainer "seen" -DestBlob $ConfigOldFile -Context $StorageContext
}
Write-Host "📃 Uploading the config file" 
Set-AzStorageBlobContent -Container seen -Blob "seen.config" -Context $StorageContext -File $TempConfigFile -Force | Out-Null
Write-Host "📃 Deleting the temporary file ($TempConfigFile)" 
Remove-Item $TempConfigFile
#endregion

#region Templates
Write-Host "⚙️ Uploading templates"
try
{
    $GetHeaderTemplate = Invoke-WebRequest -Uri "https://raw.githubusercontent.com/piaudonn/SecurityNotifications/$SourceBranch/templates/header.html"
    $GetFooterTemplate = Invoke-WebRequest -Uri "https://raw.githubusercontent.com/piaudonn/SecurityNotifications/$SourceBranch/templates/footer.html"
    $GetMFATemplate = Invoke-WebRequest -Uri "https://raw.githubusercontent.com/piaudonn/SecurityNotifications/$SourceBranch/templates/mfa.html"
    $GetTAPTemplate = Invoke-WebRequest -Uri "https://raw.githubusercontent.com/piaudonn/SecurityNotifications/$SourceBranch/templates/tap.html"
}
catch {
    Write-Host "⛔ Cannot download the templates."
}
Write-Host "📃 Creating temporary files for templates "
$GetHeaderTemplateFile = New-TemporaryFile
$GetFooterTemplateFile = New-TemporaryFile
$GetMFATemplateFile = New-TemporaryFile
$GetTAPTemplateFile = New-TemporaryFile
$GetHeaderTemplate.Content | Out-File -LiteralPath $GetHeaderTemplateFile -Force
$GetFooterTemplate.Content | Out-File -LiteralPath $GetFooterTemplateFile -Force
$GetMFATemplate.Content | Out-File -LiteralPath $GetMFATemplateFile -Force
$GetTAPTemplate.Content | Out-File -LiteralPath $GetTAPTemplateFile -Force
Write-Host "🃏 Uploading the config file" 
Set-AzStorageBlobContent -Container seen -Blob "templates/header.html" -Context $StorageContext -File $GetHeaderTemplateFile -Force | Out-Null
Remove-Item $GetHeaderTemplateFile
Set-AzStorageBlobContent -Container seen -Blob "templates/footer.html" -Context $StorageContext -File $GetFooterTemplateFile -Force | Out-Null
Remove-Item $GetFooterTemplateFile
Set-AzStorageBlobContent -Container seen -Blob "templates/mfa.html" -Context $StorageContext -File $GetMFATemplateFile -Force | Out-Null
Remove-Item $GetMFATemplateFile
Set-AzStorageBlobContent -Container seen -Blob "templates/tap.html" -Context $StorageContext -File $GetTAPTemplateFile -Force | Out-Null
Remove-Item $GetTAPTemplateFile
#endregion

#region Tables initialization 
Write-Host "⚙️ Initializing the Azure table"

#$CurrentTable = Get-AzStorageTable –Name "trackers" –Context $StorageContext.Context -ErrorAction SilentlyContinue
$CurrentTable = Get-AzTableTable -resourceGroup $StorageAccountResourceGroupName -TableName "trackers" -storageAccountName $StorageAccountName -ErrorAction SilentlyContinue
#if (!$CurrentTable)
#{
#    $CurrentTable = New-AzStorageTable –Name "trackers" –Context $StorageContext.Context
#}
$CurrentTime = (get-date -Format u).Replace(" ","T")
Write-Host "⏲️ Initializing the tracker with the current time $CurrentTime"
Add-AzTableRow -Table $CurrentTable -PartitionKey "seen" -RowKey "MFAMethods" -property @{"Tracker" = $CurrentTime} 
Add-AzTableRow -Table $CurrentTable -PartitionKey "seen" -RowKey "TAPUsage" -property @{"Tracker" = $CurrentTime}
#endregion

#region Enable modules
Write-Host "⚙️ Enabling Logic Apps modules"
try
{
    Write-Host "🟢 Enabling $MFAMethodsLogicAppName in $SEENResourceGroupName"
    Set-AzLogicApp -ResourceGroupName $SEENResourceGroupName -Name $MFAMethodsLogicAppName -State Enabled -Force | Out-Null
    Write-Host "🟢 Enabling $TAPMethodsLogicAppName in $SEENResourceGroupName"
    Set-AzLogicApp -ResourceGroupName $SEENResourceGroupName -Name $TAPMethodsLogicAppName -State Enabled -Force | Out-Null
}
catch {
    Write-Host "⛔ Cannot enable the logic apps."
}
#endregion

Write-Host "⚙️ End of the script. Please review the output and check for potential failures."