<#
    .SYNOPSIS
    The Script is create and configure the firewall rules in azure vm.

    .DESCRIPTION
    The Script is create and configure the firewall rules in azure vm.

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
            
    .PARAMETER VMName
    Name of the Virtual Machine to be used for this command.

    .PARAMETER FirewallRuleName
    Name of the firewall rule to be used for this command.

    .PARAMETER ScriptAction
    Script Action to be used for this command. Actions are like New,Set,Remove

    .PARAMETER FirewallAction
    Firewall action to be used for this command. e.g Allow, Deny

    .PARAMETER FlowDirection
    Flow Direction to be used for this command. e.g Inbound, Outbound

    .PARAMETER LocalPort
    Local Port number to be used for this command.

    .PARAMETER RemotePort
    Remote Port number to be used for this command.

    .PARAMETER Protocol
    Name of the Protocol to be used for this command. e.g tcp,udp,icmp etc

    .PARAMETER FirewallProfile
    Name of the Firewall profile to be used for this command. e.g Any, Domain, Public, Private

    .INPUTS
    All parameter values in String format.

    .OUTPUTS
    String. Result of the command output.

    .NOTES
     Purpose of script: The script is to create Firewall rules on Azure VM
     Minimum requirements: Azure PowerShell Version 1.4.0
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

    .EXAMPLE
    C:\PS> .\Create-Firewallrules.ps1 -ClientID 123456 AzureUserName bhaskar.desharaju@netenrich.com AzurePassword ****** AzureSubscriptionID ca68598c-ecc3-4abc-b7a2-1ecef33f278d ResourceGroupName testgrp Location 'southeast asia' VMName testvm-bhaskar ScriptAction New FirewallAction Allow FlowDirection Inbound LocalPort 80 RemotePort 80 Protocol tcp FirewallProfile Public

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
    [String]$FirewallRuleName,
    
    [Parameter(ValueFromPipelineByPropertyName)]
    [String]$ScriptAction,

    [Parameter(ValueFromPipelineByPropertyName)]
    [String]$FirewallAction,

    [Parameter(ValueFromPipelineByPropertyName)]
    [String]$FlowDirection,
    
    [Parameter(ValueFromPipelineByPropertyName)]
    [String]$LocalPort,

    [Parameter(ValueFromPipelineByPropertyName)]
    [String]$RemotePort,

    [Parameter(ValueFromPipelineByPropertyName)]
    [String]$Protocol,

    [Parameter(ValueFromPipelineByPropertyName)]
    [String]$FirewallProfile
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
       $ObjOut = "Required version of Azure PowerShell not available. Stopping execution.`nDownload and install required version from: http://aka.ms/webpi-azps.`
        `r`nRequired version of Azure PowerShell is $($ScriptUploadConfig.RequiredPSVersion). Current version on host machine is $($AzurePSVersion.ToString())."
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

            # Validate parameter: FirewallRuleName
            Write-LogFile -FilePath $LogFilePath -LogText "Validating Parameters: FirewallRuleName. Only ERRORs will be logged."
            If([String]::IsNullOrEmpty($FirewallRuleName))
            {
                Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. FirewallRuleName parameter value is empty.`r`n<#BlobFileReadyForUpload#>"
                $ObjOut = "Validation failed. FirewallRuleName parameter value is empty."
                $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                Write-Output $output
                Exit
            }
            If($FirewallRuleName.Contains(","))
            {
                Write-LogFile -FilePath $LogFilePath -LogText "FirewallRuleName parameter received an array. Spitting the Values.`r`n<#BlobFileReadyForUpload#>"
                $script:FirewallRuleNames = @()
                $script:FirewallRuleNames = $FirewallRuleName.Split(",")
            }
               
            # Validate parameter: ScriptAction
            Write-LogFile -FilePath $LogFilePath -LogText "Validating Parameters: ScriptAction. Only ERRORs will be logged."
            If([String]::IsNullOrEmpty($ScriptAction))
            {
                Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. ScriptAction parameter value is empty.`r`n<#BlobFileReadyForUpload#>"
                $ObjOut = "Validation failed. ScriptAction parameter value is empty."
                $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                Write-Output $output
                Exit
            }
            If($ScriptAction.Contains(","))
            {
                Write-LogFile -FilePath $LogFilePath -LogText "ScriptAction parameter received an array. Spitting the Values.`r`n<#BlobFileReadyForUpload#>"
                $Script:ScriptActions = @()
                $Script:ScriptActions = $ScriptAction.Split(",")

                foreach($SAction in $Script:ScriptActions )
                {
                    if($SAction -notin ('New','Set','Remove'))
                    {
                        Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. SAction is not a valid value.`r`n<#BlobFileReadyForUpload#>"
                        $ObjOut = "Validation failed. SAction is not a valid value."
                        $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                        Write-Output $output
                        Exit
                    }
                }
            }
            Else
            {
                if($ScriptAction -notin ('New','Set','Remove'))
                {
                    Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. ScriptAction is not a valid value.`r`n<#BlobFileReadyForUpload#>"
                    $ObjOut = "Validation failed. ScriptAction is not a valid value."
                    $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                    Write-Output $output
                    Exit
                }                
            }

            if($ScriptAction -in ('New','Set'))
            {
                # Validate parameter: FirewallAction
                Write-LogFile -FilePath $LogFilePath -LogText "Validating Parameters: FirewallAction. Only ERRORs will be logged."
                If([String]::IsNullOrEmpty($FirewallAction))
                {
                    Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. FirewallAction parameter value is empty.`r`n<#BlobFileReadyForUpload#>"
                    $ObjOut = "Validation failed. FirewallAction parameter value is empty."
                    $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                    Write-Output $output
                    Exit
                }
                if($FirewallAction.Contains(","))
                {
                    Write-LogFile -FilePath $LogFilePath -LogText "FirewallAction parameter received an array. Spitting the Values.`r`n<#BlobFileReadyForUpload#>"
                    $Script:FirewallActions = @()
                    $Script:FirewallActions = $FirewallAction.Split(",")

                    foreach($FAction in $Script:FirewallActions)
                    {
                        if($FAction -notin ('Allow','Deny'))
                        {
                            Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. FirewallAction is not a valid value.`r`n<#BlobFileReadyForUpload#>"
                            $ObjOut = "Validation failed. FirewallAction is not a valid value."
                            $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                            Write-Output $output
                            Exit
                        }
                    }               
                }
                Else
                {
                    if($FirewallAction -notin ('Allow','Deny'))
                    {
                        Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. FirewallAction is not a valid value.`r`n<#BlobFileReadyForUpload#>"
                        $ObjOut = "Validation failed. FirewallAction is not a valid value."
                        $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                        Write-Output $output
                        Exit
                    }
                } 
            
                # Validate parameter: FlowDirection
                Write-LogFile -FilePath $LogFilePath -LogText "Validating Parameters: FlowDirection. Only ERRORs will be logged."
                If([String]::IsNullOrEmpty($FlowDirection))
                {
                    Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. FlowDirection parameter value is empty.`r`n<#BlobFileReadyForUpload#>"
                    $ObjOut = "Validation failed. FlowDirection parameter value is empty."
                    $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                    Write-Output $output
                    Exit
                }
                if($FlowDirection.Contains(","))
                {
                    Write-LogFile -FilePath $LogFilePath -LogText "FlowDirection parameter received an array. Spitting the Values.`r`n<#BlobFileReadyForUpload#>"
                    $Script:FlowDirections = @()
                    $Script:FlowDirections = $FlowDirection.Split(",")

                    foreach($FDirection in $Script:FlowDirections)
                    {
                        if($FDirection -notin ('Inbound','Outbound'))
                        {
                            Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. FlowDirection is not a valid value.`r`n<#BlobFileReadyForUpload#>"
                            $ObjOut = "Validation failed. FlowDirection is not a valid value."
                            $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                            Write-Output $output
                            Exit
                        }
                    }
                }
                Else
                {
                    if($FlowDirection -notin ('Inbound','Outbound'))
                    {
                        Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. FlowDirection is not a valid value.`r`n<#BlobFileReadyForUpload#>"
                        $ObjOut = "Validation failed. FlowDirection is not a valid value."
                        $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                        Write-Output $output
                        Exit
                    }
                }
               
                # Validate parameter: LocalPort
                Write-LogFile -FilePath $LogFilePath -LogText "Validating Parameters: LocalPort. Only ERRORs will be logged."
                If([String]::IsNullOrEmpty($LocalPort))
                {
                    Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. LocalPort parameter value is empty.`r`n<#BlobFileReadyForUpload#>"
                    $ObjOut = "Validation failed. LocalPort parameter value is empty."
                    $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                    Write-Output $output
                    Exit
                }
                if($LocalPort.Contains(","))
                {
                    $Script:LocalPorts = @()
                    $Script:LocalPorts = $LocalPort.Split(",")
                }

                # Validate parameter: RemotePort
                Write-LogFile -FilePath $LogFilePath -LogText "Validating Parameters: RemotePort. Only ERRORs will be logged."
                If([String]::IsNullOrEmpty($RemotePort))
                {
                    Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. RemotePort parameter value is empty.`r`n<#BlobFileReadyForUpload#>"
                    $ObjOut = "Validation failed. RemotePort parameter value is empty."
                    $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                    Write-Output $output
                    Exit
                }
                if($RemotePort.Contains(","))
                {
                    $Script:RemotePorts = @()
                    $Script:RemotePorts = $RemotePort.Split(",")
                }

                # Validate parameter: Protocol
                Write-LogFile -FilePath $LogFilePath -LogText "Validating Parameters: Protocol. Only ERRORs will be logged."
                If([String]::IsNullOrEmpty($Protocol))
                {
                    Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. Protocol parameter value is empty.`r`n<#BlobFileReadyForUpload#>"
                    $ObjOut = "Validation failed. Protocol parameter value is empty."
                    $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                    Write-Output $output
                    Exit
                }
                if($Protocol.Contains(","))
                {
                    $Script:Protocols = @()
                    $Script:Protocols = $Protocol.Split(",")
                }
            
                # Validate parameter: FirewallProfile
                Write-LogFile -FilePath $LogFilePath -LogText "Validating Parameters: FirewallProfile. Only ERRORs will be logged."
                If([String]::IsNullOrEmpty($FirewallProfile))
                {
                    Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. FirewallProfile parameter value is empty.`r`n<#BlobFileReadyForUpload#>"
                    $ObjOut = "Validation failed. FirewallProfile parameter value is empty."
                    $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                    Write-Output $output
                    Exit
                }
                if($FirewallProfile.Contains(","))
                {
                    Write-LogFile -FilePath $LogFilePath -LogText "FirewallProfile parameter received an array. Spitting the Values.`r`n<#BlobFileReadyForUpload#>"
                    $Script:FirewallProfiles = @()
                    $Script:FirewallProfiles = $FirewallProfile.Split(",")

                    foreach($FProfile in $Script:FirewallProfiles)
                    {
                        if($FProfile -notin ('Any','Domain','Public','Private'))
                        {
                            Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. FirewallProfile is not a valid value.`r`n<#BlobFileReadyForUpload#>"
                            $ObjOut = "Validation failed. FirewallProfile is not a valid value."
                            $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                            Write-Output $output
                            Exit
                        }
                    }
                }
                Else
                {
                    if($FirewallProfile -notin ('Any','Domain','Public','Private'))
                    {
                        Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. FirewallProfile is not a valid value.`r`n<#BlobFileReadyForUpload#>"
                        $ObjOut = "Validation failed. FirewallProfile is not a valid value."
                        $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                        Write-Output $output
                        Exit
                    }
                }
                $Script:ParamCount = $script:FirewallRuleNames.Count
                if(($script:FirewallRuleNames.Count -eq 0)){}
                Elseif($script:FirewallRuleNames.Count -ge 1)
                {
                    if((($script:FirewallRuleNames.Count -gt 1) -and ($Script:ScriptActions -eq $script) -and ($Script:FirewallActions -eq $Script:ParamCount) -and ($Script:FlowDirections -eq $Script:ParamCount) -and ($Script:LocalPorts -eq $Script:ParamCount) -and ($Script:RemotePorts -eq $Script:ParamCount) -and ($Script:Protocols -eq $Script:ParamCount) -and ($Script:FirewallProfiles -eq $Script:ParamCount)))
                    {
                    }
                    Else
                    {
                        Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. Multiple rules have been provided with less number of parameters.`r`n<#BlobFileReadyForUpload#>"
                        $ObjOut = "Validation failed. Multiple rules have been provided with less number of parameters."
                        $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                        Write-Output $output
                        Exit
                    }
                }
                else {
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
    # 1. Validate Parameters

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

    # 4. Checking for the VM Existence and Its status
    Try
    {
        Write-LogFile -FilePath $LogFilePath -LogText "Verifying the VM existence in the subscription." 

        ($VMExist = Get-AzureRMVM -ResourceGroupName $ResourceGroupName -Name $VMName -ErrorAction SilentlyContinue -WarningAction SilentlyContinue) | Out-Null
        if($VMExist)
        {
            Write-LogFile -FilePath $LogFilePath -LogText "Virtual Machine is already exist."
            ($VMStatus = Get-AzureRMVM -ResourceGroupName $ResourceGroupName -Name $VMName -Status -ErrorAction SilentlyContinue -WarningAction SilentlyContinue) | Out-Null
            $state = $VMStatus.Statuses | Where-Object {$_.DisplayStatus -eq "VM Running"}
            if($state.code -eq 'PowerState/running')
            {
                 Write-LogFile -FilePath $LogFilePath -LogText "The Virtual Machine $VMName is already running state."
            }
            else
            {
                Write-LogFile -FilePath $LogFilePath -LogText "The Virtual Machine $VMName is not in a running state.`r`n<#BlobFileReadyForUpload#>"
                $ObjOut = "The Virtual Machine $VMName is not in a running state."
                $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                Write-Output $output
                Exit
            }
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

    # 5. Applying the custom script for Firewall rules configuration
    Try
    {
        Write-LogFile -FilePath $LogFilePath -LogText "Checking for the existing Customscript extensions."
        $extensions = $VMExist.Extensions | Where-Object {$_.VirtualMachineExtensionType -eq 'CustomScriptExtension'}
        if($extensions -ne $null)
        {
            Write-LogFile -FilePath $LogFilePath -LogText "Removing the existing CustomScriptExtension extensions."
            ($RemoveState = Remove-AzureRmVMExtension -ResourceGroupName $ResourceGroupName -VMName $VMName -Name $($extensions.Name) -Force -ErrorAction Stop -WarningAction SilentlyContinue) | Out-Null
            if($RemoveState.StatusCode -eq 'OK')
            {
                Write-LogFile -FilePath $LogFilePath -LogText "Successfully removed the existing extension and adding new handle."
            }
            else
            {
                Write-LogFile -FilePath $LogFilePath -LogText "Unable to remove the existing VM extensions.`r`n<#BlobFileReadyForUpload#>"
                $ObjOut = "Unable to remove the existing VM extensions."
                $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                Write-Output $output
                Exit
            }
        }

        $ExtensionName = "FirewallRules"
        Write-LogFile -FilePath $LogFilePath -LogText "Applying the Firewall rules to the Virtual Machine."
        if($Script:ParamCount -gt 1)
        {
            ($FirewallExtensionStatus = Set-AzureRmVMCustomScriptExtension -Name $ExtensionName -FileUri "https://automationtest.blob.core.windows.net/customscriptfiles/Create-FirewallSettingsCS.ps1" -Run Create-FirewallSettingsCS.ps1 -Argument "$($Script:ParamCount) $($script:FirewallRuleNames) $($Script:ScriptActions) $($Script:FirewallActions) $($Script:FlowDirections) $($Script:LocalPorts) $($Script:RemotePorts) $($Script:Protocols) $($script:FirewallProfiles)" -ResourceGroupName $ResourceGroupName -Location $Location -VMName $VMName -TypeHandlerVersion 1.8 -ErrorAction Stop -WarningAction SilentlyContinue) | Out-Null
        }
        Else
        {
            ($FirewallExtensionStatus = Set-AzureRmVMCustomScriptExtension -Name $ExtensionName -FileUri "https://automationtest.blob.core.windows.net/customscriptfiles/Create-FirewallSettingsCS.ps1" -Run Create-FirewallSettingsCS.ps1 -Argument "1 $FirewallRuleName $ScriptAction $FirewallAction $FlowDirection $LocalPort $RemotePort $Protocol $FirewallProfile" -ResourceGroupName $ResourceGroupName -Location $Location -VMName $VMName -TypeHandlerVersion 1.8 -ErrorAction Stop -WarningAction SilentlyContinue) | Out-Null
        }

        if($FirewallExtensionStatus.StatusCode -eq 'OK')
        {
            ($FirewallScritStatus = Get-AzureRmVMExtension -Name $ExtensionName -ResourceGroupName $ResourceGroupName -VMName $VMName -Status -ErrorAction SilentlyContinue -WarningAction SilentlyContinue) | Out-Null
            if($FirewallScritStatus -ne $null)
            {
                while($FirewallScritStatus.ProvisioningState -notin ('Succeeded','Failed'))
                {
                    ($FirewallScritStatus = Get-AzureRmVMExtension -Name $ExtensionName -ResourceGroupName $ResourceGroupName -VMName $VMName -Status -ErrorAction SilentlyContinue -WarningAction SilentlyContinue) | Out-Null
                }

                ($ScriptStatus = Get-AzureRMVM -Name $VMName -ResourceGroupName $ResourceGroupName -Status -ErrorAction SilentlyContinue -WarningAction SilentlyContinue) | Out-Null
                $ExtScriptStatus = $ScriptStatus.Extensions | Where-Object {$_.Name -eq $ExtensionName}
                if(($ExtScriptStatus.Statuses.Code -eq 'ProvisioningState/succeeded'))
                {
                    $message1 = ($ExtScriptStatus.Substatuses | Where-Object {$_.code -contains 'StdOut'}).Message
                    $message2 = ($ExtScriptStatus.Substatuses | Where-Object {$_.code -contains 'StdErr'}).Message
                    if(($message1 -eq $null) -and ($message2 -eq $null))
                    {
                        Write-LogFile -FilePath $LogFilePath -LogText "Firewall Rules have been configured successfully on Virtual Machine $VMName.`r`n<#BlobFileReadyForUpload#>"
                        $ObjOut = "Firewall Rules have been configured successfully on Virtual Machine $VMName."
                        $output = (@{"Response" = [Array]$ObjOut; Status = "Success"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                        Write-Output $output
                    }
                    Else 
                    {
                        Write-LogFile -FilePath $LogFilePath -LogText "Firewall rules were not configured successfully on $VMName.$message1.$message2.`r`n<#BlobFileReadyForUpload#>"
                        $ObjOut = "Firewall rules were not configured successfully on $VMName.$message1.$message2."
                        $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                        Write-Output $output
                        Exit                        
                    }
                }
                else
                {
                    Write-LogFile -FilePath $LogFilePath -LogText "Provisioning the script for firewall rules configuration was failed on $VMName.`r`n<#BlobFileReadyForUpload#>"
                    $ObjOut = "Provisioning the script for firewall rules configuration was failed on $VMName."
                    $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                    Write-Output $output
                    Exit
                }
            }
            else
            {
                Write-LogFile -FilePath $LogFilePath -LogText "The extension was not installed for configuring the firewall rules on $VMName.`r`n<#BlobFileReadyForUpload#>"
                $ObjOut = "Extension was not installed for configuring the firewall rules on $VMName."
                $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                Write-Output $output
                Exit
            }           
        }
        Else
        {
            Write-LogFile -FilePath $LogFilePath -LogText "Unable to install the custom script extension for Virtual Machine $VMName.`r`n<#BlobFileReadyForUpload#>"
            $ObjOut = "Unable to install the custom script extension for Virtual Machine $VMName."
            $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
            Write-Output $output
            Exit            
        }
    }
    Catch
    {
        $ObjOut = "Error while setting the script for Configuring the Firewall rules in the VM $VMName.$($Error[0].Exception.Message)"
        $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
        Write-Output $output
        Write-LogFile -FilePath $LogFilePath -LogText "$ObjOut`r`n<#BlobFileReadyForUpload#>"
        Exit
    }

    # 7. Custom script Cleanup activity to avoid script rerun on Virtual Machine restarts
    Try 
    {
        Write-LogFile -FilePath $LogFilePath -LogText "Checking for the existing custom script extensions."
        ($VMObjExtension = Get-AzureRmVm -Name $VMName -ResourcegroupName $ResourceGroupName -ErrorAction SilentlyContinue -WarningAction SilentlyContinue) | Out-Null
        if($VMObjExtension -ne $null)
        {
            $extensions = $VMObjExtension.Extensions | Where-Object {$_.VirtualMachineExtensionType -eq 'CustomScriptExtension'}
            if($extensions)
            {
                Write-LogFile -FilePath $LogFilePath -LogText "Removing the existing CustomScript extensions."
                ($RemoveState = Remove-AzureRmVMExtension -ResourceGroupName $ResourceGroupName -VMName $VMName -Name $($extensions.Name) -Force -ErrorAction Stop -WarningAction SilentlyContinue) | Out-Null
                if($RemoveState.StatusCode -eq 'OK')
                {
                    Write-LogFile -FilePath $LogFilePath -LogText "Successfully removed the existing extension and adding new handle."
                }
                else
                {
                    Write-LogFile -FilePath $LogFilePath -LogText "Unable to remove the existing extensions.`r`n<#BlobFileReadyForUpload#>"
					$ObjOut = "Unable to remove the existing extensions."
                    $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                }
            }
        }
        Else 
        {
            Write-LogFile -FilePath $LogFilePath -LogText "Unable to fetch the Vm information to remove extension.`r`n<#BlobFileReadyForUpload#>"
            $ObjOut = "Unable to fetch the Vm information to remove extension."
            $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")            
        }
    }
    Catch
    {
        Write-LogFile -FilePath $LogFilePath -LogText "Error while removing the extension.`r`n<#BlobFileReadyForUpload#>"
        $ObjOut = "Error while removing the extension."
        $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
    }
}
End
{
    Write-LogFile -FilePath $LogFilePath -LogText "####[ Script execution completed cuccessfully: $($MyInvocation.MyCommand.Name) ]####`r`n<#BlobFileReadyForUpload#>"
}