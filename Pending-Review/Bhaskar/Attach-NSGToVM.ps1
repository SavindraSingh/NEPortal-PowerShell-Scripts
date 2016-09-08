<#
    .SYNOPSIS
    Script to associating the NSG group to the Virtual Machine.

    .DESCRIPTION
    Script to associating the NSG group to the Virtual Machine.

    .PARAMETER ClientID

    Client ID to be used for this script.

    .PARAMETER AzureUserName

    User name for Azure login. This should be an Organizational account (not Hotmail/Outlook account)

    .PARAMETER AzurePassword

    Password for Azure user account.

    .PARAMETER AzureSubscriptionID

    Azure Subscription ID to use for this activity.

    .PARAMETER NSGGroup

    Azure NSGGroup to be used for this command.

    .PARAMETER ResourceGroupName

    Name of the Azure ARM resource group to use for this command.

    .PARAMETER VMName

    Name of the Virtual Machine to be used for this command.

    .PARAMETER NICCardNames

    Name of the NIC Cards to be used for this command.

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
    C:\PS> .\Attach-NSGToVM.ps1 -ClientID 123456 -AzureUserName 'testlab@netenrich.com' -AzurePassword 'pass12@word' -AzureSubscriptionID 'ae7c7576-f01c-4026-9b94-d05e04e459fc' -NSGGroup 'testGrp' -ResourceGroupName 'TestLabRG' -VMName 'testImage123'

    .LINK
    http://www.netenrich.com/
#>
[CmdletBinding()]
Param
(
    [Parameter(ValueFromPipelineByPropertyName)]
    [string]$ClientID,

    [Parameter(ValueFromPipelineByPropertyName)]
    [string]$AzureUserName,

    [Parameter(ValueFromPipelineByPropertyName)]
    [string]$AzurePassword,

    [Parameter(ValueFromPipelineByPropertyName)]
    [string]$AzureSubscriptionID,

    [Parameter(ValueFromPipelineByPropertyName)]
    [String]$NSGGroup,
	
	[Parameter(ValueFromPipelineByPropertyName)]
    [String]$ResourceGroupName,
    
    [Parameter(ValueFromPipelineByPropertyName)]
    [string]$VMName,

    [Parameter(ValueFromPipelineByPropertyName)]
    [string]$NICCardNames
)

