<#
    .SYNOPSIS
    Script to Get List of Virtual Network Subnets

    .DESCRIPTION
    Script to Get list of Virtual Network Subnets available in Azure Resource Manager Portal

    .PARAMETER AzureUserName

    User name for Azure login. This should be an Organizational account (not Hotmail/Outlook account)

    .PARAMETER AzurePassword

    Password for Azure user account.

    .PARAMETER AzureSubscriptionID

    Azure Subscription ID to use for this activity.

    .PARAMETER ResourceGroupName

    Name of the Azure ARM resource group to use for this command.

    .PARAMETER VNetName

    Azure Virtual Network Name for which you want to see the available subnets.
    
    .INPUTS
    All parameter values in String format.

    .OUTPUTS
    String. Result of the command output.

    .NOTES
     Purpose of script: Get list of available Virtual Network Subnets
     Minimum requirements: PowerShell Version 1.2.1
     Initially written by: SavindraSingh Shahoo
     Update/revision History:
     =======================
     Updated by        Date            Reason
     ==========        ====            ======
     SavindraSingh     26-May-16       Changed Mandatory=$True to Mandatory=$False for all parameters.

    .EXAMPLE
    C:\PS> .\Get-ListOfVNetSubnets.ps1 -AzureUserName 'testlab@netenrich.com' -AzurePassword 'pass12@word' -AzureSubscriptionID 'ae7c7576-f01c-4026-9b94-d05e04e459fc' -ResourceGroupName 'TestLabRG' -VNetname 'JsnTmplVNetPSTest' -WarningAction 'SilentlyContinue'

    .LINK
    http://www.netenrich.com/#>

[CmdletBinding()]
Param
(
    [Parameter(Mandatory=$false,ValueFromPipelineByPropertyName=$true)]
    [string]$AzureUserName,

    [Parameter(Mandatory=$false,ValueFromPipelineByPropertyName=$true)]
    [string]$AzurePassword,

    [Parameter(Mandatory=$false,ValueFromPipelineByPropertyName=$true)]
    [string]$AzureSubscriptionID,

    [Parameter(Mandatory=$False)]
    [String]$ResourceGroupName,

    [Parameter(Mandatory=$false,ValueFromPipelineByPropertyName=$true)]
    [string]$VNetName
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
        ($arrVNetSubnets = (Get-AzureRmVirtualNetwork -Name $VNetname -ResourceGroupName $ResourceGroupName -ErrorAction Stop).Subnets.Name) | Out-Null
        $VNSubnets = (@{ "Response" = [Array]$arrVNetSubnets; "Status" = "Success"} | ConvertTo-Json)
        Write-Output $VNSubnets
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