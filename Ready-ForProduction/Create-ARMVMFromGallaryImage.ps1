<#
    .SYNOPSIS
    Script to create New Virual Machine in Azure Resource Manager Portal

    .DESCRIPTION
    Script to create New Virtual Machine in Azure Resource Manager Portal

    .PARAMETER ClientID

    Client ID to be used for this script.

    .PARAMETER AzureUserName

    User name for Azure login. This should be an Organizational account (not Hotmail/Outlook account)

    .PARAMETER AzurePassword

    Password for Azure user account.

    .PARAMETER AzureSubscriptionID

    Azure Subscription ID to use for this activity.

    .PARAMETER Location

    Azure Location to use for creating/saving/accessing resources (should be a valid location. Refer to https://azure.microsoft.com/en-us/regions/ for more details.)

    .PARAMETER VMName

    Azure Virtual Machine Name to use.
    
    .PARAMETER PublisherName

    Azure VM Image publihser name i.e MicrosoftWindowsServer, Canonical etc. Refer:https://azure.microsoft.com/en-in/documentation/articles/virtual-machines-linux-cli-deploy-templates/
    
    .PARAMETER OfferName

    Azure VM Image Offer name i.e WindowsServer, UbuntuServer etc. Refer Refer:https://azure.microsoft.com/en-in/documentation/articles/virtual-machines-linux-cli-deploy-templates/
    
    .PARAMETER SKUName

    Azure VM Imgae version name i.e 2012-R2-Datacenter, 12.04 LTS etc.

    .PARAMETER AdminUserName

    Login Administrator user name for the Virtual Machine. It should not be default usernames

    .PARAMETER AdminPassword

    Login Administrator Password for the Virtual Machine.

    .PARAMETER VMSize

    Azure Virtual Machine Size. Refer https://azure.microsoft.com/en-in/documentation/articles/virtual-machines-windows-sizes/

    .PARAMETER AvailabilitySetName

    Availability Set name to be used for this command

    .PARAMETER StorageAccountName 

    Name of the Storage Account that in which the VM disk is stored.

    .PARAMETER VirtualNetworkName

    Existing Virtual Network name in which the Virtual Machine will be deployed.

    .PARAMETER SubnetName

    Subnet name in the existing Virtual network in which the Virtual Machine will be deployed.

    .PARAMETER DNSNameForPublicIP

    Name for the Public IP Address which will be associated with the Virtual Machine.

    .PARAMETER ResourceGroupName

    Name of the Azure ARM resource group to use for this command.

    .PARAMETER DeploymentName

    Azure Deployment Name to use for this command.

    .PARAMETER TemplateJSONPath

    Path for JSON template file to create the Virtual Machine. 

    .PARAMETER ParameterJSONPath

    Path for JSON Parameter template file to create the Virtual Machine. 

    .INPUTS
    All parameter values in String format.

    .OUTPUTS
    String. Result of the command output.

    .NOTES
     Purpose of script: The script is to create VM from Azure Image Gallary
     Minimum requirements: PowerShell Version 1.2.1
     Initially written by: Bhaskar Desharaju
     Update/revision History:
     =======================
     Updated by    Date      Reason
     ==========    ====      ======

    .EXAMPLE
    C:\PS> .\Create-ARMVMFromGallaryImage.ps1 -ClientID 123456 -AzureUserName 'testlab@netenrich.com' -AzurePassword 'pass12@word' -AzureSubscriptionID 'ae7c7576-f01c-4026-9b94-d05e04e459fc' -Location 'Central US' -VMName MyAzureVM -PublisherName MicrosoftWindowsServer -OfferName WindowsServer -SKUName 2012-R2-Datacenter -AdminUserName azure-admin -AdminPassword P@ssW0rd -VmSize Basic_A0 -StorageAccountName mystorage -VirtualNetworkname MyVnet -Subnet InfraSubnet -DNSNameForPublicIP MyPIP -ResourceGroupName 'TestLabRG' -DeploymentName 'SavindraTestFromPS' -TemplateJSONPath '.\JsonTemplates\CreateVMFromGallaryImage.json' -ParameterJSONPath '.\JsonTemplates\CreateVMFromGallaryParam.json' -PerformanceTear 'Standard_LRS' -StorageAccountName 'JsnTmplStorAcPSTest' -WarningAction 'SilentlyContinue'

    This will create a Virtual Machine based on the template and parameter JSON files available at the given path.
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
    [string]$Location,
    
    [Parameter(ValueFromPipelineByPropertyName)]
    [string]$VMName,

    [Parameter(ValueFromPipelineByPropertyName)]
    [string]$PublisherName,
        
    [Parameter(ValueFromPipelineByPropertyName)]
    [string]$OfferName,
    
    [Parameter(ValueFromPipelineByPropertyName)]
    [string]$SKUName,
    
    [Parameter(ValueFromPipelineByPropertyName)]
    [string]$AdminUserName,

    [Parameter(ValueFromPipelineByPropertyName)]
    [string]$AdminPassword,
    
    [Parameter(ValueFromPipelineByPropertyName)]
    [string]$VMSize,

    [Parameter(ValueFromPipelineByPropertyName)]
    [string]$AvailabilitySetName,
    
    [Parameter(ValueFromPipelineByPropertyName)]
    [string]$StorageAccountName,
    
    [Parameter(ValueFromPipelineByPropertyName)]
    [string]$VirtualNetworkName,

    [Parameter(ValueFromPipelineByPropertyName)]
    [string]$SubnetName,

    [Parameter(ValueFromPipelineByPropertyName)]
    [string]$DNSNameForPublicIP,

    [Parameter(ValueFromPipelineByPropertyName)]
    [String]$ResourceGroupName,

    [Parameter(ValueFromPipelineByPropertyName)]
    [String]$DeploymentName,

    [Parameter(ValueFromPipelineByPropertyName)]
    [String]$TemplateJSONPath,

    [Parameter(ValueFromPipelineByPropertyName)]
    [String]$ParameterJSONPath
)

