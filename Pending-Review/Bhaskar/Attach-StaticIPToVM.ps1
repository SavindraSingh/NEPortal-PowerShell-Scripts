<#
    .SYNOPSIS
    Script to attach static private IP address to ARM VM.

    .DESCRIPTION
    Script to attach static private IP address to ARM VM.

    .PARAMETER ClientID
    ClientID of the client for whom the script is being executed.

    .PARAMETER AzureUserName
    User name for Azure login. This should be an Organizational account (not Hotmail/Outlook account)

    .PARAMETER AzurePassword
    Password for Azure user account.

    .PARAMETER AzureSubscriptionID
    Azure Subscription ID to use for this activity.

    .PARAMETER ResourceGroupName
    Name of the Azure ARM resource group to use for this command.

    .PARAMETER Location
    Azure Location to use for creating/saving/accessing resources (should be a valid location. Refer to https://azure.microsoft.com/en-us/regions/ for more details.)

    .PARAMETER VMName
    Name of the Virtual Machine to be used for this command.

    .PARAMETER NICCardNames
    NIC Card Names

    .PARAMETER StaticIPAddress
    Static IP Address to be used for this command.

    .INPUTS
    All parameter values in String format.

    .OUTPUTS
    String. Result of the command output.

    .NOTES
     Purpose of script: The script is to attach a static IP to Azure Virtual Machine.
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
    C:\PS> .\Attach-StaticIPToVM.ps1 -ClientID 12345 -AzureUserName testlab@netenrich.com -AzurePassword **** -AzureSubscriptionID ca68598c-ecc3-4abc-b7a2-1ecef33f278d -ResourceGroupName mytestgrp -VMName myvm -StaticIPAddress 10.0.1.7 -NICCardNames vm123

    .LINK
    http://www.netenrich.com/#>

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
    [String]$ResourceGroupName,

	[Parameter(ValueFromPipelineByPropertyName)]
    [String]$Location,

    [Parameter(ValueFromPipelineByPropertyName)]
    [String]$VMName,
    
    [Parameter(ValueFromPipelineByPropertyName)]
    [String]$NICCardNames,

    [Parameter(ValueFromPipelineByPropertyName)]
    [String]$StaticIPAddress
)

