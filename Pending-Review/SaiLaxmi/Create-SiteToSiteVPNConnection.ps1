<#
    .SYNOPSIS
    Script to create Site-to-Site VPN Connection between Virtual Network Gateway and Local Network Gateway

    .DESCRIPTION
    Script to create Site-to-Site VPN Connection between Virtual Network Gateway and Local Network Gateway

    .PARAMETER ClientID
    ClientID of the client for whom the script is being executed.

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

    .PARAMETER VirtualNetworkName
    Name of the Virtual Network Name

    .PARAMETER LocalNetworkGatewayName
    Name of the Local Network Gateway Name

    .PARAMETER LocalNetworkGatewayIPAddress
    Give the Local Network Gateway IP

    .PARAMETER LocalNetworkGatewayAddressPrefix
    Give the Local Network IP Address Range

    .PARAMETER VirtualNetworkGatewayName
     Name of the Virtual Network Gateway Name

    .PARAMETER VirtualNetworkGatewaySku
    Give either Basic,Standard or HighPerformance

    .PARAMETER RoutingWeight
    Give the Routing Weight

    .PARAMETER Sharedkey
    Give a Sharedkey for VPN Connection between Local and Virtual Network Gateways.It must be combination of characters and integers.
    Not Special Characters.

    .INPUTS
    C:\PS> .\Create-SiteToSiteVPNConnection.ps1 -ClientID 1235 -AzureUserName sailakshmi.penta@netenrich.com -AzurePassword ********* 
    -AzureSubscriptionID ca68598c-ecc3-4abc-b7a2-1ecef33f278d -Location "Southeast Asia" -ResourceGroupName samplerg123 
    -VirtualNetworkName samplevnet1234 -LocalNetworkGatewayName samplelocalgw -LocalNetworkGatewayIPAddress 23.98.75.63 
    -LocalNetworkGatewayAddressPrefix '172.18.1.0/24' -VirtualNetworkGatewayName samplevnetgw1234 -VirtualNetworkGatewaySku Standard 
    -RoutingWeight 10 -Sharedkey 'abc123' 

    .OUTPUTS
    
    {
        "Status":  "Success",
        "BlobURI":  "https://nelogfiles.blob.core.windows.net/neportallogs/1235-Create-SiteToSiteVPNConnection-10-Aug-2016_145439.log",
        "Response":  [
                         "Successfully created Virtual Network Gateway 'samplevnetgw1234' and Local Network Gateway 'samplelocalg
    w'.Created VPN Connection 'samplevnet1234VPNConnection' between them."
                     ]
    }

    .NOTES
     Purpose of script: Template for Azure Scripts to create Site-to-Site VPN Connection between Virtual Network Gateway and Local Network Gateway
     Minimum requirements: Azure PowerShell Version 1.4.0
     Initially written by: P S L Prasanna
     Update/revision History:
     =======================
     Updated by        Date            Reason
     ==========        ====            ======
     
    .EXAMPLE
    C:\PS> .\Create-SiteToSiteVPNConnection.ps1 -ClientID 1235 -AzureUserName sailakshmi.penta@netenrich.com -AzurePassword ********* 
    -AzureSubscriptionID ca68598c-ecc3-4abc-b7a2-1ecef33f278d -Location "Southeast Asia" -ResourceGroupName samplerg123 
    -VirtualNetworkName samplevnet1234 -LocalNetworkGatewayName samplelocalgw -LocalNetworkGatewayIPAddress 23.98.75.63 
    -LocalNetworkGatewayAddressPrefix '172.18.1.0/24' -VirtualNetworkGatewayName samplevnetgw1234 -VirtualNetworkGatewaySku Standard 
    -RoutingWeight 10 -Sharedkey 'abc123' 
    WARNING: The output object type of this cmdlet will be modified in a future release.
    {
        "Status":  "Success",
        "BlobURI":  "https://nelogfiles.blob.core.windows.net/neportallogs/1235-Create-SiteToSiteVPNConnection-10-Aug-2016_145439.log",
        "Response":  [
                         "Successfully created Virtual Network Gateway 'samplevnetgw1234' and Local Network Gateway 'samplelocalg
    w'.Created VPN Connection 'samplevnet1234VPNConnection' between them."
                     ]
    }

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
    [String]$VirtualNetworkName,
    
    [Parameter(ValueFromPipelineByPropertyName)]
    [String]$LocalNetworkGatewayName,
    
    [Parameter(ValueFromPipelineByPropertyName)]
    [String]$LocalNetworkGatewayIPAddress,
   
    [Parameter(ValueFromPipelineByPropertyName,HelpMessage="'10.0.0.1/16','10.0.0.2/16'")]
    [String]$LocalNetworkGatewayAddressPrefix,

    [Parameter(ValueFromPipelineByPropertyName)]
    [String]$VirtualNetworkGatewayName,

    [Parameter(ValueFromPipelineByPropertyName)]
    [String]$VirtualNetworkGatewaySku,

    [Parameter(ValueFromPipelineByPropertyName)]
    [String]$RoutingWeight,

    [Parameter(ValueFromPipelineByPropertyName)]
    [String]$Sharedkey

    # Add other parameters as required
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

            # Validate parameter: LocalNetworkGatewayName
            Write-LogFile -FilePath $LogFilePath -LogText "Validating Parameters: LocalNetworkGatewayName. Only ERRORs will be logged."
            If([String]::IsNullOrEmpty($LocalNetworkGatewayName))
            {
                Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. LocalNetworkGatewayName parameter value is empty.`r`n<#BlobFileReadyForUpload#>"
                $ObjOut = "Validation failed. LocalNetworkGatewayName parameter value is empty."
                $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                Write-Output $output
                Exit
            }

            # Validate parameter: LocalNetworkGatewayIPAddress
            Write-LogFile -FilePath $LogFilePath -LogText "Validating Parameters: LocalNetworkGatewayIPAddress. Only ERRORs will be logged."
            If([String]::IsNullOrEmpty($LocalNetworkGatewayIPAddress))
            {
                Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. LocalNetworkGatewayIPAddress parameter value is empty.`r`n<#BlobFileReadyForUpload#>"
                $ObjOut = "Validation failed. LocalNetworkGatewayIPAddress parameter value is empty."
                $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                Write-Output $output
                Exit
            }

             # Validate parameter: LocalNetworkGatewayAddressPrefix
            Write-LogFile -FilePath $LogFilePath -LogText "Validating Parameters: LocalNetworkGatewayAddressPrefix. Only ERRORs will be logged."
            If([String]::IsNullOrEmpty($LocalNetworkGatewayAddressPrefix))
            {
                Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. LocalNetworkGatewayAddressPrefix parameter value is empty.`r`n<#BlobFileReadyForUpload#>"
                $ObjOut = "Validation failed. LocalNetworkGatewayAddressPrefix parameter value is empty."
                $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                Write-Output $output
                Exit
            }

            # Validate parameter: VirtualNetworkGatewayName
            Write-LogFile -FilePath $LogFilePath -LogText "Validating Parameters: VirtualNetworkGatewayName. Only ERRORs will be logged."
            If([String]::IsNullOrEmpty($VirtualNetworkGatewayName))
            {
                Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. VirtualNetworkGatewayName parameter value is empty.`r`n<#BlobFileReadyForUpload#>"
                $ObjOut = "Validation failed. VirtualNetworkGatewayName parameter value is empty."
                $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                Write-Output $output
                Exit
            }

            # Validate parameter: VirtualNetworkGatewaySku
            Write-LogFile -FilePath $LogFilePath -LogText "Validating Parameters: VirtualNetworkGatewaySku. Only ERRORs will be logged."
            If([String]::IsNullOrEmpty($VirtualNetworkGatewaySku))
            {
                Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. VirtualNetworkGatewaySku parameter value is empty.`r`n<#BlobFileReadyForUpload#>"
                $ObjOut = "Validation failed. VirtualNetworkGatewaySku parameter value is empty."
                $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                Write-Output $output
                Exit
            }

            If($VirtualNetworkGatewaySku.Length -ne 0){
                 Write-LogFile -FilePath $LogFilePath -LogText "Validating Parameters: VirtualNetworkGatewaySku. Only ERRORs will be logged."
                 $arr = "Basic","Standard","HighPerformance"
                 If($arr -notcontains $VirtualNetworkGatewaySku){
                    Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. PerformanceTear '$VirtualNetworkGatewaySku' is NOT a valid value for this parameter.`r`n<#BlobFileReadyForUpload#>"
                    $ObjOut = "Validation failed. PerformanceTear '$VirtualNetworkGatewaySku' is not a valid value for this parameter."
                    $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                    Write-Output $output
                    Exit
                 }               
            }

            # Validate parameter: RoutingWeight
            Write-LogFile -FilePath $LogFilePath -LogText "Validating Parameters: RoutingWeight. Only ERRORs will be logged."
            If([String]::IsNullOrEmpty($RoutingWeight))
            {
                Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. RoutingWeight parameter value is empty.`r`n<#BlobFileReadyForUpload#>"
                $ObjOut = "Validation failed. RoutingWeight parameter value is empty."
                $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                Write-Output $output
                Exit
            }

            # Validate parameter: SharedKey
            Write-LogFile -FilePath $LogFilePath -LogText "Validating Parameters: SharedKey. Only ERRORs will be logged."
            If([String]::IsNullOrEmpty($SharedKey))
            {
                Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. SharedKey parameter value is empty.`r`n<#BlobFileReadyForUpload#>"
                $ObjOut = "Validation failed. SharedKey parameter value is empty."
                $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                Write-Output $output
                Exit
            }

            If($SharedKey.Length -ne 0){
                If($SharedKey -notmatch "^[a-zA-Z0-9]*$"){
                    Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. SharedKey value must be combination of characters and numbers.`r`n<#BlobFileReadyForUpload#>"
                    $ObjOut = "Validation failed. SharedKey parameter value  must be combination of characters and numbers."
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
            $ObjOut = "Error logging in to Azure Account.`n$($Error[0].Exception.Message)`r`n<#BlobFileReadyForUpload#>"
            Write-LogFile -FilePath $LogFilePath -LogText $ObjOut
            $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
            Write-Output $output
            Exit
        }
    }
}

