<#
    .SYNOPSIS
    The script is to get the protected servers under a backup vault

    .DESCRIPTION
    The script is to get the protected servers under a backup vault

    .PARAMETER AzureUserName

    User name for Azure login. This should be an Organizational account (not Hotmail/Outlook account)

    .PARAMETER AzurePassword

    Password for Azure user account.

    .PARAMETER AzureSubscriptionID

    Azure Subscription ID to use for this activity.

    .INPUTS
    All parameter values in String format.

    .OUTPUTS
    String. Result of the command output.

    .NOTES
    .NOTES
     Purpose of script:     The script is to fetch the production servers under Azure Backup.
     Minimum requirements: Azure PowerShell Version 2.0.0
     Initially written by: Bhaskar Desharaju
     Update/revision History:
     =======================
     Updated by        Date            Reason
     ==========        ====            ======
     SavindraSingh     26-May-16       Changed Mandatory=$True to Mandatory=$False for all parameters.
     SavindraSingh     21-Jul-16       1. Added Login function in Begin block, instead of commands in Process block.
                                       2. Check minumum required version of Azure PowerShell
     SavindraSingh     26-Jul-16       1. Added flag for indicating log file readyness for uploading to blob in the log text.
                                       2. Added Function Get-BlobURIForLogFile to return the URI for Log file blob in output.
                                       3. Added Common parameter $ClientID to indicate the Client details in the logfile.
    SavindraSingh      9-Sep-2016      1. Added a variable at script level (line 89) - $ScriptUploadConfig = $null
                                       2. $Script:ScriptUploadConfig will now hold the value for the current required version
                                          of Azure PowerShell. Which is used at line 176 with - If($AzurePSVersion -gt $ScriptUploadConfig.RequiredPSVersion)
                                          to check if we have Azure PowerShell version available.
                                       3. The required version of Azure PowerShell should now be mentioned in the NEPortalApp.Config as given below:
                                          Under <appSettings> tag - <add key="RequiredPSVersion" value="2.0.1"/>

    .EXAMPLE
    C:\PS> .\Get-ListOfProductionServers.ps1 -AzureUserName bhaskar.desharaju@netenrich.com -AzurePassword Rama123$ -AzureSubscriptionID ca68598c-ecc3-4abc-b7a2-1ecef33f278d -ResourceGroupName resourcegrp-bhaskar -RecoveryServicesVaultName automationtest

    .LINK
    http://www.netenrich.com/#>

[CmdletBinding()]
Param
(
    [Parameter(ValueFromPipelineByPropertyName)]
    [string]$AzureUserName,

    [Parameter(ValueFromPipelineByPropertyName)]
    [string]$AzurePassword,

    [Parameter(ValueFromPipelineByPropertyName)]
    [string]$AzureSubscriptionID,

    [Parameter(ValueFromPipelineByPropertyName)]
    [string]$ResourceGroupName,

    [Parameter(ValueFromPipelineByPropertyName)]
    [string]$RecoveryServicesVaultName
)

Begin
{
    # Function: Login to Azure subscription
    Function Login-ToAzureAccount
    {
        Try
        {
            $SecurePassword = ConvertTo-SecureString -AsPlainText $AzurePassword -Force
            $Cred = New-Object System.Management.Automation.PSCredential -ArgumentList $AzureUserName, $securePassword
            (Login-AzureRmAccount -Credential $cred -SubscriptionId $AzureSubscriptionID -ErrorAction Stop) | Out-Null
        }
        Catch
        {
            $ObjOut = "Error logging in to Azure Account.`n$($Error[0].Exception.Message)"
            $output = (@{"Response" = [Array]$ObjOut; "Status" = "Failed"} | ConvertTo-Json).ToString().Replace('\u0027',"'")
            Write-Output $output
            Exit
        }
    }
}

Process
{
    # 1. Login to Azure subscription
    Login-ToAzureAccount

    # 2. Fetch List of Virtual networks
    Try
    {
        $BackupVaultObj = $null
        ($BackupVaultObj = Get-AzureRmRecoveryServicesVault -ResourceGroupName $ResourceGroupName -Name $RecoveryServicesVaultName -ErrorAction Stop -WarningAction SilentlyContinue) | Out-Null
        if($BackupVaultObj -ne $null)
        {
            ($SetStatus = Set-AzureRmRecoveryServicesVaultContext -Vault $BackupVaultObj -ErrorAction Stop -WarningAction SilentlyContinue) | Out-Null
            ($productionServers = Get-AzureRmRecoveryServicesBackupContainer -ContainerType Windows -BackupManagementType MARS -ErrorAction SilentlyContinue -WarningAction SilentlyContinue) | Out-Null
            if($productionServers -ne $null)
            {
                $ListOfProductionServers = $productionServers.Name
                $ProdList = (@{ "Response" = [Array]$ListOfProductionServers; "Status" = "Success"} | ConvertTo-Json)
                Write-Output $ProdList
            }
            Else
            {
                $ObjOut = "Backup vault $RecoveryServicesVaultName does not have any Protected Servers."
                $output = (@{"Response" = [Array]$ObjOut; "Status" = "Failed"} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                Write-Output $output
                Exit
            }
        }
        Else
        {
            $ObjOut = "Backup Vault $RecoveryServicesVaultName does not exist."
            $output = (@{"Response" = [Array]$ObjOut; "Status" = "Failed"} | ConvertTo-Json).ToString().Replace('\u0027',"'")
            Write-Output $output
            Exit
        }
    }
    Catch
    {
        $ObjOut = "Error fetching List: $($Error[0].Exception.Message)"
        $output = (@{"Response" = [Array]$ObjOut; "Status" = "Failed"} | ConvertTo-Json).ToString().Replace('\u0027',"'")
        Write-Output $output
        Exit
    }
}
End
{

}