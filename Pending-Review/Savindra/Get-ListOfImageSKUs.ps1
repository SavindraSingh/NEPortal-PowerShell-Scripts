<#
    .SYNOPSIS
    Script to Get List of Image SKUs Names

    .DESCRIPTION
    Script to Get list of Image SKUs Names available in Azure Resource Manager Portal

    .PARAMETER AzureUserName
    User name for Azure login. This should be an Organizational account (not Hotmail/Outlook account)

    .PARAMETER AzurePassword
    Password for Azure user account.

    .PARAMETER AzureSubscriptionID
    Azure Subscription ID to use for this activity.

    .PARAMETER Location
    Azure Location to use for creating/saving/accessing resources (should be a valid location. Refer to https://azure.microsoft.com/en-us/regions/ for more details.)

    .PARAMETER PublisherName
    Name of the Azure RM VM Image publisher available for this location.

    .PARAMETER Offer
    Name of the offer provided by Azure RM VM Image publisher.

    .INPUTS
    All parameter values in String format.

    .OUTPUTS
    String. List of values in JSON format.

    .NOTES
     Purpose of script: Get list of available Image SKUs Names
     Minimum requirements: PowerShell Version 1.2.1
     Initially written by: SavindraSingh Shahoo
     Update/revision History:
     =======================
     Updated by        Date            Reason
     ==========        ====            ======
     SavindraSingh     26-May-16       Changed Mandatory=$True to Mandatory=$False for all parameters.

    .EXAMPLE
    C:\PS> .\Get-ListOfImageSKUs.ps1  -AzureUserName "testlab@netenrich.com" -AzurePassword 'pass12@w0rd' -AzureSubscriptionID 'ca68598c-ecc3-4abc-b7a2-1ecef33f278d' -Location 'East US' -PublisherName 'virtualworks' -Offer 'viaworks' -ErrorAction Stop -WarningAction SilentlyContinue

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

    [Parameter(Mandatory=$false,ValueFromPipelineByPropertyName=$true)]
    [string]$Location,

    [Parameter(Mandatory=$false,ValueFromPipelineByPropertyName=$true)]
    [string]$PublisherName,

    [Parameter(Mandatory=$false,ValueFromPipelineByPropertyName=$true)]
    [string]$Offer
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

    # 2. Fetch List of Image SKUs Names
    Try
    {
        ($arrImageSKUs = (Get-AzureRmVMImageSku -Location $Location -PublisherName $PublisherName -Offer $Offer -ErrorAction Stop -WarningAction SilentlyContinue).Skus) | Out-Null
        $ImageSKUs = (@{ "Response" = [Array]$arrImageSKUs; "Status" = "Success"} | ConvertTo-Json)
        Write-Output $ImageSKUs
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