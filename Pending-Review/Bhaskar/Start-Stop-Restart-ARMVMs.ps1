<##
    .SYNOPSIS
    The script to Stop the virtual machine in the given Resource Group

    .DESCRIPTION
    The script to Stop the virtual machine in the given Resource Group

    .PARAMETER AzureUserName
    User name for Azure login. This should be an Organizational account (not Hotmail/Outlook account)

    .PARAMETER AzurePassword
    Password for Azure user account.

    .PARAMETER AzureSubscriptionID
    Azure Subscription ID to use for this activity.

    .PARAMETER ResourceGroupName
    Name of the Resource Group name to be used for this command.

    .PARAMETER PowerOption
    Whether to Start or Stop the VMs

    .INPUTS 
    All parameter values in String format.

    .OUTPUTS
    String. Result of the command output.

    .NOTES
     Purpose of script: Create New Storage Account in Azure Resource Manager Portal
     Minimum requirements: PowerShell Version 1.2.1
     Initially written by: Bhaskar Desharaju
     Update/revision History:
     =======================
     Updated by    Date      Reason
     ==========    ====      ======

    .EXAMPLE
    C:\PS> .\Stop-ResourceGroupVMs.ps1 -AzureUserName bhaskar@desharajubhaskaroutlook.onmicrosoft.com -AzurePassword Pa55w0rd1! -AzureSubscriptionID 13483623-4785-4789-8d13-b58c06d37cb9 -ResourceGroupName MyResourceGrp -PowerOption Start

    .LINK
    http://www.netenrich.com/
#>
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
    [string]$PowerOption
)