Process
{
    Validate-AllParameters

    # 1. Login to Azure subscription
    Login-ToAzureAccount

    $GatewayPublicIP = $VirtualNetworkName+"GatewayPublicIP"
    $GatewayIPConfig = $VirtualNetworkName+"GatewayIPConfig"
    $VPNConnection = $VirtualNetworkName+"VPNConnection"

    # 2. Check if Resource Group exists. Create Resource Group if it does not exist.
    Try
    {
       Write-LogFile -FilePath $LogFilePath -LogText "Checking existance of resource group '$ResourceGroupName'"
        $ResourceGroup = $null
        ($ResourceGroup = Get-AzureRmResourceGroup -Name $ResourceGroupName -ErrorAction Stop) | Out-Null
    
        If($ResourceGroup -ne $null) # Resource Group already exists
        {
           Write-LogFile -FilePath $LogFilePath -LogText "Resource Group exists"
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

    # 3. Creating Local Network Gateway
    Try
    {
        Write-LogFile -FilePath $LogFilePath -LogText "Trying to create Local Network Gateway"
        ($localNWGW = New-AzureRmLocalNetworkGateway -Name $LocalNetworkGatewayName -ResourceGroupName $ResourceGroupName -Location $Location -GatewayIpAddress $LocalNetworkGatewayIPAddress -AddressPrefix $LocalNetworkGatewayAddressPrefix -ErrorAction Stop) | Out-Null
        Write-LogFile -FilePath $LogFilePath -LogText "Successfully created Local Network Gateway"
    }
    Catch
    {
        $ObjOut = "Error while Creating Azure Local Network Gateway.`r`n$($Error[0].Exception.Message)`r`n<#BlobFileReadyForUpload#>"
        $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
        Write-Output $output
        Write-LogFile -FilePath $LogFilePath -LogText $ObjOut
        Exit
    }

    # 4. Creating Public IP Address for Virtual Network and Configuring Gateway IP 
    Try
    {
        Write-LogFile -FilePath $LogFilePath -LogText "Trying to create Public IP Address"
        ($GatewayPIP= New-AzureRmPublicIpAddress -Name $GatewayPublicIP -ResourceGroupName $ResourceGroupName -Location $Location -AllocationMethod Dynamic -ErrorAction Stop) | Out-Null
        Write-LogFile -FilePath $LogFilePath -LogText "Successfully created Public IP Address"
        Try
        {
            Write-LogFile -FilePath $LogFilePath -LogText "Trying to get Virtual Network Details."
            ($vnet = Get-AzureRmVirtualNetwork -Name $VirtualNetworkName -ResourceGroupName $ResourceGroupName -ErrorAction Stop) | Out-Null
            Write-LogFile -FilePath $LogFilePath -LogText "Got the '$VirtualNetworkName' Virtual Network Details"
            Try
            {
                Write-LogFile -FilePath $LogFilePath -LogText "Trying to get Gateway Subnet Details."
                ($subnet = Get-AzureRmVirtualNetworkSubnetConfig -Name 'GatewaySubnet' -VirtualNetwork $vnet -ErrorAction Stop) | Out-Null
                Write-LogFile -FilePath $LogFilePath -LogText "Got the Gateway Subnet Details."
                Try
                {
                    Write-LogFile -FilePath $LogFilePath -LogText "Trying to Configure Gateway IP."
                    ($gwipconfig = New-AzureRmVirtualNetworkGatewayIpConfig -Name $GatewayIPConfig -SubnetId $subnet.Id -PublicIpAddressId $GatewayPIP.Id -ErrorAction Stop) | Out-Null
                    Write-LogFile -FilePath $LogFilePath -LogText "Successfully Configured Gateway IP."
                }
                Catch
                {
                    $ObjOut = "Error while Configuring Gateway IP.`r`n$($Error[0].Exception.Message)`r`n<#BlobFileReadyForUpload#>"
                    $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                    Write-Output $output
                    Write-LogFile -FilePath $LogFilePath -LogText $ObjOut
                    Exit
                }
            }
            Catch
            {
                $ObjOut = "Error while getting Gateway Subnet Details.`r`n$($Error[0].Exception.Message)`r`n<#BlobFileReadyForUpload#>"
                $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                Write-Output $output
                Write-LogFile -FilePath $LogFilePath -LogText $ObjOut
                Exit
            }
        }
        Catch
        {
            $ObjOut = "Error while getting Virtual Network Details.`r`n$($Error[0].Exception.Message)`r`n<#BlobFileReadyForUpload#>"
            $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
            Write-Output $output
            Write-LogFile -FilePath $LogFilePath -LogText $ObjOut
            Exit
        }
    }
    Catch
    {
        $ObjOut = "Error while Creating Public IP Address.`r`n$($Error[0].Exception.Message)`r`n<#BlobFileReadyForUpload#>"
        $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
        Write-Output $output
        Write-LogFile -FilePath $LogFilePath -LogText $ObjOut
        Exit
    }

    # 5. Creating Virtual Network Gateway
    Try
    {
        Write-LogFile -FilePath $LogFilePath -LogText "Trying to create Virtual Network Gateway"
        ($vnetgwconfig = New-AzureRmVirtualNetworkGateway -Name $VirtualNetworkGatewayName -ResourceGroupName $ResourceGroupName -Location $Location -IpConfigurations $gwipconfig -GatewayType Vpn -VpnType RouteBased -GatewaySku $VirtualNetworkGatewaySku -ErrorAction Stop) | Out-Null
        Write-LogFile -FilePath $LogFilePath -LogText "Successfully created Virtual Network Gateway"
    }
    Catch
    {
        $ObjOut = "Error while Creating Virtual Network Gateway.`r`n$($Error[0].Exception.Message)`r`n<#BlobFileReadyForUpload#>"
        $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
        Write-Output $output
        Write-LogFile -FilePath $LogFilePath -LogText $ObjOut
        Exit
    }

    # 6. Create VPN Connection
    Try
    {
        Write-LogFile -FilePath $LogFilePath -LogText "Trying to get Virtual Network Gateway Details."
        ($VnetGW = Get-AzureRmVirtualNetworkGateway -Name $VirtualNetworkGatewayName -ResourceGroupName $ResourceGroupName -ErrorAction SilentlyContinue) | Out-Null
        Write-LogFile -FilePath $LogFilePath -LogText "Got Virtual Network Gateway Details"
        Write-LogFile -FilePath $LogFilePath -LogText "Trying to get Local Network Gateway Details."
        ($LocalGW = Get-AzureRmLocalNetworkGateway -Name $LocalNetworkGatewayName -ResourceGroupName $ResourceGroupName -ErrorAction SilentlyContinue) | Out-Null
        Write-LogFile -FilePath $LogFilePath -LogText "Got Local Network Gateway Details"
        Write-LogFile -FilePath $LogFilePath -LogText "Trying to Create VPN Connection."
        ($con = New-AzureRmVirtualNetworkGatewayConnection -Name $VPNConnection -ResourceGroupName $ResourceGroupName -Location $Location -VirtualNetworkGateway1 $VnetGW -LocalNetworkGateway2 $LocalGW -ConnectionType IPsec -RoutingWeight $RoutingWeight -SharedKey $Sharedkey -ErrorAction Stop) | Out-Null
        Write-LogFile -FilePath $LogFilePath -LogText "Successfully created the VPN Connection."

        $ObjOut = "Successfully created Virtual Network Gateway '$VirtualNetworkGatewayName' and Local Network Gateway '$LocalNetworkGatewayName'.Created VPN Connection '$VPNConnection' between them."
        $output = (@{"Response" = [Array]$ObjOut; Status = "Success"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
        Write-Output $output 
    }
    Catch
    {
        $ObjOut = "Error while Creating VPNConnection.`r`n$($Error[0].Exception.Message)`r`n<#BlobFileReadyForUpload#>"
        $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
        Write-Output $output
        Write-LogFile -FilePath $LogFilePath -LogText $ObjOut
        Exit
    }
}
End
{
    Write-LogFile -FilePath $LogFilePath -LogText "####[ Script execution completed cuccessfully: $($MyInvocation.MyCommand.Name) ]####`r`n<#BlobFileReadyForUpload#>"
}