Begin
{
    # Name the Log file based on script name
    [DateTime]$LogFileTime = Get-Date
    $FileTimeStamp = $LogFileTime.ToString("dd-MMM-yyyy_HHmmss")
    $LogFileName = "$ClientID-$($MyInvocation.MyCommand.Name.Replace('.ps1',''))-$FileTimeStamp.log"
    $LogFilePath = "C:\NEPortal\$LogFileName"

    $ScriptUploadConfig = $null
    Function Get-BlobURIForLogFile
    {
        Try
        {
            $UC = Select-Xml -Path "C:\NEPortal\NEPortalApp.Config" -XPath configuration/appSettings -ErrorAction SilentlyContinue | Select -ExpandProperty Node | Select -ExpandProperty add
            $UploadConfig = [ordered]@{}; $UC | % { $UploadConfig += @{ $_.key = $_.Value } }
            $Script:ScriptUploadConfig = [PSCustomObject]$UploadConfig

            $Container = $ScriptUploadConfig.Container
            $StorageAccName = $ScriptUploadConfig.StorageAccName
            $StorageAccKey = $ScriptUploadConfig.StorageAccKey

            ($context = New-AzureStorageContext -StorageAccountName $StorageAccName -StorageAccountKey $StorageAccKey -ErrorAction Stop) | Out-Null
        }
        Catch
        {
            Return "Error processing blob URI. Check if storage credentials are correct in 'C:\NEPortal\NEPortalApp.Config'"
        }
        Return "$($context.BlobEndPoint)$($ScriptUploadConfig.Container)/$($LogFilename)"
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
    If($AzurePSVersion -ge $ScriptUploadConfig.RequiredPSVersion)
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

            # Validate parameter: Location
            Write-LogFile -FilePath $LogFilePath -LogText "Validating Parameters: Location. Only ERRORs will be logged."
            If([String]::IsNullOrEmpty($Location))
            {
                Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. Location parameter value is empty.`r`n<#BlobFileReadyForUpload#>"
                $ObjOut = "Validation failed. Location parameter value is empty."
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

            # Validate parameter: StaticIPAddress
            Write-LogFile -FilePath $LogFilePath -LogText "Validating Parameters: StaticIPAddress. Only ERRORs will be logged."
            If([String]::IsNullOrEmpty($StaticIPAddress))
            {
                Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. StaticIPAddress parameter value is empty.`r`n<#BlobFileReadyForUpload#>"
                $ObjOut = "Validation failed. StaticIPAddress parameter value is empty."
                $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                Write-Output $output
                Exit
            }
            If($StaticIPAddress.Contains(","))
            {
                $script:IPAddresses = @()
                $Script:IPAddresses = $StaticIPAddress.Split(",")
                
                foreach($IP in $script:IPAddresses)
                {
                    Write-LogFile -FilePath $LogFilePath -LogText "Validating if StaticIPAddress is valid IP Address. Only ERRORs will be logged."
                    If([bool]($IP -as [ipaddress])) { <# Valid IP address #>}
                    Else
                    {
                        Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. StaticIPAddress $IP is NOT a valid IP address.`r`n<#BlobFileReadyForUpload#>"
                        $ObjOut = "Validation failed. StaticIPAddress $IP is not a valid IP address."
                        $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                        Write-Output $output
                        Exit
                    }
                }   
            }
            Else
            {
                Write-LogFile -FilePath $LogFilePath -LogText "Validating if StaticIPAddress is valid IP Address. Only ERRORs will be logged."
                If([bool]($StaticIPAddress -as [ipaddress])) { <# Valid IP address #>}
                Else
                {
                    Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. StaticIPAddress $StaticIPAddress is NOT a valid IP address.`r`n<#BlobFileReadyForUpload#>"
                    $ObjOut = "Validation failed. StaticIPAddress $StaticIPAddress is not a valid IP address."
                    $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                    Write-Output $output
                    Exit
                }
            }

            # Validate parameter: NICCardNames
            Write-LogFile -FilePath $LogFilePath -LogText "Validating Parameters: NICCardNames. Only ERRORs will be logged."
            If([String]::IsNullOrEmpty($NICCardNames))
            {
                Write-LogFile -FilePath $LogFilePath -LogText "Validation warning. NICCardNames parameter value is empty.Default NIC Card will be used.`r`n<#BlobFileReadyForUpload#>"
                $ObjOut = "Validation warning. NICCardNames parameter value is empty.Default NIC Card will be used."
                $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                #Write-Output $output
                #Exit
            }
            else
            {
                If($NICCardNames.Contains(","))
                {
                    $Script:NICCards = @()
                    $Script:NICCards = $NICCardNames.Split(",")
                }
            }

            # Validating the NIC Cards numbers and IP Addresses Provided
            if(([String]::IsNullOrEmpty($NICCardNames)) -and ($script:IPAddresses.Count -gt 1))
            {
                Write-LogFile -FilePath $LogFilePath -LogText "Validation Failed. The number of IP addresses provided not equal to nic card names.`r`n<#BlobFileReadyForUpload#>"
                $ObjOut = "Validation warning. The number IP provided and number of NIC card names provided are not equal. If miltiple ip address are given provide their NIC Names"
                $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                Write-Output $output
                Exit
            }
            if($NICCardNames -ne "")
            {
                if($NICCardNames.Contains(",") -and ($Script:NICCards.Count -eq $script:IPAddresses.Count))
                {
                }
                Elseif($NICCardNames -notContains "," -and ($StaticIPAddress.Contains(",")))
                {
                    Write-LogFile -FilePath $LogFilePath -LogText "Validation Failed. The number NICCards provided and number of IP address provided are not equal.`r`n<#BlobFileReadyForUpload#>"
                    $ObjOut = "Validation warning. The number NICCards provided and number of IP address provided are not equal."
                    $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                    Write-Output $output
                    Exit                 
                }
                Else
                {
                }
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
            Write-LogFile -FilePath $LogFilePath -LogText "Attempting to login to Azure RM subscription" 
            $SecurePassword = ConvertTo-SecureString -AsPlainText $AzurePassword -Force
            $Cred = New-Object System.Management.Automation.PSCredential -ArgumentList $AzureUserName, $securePassword
            (Login-AzureRmAccount -Credential $Cred -SubscriptionId $AzureSubscriptionID -ErrorAction Stop) | Out-Null
            Write-LogFile -FilePath $LogFilePath -LogText "Login to Azure RM successful"
        }
        Catch
        {
            $ObjOut = "Error logging in to Azure Account.`n$($Error[0].Exception.Message)`r`n<#BlobFileReadyForUpload#>"
            Write-LogFile -FilePath $LogFilePath -LogText $ObjOut
            $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
            Write-Output $output
            Exit
        }
    }

    Function Attach-StaticIP
    {
        Param
        (
            $NicName,
            $IPAddress
        )

        try
        {
            Write-LogFile -FilePath $LogFilePath -LogText "Fetching the NIC Interface $NicName details."
            ($NICObj = Get-AzureRmNetworkInterface -Name $NicName -ResourceGroupName $ResourceGroupName -ErrorAction SilentlyContinue -WarningAction SilentlyContinue) | Out-Null
            if($NICObj -ne $null)
            {
                Write-LogFile -FilePath $LogFilePath -LogText "Trying to set the Static IP $IPAddress to the NIC Card."
                $NICObj.IpConfigurations[0].PrivateIpAllocationMethod = 'Static'
                $NICObj.IpConfigurations[0].PrivateIpAddress = $IPAddress
                ($Status = Set-AzureRmNetworkInterface -NetworkInterface $NICObj -ErrorAction Stop -WarningAction SilentlyContinue) | Out-Null
                if($Status.ProvisioningState -eq 'Succeeded')
                {
                    Write-LogFile -FilePath $LogFilePath -LogText "The NIC Card has been set with Static IP $IPAddress for the VM $VMName.`r`n<#BlobFileReadyForUpload#>"
                    $ObjOut = "The NIC Card has been set with Static IP $IPAddress for the VM $VMName."
                    $output = (@{"Response" = [Array]$ObjOut; Status = "Success"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                    Write-Output $output
                }
                Else
                {
                    Write-LogFile -FilePath $LogFilePath -LogText "The NIC Card has not been set with Static IP $IPAddress for the VM $VMName.`r`n<#BlobFileReadyForUpload#>"
                    $ObjOut = "The NIC Card has not been set with Static IP $IPAddress for the VM $VMName."
                    $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                    Write-Output $output
                    Exit
                }
            }
            Else
            {
                Write-LogFile -FilePath $LogFilePath -LogText "The Network interface $NicName is not available for the VM $VMName.`r`n<#BlobFileReadyForUpload#>"
                $ObjOut = "The Network interface $NicName is not available for the VM $VMName."
                $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                Write-Output $output
                Exit
            }
        }
        Catch
        {
            $ObjOut = "Error while fetching the NIC Card details of the VM $VMName.`r`n$($Error[0].Exception.Message)"
            $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
            Write-Output $output
            Write-LogFile -FilePath $LogFilePath -LogText "$ObjOut`r`n<#BlobFileReadyForUpload#>"
            Exit
        }
    }
}

Process
{
    # 1. Validating the Parameters
    Validate-AllParameters

    # 2. Login to Azure subscription
    Login-ToAzureAccount

    # 3. Check if Resource Group exists. Create Resource Group if it does not exist.
    Try
    {
        Write-LogFile -FilePath $LogFilePath -LogText "Checking existance of resource group '$ResourceGroupName'"
        $ResourceGroup = $null
        ($ResourceGroup = Get-AzureRmResourceGroup -Name $ResourceGroupName -ErrorAction SilentlyContinue -WariningAction SilentlyContinue) | Out-Null
    
        If($ResourceGroup -ne $null) # Resource Group already exists
        {
           Write-LogFile -FilePath $LogFilePath -LogText "Resource Group already exists"
        }
        Else # Resource Group does not exist. Can't continue without creating resource group.
        {
            $ObjOut = "The resource group $ResourceGroup does not exist.`r`n$($Error[0].Exception.Message)`r`n<#BlobFileReadyForUpload#>"
            $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
            Write-Output $output
            Write-LogFile -FilePath $LogFilePath -LogText "$ObjOut"
            exit
        }
    }
    Catch
    {
        $ObjOut = "Error while getting Azure Resource Group details.`r`n$($Error[0].Exception.Message)`r`n<#BlobFileReadyForUpload#>"
        $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
        Write-Output $output
        Write-LogFile -FilePath $LogFilePath -LogText $ObjOut
        Exit
    }

    # 4. Checking for the VM Existence
    Try
    {
        Write-LogFile -FilePath $LogFilePath -LogText "Verifying the VM existence in the subscription." 

        ($VMExist = Get-AzureRMVM -ResourceGroupName $ResourceGroupName -Name $VMName -ErrorAction SilentlyContinue -WarningAction SilentlyContinue) | Out-Null
        if($VMExist -ne $null)
        {
            Write-LogFile -FilePath $LogFilePath -LogText "The Virtual Machine $VMName is already exists."
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
    # 5. Attaching the Static IP to the Virtual Machine
    Try
    {
        Write-LogFile -FilePath $LogFilePath -LogText "Fetching and Validating the NIC Cards Information of the VM $VMName."
        $NICInterfaces = $VMExist.NetworkInterfaceIDs
        $NICCardInterfaceNames = @()
        foreach($NInterface in $NICInterfaces)
        {
            $NICCardInterfaceNames += Split-Path -Path $NInterface -Leaf
        }
        if($NICCardNames.Contains(",") -and ($Script:NICCards.Count -gt 1))
        {
            if($Script:NICCards.Count -eq $NICInterfaces.Count)
            {   
                $Result = Compare-Object -ReferenceObject $NICCardInterfaceNames -DifferenceObject $Script:NICCards
                if($Result -eq $null)
                {
                    $ExitCode = 0
                    for($i =0;$i -lt $Script:NICCards.Count;$i++)
                    {
                        Write-LogFile -FilePath $LogFilePath -LogText "Fetching the NIC Card $($Script:NICCards[$i]) details."
                        ($NICObj = Get-AzureRmNetworkInterface -Name $Script:NICCards[$i] -ResourceGroupName $ResourceGroupName -ErrorAction SilentlyContinue -WarningAction SilentlyContinue) | Out-Null
                        if($NICObj -ne $null)
                        {
                            $NICObj.IpConfigurations[0].PrivateIpAllocationMethod = 'Static'
                            $NICObj.IpConfigurations[0].PrivateIpAddress = $script:IPAddresses[$i]
                            ($Status = Set-AzureRmNetworkInterface -NetworkInterface $NICObj -ErrorAction Stop -WarningAction SilentlyContinue) | Out-Null
                            if($Status.ProvisioningState -ne 'Succeeded')
                            {
                                $ExitCode = 1
                            }
                        }
                        else
                        {
                            $ExitCode = 1
                        }
                    }
                    if($ExitCode -eq 0)
                    {
                        Write-LogFile -FilePath $LogFilePath -LogText "All the NIC Cards have been successfully attached with Static IPs provided.`r`n<#BlobFileReadyForUpload#>"
                        $ObjOut = "All the NIC Cards have been successfully attached with Static IPs provided."
                        $output = (@{"Response" = [Array]$ObjOut; Status = "Success"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                        Write-Output $output                        
                    }
                    Else
                    {
                        Write-LogFile -FilePath $LogFilePath -LogText "Unable to Get the Info of provided NIC / Provided NIC Info is wrong.`r`n<#BlobFileReadyForUpload#>"
                        $ObjOut = "Unable to Get the Info of provided NIC / Provided NIC Info is wrong"
                        $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                        Write-Output $output
                        Exit
                    }
                }
                Else
                {
                    Write-LogFile -FilePath $LogFilePath -LogText "The Number of Nics provided and the number nic cards that VM has not equal.`r`n<#BlobFileReadyForUpload#>"
                    $ObjOut = "The Number of Nics provided and the number nic cards that VM has not equal"
                    $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                    Write-Output $output
                    Exit
                }
            }
            Else
            {
                Write-LogFile -FilePath $LogFilePath -LogText "The Number of Nics provided and the number nic cards that VM has not equal.`r`n<#BlobFileReadyForUpload#>"
                $ObjOut = "The Number of Nics provided and the number nic cards that VM has not equal."
                $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                Write-Output $output
                Exit                
            }
        }
        Elseif($NICCardNames)
        {
            if($NICCardInterfaceNames.Contains($($NICCardNames.Trim())))
            {
                if($StaticIPAddress.Contains(","))
                {
                    Attach-StaticIP -NicName $NICCardNames -IPAddress $script:IPAddresses[0]
                }
                Else
                {
                    Attach-StaticIP -NicName $NICCardNames -IPAddress $StaticIPAddress
                }
            }
            Else
            {
                Write-LogFile -FilePath $LogFilePath -LogText "The Number of Nics provided and the number nic cards that VM has not equal.`r`n<#BlobFileReadyForUpload#>"
                $ObjOut = "The Virtual Machine $VMName does not exist in the resource group $ResourceGroupName."
                $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                Write-Output $output
                Exit
            }
        }
        Else
        {
            $NICDefaultName = $NICCardInterfaceNames[0]
            if($StaticIPAddress.Contains(","))
            {
                Attach-StaticIP -NicName $NICDefaultName -IPAddress $script:IPAddresses[0]
            }
            Else
            {
                Attach-StaticIP -NicName $NICDefaultName -IPAddress $StaticIPAddress
            }
        }
    }
    Catch
    {
        $ObjOut = "Error while checking Virtul Machine $VMName in the $ResourceGroupName.$($Error[0].Exception.Message)"
        $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
        Write-Output $output
        Write-LogFile -FilePath $LogFilePath -LogText "$ObjOut`r`n<#BlobFileReadyForUpload#>"
        Exit
    }
    Finally
    {
    }
}
End
{
    Write-LogFile -FilePath $LogFilePath -LogText "####[ Script execution completed Successfully: $($MyInvocation.MyCommand.Name) ]####`r`n<#BlobFileReadyForUpload#>"
}