Begin
{
    # Supress warnings
    $OldWarningPreference = $WarningPreference
    $WarningPreference = 'SilentlyContinue'

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
       $ObjOut = "Required version of Azure PowerShell not available. Stopping execution.`nDownload and install required version from: http://aka.ms/webpi-azps.`
        `r`nRequired version of Azure PowerShell is $($ScriptUploadConfig.RequiredPSVersion). Current version on host machine is $($AzurePSVersion.ToString())."
        $output = (@{"Response" = [Array]$ObjOut; "Status" = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
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
                $output = (@{"Response" = [Array]$ObjOut; "Status" = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                Write-Output $output
                Exit
            }

            # Validate parameter: AzurePassword
            Write-LogFile -FilePath $LogFilePath -LogText "Validating Parameters: AzurePassword. Only ERRORs will be logged."
            If([String]::IsNullOrEmpty($AzurePassword))
            {
                Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. AzurePassword parameter value is empty.`r`n<#BlobFileReadyForUpload#>"
                $ObjOut = "Validation failed. AzurePassword parameter value is empty."
                $output = (@{"Response" = [Array]$ObjOut; "Status" = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                Write-Output $output
                Exit
            }

            # Validate parameter: AzureSubscriptionID
            Write-LogFile -FilePath $LogFilePath -LogText "Validating Parameters: AzureSubscriptionID. Only ERRORs will be logged."
            If([String]::IsNullOrEmpty($AzureSubscriptionID))
            {
                Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. AzureSubscriptionID parameter value is empty.`r`n<#BlobFileReadyForUpload#>"
                $ObjOut = "Validation failed. AzureSubscriptionID parameter value is empty."
                $output = (@{"Response" = [Array]$ObjOut; "Status" = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                Write-Output $output
                Exit
            }

            # Validate parameter: Location
            Write-LogFile -FilePath $LogFilePath -LogText "Validating Parameters: Location. Only ERRORs will be logged."
            If([String]::IsNullOrEmpty($Location))
            {
                Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. Location parameter value is empty.`r`n<#BlobFileReadyForUpload#>"
                $ObjOut = "Validation failed. Location parameter value is empty."
                $output = (@{"Response" = [Array]$ObjOut; "Status" = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                Write-Output $output
                Exit
            }

            # Validate parameter: VMName
            Write-LogFile -FilePath $LogFilePath -LogText "Validating Parameters: VMName. Only ERRORs will be logged."
            If([String]::IsNullOrEmpty($VMName))
            {
                Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. VMName parameter value is empty.`r`n<#BlobFileReadyForUpload#>"
                $ObjOut = "Validation failed. VMName parameter value is empty."
                $output = (@{"Response" = [Array]$ObjOut; "Status" = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                Write-Output $output
                Exit
            }

            # Validate parameter: PublisherName
            Write-LogFile -FilePath $LogFilePath -LogText "Validating Parameters: PublisherName. Only ERRORs will be logged."
            If([String]::IsNullOrEmpty($PublisherName))
            {
                Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. PublisherName parameter value is empty.`r`n<#BlobFileReadyForUpload#>"
                $ObjOut = "Validation failed. PublisherName parameter value is empty."
                $output = (@{"Response" = [Array]$ObjOut; "Status" = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                Write-Output $output
                Exit
            }
            Else
            {
                if($PublisherName -in ("OpenLogic","CoreOS","Canonical","MicrosoftWindowsServer","SUSE","Redhat"))
                {}
                else
                {
                    Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. Provided Publisher name $PublisherName is not valid.`r`n<#BlobFileReadyForUpload#>"
                    $ObjOut = "Validation failed. Provided Publisher name $PublisherName is not valid."
                    $output = (@{"Response" = [Array]$ObjOut; "Status" = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                    Write-Output $output
                    Exit
                }
            }

            # Validate parameter: OfferName
            Write-LogFile -FilePath $LogFilePath -LogText "Validating Parameters: OfferName. Only ERRORs will be logged."
            If([String]::IsNullOrEmpty($OfferName))
            {
                Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. OfferName parameter value is empty.`r`n<#BlobFileReadyForUpload#>"
                $ObjOut = "Validation failed. OfferName parameter value is empty."
                $output = (@{"Response" = [Array]$ObjOut; "Status" = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                Write-Output $output
                Exit
            }
            Else
            {
                if($OfferName -in ("CentOS","CoreOS","UbuntuServer","WindowsServer","openSUSE","RHEL"))
                {}
                else
                {
                    Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. Provided OfferName name $OfferName is not valid.`r`n<#BlobFileReadyForUpload#>"
                    $ObjOut = "Validation failed. Provided OfferName name $OfferName is not valid."
                    $output = (@{"Response" = [Array]$ObjOut; "Status" = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                    Write-Output $output
                    Exit
                }
            }

            # Validate parameter: SKUName
            Write-LogFile -FilePath $LogFilePath -LogText "Validating Parameters: SKUName. Only ERRORs will be logged."
            If([String]::IsNullOrEmpty($SKUName))
            {
                Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. SKUName parameter value is empty.`r`n<#BlobFileReadyForUpload#>"
                $ObjOut = "Validation failed. SKUName parameter value is empty."
                $output = (@{"Response" = [Array]$ObjOut; "Status" = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                Write-Output $output
                Exit
            }

            # Validate parameter: AdminUserName
            Write-LogFile -FilePath $LogFilePath -LogText "Validating Parameters: AdminUserName. Only ERRORs will be logged."
            If([String]::IsNullOrEmpty($AdminUserName))
            {
                Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. AdminUserName parameter value is empty.`r`n<#BlobFileReadyForUpload#>"
                $ObjOut = "Validation failed. AdminUserName parameter value is empty."
                $output = (@{"Response" = [Array]$ObjOut; "Status" = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                Write-Output $output
                Exit
            }
            Else
            {
                if($AdminUserName -in ("admin","Administrator"))
                {
                    Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. AdminUserName should not be default usernames.`r`n<#BlobFileReadyForUpload#>"
                    $ObjOut = "Validation failed. Validation failed. AdminUserName should not be default usernames."
                    $output = (@{"Response" = [Array]$ObjOut; "Status" = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                    Write-Output $output
                    Exit
                }
            }

            # Validate parameter: AdminPassword
            Write-LogFile -FilePath $LogFilePath -LogText "Validating Parameters: AdminPassword. Only ERRORs will be logged."
            If([String]::IsNullOrEmpty($AdminPassword))
            {
                Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. AdminPassword parameter value is empty.`r`n<#BlobFileReadyForUpload#>"
                $ObjOut = "Validation failed. AdminPassword parameter value is empty."
                $output = (@{"Response" = [Array]$ObjOut; "Status" = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                Write-Output $output
                Exit
            }
            else
            {
                if(!($AdminPassword -match ".{8,}"))
                {
                    Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. AdminPassword should be strong enough.`r`n<#BlobFileReadyForUpload#>"
                    $ObjOut = "Validation failed. AdminPassword should be strong enough."
                    $output = (@{"Response" = [Array]$ObjOut; "Status" = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                    Write-Output $output
                    Exit
                }
            }

            # Validate parameter: VMSize
            Write-LogFile -FilePath $LogFilePath -LogText "Validating Parameters: VMSize. Only ERRORs will be logged."
            If([String]::IsNullOrEmpty($VMSize))
            {
                Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. VMSize parameter value is empty.`r`n<#BlobFileReadyForUpload#>"
                $ObjOut = "Validation failed. VMSize parameter value is empty."
                $output = (@{"Response" = [Array]$ObjOut; "Status" = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                Write-Output $output
                Exit
            }
            
            # Validate parameter: AvailabilitySetName
            Write-LogFile -FilePath $LogFilePath -LogText "Validating Parameters: AvailabilitySetName. Only ERRORs will be logged."
            If([String]::IsNullOrEmpty($AvailabilitySetName))
            {
                Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. AvailabilitySetName parameter value is empty.`r`n<#BlobFileReadyForUpload#>"
                $ObjOut = "Validation failed. AvailabilitySetName parameter value is empty."
                $output = (@{"Response" = [Array]$ObjOut; "Status" = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                Write-Output $output
                Exit
            }

            # Validate parameter: DeploymentName
            Write-LogFile -FilePath $LogFilePath -LogText "Validating Parameters: DeploymentName. Only ERRORs will be logged."
            If([String]::IsNullOrEmpty($DeploymentName))
            {
                Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. DeploymentName parameter value is empty.`r`n<#BlobFileReadyForUpload#>"
                $ObjOut = "Validation failed. DeploymentName parameter value is empty."
                $output = (@{"Response" = [Array]$ObjOut; "Status" = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                Write-Output $output
                Exit
            }

            # Validate parameter: ResourceGroupName
            Write-LogFile -FilePath $LogFilePath -LogText "Validating Parameters: ResourceGroupName. Only ERRORs will be logged."
            If([String]::IsNullOrEmpty($ResourceGroupName))
            {
                Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. ResourceGroupName parameter value is empty.`r`n<#BlobFileReadyForUpload#>"
                $ObjOut = "Validation failed. ResourceGroupName parameter value is empty."
                $output = (@{"Response" = [Array]$ObjOut; "Status" = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                Write-Output $output
                Exit
            }
            
            # Validate parameter: StorageAccountName
            Write-LogFile -FilePath $LogFilePath -LogText "Validating Parameters: StorageAccountName. Only ERRORs will be logged."
            If([String]::IsNullOrEmpty($StorageAccountName))
            {
                Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. StorageAccountName parameter value is empty.`r`n<#BlobFileReadyForUpload#>"
                $ObjOut = "Validation failed. StorageAccountName parameter value is empty."
                $output = (@{"Response" = [Array]$ObjOut; "Status" = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                Write-Output $output
                Exit
            }
            Else
            {
                $Script:StorageAccountName = $StorageAccountName.ToLower()
            }

            # Validate parameter: VirtualNetworkName
            Write-LogFile -FilePath $LogFilePath -LogText "Validating Parameters: VirtualNetworkName. Only ERRORs will be logged."
            If([String]::IsNullOrEmpty($VirtualNetworkName))
            {
                Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. VirtualNetworkName parameter value is empty.`r`n<#BlobFileReadyForUpload#>"
                $ObjOut = "Validation failed. VirtualNetworkName parameter value is empty."
                $output = (@{"Response" = [Array]$ObjOut; "Status" = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                Write-Output $output
                Exit
            }

            # Validate parameter: SubnetName
            Write-LogFile -FilePath $LogFilePath -LogText "Validating Parameters: SubnetName. Only ERRORs will be logged."
            If([String]::IsNullOrEmpty($SubnetName))
            {
                Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. SubnetName parameter value is empty.`r`n<#BlobFileReadyForUpload#>"
                $ObjOut = "Validation failed. SubnetName parameter value is empty."
                $output = (@{"Response" = [Array]$ObjOut; "Status" = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                Write-Output $output
                Exit
            }   

            # Validate parameter: DNSNameForPublicIP
            Write-LogFile -FilePath $LogFilePath -LogText "Validating Parameters: DNSNameForPublicIP. Only ERRORs will be logged."
            If([String]::IsNullOrEmpty($DNSNameForPublicIP))
            {
                Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. DNSNameForPublicIP parameter value is empty.`r`n<#BlobFileReadyForUpload#>"
                $ObjOut = "Validation failed. DNSNameForPublicIP parameter value is empty."
                $output = (@{"Response" = [Array]$ObjOut; "Status" = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                Write-Output $output
                Exit
            } 
                
            # Validate parameter: TemplateJSONPath
            Write-LogFile -FilePath $LogFilePath -LogText "Validating Parameters: TemplateJSONPath. Only ERRORs will be logged."
            If([String]::IsNullOrEmpty($TemplateJSONPath))
            {
                Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. TemplateJSONPath parameter value is empty.`r`n<#BlobFileReadyForUpload#>"
                $ObjOut = "Validation failed. TemplateJSONPath parameter value is empty."
                $output = (@{"Response" = [Array]$ObjOut; "Status" = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                Write-Output $output
                Exit
            }
            Else
            {
                If(Test-Path $TemplateJSONPath) {}
                Else
                {
                    Write-LogFile -FilePath $LogFilePath -LogText "File/path not found '$TemplateJSONPath'.`r`n<#BlobFileReadyForUpload#>"
                    $ObjOut = "File/path not found '$TemplateJSONPath'."
                    $output = (@{"Response" = [Array]$ObjOut; "Status" = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                    Write-Output $output
                    Exit
                }
            }

            # Validate parameter: ParameterJSONPath
            Write-LogFile -FilePath $LogFilePath -LogText "Validating Parameters: ParameterJSONPath. Only ERRORs will be logged."
            If([String]::IsNullOrEmpty($ParameterJSONPath))
            {
                Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. ParameterJSONPath parameter value is empty.`r`n<#BlobFileReadyForUpload#>"
                $ObjOut = "Validation failed. ParameterJSONPath parameter value is empty."
                $output = (@{"Response" = [Array]$ObjOut; "Status" = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                Write-Output $output
                Exit
            }
            Else
            {
                If(Test-Path (Split-Path $ParameterJSONPath)) {}
                Else
                {
                    Write-LogFile -FilePath $LogFilePath -LogText "File/path not found '$ParameterJSONPath'. Creating folder/path."
                    Try
                    {
                        New-Item -Path (Split-Path $ParameterJSONPath) -ItemType Directory -Force
                        Write-LogFile -FilePath $LogFilePath -LogText "Created folder path '$ParameterJSONPath'."
                    }
                    Catch
                    {
                        $ObjOut = "Unable to create required folder/path '$ParameterJSONPath'."
                        $output = (@{"Response" = [Array]$ObjOut; "Status" = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                        Write-Output $output
                        Write-LogFile -FilePath $LogFilePath -LogText "Unable to create required folder/path '$ParameterJSONPath'`r`n<#BlobFileReadyForUpload#>"
                        Exit
                    }
                }
            }
        }
        Catch
        {
            Write-LogFile -FilePath $LogFilePath -LogText "Error while validating parameters: $($Error[0].Exception.Message)`r`n<#BlobFileReadyForUpload#>"
            $ObjOut = "Error while validating parameters: $($Error[0].Exception.Message)"
            $output = (@{"Response" = [Array]$ObjOut; "Status" = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
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
            $ObjOut = "Error logging in to Azure Account.`n$($Error[0].Exception.Message)."
            Write-LogFile -FilePath $LogFilePath -LogText "$ObjOut`r`n<#BlobFileReadyForUpload#>"
            $output = (@{"Response" = [Array]$ObjOut; "Status" = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
            Write-Output $output
            Exit
        }
    }
}
Process
{
    # 1.  Validating all Parameters
    Validate-AllParameters

    # 2. Login to Azure RM Account

    Login-ToAzureAccount

    # 3. Registering Azure Provider Namespaces
    Try
    {
        Write-LogFile -FilePath $LogFilePath -LogText "Registering the Azure resource providers." 

        # Required Provider name spaces as of now
        $ReqNameSpces = @("Microsoft.Compute","Microsoft.Storage","Microsoft.Network")
        foreach($NameSpace in $ReqNameSpces)
        {
            Write-LogFile -FilePath $LogFilePath -LogText "Registering the provider $NameSpace." 
            ($Status = Register-AzureRmResourceProvider -ProviderNamespace $NameSpace -ErrorAction Stop -WarningAction SilentlyContinue) | Out-Null
            If($Status)
            {
                Write-LogFile -FilePath $LogFilePath -LogText "Verifying the provider $NameSpace Registration."
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
                $output = (@{"Response" = [Array]$ObjOut; "Status" = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                Write-Output $output
                Exit
            }
        }
    }
    catch
    {
        $ObjOut = "Error while registering the Resource provide namespace.$($Error[0].Exception.Message)"
        $output = (@{"Response" = [Array]$ObjOut; "Status" = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
        Write-Output $output
        Write-LogFile -FilePath $LogFilePath -LogText "$ObjOut`r`n<#BlobFileReadyForUpload#>"
        Exit
    }

    # 3. Check if Resource Group exists. Create Resource Group if it does not exist.
    Try
    {
        Write-LogFile -FilePath $LogFilePath -LogText "Checking existance of resource group '$ResourceGroupName'"
        $ResourceGroup = $null
        ($ResourceGroup = Get-AzureRmResourceGroup -Name $ResourceGroupName -ErrorAction SilentlyContinue -WarningAction SilentlyContinue) | Out-Null
    
        If($ResourceGroup -ne $null) # Resource Group already exists
        {
            Write-LogFile -FilePath $LogFilePath -LogText "Resource Group already exists"
        }
        Else # Resource Group does not exist. Can't continue without creating resource group.
        {
            Try
            {
                Write-LogFile -FilePath $LogFilePath -LogText "Resource group $ResourceGroupName does not exist. Creating resource group."
                ($ResourceGroup = New-AzureRmResourceGroup -Name $ResourceGroupName -Location $Location -ErrorAction Stop -WarningAction SilentlyContinue) | Out-Null
                Write-LogFile -FilePath $LogFilePath -LogText "Resource group $ResourceGroupName created"
            }
            Catch
            {
                $ObjOut = "Error while creating Azure Resource Group '$ResourceGroupName'.$($Error[0].Exception.Message)"
                $output = (@{"Response" = [Array]$ObjOut; "Status" = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                Write-Output $output
                Write-LogFile -FilePath $LogFilePath -LogText "$ObjOut`r`n<#BlobFileReadyForUpload#>"
                Exit
            }
        }
    }
    Catch
    {
        $ObjOut = "Error while getting Azure Resource Group details.$($Error[0].Exception.Message)"
        $output = (@{"Response" = [Array]$ObjOut; "Status" = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
        Write-Output $output
        Write-LogFile -FilePath $LogFilePath -LogText "$ObjOut`r`n<#BlobFileReadyForUpload#>"
        Exit
    }

    # 4. Checking whether the given location suports the VM Size
    try
    {
        # Checking whether the given location supports the given VMSize
        Write-LogFile -FilePath $LogFilePath -LogText "Checking for supported VM Size $VMSize in the given location."
        $AvailableSizes = $null
        ($AvailableSizes = Get-AzureRmVMSize -Location $Location -ErrorAction SilentlyContinue -WarningAction SilentlyContinue) | Out-Null
        if($AvailableSizes -and $AvailableSizes.Name.Contains($VMSize))
        {
            Write-LogFile -FilePath $LogFilePath -LogText "The location supports the given size."
        }
        Else
        {
            Write-LogFile -FilePath $LogFilePath -LogText "The location does not support the given VMSize.`r`n<#BlobFileReadyForUpload#>" 
            $ObjOut = "Validation failed. The location does not support the given VMSize."
            $output = (@{"Response" = [Array]$ObjOut; "Status" = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
            Write-Output $output
            Exit
        }
    }
    catch
    {
        $ObjOut = "Error while getting Azure vm sizes for the locaion. $($Error[0].Exception.Message)"
        $output = (@{"Response" = [Array]$ObjOut; "Status" = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
        Write-Output $output
        Write-LogFile -FilePath $LogFilePath -LogText "$ObjOut`r`n<#BlobFileReadyForUpload#>"
        Exit
    }

    # 5. Checking for the Virtual Network and Subnet existence
    Try
    {
        Write-LogFile -FilePath $LogFilePath -LogText "Checking for the existence of Virtual Network $VirtualNetworkName in the given $ResourceGroupName resource group."
        $VnetExist = $null
        ($VnetExist = Get-AzureRmVirtualNetwork -Name $VirtualNetworkName -ResourceGroupName $ResourceGroupName -ErrorAction SilentlyContinue -WarningAction SilentlyContinue) | Out-Null
        if($VnetExist)
        {
             Write-LogFile -FilePath $LogFilePath -LogText "The given Vnet is already exists."
             Write-LogFile -FilePath $LogFilePath -LogText "Checking for the existence of Virtual Network $SubnetName in the given $VirtualNetworkName Virtual Network group."
             $ExistingSubnets = @()
             $ExistingSubnets = $VnetExist.Subnets.Name
             if($ExistingSubnets -and $ExistingSubnets.Contains($SubnetName))
             {
                Write-LogFile -FilePath $LogFilePath -LogText "The given Subnet is already exists in $VirtualNetworkName."
             }
             else
             {
                Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. The Provided Subnet does not exist in given virtual Network $VirtualNetworkName.`r`n<#BlobFileReadyForUpload#>"
                $ObjOut = "Validation failed. The Provided Subnet does not exist in given virtual Network $VirtualNetworkName."
                $output = (@{"Response" = [Array]$ObjOut; "Status" = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                Write-Output $output
                Exit
             }
        }
        else
        {
            Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. The Provided virtual Network does not exist in the $ResourceGroupName resource group.`r`n<#BlobFileReadyForUpload#>"
            $ObjOut = "Validation failed. The Provided virtual Network does not exist in the $ResourceGroupName resource group."
            $output = (@{"Response" = [Array]$ObjOut; "Status" = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
            Write-Output $output
            Exit
        }   
    }
    catch
    {
        $ObjOut = "Error while getting Azure Virtual Network details.$($Error[0].Exception.Message)"
        $output = (@{"Response" = [Array]$ObjOut; "Status" = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
        Write-Output $output
        Write-LogFile -FilePath $LogFilePath -LogText "$ObjOut`r`n<#BlobFileReadyForUpload#>"
        Exit
    }

    # 6. Checking for the Storage Account existence
    Try
    {
        Write-LogFile -FilePath $LogFilePath -LogText "Checking for the existence of Storage Account $StorageAccountName in the given $ResourceGroupName resource group."
        $StorageAcExist = $null
        ($StorageAcExist = Get-AzureRmStorageAccount -Name $StorageAccountName -ResourceGroupName $ResourceGroupName -ErrorAction SilentlyContinue -WarningAction SilentlyContinue) | Out-Null
        if($StorageAcExist)
        {
             Write-LogFile -FilePath $LogFilePath -LogText "The given Storage Account is already exists"
        }
        else
        {
            Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. The Provided Storage Account does not exist in the $ResourceGroupName resource group.`r`n<#BlobFileReadyForUpload#>"
            $ObjOut = "Validation failed. The Provided Storage Account does not exist in the $ResourceGroupName resource group."
            $output = (@{"Response" = [Array]$ObjOut; "Status" = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
            Write-Output $output
            Exit
        }   
    }
    catch
    {
        $ObjOut = "Error while getting Azure Storage Account details.$($Error[0].Exception.Message)"
        $output = (@{"Response" = [Array]$ObjOut; "Status" = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
        Write-Output $output
        Write-LogFile -FilePath $LogFilePath -LogText "$ObjOut`r`n<#BlobFileReadyForUpload#>"
        Exit
    }

    # 7. Checking for the Public IP Existence
    Try
    {
        Write-LogFile -FilePath $LogFilePath -LogText "Checking for the Public IP Address $DNSNameForPublicIP."
        ($PublicIPObj = Get-AzureRmPublicIpAddress -Name $DNSNameForPublicIP -ResourceGroupName $ResourceGroupName -ErrorAction SilentlyContinue -WarningAction SilentlyContinue) | Out-Null
        if($PublicIPObj -ne $null)
        {
            Write-LogFile -FilePath $LogFilePath -LogText "The Public IP Address $DNSNameForPublicIP is already exist. Checking for its availability."
            if($PublicIPObj.IpConfiguration -ne $null)
            {
                Write-LogFile -FilePath $LogFilePath -LogText "The Public IP Address Name $DNSNameForPublicIP is already in Use.`r`n<#BlobFileReadyForUpload#>"
                $ObjOut = "The Public IP Address Name $DNSNameForPublicIP is already in Use."
                $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                Write-Output $output
                Exit                    
            }Else{ }
        }
    }
    Catch
    {
        $ObjOut = "Error while Checking the $DNSNameForPublicIP Public IP details.$($Error[0].Exception.Message)"
        $output = (@{"Response" = [Array]$ObjOut; "Status" = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
        Write-Output $output
        Write-LogFile -FilePath $LogFilePath -LogText "$ObjOut`r`n<#BlobFileReadyForUpload#>"
        Exit
    }

    # 8. Create Virtual Machine using Image from Gallary
    try
    {
        # Creating the Parameter File for Virtual Machine creation
        $OSDiskName = $VMName + "_OSDisk"
        $NICName = $VMName+"_NIC"
        $ParameterJSONText = @"
{
    "`$schema": "http://schema.management.azure.com/schemas/2015-01-01/deploymentParameters.json#",
    "contentVersion": "1.0.0.0",
    "parameters": {
                        "adminUsername": {"value":"$AdminUserName"},
                        "adminPassword":{"value":"$AdminPassword"},
                        "dnsNameForPublicIP": {"value":"$DNSNameForPublicIP"},
                        "location": {"value":"$Location"},
                        "imagePublisher":{"value":"$PublisherName"},
                        "imageOffer":{"value":"$OfferName"},
                        "windowsOSVersion":{"value":"$SKUName"},
                        "vmName":{"value":"$VMName"},
                        "vmSize":{"value":"$VMSize"},
                        "virtualNetworkName":{"value":"$VirtualNetworkName"},
                        "nicName":{"value":"$NICName"},
                        "OSDiskName":{"value":"$OSDiskName"},
                        "SubnetName":{"value":"$SubnetName"},
                        "storageAccountName":{"value":"$StorageAccountName"},
                        "availabilitySet":{"value":"$AvailabilitySetName"}
                  }
}
"@
    ($ParameterJSONText | Out-File -FilePath $ParameterJSONPath -ErrorAction Stop) | Out-Null

        Write-LogFile -FilePath $LogFilePath -LogText "Provisioning the Virtual Machine $VMName."
        ($Status = New-AzureRmResourceGroupDeployment -Name $DeploymentName -ResourceGroupName $ResourceGroupName -TemplateFile $TemplateJSONPath -TemplateParameterFile $ParameterJSONPath -ErrorAction Stop -WarningAction SilentlyContinue) | Out-Null
        if($Status.ProvisioningState -eq 'Succeeded')
        {
            Write-LogFile -FilePath $LogFilePath -LogText "Virtual Machine $VMName has been provisioned successfully."
            $ObjOut = "Virtual Machine $VMName has been provisioned successfully."
            $output = (@{"Response" = [Array]$ObjOut; "Status" = "Success"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
            Write-Output $output
        }
        else
        {
            Write-LogFile -FilePath $LogFilePath -LogText "Virtual Machine $VMName has not been provisioned successfully.`r`n<#BlobFileReadyForUpload#>"
            $ObjOut = "Virtual Machine $VMName has not been provisioned successfully."
            $output = (@{"Response" = [Array]$ObjOut; "Status" = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
            Write-Output $output
            exit
        }
    }
    Catch
    {
        $ObjOut = "Error while provisioining the virtual machine $VMName.$($Error[0].Exception.Message)"
        $output = (@{"Response" = [Array]$ObjOut; "Status" = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
        Write-Output $output
        Write-LogFile -FilePath $LogFilePath -LogText "$ObjOut`r`n<#BlobFileReadyForUpload#>"
        Exit
    }
}
End
{
    Write-LogFile -FilePath $LogFilePath -LogText "####[ Script execution completed cuccessfully: $($MyInvocation.MyCommand.Name) ]####`r`n<#BlobFileReadyForUpload#>"
}
