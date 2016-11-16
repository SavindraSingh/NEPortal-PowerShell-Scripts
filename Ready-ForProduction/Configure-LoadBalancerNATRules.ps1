<##
    .SYNOPSIS
    Script to create Load Balancers and NAT rules

    .DESCRIPTION
    Script to create Load Balancers and NAT rules

    .PARAMETER ClientID

    Client ID to be used for this script.

    .PARAMETER AzureUserName

    User name for Azure login. This should be an Organizational account (not Hotmail/Outlook account)

    .PARAMETER AzurePassword

    Password for Azure user account.

    .PARAMETER AzureSubscriptionID
    
    Azure Subscription ID to be used for this activity.

    .PARAMETER Location
         
    Azure Location to be used for creating/saving/accessing resources (should be a valid location. Refer to https://azure.microsoft.com/en-us/regions/ for more details.)

    .PARAMETER ResourceGroupName
     
    Name of the Azure ARM resource group to be used for this command.

    .PARAMETER LoadBalancerName
   
    Name of the Load Balancer to be used for this command.

    .PARAMETER LoadBalancerType
     
    Name of the LoadBalancerType be used for this command. e.g Public . Internal

    .PARAMETER PublicIPAddressName
    
    Name of the PublicIPAddressName to be used for this command.

    .PARAMETER VirtualNetworkName
    
    Name of the VirtualNetworkName to be used for this command.

    .PARAMETER SubnetName
    
    Name of the SubnetName to be used for this command.   

    .PARAMETER IPAddressType
    
    Type of the IP Address to be used for this command. e.g Dynamic, Static

    .PARAMETER StaticIPAddress

    IP Address to be used for this command.
    
    .PARAMETER ProbeName

    Name of Probe to be used for this command.

    .PARAMETER ProbeProtocol

    Name of the Probe Protocol to be used for this command.e.g Http,Tcp

    .PARAMETER ProbePort
         
    Probe Port to be used for this command.

    .PARAMETER ProbePath

    Probe path to be used for this command.

    .PARAMETER ProbeInterval

    Probe interval in seconds to be used for this command.

    .PARAMETER ProbeUnhealthythreshold

    Probe Unhealthy Threshold to be used for this command.

    .PARAMETER BackEndPoolName

    Name of the BackEndPoolName to be used for this command.

    .PARAMETER InboundNATRuleName

    Name of the InboundNATRuleNames to be used for this command.e.g Cab be multiple with comma seperated.

    .PARAMETER InboundProtocol

    Name of the Inbound Protocol to be used for this command.e.g Tcp,Udp. It can be multiple with comma seperated.

    .PARAMETER InboundPort

    Port number to be used for this command.It can be multiple with comma seperated.

    .PARAMETER InboundBackEndPort

    Back end port to be used for this command.It can be multiple with comma seperated
    
    .PARAMETER LoadBalancerRuleName

    Name of the Load Balancer rule to be used for this command.

    .PARAMETER LoadBalancingProtocol
 
    Name of the Load balancing protocol to be used for this command.

    .PARAMETER LoadBalancingPort

    Load Balancing port to be used for this command.

    .PARAMETER BackEndPort

    Back end port to be used for this command.

    .INPUTS
    All parameter values in String format.

    .OUTPUTS
    String. Result of the command output.

    .NOTES
     Purpose of script: The script is to create load balancer and NATing rules
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
        C:\PS>.\Configure-LoadBalancerNATRules.ps1 -ClientID 12345 -AzureUserName bhaskar@netenrich.com -AzurePassword ***** -AzureSubscriptionID ca68598c-ecc3-4abc-b7a2-1ecef33f278d -Location 'Southeast Asia' -ResourceGroupName 'testgrp' -LoadBalancerName TestLB LoadBalancerType Internal -VirtualNetworkName testvnet -SubnetName infrasubnet -IPAddressType Static -StaticIPAddress 10.0.0.8 -ProbeName LBProbe -ProbeProtocol http -ProbePort 80 -ProbePath /index.html -ProbeInterval 5 -ProbeUnhealthythreshold 2 -BackEndPoolName testbackpool -InboundNATRuleName InRule -InboundProtocol tcp -InboundPort 80 -InboundBackEndPort 80 -LoadBalancerRuleName LBrule -LoadBalancingProtocol tcp -LoadBalancingPort 80 -BackEndPort 80


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
    [string]$ResourceGroupName,

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
    [String]$StaticIPAddress,

    [Parameter(ValueFromPipelineByPropertyName)]
    [string]$ProbeName,

    [Parameter(ValueFromPipelineByPropertyName)]
    [string]$ProbeProtocol,

    [Parameter(ValueFromPipelineByPropertyName)]
    [string]$ProbePort,

    [Parameter(ValueFromPipelineByPropertyName)]
    [string]$ProbePath,

    [Parameter(ValueFromPipelineByPropertyName)]
    [string]$ProbeInterval,

    [Parameter(ValueFromPipelineByPropertyName)]
    [string]$ProbeUnhealthythreshold,

    [Parameter(ValueFromPipelineByPropertyName)]
    [string]$BackEndPoolName,

    [Parameter(ValueFromPipelineByPropertyName)]
    [string]$InboundNATRuleName,

    [Parameter(ValueFromPipelineByPropertyName)]
    [string]$InboundProtocol,

    [Parameter(ValueFromPipelineByPropertyName)]
    [string]$InboundPort,

    [Parameter(ValueFromPipelineByPropertyName)]
    [string]$InboundBackEndPort,

    [Parameter(ValueFromPipelineByPropertyName)]
    [string]$LoadBalancerRuleName,

    [Parameter(ValueFromPipelineByPropertyName)]
    [string]$LoadBalancingProtocol,

    [Parameter(ValueFromPipelineByPropertyName)]
    [string]$LoadBalancingPort,

    [Parameter(ValueFromPipelineByPropertyName)]
    [string]$BackEndPort
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
                Write-LogFile -FilePath $LogFilePath -LogText "Validating if the $LoadBalancerType is a valid Type.Only ERRORs will be logged."
                if($LoadBalancerType -notin ('Public','Internal'))
                {
                    Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. LoadBalancerType parameter value is not a valid type.`r`n<#BlobFileReadyForUpload#>"
                    $ObjOut = "Validation failed. LoadBalancerType parameter value is not a valid type."
                    $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                    Write-Output $output
                    Exit
                }
            }

            #validating parameters required for 'public' load balancer.
            If($LoadBalancerType -eq 'Public')
            {
                # Validate parameter: PublicIPAddressName
                if($PublicIPAddressName -ne $null)
                {

                    Write-LogFile -FilePath $LogFilePath -LogText "Validating Parameters: PublicIPAddressName. Only ERRORs will be logged."
                    If([String]::IsNullOrEmpty($PublicIPAddressName))
                    {
                        Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. PublicIPAddressName parameter value is empty.`r`n<#BlobFileReadyForUpload#>"
                        $ObjOut = "Validation failed. PublicIPAddressName parameter value is empty."
                        $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                        Write-Output $output
                        Exit
                    }
                }
                Else
                {                
                    Write-LogFile -FilePath $LogFilePath -LogText "Validating if PublicIPAddressName is valid IP Address. Only ERRORs will be logged."
                    If([bool]($PublicIPAddressName -as [ipaddress])) { <# Valid IP address #>}
                    Else
                    {
                        Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. PublicIPAddressName $StaticIPAddress is NOT a valid IP address.`r`n<#BlobFileReadyForUpload#>"
                        $ObjOut = "Validation failed. PublicIPAddressName $PublicIPAddressName is not a valid IP address."
                        $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                        Write-Output $output
                        Exit
                    }
                }                                
            }
            Else #validting parameters required for internal load balancer
            {
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
                    Write-LogFile -FilePath $LogFilePath -LogText "Validating if the $IPAddressType is a valid Type.Only ERRORs will be logged."
                    if($IPAddressType -notin ('Dynamic','Static'))
                    {
                        Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. IPAddressType parameter value is not a valid type.`r`n<#BlobFileReadyForUpload#>"
                        $ObjOut = "Validation failed. IPAddressType parameter value is not a valid type."
                        $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                        Write-Output $output
                        Exit                    
                    }
                }

                If ($IPAddressType -eq 'Static')
                {
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
            }

            # Validate parameter: ProbeName
            Write-LogFile -FilePath $LogFilePath -LogText "Validating Parameters: ProbeName. Only ERRORs will be logged."
            If([String]::IsNullOrEmpty($ProbeName))
            {
                Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. ProbeName parameter value is empty.`r`n<#BlobFileReadyForUpload#>"
                $ObjOut = "Validation failed. ProbeName parameter value is empty."
                $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                Write-Output $output
                Exit
            }

            # Validate parameter: ProbeProtocol
            Write-LogFile -FilePath $LogFilePath -LogText "Validating Parameters: ProbeProtocol. Only ERRORs will be logged."
            If([String]::IsNullOrEmpty($ProbeProtocol))
            {
                Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. ProbeProtocol parameter value is empty.`r`n<#BlobFileReadyForUpload#>"
                $ObjOut = "Validation failed. ProbeProtocol parameter value is empty."
                $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                Write-Output $output
                Exit
            }
            Else
            {
                Write-LogFile -FilePath $LogFilePath -LogText "Validating if the $ProbeProtocol is a valid type.Only ERRORs will be logged."
                if($ProbeProtocol -notin ('Http','Tcp'))
                {
                    Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. ProbeProtocol parameter value is not a valid type.`r`n<#BlobFileReadyForUpload#>"
                    $ObjOut = "Validation failed. ProbeProtocol parameter value is not a valid type."
                    $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                    Write-Output $output
                    Exit                   
                }
            }

            # Validate parameter: ProbePort
            Write-LogFile -FilePath $LogFilePath -LogText "Validating Parameters: ProbePort. Only ERRORs will be logged."
            If([String]::IsNullOrEmpty($ProbePort))
            {
                Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. ProbePort parameter value is empty.`r`n<#BlobFileReadyForUpload#>"
                $ObjOut = "Validation failed. ProbePort parameter value is empty."
                $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                Write-Output $output
                Exit
            }
            Else
            {
                Write-LogFile -FilePath $LogFilePath -LogText "Validating if the $ProbePort is a valid number.Only ERRORs will be logged."
                $ProbePort = [Int32]$ProbePort
                if($ProbePort -notin (1..65535))
                {
                    Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. ProbePort $ProbePort is not a valid Port Number.`r`n<#BlobFileReadyForUpload#>"
                    $ObjOut = "Validation failed. ProbePort $ProbePort is not a valid Port Number."
                    $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                    Write-Output $output
                    Exit                    
                }
            }

            if($ProbeProtocol -eq 'Http')
            {
                # Validate parameter: ProbePath
                Write-LogFile -FilePath $LogFilePath -LogText "Validating Parameters: ProbePath. Only ERRORs will be logged."
                If([String]::IsNullOrEmpty($ProbePath))
                {
                    Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. ProbePath parameter value is empty.`r`n<#BlobFileReadyForUpload#>"
                    $ObjOut = "Validation failed. ProbePath parameter value is empty."
                    $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                    Write-Output $output
                    Exit
                }
            }

            # Validate parameter: ProbeInterval
            Write-LogFile -FilePath $LogFilePath -LogText "Validating Parameters: ProbeInterval. Only ERRORs will be logged."
            If([String]::IsNullOrEmpty($ProbeInterval))
            {
                Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. ProbeInterval parameter value is empty.`r`n<#BlobFileReadyForUpload#>"
                $ObjOut = "Validation failed. ProbeInterval parameter value is empty."
                $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                Write-Output $output
                Exit
            }
            Else
            {
                Write-LogFile -FilePath $LogFilePath -LogText "Validating if the $ProbeInterval is a valid number.Only ERRORs will be logged."
                $ProbeInterval = [Int32]$ProbeInterval
                if($ProbeInterval -notin (5..2147483646))
                {
                    Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. ProbeInterval $ProbeInterval is not a valid Number.it must be in (5 to 2147483646).`r`n<#BlobFileReadyForUpload#>"
                    $ObjOut = "Validation failed. ProbeInterval $ProbeInterval is not a valid Number.it must be in (5 to 2147483646)."
                    $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                    Write-Output $output
                    Exit                    
                }
            }

            # Validate parameter: ProbeUnhealthythreshold
            Write-LogFile -FilePath $LogFilePath -LogText "Validating Parameters: ProbeUnhealthythreshold. Only ERRORs will be logged."
            If([String]::IsNullOrEmpty($ProbeUnhealthythreshold))
            {
                Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. ProbeUnhealthythreshold parameter value is empty.`r`n<#BlobFileReadyForUpload#>"
                $ObjOut = "Validation failed. ProbeUnhealthythreshold parameter value is empty."
                $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                Write-Output $output
                Exit
            }
            Else
            {
                Write-LogFile -FilePath $LogFilePath -LogText "Validating if the $ProbeUnhealthythreshold is a valid number.Only ERRORs will be logged."
                $ProbeUnhealthythreshold = [Int32]$ProbeUnhealthythreshold
                if($ProbeUnhealthythreshold -notin (2..429496729))
                {
                    Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. ProbeUnhealthythreshold $ProbeUnhealthythreshold is not a valid Number.it must be in(2..429496729).`r`n<#BlobFileReadyForUpload#>"
                    $ObjOut = "Validation failed. ProbeUnhealthythreshold $ProbeUnhealthythreshold is not a valid Number.it must be in(2..429496729)."
                    $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                    Write-Output $output
                    Exit                    
                }
            }

            # Validate parameter: BackEndPoolName
            Write-LogFile -FilePath $LogFilePath -LogText "Validating Parameters: BackEndPoolName. Only ERRORs will be logged."
            If([String]::IsNullOrEmpty($BackEndPoolName))
            {
                Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. BackEndPoolName parameter value is empty.`r`n<#BlobFileReadyForUpload#>"
                $ObjOut = "Validation failed. BackEndPoolName parameter value is empty."
                $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                Write-Output $output
                Exit
            }

            # Validate parameter: InboundNATRuleName
            Write-LogFile -FilePath $LogFilePath -LogText "Validating Parameters: InboundNATRuleName. Only ERRORs will be logged."
            If([String]::IsNullOrEmpty($InboundNATRuleName))
            {
                Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. InboundNATRuleName parameter value is empty.`r`n<#BlobFileReadyForUpload#>"
                $ObjOut = "Validation failed. InboundNATRuleName parameter value is empty."
                $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                Write-Output $output
                Exit
            }
            If($InboundNATRuleName.Contains(","))
            {
                $Script:InboundNATRuleNames = @()
                $Script:InboundNATRuleNames = $InboundNATRuleName.Split(",")    
            }

            # Validate parameter: InBoundService
            #Write-LogFile -FilePath $LogFilePath -LogText "Validating Parameters: InBoundService. Only ERRORs will be logged."
            #If([String]::IsNullOrEmpty($InBoundService))
            #{
            #    Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. InBoundService parameter value is empty."
            #    $ObjOut = "Validation failed. InBoundService parameter value is empty."
            #    $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
            #    Write-Output $output
            #    Exit
            #}

            # Validate parameter: InboundProtocol
            Write-LogFile -FilePath $LogFilePath -LogText "Validating Parameters: InboundProtocol. Only ERRORs will be logged."
            If([String]::IsNullOrEmpty($InboundProtocol))
            {
                Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. InboundProtocol parameter value is empty.`r`n<#BlobFileReadyForUpload#>"
                $ObjOut = "Validation failed. InboundProtocol parameter value is empty."
                $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                Write-Output $output
                Exit
            }
            If($InboundProtocol.Contains(","))
            {
                $Script:InboundProtocols = @()
                $Script:InboundProtocols = $InboundProtocol.Split(",") 

                foreach($InProtocol in $Script:InboundProtocols)
                {
                    Write-LogFile -FilePath $LogFilePath -LogText "Validating if the $InProtocol is a valid Type.Only ERRORs will be logged."
                    if($InProtocol -notin ('TCP','UDP'))
                    {
                        Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. InboundProtocol parameter value is not a valid type.`r`n<#BlobFileReadyForUpload#>"
                        $ObjOut = "Validation failed. InboundProtocol parameter value is not a valid type."
                        $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                        Write-Output $output
                        Exit                        
                    }
                }
            }
            else
            {
                Write-LogFile -FilePath $LogFilePath -LogText "Validating if the $InboundProtocol is a valid Type.Only ERRORs will be logged."
                if($InboundProtocol -notin ('TCP','UDP'))
                    {
                        Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. InboundProtocol parameter value is not a valid type.`r`n<#BlobFileReadyForUpload#>"
                        $ObjOut = "Validation failed. InboundProtocol parameter value is not a valid type."
                        $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                        Write-Output $output
                        Exit                        
                    }
            }

            # Validate parameter: InboundPort
            Write-LogFile -FilePath $LogFilePath -LogText "Validating Parameters: InboundPort. Only ERRORs will be logged."
            If([String]::IsNullOrEmpty($InboundPort))
            {
                Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. $InboundPort parameter value is empty.`r`n<#BlobFileReadyForUpload#>"
                $ObjOut = "Validation failed. InboundPort parameter value is empty."
                $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                Write-Output $output
                Exit
            }
            If($InboundPort.Contains(","))
            {
                $InboundPortsIn = @()
                $InboundPortsIn = $InboundPort.Split(",")
                $Script:InboundPorts = @()

                foreach($InPort in $InboundPortsIn)
                {
                    Write-LogFile -FilePath $LogFilePath -LogText "Validating if the $InPort is a valid port number.Only ERRORs will be logged."
                    $Script:InboundPorts += [int32]$InPort
                    if([Int32]$InPort -notin (1..65535))
                    {
                        Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. InboundProtocol parameter value is not a vlaid port number.`r`n<#BlobFileReadyForUpload#>"
                        $ObjOut = "Validation failed. InboundProtocol parameter value is not a vlaid port number."
                        $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                        Write-Output $output
                        Exit                        
                    }
                }
            }
            else
            {
                Write-LogFile -FilePath $LogFilePath -LogText "Validating if the $InboundPort is a valid port number.Only ERRORs will be logged."
                #$InboundPort = [Int32]$InboundPort
                if([Int32]$InboundPort -notin (1..65535))
                {
                    Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. InboundPort parameter value is not a vlaid port number.`r`n<#BlobFileReadyForUpload#>"
                    $ObjOut = "Validation failed. InboundPort parameter value is not a vlaid port number."
                    $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                    Write-Output $output
                    Exit                        
                }                
            }

            # Validate parameter: InboundBackEndPort
            Write-LogFile -FilePath $LogFilePath -LogText "Validating Parameters: $InboundBackEndPort. Only ERRORs will be logged."
            If([String]::IsNullOrEmpty($InboundBackEndPort))
            {
                Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. InboundBackEndPort parameter value is empty.`r`n<#BlobFileReadyForUpload#>"
                $ObjOut = "Validation failed. InboundBackEndPort parameter value is empty."
                $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                Write-Output $output
                Exit
            }
            If($InboundBackEndPort.Contains(","))
            {
                $InboundBackPorts = @()
                $InboundBackPorts = $InboundBackEndPort.Split(",")
                $Script:InboundBackEndPorts = @() 

                foreach($InBackPort in $InboundBackPorts)
                {
                    Write-LogFile -FilePath $LogFilePath -LogText "Validating if the $InBackPort is a valid port number.Only ERRORs will be logged."
                    $Script:InboundBackEndPorts += [int32]$InBackPort
                    if([Int32]$InBackPort -notin (1..65535))
                    {
                        Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. InboundProtocol parameter value is not a valid port number.`r`n<#BlobFileReadyForUpload#>"
                        $ObjOut = "Validation failed. InboundProtocol parameter value is not a valid port number."
                        $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                        Write-Output $output
                        Exit                        
                    }
                }
            }
            else
            {
                Write-LogFile -FilePath $LogFilePath -LogText "Validating if the $InboundBackEndPort is a valid port number.Only ERRORs will be logged."
                #$InboundBackEndPort = [Int32]$InboundBackEndPort
                #write-host ([Int32]$InboundBackEndPortt -notin (1..65535))
                if([Int32]$InboundBackEndPortt -notin (1..65535))
                {
                    Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. InboundBackEndPort parameter value is not a vlaid port number.`r`n<#BlobFileReadyForUpload#>"
                    $ObjOut = "Validation failed. InboundBackEndPort parameter value is not a vlaid port number."
                    $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                    Write-Output $output
                    Exit                        
                }
            } 
            # Validate parameter: TargetVMorAvailabilitySet
            #Write-LogFile -FilePath $LogFilePath -LogText "Validating Parameters: TargetVMorAvailabilitySet. Only ERRORs will be logged."
            #If([String]::IsNullOrEmpty($TargetVMorAvailabilitySet))
            #{
            #    Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. TargetVMorAvailabilitySet parameter value is empty."
            #    $ObjOut = "Validation failed. TargetVMorAvailabilitySet parameter value is empty."
            #    $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
            #    Write-Output $output
            #    Exit
            #}

            <# Validate parameter: PortMapping
            Write-LogFile -FilePath $LogFilePath -LogText "Validating Parameters: PortMapping. Only ERRORs will be logged."
            If([String]::IsNullOrEmpty($PortMapping))
            {
                Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. PortMapping parameter value is empty."
                $ObjOut = "Validation failed. PortMapping parameter value is empty."
                $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                Write-Output $output
                Exit
            }
            if($PortMapping.Contains(","))
            {
                $PortMappings = @()
                $PortMappings = $PortMapping.Split(",")
                $Script:InPortMappings = @() 

                foreach($PortMap in $PortMappings)
                {
                    Write-LogFile -FilePath $LogFilePath -LogText "Validating if the $PortMap is a valid Port mapping.Only ERRORs will be logged."
                    if($PortMapping -notin ('Default','Custom'))
                    {
                        Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. InboundProtocol parameter value is not a valid port mapping."
                        $ObjOut = "Validation failed. InboundProtocol parameter value is not a valid port mapping."
                        $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                        Write-Output $output
                        Exit                        
                    }
                }
            }#>

            # Validate parameter: NATFloatingIP
            #Write-LogFile -FilePath $LogFilePath -LogText "Validating Parameters: NATFloatingIP. Only ERRORs will be logged."
            #If([String]::IsNullOrEmpty($NATFloatingIP))
            #{
            #    Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. NATFloatingIP parameter value is empty."
            #    $ObjOut = "Validation failed. NATFloatingIP parameter value is empty."
            #    $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
            #    Write-Output $output
            #    Exit
            #}

            # Validate parameter: TargetPort
            #Write-LogFile -FilePath $LogFilePath -LogText "Validating Parameters: TargetPort. Only ERRORs will be logged."
            #If([String]::IsNullOrEmpty($TargetPort))
            #{
            #    Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. TargetPort parameter value is empty."
            #    $ObjOut = "Validation failed. TargetPort parameter value is empty."
            #    $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
            #    Write-Output $output
            #    Exit
            #}

            # Validate parameter: LoadBalancingProtocol
            Write-LogFile -FilePath $LogFilePath -LogText "Validating Parameters: LoadBalancingProtocol. Only ERRORs will be logged."
            If([String]::IsNullOrEmpty($LoadBalancingProtocol))
            {
                Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. LoadBalancingProtocol parameter value is empty.`r`n<#BlobFileReadyForUpload#>"
                $ObjOut = "Validation failed. LoadBalancingProtocol parameter value is empty."
                $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                Write-Output $output
                Exit
            }
            Else
            {
                Write-LogFile -FilePath $LogFilePath -LogText "Validating if the $LoadBalancingProtocol is a valid load balancing protocol.Only ERRORs will be logged."
                if($LoadBalancingProtocol -notin ('Tcp','Udp'))
                {
                    Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. LoadBalancingProtocol parameter value is not a valid load balancing protocol.`r`n<#BlobFileReadyForUpload#>"
                    $ObjOut = "Validation failed. LoadBalancingProtocol parameter value is not a valid load balancing protocol."
                    $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                    Write-Output $output
                    Exit
                }
            }

            # Validate parameter: LoadBalancingPort
            Write-LogFile -FilePath $LogFilePath -LogText "Validating Parameters: LoadBalancingPort. Only ERRORs will be logged."
            If([String]::IsNullOrEmpty($LoadBalancingPort))
            {
                Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. LoadBalancingPort parameter value is empty.`r`n<#BlobFileReadyForUpload#>"
                $ObjOut = "Validation failed. LoadBalancingPort parameter value is empty."
                $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                Write-Output $output
                Exit
            }
            Else
            {
                Write-LogFile -FilePath $LogFilePath -LogText "Validating if the $LoadBalancingPort is a valid port number.Only ERRORs will be logged."
                $LoadBalancingPort = [Int32]$LoadBalancingPort
                if($LoadBalancingPort -notin (1..65535))
                {
                    Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. LoadBalancingPort parameter value is not a valid port number.`r`n<#BlobFileReadyForUpload#>"
                    $ObjOut = "Validation failed. LoadBalancingPort parameter value is not a valid port number."
                    $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                    Write-Output $output
                    Exit
                }
            }

            # Validate parameter: BackEndPort
            Write-LogFile -FilePath $LogFilePath -LogText "Validating Parameters: BackEndPort. Only ERRORs will be logged."
            If([String]::IsNullOrEmpty($BackEndPort))
            {
                Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. BackEndPort parameter value is empty.`r`n<#BlobFileReadyForUpload#>"
                $ObjOut = "Validation failed. BackEndPort parameter value is empty."
                $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                Write-Output $output
                Exit
            }
            Else
            {
                Write-LogFile -FilePath $LogFilePath -LogText "Validating if the $BackEndPort is a valid port number.Only ERRORs will be logged."
                $BackEndPort = [int32]$BackEndPort
                if($BackEndPort -notin (1..65535))
                {
                    Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. BackEndPort parameter value is not a valid port number.`r`n<#BlobFileReadyForUpload#>"
                    $ObjOut = "Validation failed. BackEndPort parameter value is not a valid port number."
                    $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                    Write-Output $output
                    Exit
                }
            }

            # Validate parameter: SessionPersistence
            #Write-LogFile -FilePath $LogFilePath -LogText "Validating Parameters: SessionPersistence. Only ERRORs will be logged."
            #If([String]::IsNullOrEmpty($SessionPersistence))
            #{
            #    Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. SessionPersistence parameter value is empty."
            #    $ObjOut = "Validation failed. SessionPersistence parameter value is empty."
            #    $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
            #    Write-Output $output
            #    Exit
            #}

            # Validate parameter: LoadBalancerFloatingIP
            #Write-LogFile -FilePath $LogFilePath -LogText "Validating Parameters: LoadBalancerFloatingIP. Only ERRORs will be logged."
            #If([String]::IsNullOrEmpty($LoadBalancerFloatingIP))
            #{
            #    Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. LoadBalancerFloatingIP parameter value is empty."
            #    $ObjOut = "Validation failed. LoadBalancerFloatingIP parameter value is empty."
            #   $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
            #    Write-Output $output
            #    Exit
            #}
            # Validating the number of arguments are equal or not if mutliple Inbound NAT rules are provided.
            $Script:ParamCount = $Script:InboundNATRuleNames.Count
            if($Script:InboundNATRuleNames.Count -eq 1)
            {
            }
            Else
            {
                if(($Script:InboundNATRuleNames.Count -gt 1) -and ($Script:InboundProtocols.Count -eq $Script:ParamCount) -and ($Script:InboundPorts.Count -eq $Script:ParamCount) -and ($Script:InboundBackEndPorts.Count -eq $Script:ParamCount))
                {
                }
                Else
                {
                    Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. The Number of aruguments for Inbound NAT rules are not equal for multiple rules.`r`n<#BlobFileReadyForUpload#>"
                    $ObjOut = "Validation failed. The Number of aruguments for Inbound NAT rules are not equal for multiple rules."
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
    # 1. Validating the parameters

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
        $ObjOut = "Error while getting Azure Resource Group details.`r`n$($Error[0].Exception.Message)"
        $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
        Write-Output $output
        Write-LogFile -FilePath $LogFilePath -LogText "$ObjOut`r`n<#BlobFileReadyForUpload#>"
        Exit
    }

    # 6. Creating the FrondEndPool
    Try
    {
        Write-LogFile -FilePath $LogFilePath -LogText "Creating the FronEnd Pool $FrontEndPoolName."
        $FrontEndPools = $null
        $FrontEndPoolName = $LoadBalancerName +"_FronEndPool"
        if($LoadBalancerType -eq 'Public')
        {
            Write-LogFile -FilePath $LogFilePath -LogText "Checking for the Public IP Address $PublicIPAddressName."
            ($PublicIPObj = Get-AzureRmPublicIpAddress -Name $PublicIPAddressName -ResourceGroupName $ResourceGroupName -ErrorAction SilentlyContinue -WarningAction SilentlyContinue) | Out-Null
            if($PublicIPObj -ne $null)
            {
                Write-LogFile -FilePath $LogFilePath -LogText "The Public IP Address $PublicIPAddressName is already exist. Checking for its availability."
                if($PublicIPObj.IpConfiguration -ne $null)
                {
                    Write-LogFile -FilePath $LogFilePath -LogText "The Public IP Address Name $PublicIPAddressName is already in Use.`r`n<#BlobFileReadyForUpload#>"
                    $ObjOut = "The Public IP Address Name $PublicIPAddressName is already in Use."
                    $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                    Write-Output $output
                    Exit                    
                }Else{ }
            }
            Else
            {
                Write-LogFile -FilePath $LogFilePath -LogText "The Provided Public IP address $PublicIPAddressName does not exist, creating a new public ip address."
                ($PublicIPObj = New-AzureRmPublicIpAddress -Name $PublicIPAddressName -ResourceGroupName $ResourceGroupName -Location $Location -AllocationMethod Dynamic -IpAddressVersion IPv4 -DomainNameLabel $LoadBalancerName -ErrorAction Stop -WarningAction SilentlyContinue) | Out-Null
                if($PublicIPObj.ProvisioningState -eq 'Succeeded')
                {
                    Write-LogFile -FilePath $LogFilePath -LogText "The Public IP Address $PublicIPAddressName has been created successfully."
                }
                Else
                {
                    Write-LogFile -FilePath $LogFilePath -LogText "Creation of new public Ip address $PublicIPAddressName was not successful.`r`n<#BlobFileReadyForUpload#>" 
                    $ObjOut = "Creation of new public Ip address $PublicIPAddressName was not successful."
                    $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                    Write-Output $output
                    Exit                    
                }
            }

            Write-LogFile -FilePath $LogFilePath -LogText "Creating the FrontEnd Pool $FrontEndPoolName with Public Ip address $PublicIPAddressName."
            ($FrontEndPools = New-AzureRmLoadBalancerFrontendIpConfig -Name $FrontEndPoolName -PublicIpAddress $PublicIPObj -ErrorAction Stop -WarningAction SilentlyContinue) | Out-Null
            if($FrontEndPools.ProvisioningState -eq 'Succeeded')
            {
                Write-LogFile -FilePath $LogFilePath -LogText "The FrondEnd rule $FrontEndPoolName has been created successfully."
            }
            Else
            {
                Write-LogFile -FilePath $LogFilePath -LogText "Creation of frondEnd pool $FrontEndPoolName with Public IP was not successful.`r`n<#BlobFileReadyForUpload#>" 
                $ObjOut = "Creation of frondEnd pool $FrontEndPoolName with Public IP was not successful."
                $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                Write-Output $output
                Exit
            }
        }
        Elseif($LoadBalancerType -eq 'Internal')
        {
            Write-LogFile -FilePath $LogFilePath -LogText "checking for the Virtual Network $VirtualNetworkName and Subnet $SubnetName existence for Internal Load Balancer."
            ($VNetObject = Get-AzureRmVirtualNetwork -Name $VirtualNetworkName -ResourceGroupName $ResourceGroupName -ErrorAction SilentlyContinue -WarningAction SilentlyContinue) | Out-Null
            if($VNetObject -ne $null)
            {
                 Write-LogFile -FilePath $LogFilePath -LogText "The Virtual Network $VirtualNetworkName is already exist.Checking for the Subnet $SubnetName."
                 $SubnetNames = $VNetObject.Subnets.Name                
                if($SubnetNames.Contains($SubnetName))
                {
                    Write-LogFile -FilePath $LogFilePath -LogText "The Provided Subnet $SubnetName is already exist in VNet $VirtualNetworkName."
                    $SubnetObj = $VNetObject.Subnets | Where-Object {$_.Name -eq "$SubnetName"}
                }
                Else
                {
                    Write-LogFile -FilePath $LogFilePath -LogText "The Provided Subnet $SubnetName does not exist in the VNet $VirtualNetworkName.`r`n<#BlobFileReadyForUpload#>"
                    $ObjOut = "The Provided Subnet $SubnetName does not exist in the VNet $VirtualNetworkName."
                    $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                    Write-Output $output
                    Exit
                }
            }
            Else
            {
                Write-LogFile -FilePath $LogFilePath -LogText "The Provided Virtual Network $VirtualNetworkName does not exist.`r`n<#BlobFileReadyForUpload#>"
                $ObjOut = "The Provided Virtual Network $VirtualNetworkName does not exist."
                $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                Write-Output $output
                Exit
            }

            Write-LogFile -FilePath $LogFilePath -LogText "Creating the FrontEnd Pool $FrontEndPoolName for Internal Load Balancer."
            if($IPAddressType -eq 'Static')
            {
                Write-LogFile -FilePath $LogFilePath -LogText "Creating the frontend pool $FrontEndPoolName with Static IP $StaticIPAddress."
                ($FrontEndPools = New-AzureRmLoadBalancerFrontendIpConfig -Name $FrontEndPoolName -Subnet $SubnetObj -PrivateIpAddress $StaticIPAddress -ErrorAction Stop -WarningAction SilentlyContinue) | Out-Null
                if($FrontEndPools.ProvisioningState -eq 'Succeeded')
                {
                    Write-LogFile -FilePath $LogFilePath -LogText "The FrontEnd Pool $FrontEndPoolName for internal load balancer has been created successfully."
                }
                Else
                {
                    Write-LogFile -FilePath $LogFilePath -LogText "Creation of frondEnd pool $FrontEndPoolName for Internal Load Balancer with Static IP was not successful.`r`n<#BlobFileReadyForUpload#>" 
                    $ObjOut = "Creation of frondEnd pool $FrontEndPoolName for Internal Load Balancer with Static IP was not successful."
                    $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                    Write-Output $output
                    Exit
                }
            }
            Else
            {
                Write-LogFile -FilePath $LogFilePath -LogText "Creating the frontend pool $FrontEndPoolName with Dynamic IP Address."
                ($FrontEndPools = New-AzureRmLoadBalancerFrontendIpConfig -Name $FrontEndPoolName -Subnet $SubnetObj -ErrorAction Stop -WarningAction SilentlyContinue) | Out-Null
                if($FrontEndPools.ProvisioningState -eq 'Succeeded')
                {
                    Write-LogFile -FilePath $LogFilePath -LogText "The FrontEnd Pool $FrontEndPoolName for internal load balancer with Dynamic IP has been created successfully."
                }
                Else
                {
                    Write-LogFile -FilePath $LogFilePath -LogText "Creation of frondEnd pool $FrontEndPoolName for Internal Load Balancer with Dynamic IP was not successful.`r`n<#BlobFileReadyForUpload#>" 
                    $ObjOut = "Creation of frondEnd pool $FrontEndPoolName for Internal Load Balancer with Dynamic IP was not successful."
                    $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                    Write-Output $output
                    Exit
                }             
            }

        }Else{}
    }
    Catch
    {
        $ObjOut = "Error while frontEnd Address pool.`r`n$($Error[0].Exception.Message)"
        $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
        Write-Output $output
        Write-LogFile -FilePath $LogFilePath -LogText "$ObjOut`r`n<#BlobFileReadyForUpload#>"
        Exit
    }

    # 7. Creating Backend Pools
    Try
    {
        Write-LogFile -FilePath $LogFilePath -LogText "Creating the Backend Pool $BackEndPoolName."
        $BackEndPools = $null
        ($BackEndPools = New-AzureRmLoadBalancerBackendAddressPoolConfig -Name $BackEndPoolName -ErrorAction Stop -WarningAction SilentlyContinue) | Out-Null
        if($BackEndPools.ProvisioningState -eq 'Succeeded')
        {
                Write-LogFile -FilePath $LogFilePath -LogText "The Backend Pool $BackEndPoolName has been created successfully."
        }
        Else
        {
            Write-LogFile -FilePath $LogFilePath -LogText "Creationg of Backend Pool $BackEndPoolName was not successful.`r`n<#BlobFileReadyForUpload#>" 
            $ObjOut = "Creationg of Backend Pool $BackEndPoolName was not successful."
            $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
            Write-Output $output
            Exit
        }
    }
    Catch
    {
        $ObjOut = "Error while creating the Backend Address pool.`r`n$($Error[0].Exception.Message)"
        $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
        Write-Output $output
        Write-LogFile -FilePath $LogFilePath -LogText "$ObjOut`r`n<#BlobFileReadyForUpload#>"
        Exit
    }

    # 8. Creating the Probe Rules
    Try
    {
        Write-LogFile -FilePath $LogFilePath -LogText "Creating the Probe Rules $ProbeName." 
        $ProbeObj = $null
        if($ProbeProtocol -eq 'Http')
        {
            Write-LogFile -FilePath $LogFilePath -LogText "Creating the Probe rule $ProbeName with Http."             
            ($ProbeObj = New-AzureRmLoadBalancerProbeConfig -Name $ProbeName -Port $ProbePort -Protocol $ProbeProtocol -RequestPath $ProbePath -ProbeCount $ProbeUnhealthythreshold -IntervalInSeconds $ProbeInterval -ErrorAction Stop -WarningAction SilentlyContinue ) | Out-Null                 
        }
        Else
        {
            Write-LogFile -FilePath $LogFilePath -LogText "Creating the Probe rule $ProbeName with Tcp." 
            ($ProbeObj = New-AzureRmLoadBalancerProbeConfig -Name $ProbeName -Port $ProbePort -Protocol $ProbeProtocol -IntervalInSeconds $ProbeInterval -ProbeCount $ProbeUnhealthythreshold -ErrorAction Stop -WarningAction SilentlyContinue) | Out-Null
        }

        If($ProbeObj.ProvisioningState -eq 'Succeeded')
        {
            Write-LogFile -FilePath $LogFilePath -LogText "The Probe rule $ProbeName has been created successfully."            
        }
        Else
        {
            Write-LogFile -FilePath $LogFilePath -LogText "Creation of Proble rule $ProbeName was not successful.`r`n<#BlobFileReadyForUpload#>" 
            $ObjOut = "Creation of Proble rule $ProbeName was not successful."
            $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
            Write-Output $output
            Exit   
        }
    }
    Catch
    {
        $ObjOut = "Error while creating the Probe rule $ProbeName for the Load balancer.$($Error[0].Exception.Message)"
        $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
        Write-Output $output
        Write-LogFile -FilePath $LogFilePath -LogText "$ObjOut`r`n<#BlobFileReadyForUpload#>"
        Exit
    }

    # 9. Creating InBountNATRules 
    Try
    {
        Write-LogFile -FilePath $LogFilePath -LogText "Creating the Inbound NAT Rules"
        $InBoundRules = @()
        for($i=0;$i -lt $Script:Params.Length;$i++)
        {
            ($Inboundrule = New-AzureRmLoadBalancerInboundNatRuleConfig -Name $Script:InboundNATRuleNames[$i] -FrontendIpConfigurationId $FrontEndPools -Protocol $Script:InboundProtocols[$i] -FrontendPort $Script:InboundPorts[$i] -BackendPort $Script:InboundBackEndPorts[$i] -ErrorAction Stop -WarningAction SilentlyContinue) | Out-Null
            if($Inboundrule.ProvisioningState -eq 'Succeeded')
            {
                Write-LogFile -FilePath $LogFilePath -LogText "The Inbound rule $InboundNATRuleName has been created."
                $InBoundRules += $Inboundrule
            }
            Else
            {
                Write-LogFile -FilePath $LogFilePath -LogText "Creation of inbound NAT rule $InboundNATRuleName[$i] was not successful.`r`n<#BlobFileReadyForUpload#>" 
                $ObjOut = "Creation of inbound NAT rule $InboundNATRuleName[$i] was not successful."
                $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                Write-Output $output
                Exit
            }
        }
    }
    Catch
    {
        $ObjOut = "Error while creating the Inbound NAT rules.$($Error[0].Exception.Message)"
        $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
        Write-Output $output
        Write-LogFile -FilePath $LogFilePath -LogText "$ObjOut`r`n<#BlobFileReadyForUpload#>"
        Exit
    }

    # 10. Creating the Load Balancer rule Config
    Try
    {
        Write-LogFile -FilePath $LogFilePath -LogText "Creating the Load Balancer rule $LoadBalancerRuleName config."
        $LoadBalanceruleObj = $null
        ($LoadBalanceruleObj = New-AzureRmLoadBalancerRuleConfig -Name $LoadBalancerRuleName -FrontendIpConfiguration $FrontEndPools -BackendAddressPool $BackEndPools -Probe $ProbeObj -Protocol $LoadBalancingProtocol -FrontendPort $LoadBalancingPort -BackendPort $BackEndPort -LoadDistribution $SessionPersistence -ErrorAction Stop -WarningAction SilentlyContinue) | Out-Null
        if($LoadBalanceState.ProvisioningState -eq 'Succeeded')
        {
            Write-LogFile -FilePath $LogFilePath -LogText "The Load balancer rule $LoadBalancerName has been created successfully."
        }
        Else
        {
            Write-LogFile -FilePath $LogFilePath -LogText "Creation of $LoadBalancerRuleName was not successfull.`r`n<#BlobFileReadyForUpload#>" 
            $ObjOut = "Creation of $LoadBalancerRuleName was not successfull."
            $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
            Write-Output $output
            Exit
        }
    }
    Catch
    {
        $ObjOut = "Error while creating the load balancer configuration $LoadBalancerRuleName.`r`n$($Error[0].Exception.Message)"
        $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
        Write-Output $output
        Write-LogFile -FilePath $LogFilePath -LogText "$ObjOut`r`n<#BlobFileReadyForUpload#>"
        Exit
    }

    # 11. Creating the Load Balancer
    Try
    {
        Write-LogFile -FilePath $LogFilePath -LogText "Creating the Load Balancer $LoadBalancerName with all configuration."
        $LoadBalanceState = $null
        ($LoadBalanceState = Get-AzureRmLoadBalancer -Name $LoadBalancerName -ResourceGroupName $ResourceGroupName -ErrorAction SilentlyContinue -WarningAction SilentlyContinue) | Out-Null
        if($LoadBalanceState -eq $null)
        {
            ($LoadBalanceState = New-AzureRmLoadBalancer -Name $LoadBalancerName -ResourceGroupName $ResourceGroupName -Location $Location -FrontendIpConfiguration $FrontEndPools -BackendAddressPool $BackEndPools -Probe $ProbeObj -InboundNatRule $InBoundRules -LoadBalancingRule $LoadBalancerruleObj -ErrorAction Stop -WarningAction SilentlyContinue) | Out-Null
            if($LoadBalanceState.ProvisioningState -eq 'Succeeded')
            {
                Write-LogFile -FilePath $LogFilePath -LogText "The Load Balancer $LoadBalancerName has been created successfully.`r`n<#BlobFileReadyForUpload#>"
                $ObjOut = "The Load Balancer $LoadBalancerName has been created successfully."
                $output = (@{"Response" = [Array]$ObjOut; Status = "Success"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                Write-Output $output
            }
            Else
            {
                Write-LogFile -FilePath $LogFilePath -LogText "Creation of $LoadBalancerName was not successfull.`r`n<#BlobFileReadyForUpload#>" 
                $ObjOut = "Creation of $LoadBalancerName was not successfull."
                $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                Write-Output $output
                Exit
            }
        }
        Else
        {
            Write-LogFile -FilePath $LogFilePath -LogText "The Load Balancer $LoadBalancerName is already exist.`r`n<#BlobFileReadyForUpload#>" 
            $ObjOut = "The Load Balancer $LoadBalancerName is already exist."
            $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
            Write-Output $output
            Exit            
        }
    }
    Catch
    {
        $ObjOut = "Error while creating the Load Balancer $LoadBalancerName.$($Error[0].Exception.Message)"
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