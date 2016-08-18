<#
    .SYNOPSIS
    The script is to configure the Hybrid network in Azure

    .DESCRIPTION
    The script is to configure the Hybrid network in Azure by adding the local network

    .PARAMETER ClientID

    Client ID is to be used for this script.

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

    .PARAMETER DeploymentName

    Name of the Deployment to be used for this command.
      
    .PARAMETER VNetName

    Name of the Azure Virtual Network Name to be used for this command.

    .PARAMETER VNetGatewayName

    Name of the Virtua Network Gateway name to be used for this command.

    .PARAMETER VNetGatewaySubnetPrefix

   Virtual Network Gateway Subnet prefix to be used for this command.

    .PARAMETER GatewayType

    Type of the Gatway to be used for this command. e.g VPN, ExpressRoute

    .PARAMETER LocalNetworkName

    Name of the Local Network name to be used for this command. However this is an optional if the Gateway is ExpressRoute.

    .PARAMETER LocalNetGatewayName

    Name of the Local Network Gateway to use for this command.However this is an optional if the Gateway is ExpressRoute.

    .PARAMETER LocalNetAddressPrefix
       
    Local Network Address Prefix to be used for this command.However this is an optional if the Gateway is ExpressRoute.

    .PARAMETER LocalNetVPNGatewayIP

    IP Address of the On-Premise VPN Gateway to be used for this command.However this is an optional if the Gateway is ExpressRoute.

    .PARAMETER VPNType

    Type of the VPN to be used for this command.However this is an optional if the Gateway is ExpressRoute.

    .PARAMETER GatewayTier

    Gateway Tier to be used for this command.However this is an optional if the Gateway is ExpressRoute.

    .PARAMETER SharedKey

    Shared key to be used for this command.However this is an optional if the Gateway is ExpressRoute.

    .PARAMETER CirtcuitName

    Name of the Azure Express circuit to be used for this command.However this is an optional if the Gateway type is VPN.

    .PARAMETER ConnectionType

    Type of the connection to be used for this command.

    .PARAMETER ConnectionName  

    Name of the VPN/Expressroute to be used for this command.

    .PARAMETER TemplateJSONPath

    Path of the TemplateJSONPath json to be used for this command.

    .PARAMETER ParameterJSONPath

    Path of the ParameterJSONPath json to be used for this command.

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
    C:\PS> .\Configure-HybridNetwork.ps1 -ClientID 123456 -AzureUserName bhaskar@desha.onmicrosoft.com -AzurePassword PassW0rd1) -AzureSubscriptionID 13483623-2873-4789-8d13-b58c06d37cb9 -Location 'Southeast Asia' -ResourceGroupName MyresourceGrp -DeploymentName hybrid -VNetName AzureScriptTest -VNetGatewayName AzureGatewayTest -VNetGatewaySubnetPrefix 10.0.4.0/29 -VNetGatewayPIPName azurescripttest -LocalNetworkName scriptlocal -LocalNetGatewayName scriptlocalgateway -LocalNetAddressPrefix 192.168.0.0/16 -LocalNetVPNGatewayIP 2.3.4.5 -GatewayType VPN -VPNType RouteBased -GatewayTier Basic -SharedKey 123456789 -ConnectionName stsconnection -ConnectionType IPSec -TemplateJSONPath .\Add-LocalNetVPNGateway.json -ParameterJSONPath .\sitetositeparam.json

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
    [String]$DeploymentName,

    [Parameter(ValueFromPipelineByPropertyName)]
    [String]$VNetName,

    [Parameter(ValueFromPipelineByPropertyName)]
    [String]$VNetGatewayName,

    [Parameter(ValueFromPipelineByPropertyName)]
    [String]$VNetGatewaySubnetPrefix,

    [Parameter(ValueFromPipelineByPropertyName)]
    [String]$VNetGatewayPIPName,

    [Parameter(ValueFromPipelineByPropertyName)]
    [String]$LocalNetworkName,

    [Parameter(ValueFromPipelineByPropertyName)]
    [String]$LocalNetGatewayName,

    [Parameter(ValueFromPipelineByPropertyName)]
    [String]$LocalNetAddressPrefix,

    [Parameter(ValueFromPipelineByPropertyName)]
    [String]$LocalNetVPNGatewayIP,

    [Parameter(ValueFromPipelineByPropertyName)]
    [String]$GatewayType,

    [Parameter(ValueFromPipelineByPropertyName)]
    [String]$VPNType,

    [Parameter(ValueFromPipelineByPropertyName)]
    [String]$GatewayTier,

    [Parameter(ValueFromPipelineByPropertyName)]
    [String]$SharedKey,

    [Parameter(ValueFromPipelineByPropertyName)]
    [String]$ConnectionName,

    [Parameter(ValueFromPipelineByPropertyName)]
    [String]$CircuitName,

    [Parameter(ValueFromPipelineByPropertyName)]
    [String]$ConnectionType,

    [Parameter(ValueFromPipelineByPropertyName)]
    [String]$TemplateJSONPath, 

    [Parameter(ValueFromPipelineByPropertyName)]
    [String]$ParameterJSONPath
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

            # Validate parameter: DeploymentName
            Write-LogFile -FilePath $LogFilePath -LogText "Validating Parameters: DeploymentName. Only ERRORs will be logged."
            If([String]::IsNullOrEmpty($DeploymentName))
            {
                Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. DeploymentName parameter value is empty.`r`n<#BlobFileReadyForUpload#>"
                $ObjOut = "Validation failed. DeploymentName parameter value is empty."
                $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                Write-Output $output
                Exit
            }

            # Validate parameter: VNetName
            Write-LogFile -FilePath $LogFilePath -LogText "Validating Parameters: VNetName. Only ERRORs will be logged."
            If([String]::IsNullOrEmpty($VNetName))
            {
                Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. VNetName parameter value is empty.`r`n<#BlobFileReadyForUpload#>"
                $ObjOut = "Validation failed. VNetName parameter value is empty."
                $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                Write-Output $output
                Exit
            }
            
            # Validate parameter: VNetGatewayName
            Write-LogFile -FilePath $LogFilePath -LogText "Validating Parameters: VNetGatewayName. Only ERRORs will be logged."
            If([String]::IsNullOrEmpty($VNetGatewayName))
            {
                Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. VNetGatewayName parameter value is empty.`r`n<#BlobFileReadyForUpload#>"
                $ObjOut = "Validation failed. VNetGatewayName parameter value is empty."
                $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                Write-Output $output
                Exit
            }
            
            # Validate parameter: VNetGatewaySubnetPrefix
            Write-LogFile -FilePath $LogFilePath -LogText "Validating Parameters: VNetGatewaySubnetPrefix. Only ERRORs will be logged."
            If([String]::IsNullOrEmpty($VNetGatewaySubnetPrefix))
            {
                Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. VNetGatewaySubnetPrefix parameter value is empty.`r`n<#BlobFileReadyForUpload#>"
                $ObjOut = "Validation failed. VNetGatewaySubnetPrefix parameter value is empty."
                $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                Write-Output $output
                Exit
            }
            Else
            {
                Write-LogFile -FilePath $LogFilePath -LogText "Validating if VNetGatewaySubnetPrefix is valid IP Address. Only ERRORs will be logged."
                $checkIP = $VNetGatewaySubnetPrefix.Split("/")[0]
                If([bool]($checkIP -as [ipaddress])) { <# Valid IP address #>}
                Else
                {
                    Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. VNetGatewaySubnetPrefix '$VNetGatewaySubnetPrefix' is NOT a valid IP address.`r`n<#BlobFileReadyForUpload#>"
                    $ObjOut = "Validation failed. VNetGatewaySubnetPrefix '$VNetGatewaySubnetPrefix' is not a valid IP address."
                    $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                    Write-Output $output
                    Exit
                }
            }
            
            # Validate parameter: GatewayType
            Write-LogFile -FilePath $LogFilePath -LogText "Validating Parameters: GatewayType. Only ERRORs will be logged."
            If([String]::IsNullOrEmpty($GatewayType))
            {
                Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. GatewayType parameter value is empty.`r`n<#BlobFileReadyForUpload#>"
                $ObjOut = "Validation failed. GatewayType parameter value is empty."
                $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                Write-Output $output
                Exit
            }
            Else
            {
                Write-LogFile -FilePath $LogFilePath -LogText "Validating if GatewayType is valid type. Only ERRORs will be logged."
                If($GatewayType -notin ('VPN','ExpressRoute')) 
                {
                    Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. GatewayType '$GatewayType' is NOT a valid Type.`r`n<#BlobFileReadyForUpload#>"
                    $ObjOut = "Validation failed. GatewayType '$GatewayType' is NOT a valid Type."
                    $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                    Write-Output $output
                    Exit 
                }
            }   
            
            if($GatewayType -eq 'VPN')
            {                   
                # Validate parameter: LocalNetworkName
                Write-LogFile -FilePath $LogFilePath -LogText "Validating Parameters: LocalNetworkName. Only ERRORs will be logged."
                If([String]::IsNullOrEmpty($LocalNetworkName))
                {
                    Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. LocalNetworkName parameter value is empty.`r`n<#BlobFileReadyForUpload#>"
                    $ObjOut = "Validation failed. LocalNetworkName parameter value is empty."
                    $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                    Write-Output $output
                    Exit
                }
                           
                # Validate parameter: LocalNetGatewayName
                Write-LogFile -FilePath $LogFilePath -LogText "Validating Parameters: LocalNetGatewayName. Only ERRORs will be logged."
                If([String]::IsNullOrEmpty($LocalNetGatewayName))
                {
                    Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. LocalNetGatewayName parameter value is empty.`r`n<#BlobFileReadyForUpload#>"
                    $ObjOut = "Validation failed. LocalNetGatewayName parameter value is empty."
                    $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                    Write-Output $output
                    Exit
                }
                        
                # Validate parameter: LocalNetAddressPrefix
                Write-LogFile -FilePath $LogFilePath -LogText "Validating Parameters: LocalNetAddressPrefix. Only ERRORs will be logged."
                If([String]::IsNullOrEmpty($LocalNetAddressPrefix))
                {
                    Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. LocalNetAddressPrefix parameter value is empty.`r`n<#BlobFileReadyForUpload#>"
                    $ObjOut = "Validation failed. LocalNetAddressPrefix parameter value is empty."
                    $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                    Write-Output $output
                    Exit
                }
                Else
                {
                    Write-LogFile -FilePath $LogFilePath -LogText "Validating if LocalNetAddressPrefix is valid IP Address. Only ERRORs will be logged."
                    $checkIP = $LocalNetAddressPrefix.Split("/")[0]
                    If([bool]($checkIP -as [ipaddress])) { <# Valid IP address #>}
                    Else
                    {
                        Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. LocalNetAddressPrefix '$LocalNetAddressPrefix' is NOT a valid IP address.`r`n<#BlobFileReadyForUpload#>"
                        $ObjOut = "Validation failed. LocalNetAddressPrefix '$LocalNetAddressPrefix' is not a valid IP address."
                        $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                        Write-Output $output
                        Exit
                    }
                }
                       
                # Validate parameter: LocalNetVPNGatewayIP
                Write-LogFile -FilePath $LogFilePath -LogText "Validating Parameters: LocalNetVPNGatewayIP. Only ERRORs will be logged."
                If([String]::IsNullOrEmpty($LocalNetVPNGatewayIP))
                {
                    Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. LocalNetVPNGatewayIP parameter value is empty.`r`n<#BlobFileReadyForUpload#>"
                    $ObjOut = "Validation failed. LocalNetVPNGatewayIP parameter value is empty."
                    $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                    Write-Output $output
                    Exit
                }
                Else
                {
                    Write-LogFile -FilePath $LogFilePath -LogText "Validating if LocalNetVPNGatewayIP is valid IP Address. Only ERRORs will be logged."
                    If([bool]($LocalNetVPNGatewayIP -as [ipaddress])) { <# Valid IP address #>}
                    Else
                    {
                        Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. LocalNetVPNGatewayIP '$LocalNetVPNGatewayIP' is NOT a valid IP address.`r`n<#BlobFileReadyForUpload#>"
                        $ObjOut = "Validation failed. LocalNetVPNGatewayIP '$LocalNetVPNGatewayIP' is not a valid IP address."
                        $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                        Write-Output $output
                        Exit
                    }
                }

                # Validate parameter: VPNType
                Write-LogFile -FilePath $LogFilePath -LogText "Validating Parameters: VPNType. Only ERRORs will be logged."
                If([String]::IsNullOrEmpty($VPNType))
                {
                    Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. VPNType parameter value is empty.`r`n<#BlobFileReadyForUpload#>"
                    $ObjOut = "Validation failed. VPNType parameter value is empty."
                    $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                    Write-Output $output
                }
                Else
                {
                    Write-LogFile -FilePath $LogFilePath -LogText "Validating if VPNType is valid VPN type. Only ERRORs will be logged."
                    If($VPNType -notin ('RouteBased','PolicyBased')) 
                    { 
                        Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. VPNType '$VPNType' is NOT a valid VPN Type.`r`n<#BlobFileReadyForUpload#>"
                        $ObjOut = "Validation failed. VPNType '$VPNType' is not a valid VPN Type."
                        $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                        Write-Output $output
                        Exit
                    }
                }

                # Validate parameter: GatewayTier
                Write-LogFile -FilePath $LogFilePath -LogText "Validating Parameters: GatewayTier. Only ERRORs will be logged."
                If([String]::IsNullOrEmpty($GatewayTier))
                {
                    Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. GatewayTier parameter value is empty.`r`n<#BlobFileReadyForUpload#>"
                    $ObjOut = "Validation failed. GatewayTier parameter value is empty."
                    $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                    Write-Output $output
                    Exit
                }
                Else
                {
                    Write-LogFile -FilePath $LogFilePath -LogText "Validating if GatewayTier is valid Gateway Tier. Only ERRORs will be logged."
                    If($GatewayTier -notin ('Basic','Standard','HighPerformance')) 
                    { 
                        Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. GatewayTier '$GatewayTier' is NOT a valid Gateway Tier.`r`n<#BlobFileReadyForUpload#>"
                        $ObjOut = "Validation failed. GatewayTier '$GatewayTier' is not a valid Gateway Tier."
                        $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                        Write-Output $output
                        Exit
                    }
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
            }
            Else
            {

                # Validate parameter: CirtcuitName
                Write-LogFile -FilePath $LogFilePath -LogText "Validating Parameters: CirtcuitName. Only ERRORs will be logged."
                If([String]::IsNullOrEmpty($CirtcuitName))
                {
                    Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. CirtcuitName parameter value is empty.`r`n<#BlobFileReadyForUpload#>"
                    $ObjOut = "Validation failed. CirtcuitName parameter value is empty."
                    $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                    Write-Output $output
                    Exit
                }
            }

            # Validate parameter: ConnectionType
            Write-LogFile -FilePath $LogFilePath -LogText "Validating Parameters: ConnectionType. Only ERRORs will be logged."
            If([String]::IsNullOrEmpty($ConnectionType))
            {
                Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. ConnectionType $ConnectionType parameter value is empty.`r`n<#BlobFileReadyForUpload#>"
                $ObjOut = "Validation failed. ConnectionType parameter $ConnectionType value is empty."
                $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                Write-Output $output
                Exit
            }
            Else
            {
                if($ConnectionType -notin ('IPSec','ExpressRoute','vnet2vnet'))
                {
                    Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. ConnectionType $ConnectionType parameter value is not valid.`r`n<#BlobFileReadyForUpload#>"
                    $ObjOut = "Validation failed. ConnectionType parameter $ConnectionType value is not valid."
                    $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                    Write-Output $output
                    Exit
                }
            }

            # Validate parameter: ConnectionName
            Write-LogFile -FilePath $LogFilePath -LogText "Validating Parameters: ConnectionName. Only ERRORs will be logged."
            If([String]::IsNullOrEmpty($ConnectionName))
            {
                Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. ConnectionName parameter value is empty.`r`n<#BlobFileReadyForUpload#>"
                $ObjOut = "Validation failed. ConnectionName parameter value is empty."
                $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                Write-Output $output
                Exit
            }

            # Validate parameter: TemplateJSONPath
            Write-LogFile -FilePath $LogFilePath -LogText "Validating Parameters: TemplateJSONPath. Only ERRORs will be logged."
            If([String]::IsNullOrEmpty($TemplateJSONPath))
            {
                Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. TemplateJSONPath parameter value is empty.`r`n<#BlobFileReadyForUpload#>"
                $ObjOut = "Validation failed. TemplateJSONPath parameter value is empty."
                $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
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
                    $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
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
                $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
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
                        $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                        Write-LogFile -FilePath $LogFilePath -LogText "Unable to create required folder/path '$ParameterJSONPath'.`r`n<#BlobFileReadyForUpload#>"
                        Write-Output $output
                        Exit
                    }
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
    # 1. Validate all parameters
    Validate-AllParameters

    # 2. Login to Azure subscription
    Login-ToAzureAccount

    # 3. Check if Resource Group exists. Create Resource Group if it does not exist.
    Try
    {
        Write-LogFile -FilePath $LogFilePath -LogText "Checking existance of resource group '$ResourceGroupName'"
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
                Write-LogFile -FilePath $LogFilePath -LogText "Resource group '$ResourceGroupName' does not exist. Creating resource group."
                ($ResourceGroup = New-AzureRmResourceGroup -Name $ResourceGroupName -Location $Location) | Out-Null
                Write-LogFile -FilePath $LogFilePath -LogText "Resource group '$ResourceGroupName' created"
            }
            Catch
            {
                $ObjOut = "Error while creating Azure Resource Group '$ResourceGroupName'.$($Error[0].Exception.Message)"
                $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                Write-Output $output
                Write-LogFile -FilePath $LogFilePath -LogText "$ObjOut`r`n<#BlobFileReadyForUpload#>"
                Exit
            }
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

    # 4. Registering Azure Provider Namespaces
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

    # 5. Checking for the Virtual Network and Subnet existence
    Try
    {
        Write-LogFile -FilePath $LogFilePath -LogText "Checking for the existence of Virtual Network $VNetName in the given $ResourceGroupName resource group."
        $VnetExist = $null
        ($VnetExist = Get-AzureRmVirtualNetwork -Name $VNetName -ResourceGroupName $ResourceGroupName -ErrorAction SilentlyContinue -WarningAction SilentlyContinue) | Out-Null
        if($VnetExist)
        {
             Write-LogFile -FilePath $LogFilePath -LogText "The given Virtual Network $VNetName is already exists."
             $VNetGateways = $null
             ($VNetGateways = Get-AzureRmVirtualNetworkGateway -Name $VNetGatewayName -ResourceGroupName $ResourceGroupName -ErrorAction SilentlyContinue -WarningAction SilentlyContinue) | Out-Null
             if($VNetGateways -ne $null)
             {
                Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. The virtual network gateway $VNetGatewayName is already created for this vritual network $VNetName.`r`n<#BlobFileReadyForUpload#>"
                $ObjOut = "Validation failed. The virtual network gateway $VNetGatewayName is already created for this vritual network $VNetName."
                $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                Write-Output $output
                Exit
             }

             Write-LogFile -FilePath $LogFilePath -LogText "Checking for the Gateway Public IP $VNetGatewayPIPName."
             ($VNetPublicIP = Get-AzureRmPublicIpAddress -Name $VNetGatewayPIPName -ResourceGroupName $ResourceGroupName -ErrorAction SilentlyContinue -WarningAction SilentlyContinue) | Out-Null
             if($VNetPublicIP -ne $null)
             {
                Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. The Azure VNetGateway PIP Name $VNetGatewayPIPName is already exist.`r`n<#BlobFileReadyForUpload#>"
                $ObjOut = "Validation failed. The Azure VNetGateway PIP Name $VNetGatewayPIPName is already exist."
                $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                Write-Output $output
                Exit
             }
        }
        else
        {
            Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. The Provided virtual Network $VNetName does not exist in the $ResourceGroupName resource group.`r`n<#BlobFileReadyForUpload#>"
            $ObjOut = "Validation failed. The Provided virtual Network $VNetName does not exist in the $ResourceGroupName resource group."
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

    # 6. Checking for the local network configuration
    if($GatewayType -eq 'VPN')
    {
        Try
        {
            Write-LogFile -FilePath $LogFilePath -LogText "Checking for the existence of Local Network $LocalNetworkName and Gateway in the given $ResourceGroupName resource group."
            $LocalNets = $null
            ($LocalNets = Get-AzureRmLocalNetworkGateway -Name $LocalNetGatewayName -ResourceGroupName $ResourceGroupName -ErrorAction SilentlyContinue -WarningAction SilentlyContinue) | Out-Null
            if($LocalNets)
            {
                Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. The local network gateway $LocalNetGatewayName is already exist.`r`n<#BlobFileReadyForUpload#>"
                $ObjOut = "Validation failed. The local network gateway $LocalNetGatewayName is already exist."
                $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                Write-Output $output
                Exit
            }
        }
        Catch
        {
            $ObjOut = "Error while getting Azure local Network details.$($Error[0].Exception.Message)"
            $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
            Write-Output $output
            Write-LogFile -FilePath $LogFilePath -LogText "$ObjOut`r`n<#BlobFileReadyForUpload#>"
            Exit
        }
    }

    # 7. Adding the local area network,creating gateways and making connection using template
    # Creating the Parameter block for both configurations i.e VPN or ExpressRoute

    Try
    {
           $ParameterJSONText = @"
{
    "`$schema": "http://schema.management.azure.com/schemas/2015-01-01/deploymentParameters.json#",
    "contentVersion": "1.0.0.0",
    "parameters": {
                        "virtualNetworkName": {"value":"$VNetName"},
                        "gatewaySubnetPrefix":{"value":"$VNetGatewaySubnetPrefix"},
                        "gatewayPublicIPName":{"value":"$VNetGatewayPIPName"},
                        "gatewayName":{"value":"$VNetGatewayName"},
                        "connectionName":{"value":"$ConnectionName"},
                        "connectionType":{"value":"$ConnectionType"},
                        "GatewayType":{"value":"$GatewayType"},
"@

        if($GatewayType -eq 'VPN')
        {
                $VPN = @"
              
                        "localGatewayName": {"value":"$LocalNetGatewayName"},
                        "localGatewayIpAddress":{"value":"$LocalNetVPNGatewayIP"},
                        "localAddressPrefix": {"value":"$LocalNetAddressPrefix"}, 
                        "sharedKey":{"value":"$SharedKey"},
                        "gatewaySku":{"value":"$GatewayTier"},                
                        "vpnType":{"value":"$VPNType"}
                   }
}
"@
        $ParameterJSONText = $ParameterJSONText + $VPN
        }
        elseif($GatewayType -eq 'ExpressRoute')
        {
            $Expressroute = @"

                        "CircuitName":{"value":"$CircuitName"}
                   }
}
"@
        $ParameterJSONText = $ParameterJSONText + $Expressroute
        }

        ($ParameterJSONText | Out-File -FilePath $ParameterJSONPath -ErrorAction Stop) | Out-Null

        Write-LogFile -FilePath $LogFilePath -LogText "Configuring the Hybrid VNet configuration."
        ($Status = New-AzureRmResourceGroupDeployment -Name $DeploymentName -ResourceGroupName $ResourceGroupName -TemplateFile $TemplateJSONPath -TemplateParameterFile $ParameterJSONPath -ErrorAction Stop -WarningAction SilentlyContinue) | Out-Null
        if($Status.ProvisioningState -eq 'Succeeded')
        {
            Write-LogFile -FilePath $LogFilePath -LogText "Adding the local network and configuring the hybrid configuration is successful.`r`n<#BlobFileReadyForUpload#>"
            $ObjOut = "Adding the local network and configuring the hybrid configuration is successful."
            $output = (@{"Response" = [Array]$ObjOut; Status = "Success"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
            Write-Output $output
        }
        else
        {
            Write-LogFile -FilePath $LogFilePath -LogText "Creating the Hybrid configuration was not successful.`r`n<#BlobFileReadyForUpload#>"
            $ObjOut = "Creating the Hybrid configuration was not successful."
            $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
            Write-Output $output
            Exit
        }
    }
    Catch
    {
        $ObjOut = "Error while configuring the Hybrid VNet configuration.$($Error[0].Exception.Message)"
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