Begin
{
    # Name the Log file based on script name
    [DateTime]$LogFileTime = Get-Date
    $FileTimeStamp = $LogFileTime.ToString("dd-MMM-yyyy_HHmmss")
    $LogFileName = "$ClientID-$($MyInvocation.MyCommand.Name.Replace('.ps1',''))-$FileTimeStamp.log"
    $LogFilePath = "C:\NEPortal\$LogFileName"

    Function Get-BlobURIForLogFile
    {
        Try
        {
            $UC = Select-Xml -Path "C:\NEPortal\NEPortalApp.Config" -XPath configuration/appSettings -ErrorAction SilentlyContinue | Select -ExpandProperty Node | Select -ExpandProperty add
            $UploadConfig = [ordered]@{}; $UC | % { $UploadConfig += @{ $_.key = $_.Value } }
            $UploadConfig = [PSCustomObject]$UploadConfig

            $Container = $UploadConfig.Container
            $StorageAccName = $UploadConfig.StorageAccName
            $StorageAccKey = $UploadConfig.StorageAccKey

            ($context = New-AzureStorageContext -StorageAccountName $StorageAccName -StorageAccountKey $StorageAccKey -ErrorAction Stop) | Out-Null
        }
        Catch
        {
            Return "Error processing blob URI. Check if storage credentials are correct in 'C:\NEPortal\NEPortalApp.Config'"
        }
        Return "$($context.BlobEndPoint)$($UploadConfig.Container)/$($LogFilename)"
    }

    $LogFileBlobURI = Get-BlobURIForLogFile

    # ======================================================================
    # Write-Log function defination
    # ======================================================================
    Function Write-LogFile
    {
        Param([String]$FilePath, [String]$LogText, [Switch]$Overwrite = $false)

        [DateTime]$LogTime = Get-Date
        $TimeStamp = $LogTime.ToString("dd-MMM-yyyy hh:mm:ss tt")
        $InputLine = "[$TimeStamp] : $LogText"

        If($FilePath -like "*.???")
        { $CheckPath = Split-Path $FilePath; }
        Else
        { $CheckPath = $FilePath }

        If(Test-Path -Path $CheckPath -ErrorAction SilentlyContinue)
        {
            # Correct path Now check if it is a File or Folder
            ($IsFolder = (Get-Item $FilePath -ErrorAction SilentlyContinue) -is [System.IO.DirectoryInfo]) | Out-Null
            If($IsFolder)
            {
                If($FilePath.EndsWith("\")) { $FilePath = $FilePath.TrimEnd(1) }
                $FilePath = "$FilePath\Log_$($LogTime.ToString('dd-MMM-yyyy_hh.mm.ss')).log"
            }
        }
        Else
        {
            Try
            {
                If(-not($FilePath -like "*.???"))
                {
                    If($FilePath.EndsWith("\")) { $FilePath = $FilePath.TrimEnd(1) }
                    $FilePath = "$FilePath\Log_$($LogTime.ToString('dd-MMM-yyyy_HH.mm.ss')).log"
                    (New-Item -Path $FilePath -ItemType File -Force -ErrorAction Stop) | Out-Null
                }
                Else
                {
                    (New-Item -Path $CheckPath -ItemType Directory -Force -ErrorAction Stop) | Out-Null
                }
            }
            Catch
            { 
                "Error creating output folder for Log file $(Split-Path $FilePath).`n$($Error[0].Exception.Message)"
            }
        }

        If($Overwrite)
        {
            $InputLine | Out-File -FilePath $FilePath -Force
        }
        Else
        {
            $InputLine | Out-File -FilePath $FilePath -Force -Append
        }
    }

    Write-LogFile -FilePath $LogFilePath -LogText "####[ Script Execution started: $($MyInvocation.MyCommand.Name). For Client ID: $ClientID ]####" -Overwrite

    # Check minumum required version of Azure PowerShell
    $AzurePSVersion = (Get-Module -ListAvailable -Name Azure -ErrorAction Stop).Version
    If($AzurePSVersion -gt 1.4)
    {
        Write-LogFile -FilePath $LogFilePath -LogText "Required version of Azure PowerShell is available."
    }
    Else 
    {
        $ObjOut = "Required version of Azure PowerShell not available. Stopping execution.`nDownload and install required version from: http://aka.ms/webpi-azps."
        $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
        Write-LogFile -FilePath $LogFilePath -LogText "$ObjOut`r`n<#BlobFileReadyForUpload#>"
        Write-Output $output
        Exit
    }

    Function Validate-AllParameters
    {
        Try
        {
            # Validate parameter: ClientID
            Write-LogFile -FilePath $LogFilePath -LogText "Validating Parameters: ClientID. Only ERRORs will be logged."
            If([String]::IsNullOrEmpty($ClientID))
            {
                Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. ClientID parameter value is empty.`r`n<#BlobFileReadyForUpload#>"
                $ObjOut = "Validation failed. ClientID parameter value is empty."
                $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                Write-Output $output
                Exit
            }

            # Validate parameter: AzureUserName
            Write-LogFile -FilePath $LogFilePath -LogText "Validating Parameters: AzureUserName. Only ERRORs will be logged."
            If([String]::IsNullOrEmpty($AzureUserName))
            {
                Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. AzureUserName parameter value is empty.`r`n<#BlobFileReadyForUpload#>"
                $ObjOut = "Validation failed. AzureUserName parameter value is empty."
                $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                Write-Output $output
                Exit
            }

            # Validate parameter: AzurePassword
            Write-LogFile -FilePath $LogFilePath -LogText "Validating Parameters: AzurePassword. Only ERRORs will be logged."
            If([String]::IsNullOrEmpty($AzurePassword))
            {
                Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. AzurePassword parameter value is empty.`r`n<#BlobFileReadyForUpload#>"
                $ObjOut = "Validation failed. AzurePassword parameter value is empty."
                $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                Write-Output $output
                Exit
            }

            # Validate parameter: AzureSubscriptionID
            Write-LogFile -FilePath $LogFilePath -LogText "Validating Parameters: AzureSubscriptionID. Only ERRORs will be logged."
            If([String]::IsNullOrEmpty($AzureSubscriptionID))
            {
                Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. AzureSubscriptionID parameter value is empty.`r`n<#BlobFileReadyForUpload#>"
                $ObjOut = "Validation failed. AzureSubscriptionID parameter value is empty."
                $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                Write-Output $output
                Exit
            }

            # Validate parameter: NSGGroup
            Write-LogFile -FilePath $LogFilePath -LogText "Validating Parameters: NSGGroup. Only ERRORs will be logged."
            If([String]::IsNullOrEmpty($NSGGroup))
            {
                Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. NSGGroup parameter value is empty.`r`n<#BlobFileReadyForUpload#>"
                $ObjOut = "Validation failed. NSGGroup parameter value is empty."
                $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                Write-Output $output
                Exit
            }

            # Validate parameter: ResourceGroupName
            Write-LogFile -FilePath $LogFilePath -LogText "Validating Parameters: ResourceGroupName. Only ERRORs will be logged."
            If([String]::IsNullOrEmpty($ResourceGroupName))
            {
                Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. ResourceGroupName parameter value is empty.`r`n<#BlobFileReadyForUpload#>"
                $ObjOut = "Validation failed. ResourceGroupName parameter value is empty."
                $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                Write-Output $output
                Exit
            }

			# Validate parameter: VMName
            Write-LogFile -FilePath $LogFilePath -LogText "Validating Parameters: VMName. Only ERRORs will be logged."
            If([String]::IsNullOrEmpty($VMName))
            {
                Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. VMName parameter value is empty.`r`n<#BlobFileReadyForUpload#>"
                $ObjOut = "Validation failed. VMName parameter value is empty."
                $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                Write-Output $output
                Exit
            }

            # Validate parameter: NICCardNames
            Write-LogFile -FilePath $LogFilePath -LogText "Validating Parameters: NICCardNames. Only ERRORs will be logged."
            If([String]::IsNullOrEmpty($NICCardNames))
            {
                Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. NICCardNames parameter value is empty.`r`n<#BlobFileReadyForUpload#>"
                $ObjOut = "Validation failed. NICCardNames parameter value is empty."
                $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                Write-Output $output
                #Exit
            }
        }
        Catch
        {
            Write-LogFile -FilePath $LogFilePath -LogText "Error while validating parameters: $($Error[0].Exception.Message)`r`n<#BlobFileReadyForUpload#>"
            $ObjOut = "Error while validating parameters: $($Error[0].Exception.Message)"
            $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
            Write-Output $output
            Exit
        }
    }
    Function Login-ToAzureAccount
    {
        Try
        {
            Write-LogFile -FilePath $LogFilePath -LogText "Attempting to login to Azure RM subscription." 
            $SecurePassword = ConvertTo-SecureString -AsPlainText $AzurePassword -Force
            $Cred = New-Object System.Management.Automation.PSCredential -ArgumentList $AzureUserName, $securePassword
            (Login-AzureRmAccount -Credential $Cred -SubscriptionId $AzureSubscriptionID -ErrorAction Stop) | Out-Null
            Write-LogFile -FilePath $LogFilePath -LogText "Login to Azure RM successful."
        }
        Catch
        {
            $ObjOut = "Error logging in to Azure Account.`n$($Error[0].Exception.Message)"
            Write-LogFile -FilePath $LogFilePath -LogText "$ObjOut`r`n<#BlobFileReadyForUpload#>"
            $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
            Write-Output $output
            Exit
        }
    }
}
Process
{
    # 1. Validating all Parameters
    Validate-AllParameters

    # 2. Login to Azure RM Account
    Login-ToAzureAccount

    # 3. Register to Azure Provider Namespaces
    Try
    {
        # Required Provider name spaces
        Write-LogFile -FilePath $LogFilePath -LogText "Registering the resource providers." 
        $ReqNameSpces = @("Microsoft.Compute","Microsoft.Storage","Microsoft.Network")
        foreach($NameSpace in $ReqNameSpces)
        {
            Write-LogFile -FilePath $LogFilePath -LogText "Registering the provider $NameSpace" 
            ($Status = Register-AzureRmResourceProvider -ProviderNamespace $NameSpace -ErrorAction Stop -WarningAction SilentlyContinue) | Out-Null
            If($Status) 
            {
                Write-LogFile -FilePath $LogFilePath -LogText "Verifying the namespace provider $NameSpace Registration."
                ($state = Get-AzureRmResourceProvider -ProviderNamespace $NameSpace -ErrorAction SilentlyContinue -WarningAction SilentlyContinue) | Out-Null
                while($state.RegistrationState -ne 'Registered')
                {
                    ($state = Get-AzureRmResourceProvider -ProviderNamespace $NameSpace -ErrorAction SilentlyContinue -WarningAction SilentlyContinue) | Out-Null 
                }
                Write-LogFile -FilePath $LogFilePath -LogText "Registering the provider $NameSpace is successful." 
            }
            else
            {
                Write-LogFile -FilePath $LogFilePath -LogText "Registering the provider $NameSpace was not successful.`r`n<#BlobFileReadyForUpload#>" 
                $ObjOut = "Registering the provider $NameSpace was not successful."
                $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                Write-Output $output
                Exit
            }
        }
    }
    catch
    {
        $ObjOut = "Error while registering the Resource provide namespace.$($Error[0].Exception.Message)`r`n<#BlobFileReadyForUpload#>"
        $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
        Write-Output $output
        Write-LogFile -FilePath $LogFilePath -LogText "$ObjOut"
        Exit
    }

    # 4. Checking for the reosurce group existence
    Try
    {
        Write-LogFile -FilePath $LogFilePath -LogText "Checking existance of resource group '$ResourceGroupName'"
        $ResourceGroup = $null
        ($ResourceGroup = Get-AzureRmResourceGroup -Name $ResourceGroupName -ErrorAction SilentlyContinue -WarningAction SilentlyContinue) | Out-Null
        If($ResourceGroup -ne $null) # Resource Group already exists
        {
            Write-LogFile -FilePath $LogFilePath -LogText "Resource Group already exists"
        }
        Else 
        {
            Write-LogFile -FilePath $LogFilePath -LogText "The resource group $ResourceGroupName does not exist.`r`n<#BlobFileReadyForUpload#>"
            $ObjOut = "The resource group $ResourceGroupName does not exist."
            $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
            Write-Output $output
            Exit
        }
    }
    Catch
    {
        $ObjOut = "Error while getting Azure Resource Group details.$($Error[0].Exception.Message)`r`n<#BlobFileReadyForUpload#>"
        $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
        Write-Output $output
        Write-LogFile -FilePath $LogFilePath -LogText "$ObjOut"
        Exit
    }

    # 5. Checking for the VM existence
    Try
    {
        Write-LogFile -FilePath $LogFilePath -LogText "Verifying the VM existence in the resource group." 

        ($VMExist = Get-AzureRMVM -ResourceGroupName $ResourceGroupName -Name $VMName -ErrorAction SilentlyContinue -WarningAction SilentlyContinue) | Out-Null
        if($VMExist)
        {
            Write-LogFile -FilePath $LogFilePath -LogText "Virtual Machine $VMName is already exist."
        }
        else
        {
            Write-LogFile -FilePath $LogFilePath -LogText "The Virtual Machine $VMName does not exist in the resource group $ResourceGroupName.`r`n<#BlobFileReadyForUpload#>"
            $ObjOut = "The Virtual Machine $VMName does not exist in the resource group $ResourceGroupName."
            $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
            Write-Output $output
            Exit
        }
    }
    catch
    {
        $ObjOut = "Error while checking Virtul Machine $VMName in the $ResourceGroupName.$($Error[0].Exception.Message)"
        $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
        Write-Output $output
        Write-LogFile -FilePath $LogFilePath -LogText "$ObjOut`r`n<#BlobFileReadyForUpload#>"
        Exit
    }

    # 6.Checking for the NSG Group existence
    Try
    {
        Write-LogFile -FilePath $LogFilePath -LogText "Checking for the NSG Group existence."

        ($NSGGroup = Get-AzureRmNetworkSecurityGroup -Name $NSGGroup -ResourceGroupName $ResourceGroupName -ErrorAction SilentlyContinue -WarningAction SilentlyContinue) | Out-Null
        if($NSGGroup)
        {
            Write-LogFile -FilePath $LogFilePath -LogText "The Network Security Group $NSGGroup is already exist."
        }
        else
        {
            Write-LogFile -FilePath $LogFilePath -LogText "The Network security group does not exist in resource group $ResourceGroupName.`r`n<#BlobFileReadyForUpload#>"
            $ObjOut = "The Network security group does not exist in resource group $ResourceGroupName."
            $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
            Write-Output $output
            Exit
        }
    }
    Catch
    {
        $ObjOut = "Error while fetching the Network Security Group details.$($Error[0].Exception.Message)"
        $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
        Write-Output $output
        Write-LogFile -FilePath $LogFilePath -LogText "$ObjOut`r`n<#BlobFileReadyForUpload#>"
        Exit
    }

    # 7. Attaching the NSG to the Virtual Machine
    Try
    {
        Write-LogFile -FilePath $LogFilePath -LogText "Verifying the Network Interfaces of the Virtual Machine."
        $NicCards = @()
        $NicCards = $NICCardNames.Split(",")
        $ExistingNICCards = $VMExist.NetworkInterfaceIDs
        $NameExistingNICs = @()
        foreach($ENic in $ExistingNICCards)
        {
            $NameExistingNICs = $ENic.Split("/")[-1].ToString()
        }

        if($NICCardNames)
        {
            if($NicCards.Count -gt $NameExistingNICs.Count)
            {
                Write-LogFile -FilePath $LogFilePath -LogText "The number of NIC card names provided are more than the NIC cards that the VM has.`r`n<#BlobFileReadyForUpload#>"
                $ObjOut = "The number of NIC card names provided are more than the NIC cards that the VM has."
                $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                Write-Output $output
                Exit
            }
            else
            {
                foreach($NCN in $NicCards)
                {
                    if($NameExistingNICs -notcontains $NCN.Trim())
                    {
                        Write-LogFile -FilePath $LogFilePath -LogText "One of the NIC card name $NCN provided is not associated with the VM $VMName.`r`n<#BlobFileReadyForUpload#>"
                        $ObjOut = "One of the NIC card name $NCN provided is not associated with the VM $VMName."
                        $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                        Write-Output $output
                        Exit
                    }
                }
            }
        }
        $LoopExitBit = 0    
        foreach($n in $NameExistingNICs)
        {
            Write-LogFile -FilePath $LogFilePath -LogText "Fetching the Network Interface Card $n details."
            ($NICObj = Get-AzureRmNetworkInterface -Name $n.Trim() -ResourceGroupName $ResourceGroupName -ErrorAction SilentlyContinue -WarningAction SilentlyContinue) | Out-Null
            if($NICObj)
            {
                Write-LogFile -FilePath $LogFilePath -LogText "Attaching the NSG to the default NIC."
                $NICObj.NetworkSecurityGroup = $NSGGroup
                ($State = Set-AzureRmNetworkInterface -NetworkInterface $NICObj -ErrorAction Stop -WarningAction SilentlyContinue) | Out-Null
                if($State.ProvisioningState -eq 'Succeeded')
                {# $LoopExitBit remains same
                }
                else
                {
                    $LoopExitBit = 1
                }
            }
            else
            {
                Write-LogFile -FilePath $LogFilePath -LogText "Unable to fetch the Network Interface Card details.`r`n<#BlobFileReadyForUpload#>"
                $ObjOut = "Unable to fetch the Network Interface Card details."
                $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                Write-Output $output
                Exit
            }
        }
        if($LoopExitBit -eq 0)
        {
            Write-LogFile -FilePath $LogFilePath -LogText "Association of Network Security Group to VM $VMName was sucessful.`r`n<#BlobFileReadyForUpload#>"
            $ObjOut = "Association of Network Security Group to VM $VMName was sucessful."
            $output = (@{"Response" = [Array]$ObjOut; Status = "Success"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
            Write-Output $output
        }
        else
        {
            Write-LogFile -FilePath $LogFilePath -LogText "Association of Network Security Group to VM $VMName was failed.`r`n<#BlobFileReadyForUpload#>"
            $ObjOut = "Unable to fetch the Network Interface Card details."
            $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
            Write-Output $output
            Exit            
        }
    }
    catch
    {
        $ObjOut = "Error while associating the Network Security Group to the Virtual Machine.$($Error[0].Exception.Message)"
        $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
        Write-Output $output
        Write-LogFile -FilePath $LogFilePath -LogText "$ObjOut`r`n<#BlobFileReadyForUpload#>"
        Exit
    }
}
End
{
    Write-LogFile -FilePath $LogFilePath -LogText "####[ Script execution completed cuccessfully: $($MyInvocation.MyCommand.Name) ]####`r`n<#BlobFileReadyForUpload#>"
}