Begin
{
    Function Validate-AllParameters
    {
        Try
        {
            # Validate parameter: AzureUserName
            If([String]::IsNullOrEmpty($AzureUserName))
            {
                $ObjOut = "Validation failed. AzureUserName parameter value is empty."
                $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                Write-Output $output
                Exit
            }

            # Validate parameter: AzurePassword
            If([String]::IsNullOrEmpty($AzurePassword))
            {
                $ObjOut = "Validation failed. AzurePassword parameter value is empty."
                $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                Write-Output $output
                Exit
            }

            # Validate parameter: AzureSubscriptionID
            If([String]::IsNullOrEmpty($AzureSubscriptionID))
            {
                $ObjOut = "Validation failed. AzureSubscriptionID parameter value is empty."
                $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                Write-Output $output
                Exit
            }

            # Validate parameter: ResourceGroupName
            If([String]::IsNullOrEmpty($ResourceGroupName))
            {
                $ObjOut = "Validation failed. ResourceGroupName parameter value is empty."
                $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                Write-Output $output
                Exit
            }

            # Validate parameter: PowerOption
            If([String]::IsNullOrEmpty($PowerOption))
            {
                $ObjOut = "Validation failed. PowerOption parameter value is empty."
                $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                Write-Output $output
                Exit
            }
            Else
            {
                If($PowerOption -notin ('Start','Stop','Restart'))
                {
                    $ObjOut = "Validation failed. PowerOption parameter value is not a valid operation."
                    $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                    Write-Output $output
                    Exit
                }                
            }
        }
        catch 
        {
            $ObjOut = "Error while validating parameters: $($Error[0].Exception.Message)"
            $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"} | ConvertTo-Json).ToString().Replace('\u0027',"'")
            Write-Output $output
            Exit
        }
    }

    Function Login-ToAzureAccount
    {
        Try
        {
            $SecurePassword = ConvertTo-SecureString -AsPlainText $AzurePassword -Force
            $Cred = New-Object System.Management.Automation.PSCredential -ArgumentList $AzureUserName, $securePassword
            (Login-AzureRmAccount -Credential $Cred -SubscriptionId $AzureSubscriptionID -ErrorAction Stop) | Out-Null
        }
        Catch
        {
            $ObjOut = "Error logging in to Azure Account.`n$($Error[0].Exception.Message)"
            $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"} | ConvertTo-Json).ToString().Replace('\u0027',"'")
            Write-Output $output
            Exit
        }
    }

}
Process
{
    # 1. Validate all Parameters
    Validate-AllParameters

    # 2. Login to Azure Account
    Login-ToAzureAccount

    # 3. Checking for the reosurce group existence
    Try
    {
        Write-Output "Checking for the Resource Group existence..."

        $ResourceGroup = $null
        ($ResourceGroup = Get-AzureRmResourceGroup -Name $ResourceGroupName -ErrorAction SilentlyContinue -WarningAction SilentlyContinue) | Out-Null
        If($ResourceGroup -ne $null) # Resource Group already exists
        {
            Write-Output "Resource Group exists"
        }
        Else
        {
            $ObjOut = "The resource group $ResourceGroupName does not exist."
            $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"} | ConvertTo-Json).ToString().Replace('\u0027',"'")
            Write-Output $output
            Exit
        }
    }
    Catch
    {
        $ObjOut = "Error while getting Azure Resource Group details.$($Error[0].Exception.Message)"
        $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"} | ConvertTo-Json).ToString().Replace('\u0027',"'")
        Write-Output $output
        Exit
    }

    # 4. Stopping all the Virtual Machines in the given Resource Group
    Try 
    {
        Write-Output "Fetching all the Virtual Machines in the Resource Group $ResourceGroupName..."
        $AllVMs = $null
        ($AllVMs = Get-AzureRMVM -ResourceGroupName $ResourceGroupName -ErrorAction SilentlyContinue -WarningAction SilentlyContinue) | Out-Null
        if($AllVMs -ne $null)
        {
            foreach ($VM in $AllVMs) 
            {
                Try 
                {
                    switch ($PowerOption)
                    {
                        'Start' {
                                    ($StopStatus = Stop-AzureRmVM -Name $($VM.Name) -ResourceGroupName $ResourceGroupName -Force -ErrorAction Stop -WarningAction SilentlyContinue) | Out-Null
                                    if($StopStatus.Status -eq 'Succeeded')
                                    {
                                        Write-Output "Virtual Machine $($VM.Name) has been stopped and deallocated successfully."
                                    }
                                    Else
                                    {
                                        Write-Output "Unable to Stop the Virtual Machine $($VM.Name)"
                                    }
                                }
                        'Stop' {
                                    ($StartStatus = Start-AzureRmVM -Name $($VM.Name) -ResourceGroupName $ResourceGroupName -ErrorAction Stop -WarningAction SilentlyContinue) | Out-Null
                                    if($StartStatus.Status -eq 'Succeeded')
                                    {
                                        Write-Output "Virtual Machine $($VM.Name) has been Started successfully."
                                    }
                                    Else
                                    {
                                        Write-Output "Unable to Start the Virtual Machine $($VM.Name)"
                                    }
                                }
                        'Restart' {
                                    ($RestartStatus = Restart-AzureRmVM -Name $($VM.Name) -ResourceGroupName $ResourceGroupName -ErrorAction Stop -WarningAction SilentlyContinue) | Out-Null
                                    if($RestartStatus.Status -eq 'Succeeded')
                                    {
                                        Write-Output "Virtual Machine $($VM.Name) has been ReStarted successfully."
                                    }
                                    Else
                                    {
                                        Write-Output "Unable to ReStart the Virtual Machine $($VM.Name)"
                                    }
                                }
                    }
                }
                Catch 
                {
                    Write-Output "There was an Exception: $($Error[0].Exception.Message) while performing $PowerOption operation on the Virtual Machine $($VM.Name)."
                }    
            }
        }
        Else 
        {
            $ObjOut = "The Resource Group $ResourceGroupName does not hold any Virtual Machines."
            $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"} | ConvertTo-Json).ToString().Replace('\u0027',"'")
            Write-Output $output
            Exit
        }
    }
    Catch 
    {
        $ObjOut = "Error while performing $PowerOption operation on the Virtual Machine.$($Error[0].Exception.Message)"
        $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"} | ConvertTo-Json).ToString().Replace('\u0027',"'")
        Write-Output $output
        Exit
    }
}
End
{
    #
}