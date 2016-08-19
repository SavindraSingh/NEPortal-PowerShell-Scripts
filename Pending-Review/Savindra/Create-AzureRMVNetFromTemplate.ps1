<#
    .SYNOPSIS
    Script to create New Virtual Network in Azure Resource Manager Portal

    .DESCRIPTION
    Script to create New Virtual Network in Azure Resource Manager Portal with one FronEnd one Backend and one Gateway subnet.

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

    .PARAMETER VNetName
    Name of the Virtual Network that you are trying to create.

    .INPUTS
    All parameter values in String format.

    .OUTPUTS
    String. Result of the command output.

    .NOTES
     Purpose of script: Create New Virtual Network in Azure Resource Manager Portal
     Minimum requirements: PowerShell Version 1.2.1
     Initially written by: SavindraSingh Shahoo
     Update/revision History:
     =======================
     Updated by    Date      Reason
     ==========    ====      ======

    .EXAMPLE
    C:\PS> .\Create-AzureRMVNetFromTemplate.ps1 -ClientID 421 -AzureUserName 'testlab@netenrich.com' -AzurePassword 'pass12@word' -AzureSubscriptionID 'ae7c7576-f01c-4026-9b94-d05e04e459fc' -Location 'Central US' -ResourceGroupName 'TestLabRG' -DeploymentName 'SavindraTestFromPS' -TemplateJSONPath '.\JsonTemplates\VNetTemplate.json' -ParameterJSONPath '.\JsonTemplates\VNetParameters.json' -VNetName 'JsnTmplVNetPSTest' -vnetAddressPrefix '172.16.0.0/16' -subnet1Prefix '172.16.1.0/24' -subnet2Prefix '172.16.2.0/24' -GatewayPrefix '172.16.0.0/26' -WarningAction 'SilentlyContinue'

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
    [String]$ResourceGroupName,

    [Parameter(ValueFromPipelineByPropertyName)]
    [String]$DeploymentName,

    [Parameter(ValueFromPipelineByPropertyName)]
    [String]$TemplateJSONPath,

    [Parameter(ValueFromPipelineByPropertyName)]
    [String]$ParameterJSONPath,

    [Parameter(ValueFromPipelineByPropertyName)]
    [String]$VNetName,

    [Parameter(ValueFromPipelineByPropertyName,HelpMessage="Example: 10.0.0.0/16")]
    [String]$vnetAddressPrefix,

    [Parameter(ValueFromPipelineByPropertyName,HelpMessage="Example: 10.0.0.0/16")]
    [String]$subnet1Prefix,

    [Parameter(ValueFromPipelineByPropertyName,HelpMessage="Example: 10.0.0.0/16")]
    [String]$subnet2Prefix,

    [Parameter(ValueFromPipelineByPropertyName,HelpMessage="Example: 10.0.0.0/16")]
    [String]$GatewayPrefix
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
                        Write-Output $output
                        Write-LogFile -FilePath $LogFilePath -LogText "$ObjOut`r`n<#BlobFileReadyForUpload#>"
                        Exit
                    }
                }
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

            # Validate parameter: vnetAddressPrefix
            Write-LogFile -FilePath $LogFilePath -LogText "Validating Parameters: vnetAddressPrefix. Only ERRORs will be logged."
            If([String]::IsNullOrEmpty($vnetAddressPrefix))
            {
                Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. vnetAddressPrefix parameter value is empty.`r`n<#BlobFileReadyForUpload#>"
                $ObjOut = "Validation failed. vnetAddressPrefix parameter value is empty.'"
                $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                Write-Output $output
                Exit
            }
            Else
            {
                Write-LogFile -FilePath $LogFilePath -LogText "Validating if vnetAddressPrefix is valid IP Address. Only ERRORs will be logged."
                $checkIP = $vnetAddressPrefix.Split("/")[0]
                If([bool]($checkIP -as [ipaddress])) { <# Valid IP address #>}
                Else
                {
                    Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. vnetAddressPrefix '$vnetAddressPrefix' is NOT a valid IP address.`r`n<#BlobFileReadyForUpload#>"
                    $ObjOut = "Validation failed. vnetAddressPrefix '$vnetAddressPrefix' is not a valid IP address."
                    $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                    Write-Output $output
                    Exit
                }
            }

            # Validate parameter: subnet1Prefix
            Write-LogFile -FilePath $LogFilePath -LogText "Validating Parameters: subnet1Prefix. Only ERRORs will be logged."
            If([String]::IsNullOrEmpty($subnet1Prefix))
            {
                Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. subnet1Prefix parameter value is empty.`r`n<#BlobFileReadyForUpload#>"
                $ObjOut = "Validation failed. subnet1Prefix parameter value is empty.'"
                $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                Write-Output $output
                Exit
            }
            Else
            {
                Write-LogFile -FilePath $LogFilePath -LogText "Validating if subnet1Prefix is valid IP Address. Only ERRORs will be logged."
                $checkIP = $subnet1Prefix.Split("/")[0]
                If([bool]($checkIP -as [ipaddress])) { <# Valid IP address #>}
                Else
                {
                    Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. subnet1Prefix '$subnet1Prefix' is NOT a valid IP address.`r`n<#BlobFileReadyForUpload#>"
                    $ObjOut = "Validation failed. subnet1Prefix '$subnet1Prefix' is not a valid IP address."
                    $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                    Write-Output $output
                    Exit
                }
            }

            # Validate parameter: subnet2Prefix
            Write-LogFile -FilePath $LogFilePath -LogText "Validating Parameters: subnet2Prefix. Only ERRORs will be logged."
            If([String]::IsNullOrEmpty($subnet2Prefix))
            {
                Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. subnet2Prefix parameter value is empty.`r`n<#BlobFileReadyForUpload#>"
                $ObjOut = "Validation failed. subnet2Prefix parameter value is empty.'"
                $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                Write-Output $output
                Exit
            }
            Else
            {
                Write-LogFile -FilePath $LogFilePath -LogText "Validating if subnet2Prefix is valid IP Address. Only ERRORs will be logged."
                $checkIP = $subnet2Prefix.Split("/")[0]
                If([bool]($checkIP -as [ipaddress])) { <# Valid IP address #>}
                Else
                {
                    Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. subnet2Prefix '$subnet2Prefix' is NOT a valid IP address.`r`n<#BlobFileReadyForUpload#>"
                    $ObjOut = "Validation failed. subnet2Prefix '$subnet2Prefix' is not a valid IP address."
                    $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                    Write-Output $output
                    Exit
                }
            }

            # Validate parameter: GatewayPrefix
            Write-LogFile -FilePath $LogFilePath -LogText "Validating Parameters: GatewayPrefix. Only ERRORs will be logged."
            If([String]::IsNullOrEmpty($GatewayPrefix))
            {
                Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. GatewayPrefix parameter value is empty.`r`n<#BlobFileReadyForUpload#>"
                $ObjOut = "Validation failed. GatewayPrefix parameter value is empty.'"
                $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                Write-Output $output
                Exit
            }
            Else
            {
                Write-LogFile -FilePath $LogFilePath -LogText "Validating if GatewayPrefix is valid IP Address. Only ERRORs will be logged."
                $checkIP = $GatewayPrefix.Split("/")[0]
                If([bool]($checkIP -as [ipaddress])) { <# Valid IP address #>}
                Else
                {
                    Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. GatewayPrefix '$GatewayPrefix' is NOT a valid IP address.`r`n<#BlobFileReadyForUpload#>"
                    $ObjOut = "Validation failed. GatewayPrefix '$GatewayPrefix' is not a valid IP address."
                    $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                    Write-Output $output
                    Exit
                }
            }

            Write-LogFile -FilePath $LogFilePath -LogText "All parameters validated successfully."
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
            Write-Host $ObjOut -ForegroundColor Red
            Write-LogFile -FilePath $LogFilePath -LogText "$ObjOut`r`n<#BlobFileReadyForUpload#>"
            Exit
        }
    }
}

Process
{
    # Validate parameters
    Validate-AllParameters

    # 1. Login to Azure subscription
    Login-ToAzureAccount
    
    # 2. Check if Resource Group exists. Create Resource Group if it does not exist.
    Try
    {
        Write-LogFile -FilePath $LogFilePath -LogText "Checking existance of resource group '$ResourceGroupName'"
        $ResourceGroup = $null
        ($ResourceGroup = Get-AzureRmResourceGroup -Name $ResourceGroupName -ErrorAction Stop) | Out-Null
    
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
                $ObjOut = "Error while creating Azure Resource Group '$ResourceGroupName'.`r`n$($Error[0].Exception.Message)`r`n<#BlobFileReadyForUpload#>"
                $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                Write-Output $output
                Write-LogFile -FilePath $LogFilePath -LogText "$ObjOut"
                Exit
            }
        }
    }
    Catch
    {
        $ObjOut = "Error while getting Azure Resource Group details.`r`n$($Error[0].Exception.Message)`r`n<#BlobFileReadyForUpload#>"
        $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
        Write-Output $output
        Write-LogFile -FilePath $LogFilePath -LogText "$ObjOut"
        Exit
    }


    # 3. Create Virtual Network
    Try
    {
        # Create parameter JSON file
        $ParameterJSONText = @"
{
  "`$schema": "http://schema.management.azure.com/schemas/2015-01-01/deploymentParameters.json#",
  "contentVersion": "1.0.0.0",
  "parameters": {
    "vnetName": { "value": "$VNetName" },
    "vnetAddressPrefix": { "value": "$vnetAddressPrefix" },
    "subnet1Prefix": { "value": "$subnet1Prefix" },
    "subnet2Prefix": { "value": "$subnet2Prefix" },
    "gatewaySubnetPrefix": { "value": "$GatewayPrefix" }
  }
}
"@
        ($ParameterJSONText | Out-File -FilePath $ParameterJSONPath -ErrorAction Stop) | Out-Null

        Write-LogFile -FilePath $LogFilePath -LogText "Creating Virtual Network '$VNetName'"
        (New-AzureRmResourceGroupDeployment -Name $DeploymentName -ResourceGroupName $ResourceGroupName -TemplateParameterFile $ParameterJSONPath -TemplateFile $TemplateJSONPath -ErrorAction Stop -WarningAction SilentlyContinue) | Out-Null

        Write-LogFile -FilePath $LogFilePath -LogText "Virtual Network '$VNetName' created successfully"
        $ObjOut = "Virtual Network '$VNetName' created successfully"
        $output = (@{"Response" = [Array]$ObjOut; Status = "Success"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
        Write-Output $output
    }
    Catch
    {
        $ObjOut = "Error while creating Virtual Network '$VNetName'.`r`n$($Error[0].Exception.Message)`r`n<#BlobFileReadyForUpload#>"
        $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
        Write-Output $output
        Write-LogFile -FilePath $LogFilePath -LogText "$ObjOut"
        Exit
    }
}

End
{
    Write-LogFile -FilePath $LogFilePath -LogText "####[ Script execution completed cuccessfully: $($MyInvocation.MyCommand.Name) ]####`r`n<#BlobFileReadyForUpload#>"
}