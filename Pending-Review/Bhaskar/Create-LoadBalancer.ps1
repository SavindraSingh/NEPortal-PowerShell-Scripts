<#
    .SYNOPSIS
    Script to create New Azure Load Balancer

    .DESCRIPTION
    Script to create New Azure Load Balancer

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

    .PARAMETER ResourceGroupName

    Name of the Azure ARM resource group to use for this command.

    .PARAMETER LoadBalancerName

    Name of the LoadBalacerName to be used for this command.

    .PARAMETER LoadBalancerType

    Type of the load balancer to use for this command. e.g Public, Internal

    .PARAMETER PublicIPAddressName

    Name of the Public IP Address to be used for this command. However this is required if the LoadBalancerType is Public.

    .PARAMETER VirtualNetworkName

    Name of the Azure Virtual Network to be used for this command.However this is required if the LoadBalancerType is Internal.

    .PARAMETER SubnetName

    Name of the Azure Virtual Network Subnet to be used for this command.However this is required if the LoadBalancerType is Internal.

    .PARAMETER IPAddressType

    Type of the IP Address to be used for this command. e.g Static, Dynamic.However this is required if the LoadBalancerType is Internal.

    .PARAMETER StaticIPAddress

    Static IP Address to be used for this command.

    .INPUTS
    All parameter values in String format.

    .OUTPUTS
    String. Result of the command output.

    .NOTES
     Purpose of script: Template for Azure Scripts
     Minimum requirements: Azure PowerShell Version 1.4.0
     Initially written by: Bhaskar Desharaju
     Update/revision History:
     =======================
     Updated by        Date            Reason
     ==========        ====            ======
     SavindraSingh     26-May-16       Changed Mandatory=$True to Mandatory=$False for all parameters.
     SavindraSingh     21-Jul-16       1. Added Login function in Begin block, instead of commands in Process block.
                                       2. Check minumum required version of Azure PowerShell

    .EXAMPLE
    C:\PS> 


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
    [string]$Location,

    [Parameter(ValueFromPipelineByPropertyName)]
    [String]$ResourceGroupName,

    [Parameter(ValueFromPipelineByPropertyName)]
    [String]$LoadBalancerName,

    [Parameter(ValueFromPipelineByPropertyName)]
    [String]$LoadBalancerType,

    [Parameter(ValueFromPipelineByPropertyName)]
    [String]$PublicIPAddressName,

    [Parameter(ValueFromPipelineByPropertyName)]
    [String]$VirtualNetworkName,

    [Parameter(ValueFromPipelineByPropertyName)]
    [String]$SubnetName,

    [Parameter(ValueFromPipelineByPropertyName)]
    [String]$IPAddressType,

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
    If($AzurePSVersion.Major -ge 1 -and $AzurePSVersion.Minor -ge 4)
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
               
            # Validate parameter: LoadBalancerName
            Write-LogFile -FilePath $LogFilePath -LogText "Validating Parameters: LoadBalancerName. Only ERRORs will be logged."
            If([String]::IsNullOrEmpty($LoadBalancerName))
            {
                Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. LoadBalancerName parameter value is empty.`r`n<#BlobFileReadyForUpload#>"
                $ObjOut = "Validation failed. LoadBalancerName parameter value is empty."
                $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                Write-Output $output
                Exit
            }

            # Validate parameter: LoadBalancerType
            Write-LogFile -FilePath $LogFilePath -LogText "Validating Parameters: LoadBalancerType. Only ERRORs will be logged."
            If([String]::IsNullOrEmpty($LoadBalancerType))
            {
                Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. LoadBalancerType parameter value is empty.`r`n<#BlobFileReadyForUpload#>"
                $ObjOut = "Validation failed. LoadBalancerType parameter value is empty."
                $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                Write-Output $output
                Exit
            }
            Else
            {
                Write-LogFile -FilePath $LogFilePath -LogText "Validating if LoadBalancerType is valid Load Balancer Type. Only ERRORs will be logged."
                if($LoadBalancerType -notin ('Public','Internal'))
                {
                    Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. LoadBalancerType is not a valid type.`r`n<#BlobFileReadyForUpload#>"
                    $ObjOut = "Validation failed. LoadBalancerType is not a valid type."
                    $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                    Write-Output $output
                    Exit
                }
            }

            # Validate parameter: PublicIPAddressName
            Write-LogFile -FilePath $LogFilePath -LogText "Validating Parameters: PublicIPAddressName. Only ERRORs will be logged."
            If([String]::IsNullOrEmpty($PublicIPAddressName))
            {
                Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. PublicIPAddressName parameter value is empty.`r`n<#BlobFileReadyForUpload#>"
                $ObjOut = "Validation failed. PublicIPAddressName parameter value is empty."
                $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                Write-Output $output
                Exit
            }
               
            # Validate parameter: VirtualNetworkName
            Write-LogFile -FilePath $LogFilePath -LogText "Validating Parameters: VirtualNetworkName. Only ERRORs will be logged."
            If([String]::IsNullOrEmpty($VirtualNetworkName))
            {
                Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. VirtualNetworkName parameter value is empty.`r`n<#BlobFileReadyForUpload#>"
                $ObjOut = "Validation failed. VirtualNetworkName parameter value is empty."
                $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                Write-Output $output
                Exit
            }

            # Validate parameter: SubnetName
            Write-LogFile -FilePath $LogFilePath -LogText "Validating Parameters: SubnetName. Only ERRORs will be logged."
            If([String]::IsNullOrEmpty($SubnetName))
            {
                Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. SubnetName parameter value is empty.`r`n<#BlobFileReadyForUpload#>"
                $ObjOut = "Validation failed. SubnetName parameter value is empty."
                $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                Write-Output $output
                Exit
            }
            
            # Validate parameter: IPAddressType
            Write-LogFile -FilePath $LogFilePath -LogText "Validating Parameters: IPAddressType. Only ERRORs will be logged."
            If([String]::IsNullOrEmpty($IPAddressType))
            {
                Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. IPAddressType parameter value is empty.`r`n<#BlobFileReadyForUpload#>"
                $ObjOut = "Validation failed. IPAddressType parameter value is empty."
                $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                Write-Output $output
                Exit
            }
            Else
            {
                Write-LogFile -FilePath $LogFilePath -LogText "Validating if IPAddressType is a valid Type. Only ERRORs will be logged."
                if($IPAddressType -notin ('Dynamic','Static'))
                {
                    Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. IPAddressType is not a valid type.`r`n<#BlobFileReadyForUpload#>"
                    $ObjOut = "Validation failed. IPAddressType is not a valid type."
                    $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                    Write-Output $output
                    Exit
                }                
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
    # 1. Validating Parameters
    Validate-AllParameters

    # 2. Login to Azure subscription
    Login-ToAzureAccount

    # 3. Registering Azure Provider Namespaces
    Try
    {
        Write-LogFile -FilePath $LogFilePath -LogText "Registering the Azure resource providers." 
        # Required Provider name spaces as of now
        $ReqNameSpces = @("Microsoft.Compute","Microsoft.Storage","Microsoft.Network")
        foreach($NameSpace in $ReqNameSpces)
        {
            Write-LogFile -FilePath $LogFilePath -LogText "Registering the provider $NameSpace" 
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
                $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                Write-Output $output
                Exit
            }
        }
    }
    catch
    {
        $ObjOut = "Error while registering the Resource provide namespace.$($Error[0].Exception.Message)"
        $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
        Write-Output $output
        Write-LogFile -FilePath $LogFilePath -LogText "$ObjOut`r`n<#BlobFileReadyForUpload#>"
        Exit
    }

    # 4. Check if Resource Group exists. Create Resource Group if it does not exist.
    Try
    {
        Write-LogFile -FilePath $LogFilePath -LogText "Checking existance of resource group $ResourceGroupName"
        $ResourceGroup = $null
        ($ResourceGroup = Get-AzureRmResourceGroup -Name $ResourceGroupName -ErrorAction SilentlyContinue) | Out-Null
    
        If($ResourceGroup -ne $null) # Resource Group already exists
        {
           Write-LogFile -FilePath $LogFilePath -LogText "Resource Group already exists"
        }
        Else # Resource Group does not exist. Can't continue without creating resource group.
        {
            Try
            {
                Write-LogFile -FilePath $LogFilePath -LogText "Resource group $ResourceGroupName does not exist. Creating resource group."
                ($ResourceGroup = New-AzureRmResourceGroup -Name $ResourceGroupName -Location $Location) | Out-Null
                Write-LogFile -FilePath $LogFilePath -LogText "Resource group '$ResourceGroupName' created"
            }
            Catch
            {
                $ObjOut = "Error while creating Azure Resource Group '$ResourceGroupName'.`r`n$($Error[0].Exception.Message)"
                $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                Write-Output $output
                Write-LogFile -FilePath $LogFilePath -LogText "$ObjOut`r`n<#BlobFileReadyForUpload#>"
                Exit
            }
        }
    }
    Catch
    {
        $ObjOut = "Error while getting Azure Resource Group details.$($Error[0].Exception.Message)"
        $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
        Write-Output $output
        Write-LogFile -FilePath $LogFilePath -LogText "$ObjOut"
        Exit
    }

    # 5. Checking for the Public IP Provided, It will create one if not exist.
    Try
    {
        Write-LogFile -FilePath $LogFilePath -LogText "Checking existance of Public IP Name $PublicIPAddressName."
        $PublicIP = $null
        ($PublicIP = Get-AzureRmPublicIpAddress -Name $PublicIPAddressName -ResourceGroupName $ResourceGroupName -ErrorAction Continue -WarningAction SilentlyContinue) | Out-Null
        if($PublicIP -ne $null)
        {
            Write-LogFile -FilePath $LogFilePath -LogText "The Public IP Name $PublicIPAddressName is already exists."
            Write-LogFile -FilePath $LogFilePath -LogText "Checking for $PublicIPAddressName availability."
            if($PublicIP.IpConfiguration -ne $null)
            {
                Write-LogFile -FilePath $LogFilePath -LogText "The Public Ip address is already associated with $($PublicIP.IpConfiguration.Name) resource.`r`n<#BlobFileReadyForUpload#>"
                $ObjOut = "The Public Ip address is already associated with $($PublicIP.IpConfiguration.Name) resource."
                $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                Write-Output $output
                Exit
            }
            else
            {
                Write-LogFile -FilePath $LogFilePath -LogText "The public IP address is $PublicIPAddressName available for associating with load balancer.`r`n<#BlobFileReadyForUpload#>"
                $ObjOut = "The public IP address is $PublicIPAddressName available for associating with load balancer."
                $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                Write-Output $output
            }
        }
        else
        {
            Write-LogFile -FilePath $LogFilePath -LogText "The Public IP Name $PublicIPAddressName does not exist.Creating a new Public IP Address."
            ($NewIP = New-AzureRmPublicIpAddress -Name $PublicIPAddressName -ResourceGroupName $ResourceGroupName -Location $Location -AllocationMethod Dynamic -IpAddressVersion IPv4 -ErrorAction Stop -WarningAction SilentlyContinue) | Out-Null
            if($NewIP.ProvisioningState -eq 'Succeeded')
            {
                 Write-LogFile -FilePath $LogFilePath -LogText "The Public IP Name $PublicIPAddressName has been created successfully."
            }
            Else
            {
                Write-LogFile -FilePath $LogFilePath -LogText "Creation failed. Unable to create $PublicIPAddressName.`r`n<#BlobFileReadyForUpload#>"
                $ObjOut = "Creation failed. Unable to create $PublicIPAddressName."
                $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                Write-Output $output
                Exit
            }
        }
    }
    Catch
    {
        $ObjOut = "Error while checking/creating the Public IP address.$($Error[0].Exception.Message)"
        $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
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
                Write-LogFile -FilePath $LogFilePath -LogText "The given Subnet $SubnetName is already exists in $VirtualNetworkName."
             }
             else
             {
                Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. The Provided Subnet does not exist in given virtual Network $VirtualNetworkName.`r`n<#BlobFileReadyForUpload#>"
                $ObjOut = "Validation failed. The Provided Subnet does not exist in given virtual Network $VirtualNetworkName."
                $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                Write-Output $output
                Exit
             }
        }
        else
        {
            Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. The Provided virtual Network does not exist in the $ResourceGroupName resource group.`r`n<#BlobFileReadyForUpload#>"
            $ObjOut = "Validation failed. The Provided virtual Network does not exist in the $ResourceGroupName resource group."
            $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
            Write-Output $output
            Exit
        }   
    }
    catch
    {
        $ObjOut = "Error while getting Azure Virtual Network details.$($Error[0].Exception.Message)"
        $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
        Write-Output $output
        Write-LogFile -FilePath $LogFilePath -LogText "$ObjOut`r`n<#BlobFileReadyForUpload#>"
        Exit
    }

    # 7. Creating the Loadbalancer
    Try
    {
        Write-LogFile -FilePath $LogFilePath -LogText "Checking for the Load Balancer $LoadBalancerName exitence."
        $LoadBalancerExistence = $null
        ($LoadBalancerExistence = Get-AzureRmLoadBalancer -Name $LoadBalancerName -ResourceGroupName $ResourceGroupName -ErrorAction SilentlyContinue -WarningAction SilentlyContinue) | Out-Null
        if($LoadBalancerExistence -eq $null)
        {
            Write-LogFile -FilePath $LogFilePath -LogText "The Load Balancer $LoadBalancerName does not exist. Creating the new load balancer."            
            $FronEndRuleName = $LoadBalancerName + "_FrontEnd"
            if($LoadBalancerType -eq 'Public')
            {
                Write-LogFile -FilePath $LogFilePath -LogText "Fetching the Public IP $PublicIPAddressName details to create Public facing Load Balancer $LoadBalancerName."  
                ($PublicIPObj = Get-AzureRmPublicIpAddress -Name $PublicIPAddressName -ResourceGroupName $ResourceGroupName -ErrorAction SilentlyContinue -WarningAction SilentlyContinue) | Out-Null
                if($PublicIPObj -ne $null)
                {
                    Write-LogFile -FilePath $LogFilePath -LogText "Creating the Load Balancer Front end configuration."  
                    ($FronEndRule = New-AzureRmLoadBalancerFrontendIpConfig -Name $FronEndRuleName -PublicIpAddress $PublicIPObj -ErrorAction Stop -WarningAction SilentlyContinue) | Out-Null
                     Write-LogFile -FilePath $LogFilePath -LogText "Creating the Public facing load balancer $LoadBalancerName with Public IP $PublicIPAddressName."
                    ($LoadBalancer = New-AzureRmLoadBalancer -Name $LoadBalancerName -ResourceGroupName $ResourceGroupName -Location $Location -FrontendIpConfiguration $FronEndRule -ErrorAction Stop -WarningAction SilentlyContinue)| Out-Null
                    if($LoadBalancer.ProvisioningState -eq 'Succeeded')
                    {
                        Write-LogFile -FilePath $LogFilePath -LogText "Load Balancer $LoadBalancerName has been created successfully."
                        $ObjOut = "Load Balancer $LoadBalancerName has been created successfully."
                        $output = (@{"Response" = [Array]$ObjOut; "Status" = "Success"} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                        Write-Output $output                       
                    }
                    Else
                    {
                        Write-LogFile -FilePath $LogFilePath -LogText "Load Balancer $LoadBalancerName has not been created successfully.`r`n<#BlobFileReadyForUpload#>"
                        $ObjOut = "Load Balancer $LoadBalancerName has not been created successfully."
                        $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                        Write-Output $output
                        Exit 
                    }
                }
                else
                {
                    Write-LogFile -FilePath $LogFilePath -LogText "The provided Public IP address $PublicIPAddressName are not available.`r`n<#BlobFileReadyForUpload#>"
                    $ObjOut = "The provided Public IP address $PublicIPAddressName are not available."
                    $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                    Write-Output $output
                    Exit 
                }
            }
            Else
            {
                Write-LogFile -FilePath $LogFilePath -LogText "Fetching the Subnet $SubnetName details to create Internal Load Balancer $LoadBalancerName."  
                $SubnetObj = Get-AzureRmVirtualNetworkSubnetConfig -Name $SubnetName -VirtualNetwork $VnetExist
                if($SubnetObj -ne $null)
                {
                    if($IPAddressType -eq 'Static')
                    {
                        Write-LogFile -FilePath $LogFilePath -LogText "Creating the Internal Loadbalancer $LoadBalancerName with Static IP address $StaticIPAddress."  
                        ($FronEndRule = New-AzureRmLoadBalancerFrontendIpConfig -Name $FronEndRuleName -Subnet $SubnetObj -PrivateIpAddress $StaticIPAddress -ErrorAction Stop -WarningAction SilentlyContinue) | Out-Null
                        ($LoadBalancer = New-AzureRmLoadBalancer -Name $LoadBalancerName -ResourceGroupName $ResourceGroupName -Location $Location -FrontendIpConfiguration $FronEndRule -ErrorAction Stop -WarningAction SilentlyContinue)| Out-Null                        
                    }
                    Else
                    {
                        Write-LogFile -FilePath $LogFilePath -LogText "Creating the Internal Loadbalancer $LoadBalancerName with dynamic IP address from $SubnetName subnet."  
                        ($FronEndRule = New-AzureRmLoadBalancerFrontendIpConfig -Name $FronEndRuleName -Subnet $SubnetObj -ErrorAction Stop -WarningAction SilentlyContinue) | Out-Null
                        ($LoadBalancer = New-AzureRmLoadBalancer -Name $LoadBalancerName -ResourceGroupName $ResourceGroupName -Location $Location -FrontendIpConfiguration $FronEndRule -ErrorAction Stop -WarningAction SilentlyContinue)| Out-Null
                    }
                    if($LoadBalancer.ProvisioningState -eq 'Succeeded')
                    {
                        Write-LogFile -FilePath $LogFilePath -LogText "Load balancer $LoadBalancerName has been created successfully.`r`n<#BlobFileReadyForUpload#>"
                        $ObjOut = "Load balancer $LoadBalancerName has been created successfully."
                        $output = (@{"Response" = [Array]$ObjOut; "Status" = "Success"} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                        Write-Output $output                 
                    }
                    Else
                    {
                        Write-LogFile -FilePath $LogFilePath -LogText "Load balancer $LoadBalancerName has not been created successfully.`r`n<#BlobFileReadyForUpload#>"
                        $ObjOut = "Load balancer $LoadBalancerName has not been created successfully."
                        $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                        Write-Output $output
                        Exit 
                    }
                }
                Else
                {
                    Write-LogFile -FilePath $LogFilePath -LogText "The provided subnet $SubnetName details were not found.`r`n<#BlobFileReadyForUpload#>"
                    $ObjOut = "The provided subnet $SubnetName details were not found."
                    $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                    Write-Output $output
                    Exit 
                }
            }
        }
        else
        {
            Write-LogFile -FilePath $LogFilePath -LogText "Load Balander is already exist with this name $LoadBalancerName.`r`n<#BlobFileReadyForUpload#>"
            $ObjOut = "Load Balander is already exist with this name $LoadBalancerName."
            $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
            Write-Output $output
            Exit
        }  
    }
    Catch
    {
        $ObjOut = "Error while Creating the load balancer $LoadBalancerName.$($Error[0].Exception.Message)"
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