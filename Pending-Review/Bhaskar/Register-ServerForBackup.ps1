<##
    .SYNOPSIS
    The script to install the Microsoft Azure Recovery Services Agent on the Virtual Machine.

    .DESCRIPTION
    The script to install the Microsoft Azure Recovery Services Agent on the Virtual Machine.

    .PARAMETER ClientID
    Client ID to be used for this script.

    .PARAMETER AzureUserName
    User name for Azure login. This should be an Organizational account (not Hotmail/Outlook account)

    .PARAMETER AzurePassword
    Password for Azure user account.

    .PARAMETER AzureSubscriptionID
    Azure Subscription ID to use for this activity.

    .PARAMETER ResourceGroupName
    Name of the Resource Group name to be used for this command.

    .PARAMETER Location
    Azure Location to use for creating/saving/accessing resources (should be a valid location. Refer to https://azure.microsoft.com/en-us/regions/ for more details.)

    .PARAMETER VMName
    Azure virtual Machine which will be protected.

    .PARAMETER BackupVaultName 
    Azure Backup vault name to which the server has to registered.

    .PARAMETER Passphrase 
    Passphrase for encryption.

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
    C:\PS> .\RegisterServerBackup.ps1 -ClientID 12345 -AzureUserName Bhaskar@netenrich.com -AzurePassword Passwrd1 -AzureSubscriptionID ca68598c-ecc3-4abc-b7a2-1ecef33f278d -resourceGroupName testgrp -Location 'East Asia' -BackupVaultName testvault -StorageAccountName teststorage -Passphrase 1234567895241255
    
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
    [String]$ResourceGroupName,

	[Parameter(ValueFromPipelineByPropertyName)]
    [String]$Location,
    
    [Parameter(ValueFromPipelineByPropertyName)]
    [string]$VMName,

    [Parameter(ValueFromPipelineByPropertyName)]
    [string]$BackupVaultName,

    [Parameter(ValueFromPipelineByPropertyName)]
    [string]$StorageAccountName,

    #[Parameter(ValueFromPipelineByPropertyName)]
    #[string]$PrivateContainerName,

    [Parameter(ValueFromPipelineByPropertyName)]
    [string]$Passphrase
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
    #If($AzurePSVersion.Major -ge 1 -and $AzurePSVersion.Minor -ge 4)
    If($AzurePSVersion -ge 1.4)
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

            # Validate parameter: BackupVaultName
            Write-LogFile -FilePath $LogFilePath -LogText "Validating Parameters: BackupVaultName. Only ERRORs will be logged."
            If([String]::IsNullOrEmpty($BackupVaultName))
            {
                Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. BackupVaultName parameter value is empty.`r`n<#BlobFileReadyForUpload#>"
                $ObjOut = "Validation failed. BackupVaultName parameter value is empty."
                $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                Write-Output $output
                Exit
            }

            # Validate parameter: StorageAccountName
            Write-LogFile -FilePath $LogFilePath -LogText "Validating Parameters: StorageAccountName. Only ERRORs will be logged."
            If([String]::IsNullOrEmpty($StorageAccountName))
            {
                Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. StorageAccountName parameter value is empty.`r`n<#BlobFileReadyForUpload#>"
                $ObjOut = "Validation failed. StorageAccountName parameter value is empty."
                $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                Write-Output $output
                Exit
            }

            # Validate parameter: Passphrase
            Write-LogFile -FilePath $LogFilePath -LogText "Validating Parameters: Passphrase. Only ERRORs will be logged."
            If([String]::IsNullOrEmpty($Passphrase))
            {
                Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. Passphrase parameter value is empty.`r`n<#BlobFileReadyForUpload#>"
                $ObjOut = "Validation failed. Passphrase parameter value is empty."
                $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                Write-Output $output
                Exit
            }
            Else 
            {
                if($Passphrase.Length -lt 17)
                {
                    Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. Passphrase length is less than 17.`r`n<#BlobFileReadyForUpload#>"
                    $ObjOut = "Validation failed. Passphrase length is less than 17."
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
        $ObjOut = "Error while getting Azure Resource Group details.$($Error[0].Exception.Message)"
        $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
        Write-Output $output
        Write-LogFile -FilePath $LogFilePath -LogText "$ObjOut`r`n<#BlobFileReadyForUpload#>"
        Exit
    }

    # 5. Checking for the VM existence
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

    # 6. Check the vault and Download the vault credentials
    try 
    {
        $DestinationPath = "C:\"
        Write-LogFile -FilePath $LogFilePath -LogText "Checking for the Backup vault existence."
        ($vaults = Get-AzureRmRecoveryServicesVault -Name $BackupVaultname -ResourceGroupName $ResourceGroupName -ErrorAction SilentlyContinue -warningAction SilentlyContinue) | Out-Null
        if($vaults -ne $null)
        {   
            Write-LogFile -FilePath $LogFilePath -LogText "The Backup Vault $BackupVaultName is already exist.Downloading the Vault Credential file."
            ($VaultSettings = Get-AzureRmRecoveryServicesVaultSettingsFile -Vault $vaults -Path $DestinationPath -backup -ErrorAction SilentlyContinue -warningAction SilentlyContinue) | Out-Null
            if($VaultSettings -ne $null)
            {
                Write-LogFile -FilePath $LogFilePath -LogText "The Backup Vault $BackupVaultName Settings file has been downloaded."
                $VaultFileName = Split-Path -Path ($VaultSettings.FilePath) -leaf
                ($VaultFileContent = Get-Content -Path $($VaultSettings.FilePath) -Encoding Ascii -ErrorAction SilentlyContinue -WarningAction SilentlyContinue) | Out-Null
            }
            Else 
            {
                Write-LogFile -FilePath $LogFilePath -LogText "Unable to download the vault settings file.`r`n<#BlobFileReadyForUpload#>"
                $ObjOut = "Unable to download the vault settings file."
                $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                Write-Output $output
                Exit
            }
        }
        else 
        {
            Write-LogFile -FilePath $LogFilePath -LogText "The Backup vault $BackupVaultName does not exist.`r`n<#BlobFileReadyForUpload#>"
            $ObjOut = "The Backup vault $BackupVaultName does not exist."
            $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
            Write-Output $output
            Exit            
        }
    }
    Catch
    {
        Write-LogFile -FilePath $LogFilePath -LogText "Error while downlading the Vault Setting File for the Backup Vault $BackupVaultName.`r`n<#BlobFileReadyForUpload#>"
        $ObjOut = "Error while downlading the Vault Setting File for the Backup Vault $BackupVaultName."
        $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
        Write-Output $output
        Exit
    }

    # 7. Check Storage Container and Upload Vault Credentials
    Try
    {
        $ContainerName = 'vaultfile'

        Write-LogFile -FilePath $LogFilePath -LogText "Checking for the Storage Account and Container."
        ($Stores = Get-AzureRmStorageAccount -ResourceGroupName $ResourceGroupName -Name $StorageAccountName -ErrorAction SilentlyContinue -WarningAction SilentlyContinue) | Out-Null
        if($Stores -ne $null)
        {
            Write-LogFile -FilePath $LogFilePath -LogText "Storage Account is already exist and checking for the Container."
            ($StorageKeys = Get-AzureRmStorageAccountKey -ResourceGroupName $ResourceGroupName -Name $StorageAccountName -ErrorAction SilentlyContinue -WarningAction SilentlyContinue) | Out-Null
            $PrimaryKey = ($StorageKeys | Where-Object {$_.KeyName -eq 'key1'}).Value
            ($Context = New-AzureStorageContext -StorageAccountName $StorageAccountName -StorageAccountKey $PrimaryKey -ErrorAction SilentlyContinue -WarningAction SilentlyContinue) | Out-Null

            $BlobName = $ClientID + $VaultFileName
            ($ContainerExist = Get-AzureStorageContainer -Name $ContainerName -Context $Context -ErrorAction SilentlyContinue -WarningAction SilentlyContinue) | Out-Null
            if($ContainerExist -eq $null)
            {
                Write-LogFile -FilePath $LogFilePath -LogText "The given container $ContainerName does not exist,creating the new container."
                ($ContainerStatus = New-AzureStorageContainer -Name $ContainerName -Permission Container -Context $Context -ErrorAction Stop -WarningAction SilentlyContinue) | Out-Null
                if($ContainerStatus -ne $null)
                {
                    Write-LogFile -FilePath $LogFilePath -LogText "New container $ContainerName has been created, uploading the Vault credentials to blob."
                    ($Uploadstatues = Set-AzureStorageBlobContent -Container $ContainerStatus.Name -Blob $BlobName -Context $Context -Force -File $VaultSettings.FilePath -ErrorAction Stop -WarningAction SilentlyContinue) | Out-Null
                    if($? -eq $true)
                    {
                        Write-LogFile -FilePath $LogFilePath -LogText "Vault credentials have been uploaded sucessfully."
                        $Start = Get-Date
                        # Adding time to expire
                        $endTime = $Start.AddDays(1)
                        $SASToken = New-AzureStorageContainerSASToken -Name $ContainerName -Permission r -StartTime $Start -ExpiryTime $endTime -Context $Context                       
                        $Blobs = Get-AzureStorageBlob -Blob $BlobName -Container $ContainerName -Context $Context
                        $BlobUrl = $($Blobs.ICloudBlob.Uri.AbsoluteUri)
                        $SplitSASToens = $SASToken.Split("&")
                    }
                    Else
                    {
                        Write-LogFile -FilePath $LogFilePath -LogText "Uploading the vault credentials was failed.`r`n<#BlobFileReadyForUpload#>"
                        $ObjOut = "Uploading the vault credentials was failed."
                        $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                        Write-Output $output
                        Exit
                    }
                }
                Else
                {
                    Write-LogFile -FilePath $LogFilePath -LogText "Creating the new container $ContainerName was failed. `r`n<#BlobFileReadyForUpload#>"
                    $ObjOut = "Creating the new container was failed"
                    $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                    Write-Output $output
                    Exit
                }
            }
            Else
            {
                Write-LogFile -FilePath $LogFilePath -LogText "The given container $ContainerName is already exist,fetching the details."
                ($Uploadstatues = Set-AzureStorageBlobContent -Container $ContainerExist.Name -Blob $BlobName -Context $Context -Force -File $VaultSettings.FilePath -ErrorAction Stop -WarningAction SilentlyContinue) | Out-Null
                if($? -eq $true)
                {
                    Write-LogFile -FilePath $LogFilePath -LogText "Vault credentials have been uploaded sucessfully."
                    $Start = Get-Date
                    # Adding time to expire
                    $endTime = $Start.AddDays(1)
                    $SASToken = New-AzureStorageContainerSASToken -Name $ContainerName -Permission r -StartTime $Start -ExpiryTime $endTime -Context $Context                       
                    $Blobs = Get-AzureStorageBlob -Blob $BlobName -Container $ContainerName -Context $Context
                    $BlobUrl = $($Blobs.ICloudBlob.Uri.AbsoluteUri)
                    $SplitSASToens = $SASToken.Split("&")
                }
                Else
                {
                    Write-LogFile -FilePath $LogFilePath -LogText "Uploading the vault credentials was failed.`r`n<#BlobFileReadyForUpload#>"
                    $ObjOut = "Uploading the vault credentials was failed."
                    $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                    Write-Output $output
                    Exit
                }
            }
        }
        else
        {
            Write-LogFile -FilePath $LogFilePath -LogText "The provided storage account $StorageAccountName does not exist.`r`n<#BlobFileReadyForUpload#>"
            $ObjOut = "The provided storage account $StorageAccountName does not exist."
            $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
            Write-Output $output
            Exit
        }
    }
    Catch
    {
        $ObjOut = "Error while setting the script for Registering the server $VMName for backup.$($Error[0].Exception.Message)"
        $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
        Write-Output $output
        Write-LogFile -FilePath $LogFilePath -LogText "$ObjOut`r`n<#BlobFileReadyForUpload#>"
        Exit
    }

    # 8. register the server for backup
    Try
    {
        Write-LogFile -FilePath $LogFilePath -LogText "Checking for the existing custom script extensions."
        $extensions = $VMExist.Extensions | Where-Object {$_.VirtualMachineExtensionType -eq 'CustomScriptExtension'}
        if($extensions)
        {
            Write-LogFile -FilePath $LogFilePath -LogText "Removing the existing CustomScript extensions."
            ($RemoveState = Remove-AzureRmVMExtension -ResourceGroupName $ResourceGroupName -VMName $VMName -Name $($extensions.Name) -Force -ErrorAction Stop -WarningAction SilentlyContinue) | Out-Null
            if($RemoveState.StatusCode -eq 'OK')
            {
                Write-LogFile -FilePath $LogFilePath -LogText "Successfully removed the existing CustomScript extension and adding new handle."
            }
            else
            {
                Write-LogFile -FilePath $LogFilePath -LogText "Unable to remove the existing CustomScript extensions.`r`n<#BlobFileReadyForUpload#>"
                $ObjOut = "Unable to remove the existing CustomScript extensions."
                $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                Write-Output $output
                Exit
            }
        }

        $ExtensionName = "RegisterProtectedServer"
        Write-LogFile -FilePath $LogFilePath -LogText "Trying to Set the Extension for registering the protected server."

        ($MARSInstallExtensionStatus = Set-AzureRmVMCustomScriptExtension -Name $ExtensionName -FileUri "https://automationtest.blob.core.windows.net/customscriptfiles/Register-ServerForBackupCS.ps1" -Run Register-ServerForBackupCS.ps1 -Argument "$BlobUrl $Passphrase $($SplitSASToens[0]) $($SplitSASToens[1]) $($SplitSASToens[2]) $($SplitSASToens[3]) $($SplitSASToens[4]) $($SplitSASToens[5])" -ResourceGroupName $ResourceGroupName -Location $Location -VMName $VMName -TypeHandlerVersion 1.8 -ErrorAction Stop -WarningAction SilentlyContinue) | Out-Null

        if($MARSInstallExtensionStatus.StatusCode -eq 'OK')
        {
            ($InstallationStatus = Get-AzureRmVMExtension -Name $ExtensionName -ResourceGroupName $ResourceGroupName -VMName $VMName -Status -ErrorAction SilentlyContinue -WarningAction SilentlyContinue) | Out-Null
            if($InstallationStatus -ne $null)
            {
                while($InstallationStatus.ProvisioningState -notin ('Succeeded','Failed'))
                {
                    ($InstallationStatus = Get-AzureRmVMExtension -Name $ExtensionName -ResourceGroupName $ResourceGroupName -VMName $VMName -Status -ErrorAction SilentlyContinue -WarningAction SilentlyContinue) | Out-Null
                }

                ($ScriptStatus = Get-AzureRMVM -Name $VMName -ResourceGroupName $ResourceGroupName -Status -ErrorAction SilentlyContinue -WarningAction SilentlyContinue) | Out-Null
                $ExtScriptStatus = $ScriptStatus.Extensions | Where-Object {$_.Name -eq $ExtensionName}
                if(($ExtScriptStatus.Statuses.Code -eq 'ProvisioningState/succeeded'))
                {
                    $message1 = ($ExtScriptStatus.Substatuses | Where-Object {$_.code -contains 'StdOut'}).Message
                    $message2 = ($ExtScriptStatus.Substatuses | Where-Object {$_.code -contains 'StdErr'}).Message
                    if(($message1 -eq $null) -and ($message2 -eq $null))
                    {
                        Write-LogFile -FilePath $LogFilePath -LogText "The Server $VMName has been register for backup successfully.`r`n<#BlobFileReadyForUpload#>"
                        $ObjOut = "The Server $VMName has been register for backup successfully."
                        $output = (@{"Response" = [Array]$ObjOut; Status = "Success"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                        Write-Output $output
                    }
                    Else 
                    {
                        Write-LogFile -FilePath $LogFilePath -LogText "The Server $VMName has not been register for backup successfully.$message1.$message2`r`n<#BlobFileReadyForUpload#>"
                        $ObjOut = "The Server $VMName has not been register for backup successfully.$message1.$message2."
                        $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                        Write-Output $output
                        Exit                        
                    }
                }
                else
                {
                    Write-LogFile -FilePath $LogFilePath -LogText "Provisioning the script for Registering the server $VMName for backup was failed.`r`n<#BlobFileReadyForUpload#>"
                    $ObjOut = "Provisioning the script for Registering the server $VMName for backup was failed."
                    $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                    Write-Output $output
                    Exit
                }
            }
            else
            {
                Write-LogFile -FilePath $LogFilePath -LogText "The extension was not installed for Registering the server $VMName for backup.`r`n<#BlobFileReadyForUpload#>"
                $ObjOut = "The extension was not installed for Registering the server $VMName for backup."
                $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                Write-Output $output
                Exit
            }           
        }
        Else
        {
            Write-LogFile -FilePath $LogFilePath -LogText "Unable to install the custom script extension for Registering the server $VMName for backup.`r`n<#BlobFileReadyForUpload#>"
            $ObjOut = "Unable to install the custom script extension for Registering the server $VMName for backup."
            $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
            Write-Output $output
            Exit            
        }
    }
    catch
    {
        $ObjOut = "Error while setting the script for Registering the server $VMName for backup.$($Error[0].Exception.Message)"
        $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
        Write-Output $output
        Write-LogFile -FilePath $LogFilePath -LogText "$ObjOut`r`n<#BlobFileReadyForUpload#>"
        Exit
    }

    # 9. Custom script Cleanup activity to avoid script rerun on Virtual Machine restarts
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
