<#
    .SYNOPSIS
    Script to Backup Azure IIS VM in Azure Resource Manager Portal

    .DESCRIPTION
    Script to Backup Azure IIS VM in Azure Resource Manager Portal

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

    .PARAMETER RSVaultName
    Recovery services vaul name to use for backup. 

    .PARAMETER BackupStorageRedundancy
    Specify the storage type. Provide the values from the list of valid values. 
    
    Valid values: "LocallyRedundant","GeoRedundant"
    
    .PARAMETER DaysOfWeek
    Specify the Weekdays on which you want to perform backup. Valid values for this parameter are:
    "Sunday"
    "Monday"
    "Tuesday"
    "Wednesday"
    "Thursday"
    "Friday"
    "Saturday"

    .PARAMETER TimesOfDay
    Specify the time value in HH:MM (24 Hrs) time format. You can specify multiple values seperated by comma.

    .PARAMETER VMToBackup
    Name of the ARM VM to Backup.

    .INPUTS
    All parameter values in String format.

    .OUTPUTS
    String. Result of the command output.

    .NOTES
     Purpose of script: To Backup Azure IIS VM in ARM Portal
     Minimum requirements: PowerShell Version 1.2.1
     Initially written by: SavindraSingh Shahoo
     Update/revision History:
     =======================
     Updated by        Date            Reason
     ==========        ====            ======
     SavindraSingh     26-May-16       Changed Mandatory=$True to Mandatory=$False for all parameters.

    .EXAMPLE
    C:\PS> 

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
    [String]$ResourceGroupName,

    [Parameter(ValueFromPipelineByPropertyName)]
    [string]$Location,

    [Parameter(ValueFromPipelineByPropertyName)]
    [String]$RSVaultName,

    # Valid values: "LocallyRedundant","GeoRedundant"
    [Parameter(ValueFromPipelineByPropertyName)]
    [String]$BackupStorageRedundancy,

    [Parameter(ValueFromPipelineByPropertyName)]
    [String[]]$DaysOfWeek,

    # only in multipals of 00:30 minutes. e.g. 00:30, 01:00, 01:30 ... 12:00, 12:30 so on..
    [Parameter(ValueFromPipelineByPropertyName)]
    [String]$TimesOfDay,

    # Valid values "Daily","Weekly"
    [Parameter(ValueFromPipelineByPropertyName)]
    [String]$ScheduleRunFrequency,

    [Parameter(ValueFromPipelineByPropertyName)]
    [String]$VMBackupPolicyName,

    [Parameter(ValueFromPipelineByPropertyName)]
    [String]$EnableWeeklyRetentionSchedule,

    [Parameter(ValueFromPipelineByPropertyName)]
    [String]$EnableMonthlyRetentionSchedule,

    [Parameter(ValueFromPipelineByPropertyName)]
    [String]$EnableYearlyRetentionSchedule,

    [Parameter(ValueFromPipelineByPropertyName)]
    [String[]]$VMToBackup
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

    # "LocallyRedundant","GeoRedundant"
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

            # Validate parameter: RSVaultName
            Write-LogFile -FilePath $LogFilePath -LogText "Validating Parameters: RSVaultName. Only ERRORs will be logged."
            If([String]::IsNullOrEmpty($RSVaultName))
            {
                Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. RSVaultName parameter value is empty.`r`n<#BlobFileReadyForUpload#>"
                $ObjOut = "Validation failed. RSVaultName parameter value is empty."
                $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                Write-Output $output
                Exit
            }

            # Validate parameter: BackupStorageRedundancy LocallyRedundant, GeoRedundant
            Write-LogFile -FilePath $LogFilePath -LogText "Validating Parameters: BackupStorageRedundancy. Only ERRORs will be logged."
            If([String]::IsNullOrEmpty($BackupStorageRedundancy))
            {
                Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. BackupStorageRedundancy parameter value is empty.`r`n<#BlobFileReadyForUpload#>"
                $ObjOut = "Validation failed. BackupStorageRedundancy parameter value is empty.'"
                $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                Write-Output $output
                Exit
            }
            Else
            {
                $BackupStorageRedundancyValues = @("LocallyRedundant", "GeoRedundant")
                If($BackupStorageRedundancy -in $BackupStorageRedundancyValues)
                { <# Parameter value is valid #> }
                Else
                {
                    Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. PerformanceTear '$BackupStorageRedundancy' is NOT a valid value for this parameter.`r`n<#BlobFileReadyForUpload#>"
                    $ObjOut = "Validation failed. PerformanceTear '$BackupStorageRedundancy' is not a valid value for this parameter."
                    $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                    Write-Output $output
                    Exit
                }
            }

            # Validate parameter: VMToBackup
            Write-LogFile -FilePath $LogFilePath -LogText "Validating Parameters: 'VMToBackup'. Only ERRORs will be logged."
            If([String]::IsNullOrEmpty($VMToBackup))
            {
                Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. 'VMToBackup' parameter value is empty.`r`n<#BlobFileReadyForUpload#>"
                $ObjOut = "Validation failed. 'VMToBackup' parameter value is empty."
                $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                Write-Output $output
                Exit
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

    # Function: Login to Azure subscription
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
    Validate-AllParameters

    # 1. Login to Azure subscription
    Login-ToAzureAccount

    # (Validation) If you are using Azure Backup for the first time, you must use the Register-AzureRMResourceProvider cmdlet 
    #     to register the Azure Recovery Service provider with your subscription.
    Try
    {
        (Register-AzureRmResourceProvider -ProviderNamespace "Microsoft.RecoveryServices" -Force -ErrorAction Stop -WarningAction SilentlyContinue) | Out-Null
    }
    Catch
    {
        $ObjOut = "Error registering Azure Recovery Service provider with subscription.`n$($Error[0].Exception.Message)"
        $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
        Write-LogFile -FilePath $LogFilePath -LogText "$ObjOut`r`n<#BlobFileReadyForUpload#>"
        Write-Output $output
        Exit
    }

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

    # 3. Check if Recovery Services Vault exists. Create Recovery Services Vault if it does not exist.
    Try
    {
        Write-LogFile -FilePath $LogFilePath -LogText "Checking existance of Recovery Services Vault '$RSVaultName'`n"
        $RSVault = $null
        ($RSVault = Get-AzureRmRecoveryServicesVault -ResourceGroupName $ResourceGroupName -Name $RSVaultName -ErrorAction SilentlyContinue -WarningAction SilentlyContinue) | Out-Null
    
        If($RSVault -ne $null) # Recovery Services Vault already exists
        {
           Write-LogFile -FilePath $LogFilePath -LogText "Recovery Services Vault already exists"
        }
        Else # Recovery Services Vault does not exist. Can't continue without creating Recovery Services Vault.
        {
            Try
            {
               Write-LogFile -FilePath $LogFilePath -LogText "Recovery Services Vault '$RSVaultName' does not exist. Creating Recovery Services Vault."
               ($RSVault = New-AzureRmRecoveryServicesVault -Name $RSVaultName -ResourceGroupName $ResourceGroupName -Location $Location -ErrorAction Stop -WarningAction SilentlyContinue) | Out-Null
               Write-LogFile -FilePath $LogFilePath -LogText "Recovery Services Vault '$RSVaultName' created successfully."
            }
            Catch
            {
                $ObjOut = "Error while creating Azure Recovery Services Vault '$RSVaultName'.`r`n$($Error[0].Exception.Message)"
                $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                Write-Output $output
                Write-LogFile -FilePath $LogFilePath -LogText "$ObjOut`r`n<#BlobFileReadyForUpload#>"
                Exit
            }
        }
    }
    Catch
    {
        $ObjOut = "Error while getting Azure Recovery Services Vault details.`r`n$($Error[0].Exception.Message)"
        $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
        Write-Output $output
        Write-LogFile -FilePath $LogFilePath -LogText "$ObjOut`r`n<#BlobFileReadyForUpload#>"
        Exit
    }

    # Configure backup
    Try
    {
        # 4. Specify type of Storage/redundancy
        Write-LogFile -FilePath $LogFilePath -LogText "Setting-up Backup properties (type of storage/redundancy)."
        (Set-AzureRmRecoveryServicesBackupProperties  -Vault $RSVault -BackupStorageRedundancy $BackupStorageRedundancy -ErrorAction Stop -WarningAction SilentlyContinue) | Out-Null
        Write-LogFile -FilePath $LogFilePath -LogText "Backup properties (type of storage/redundancy) set to '$BackupStorageRedundancy' successfully."

        # 5. Set Vault context
        Write-LogFile -FilePath $LogFilePath -LogText "Setting-up vault context to '$RSVaultName'."
        ($RSVault | Set-AzureRmRecoveryServicesVaultContext -ErrorAction Stop -WarningAction SilentlyContinue) | Out-Null
        Write-LogFile -FilePath $LogFilePath -LogText "Vault context sucessfully set to '$RSVaultName'."
    }
    Catch
    {
        $ObjOut = "Error while configuring backup options. Check log file for more details.`r`n$($Error[0].Exception.Message)"
        $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
        Write-Output $output
        Write-LogFile -FilePath $LogFilePath -LogText "$ObjOut`r`n<#BlobFileReadyForUpload#>"
        Exit
    }

    Try
    {
        Write-LogFile -FilePath $LogFilePath -LogText "Creating Backup schedule policy object."
        $schPol = Get-AzureRmRecoveryServicesBackupSchedulePolicyObject -WorkloadType AzureVM
        Write-LogFile -FilePath $LogFilePath -LogText "Backup schedule policy object created successfully."

        Write-LogFile -FilePath $LogFilePath -LogText "Creating Backup retention policy object."
        $retPol = Get-AzureRmRecoveryServicesBackupRetentionPolicyObject -WorkloadType AzureVM
        Write-LogFile -FilePath $LogFilePath -LogText "Backup retention policy object created successfully."

        Write-LogFile -FilePath $LogFilePath -LogText "Check if Backup policy already exists '$VMBackupPolicyName'."
        ($pol = Get-AzureRmRecoveryServicesBackupProtectionPolicy -Name "$VMBackupPolicyName" -ErrorAction SilentlyContinue -WarningAction SilentlyContinue) | Out-Null

        If($pol -eq $null)
        {
            Write-LogFile -FilePath $LogFilePath -LogText "No Policy exist with name '$VMBackupPolicyName. Creating new Policy object."
            ($pol = New-AzureRmRecoveryServicesBackupProtectionPolicy -Name "$VMBackupPolicyName" -WorkloadType AzureVM -RetentionPolicy $retPol -SchedulePolicy $schPol -ErrorAction Stop -WarningAction SilentlyContinue) | Out-Null
            Write-LogFile -FilePath $LogFilePath -LogText "New Backup policy created successfully."
        }

        # Updating Policy run Schedule and Retention policy object
        Try
        {
            Write-LogFile -FilePath $LogFilePath -LogText "Updating Policy run Schedule and retention policy object."

            # Remove existing Schedules
            Write-LogFile -FilePath $LogFilePath -LogText "Removing Default schedule and configuring new schedule based on user inputs."
            $SchRunTimesCount = $schPol.ScheduleRunTimes.Count
            If($SchRunTimesCount -gt 0)
            {
             Write-LogFile -FilePath $LogFilePath -LogText "Removing Default Run times."
               for ($i = 0; $i -lt $SchRunTimesCount; $i++)
                {
                    $i | Out-Null
                    $schPol.ScheduleRunTimes.RemoveAt($i);
                }
             Write-LogFile -FilePath $LogFilePath -LogText "Default Run times removed successfully."
            }
            $SchRunDaysCount = $schPol.ScheduleRunDays.Count
            If($SchRunDaysCount -gt 0)
            {
             Write-LogFile -FilePath $LogFilePath -LogText "Removing Default Run days."
                for ($j = 0; $j -lt $SchRunDaysCount; $j++)
                {
                    $j | Out-Null
                    $schPol.ScheduleRunDays.RemoveAt($j);
             Write-LogFile -FilePath $LogFilePath -LogText "Default Run days removed successfully."
                }
            }

            If($ScheduleRunFrequency -eq "Daily")
            {
                 Write-LogFile -FilePath $LogFilePath -LogText "Setting schedule run frequency to Daily."

                $schPol.ScheduleRunFrequency = $ScheduleRunFrequency
                $schPol.ScheduleRunDays.Add($DaysOfWeek[0])
                $schPol.ScheduleRunTimes.Add((Get-Date -Date $TimesOfDay).ToUniversalTime())
                $retPol.IsDailyScheduleEnabled = $true
                If($EnableWeeklyRetentionSchedule -eq "Yes")
                { $retPol.IsWeeklyScheduleEnabled = $true }
                Else
                { $retPol.IsWeeklyScheduleEnabled = $false }

                If($EnableMonthlyRetentionSchedule -eq "Yes")
                { $retPol.IsMonthlyScheduleEnabled = $true }
                Else
                { $retPol.IsMonthlyScheduleEnabled = $false }

                If($EnableYearlyRetentionSchedule -eq "Yes")
                { $retPol.IsYearlyScheduleEnabled = $true }
                Else
                { $retPol.IsYearlyScheduleEnabled = $false }

                 Write-LogFile -FilePath $LogFilePath -LogText "Schedule run frequency set to evry '$($DaysOfWeek[0])' at $((Get-Date -Date $TimesOfDay).ToUniversalTime()) UTC."

                 Write-LogFile -FilePath $LogFilePath -LogText "Updating Backup policy with new schedule."
                (Set-AzureRmRecoveryServicesBackupProtectionPolicy -Policy $pol -SchedulePolicy $schPol -RetentionPolicy $retPol -ErrorAction Stop -WarningAction SilentlyContinue) | Out-Null
                 Write-LogFile -FilePath $LogFilePath -LogText "Backup policy has been updated successfully for new schedule."
            }
            ElseIf($ScheduleRunFrequency -eq "Weekly")
            {
                Write-LogFile -FilePath $LogFilePath -LogText "Setting schedule run frequency to Weekly."
                $schPol.ScheduleRunFrequency = $ScheduleRunFrequency

                Write-LogFile -FilePath $LogFilePath -LogText "Removing existing weekly Retention schedule."
                $RetPolDaysCount = $retPol.WeeklySchedule.DaysOfTheWeek.Count
                If($RetPolDaysCount -gt 0)
                {
                    for ($k = 0; $k -lt $RetPolDaysCount; $k++)
                    { 
                        $retPol.WeeklySchedule.DaysOfTheWeek.RemoveAt($k)
                    }
                }

                Write-LogFile -FilePath $LogFilePath -LogText "Updating weekly Retention schedule and schedule run days."
                foreach ($day in $DaysOfWeek)
                {
                    $schPol.ScheduleRunDays.Add($day)
                    $retPol.WeeklySchedule.DaysOfTheWeek.Add($day)
                }

                $SchRunTimesCount = $schPol.ScheduleRunTimes.Count
                If($SchRunTimesCount -gt 0)
                {
                    Write-LogFile -FilePath $LogFilePath -LogText "Removing existing schedule run times."
                    for ($i = 0; $i -lt $SchRunTimesCount; $i++)
                    {
                        $schPol.ScheduleRunTimes.RemoveAt($i);
                    }
                    Write-LogFile -FilePath $LogFilePath -LogText "Setting schedule run time to $((Get-Date -Date $TimesOfDay).ToUniversalTime()) UTC."
                    $schPol.ScheduleRunTimes.Add((Get-Date -Date $TimesOfDay).ToUniversalTime())
                }
                Else
                {
                    Write-LogFile -FilePath $LogFilePath -LogText "Setting schedule run time to $((Get-Date -Date $TimesOfDay).ToUniversalTime()) UTC."
                    $schPol.ScheduleRunTimes.Add((Get-Date -Date $TimesOfDay).ToUniversalTime())
                }

                Write-LogFile -FilePath $LogFilePath -LogText "Updating Retention schedule."
                $retPol.IsDailyScheduleEnabled = $false
                $retPol.IsWeeklyScheduleEnabled = $true
                If($EnableMonthlyRetentionSchedule -eq "Yes")
                { $retPol.IsMonthlyScheduleEnabled = $true }
                Else
                { $retPol.IsMonthlyScheduleEnabled = $false }

                If($EnableYearlyRetentionSchedule -eq "Yes")
                { $retPol.IsYearlyScheduleEnabled = $true }
                Else
                { $retPol.IsYearlyScheduleEnabled = $false }
                Write-LogFile -FilePath $LogFilePath -LogText "Retention schedule updated successfully."

                Write-LogFile -FilePath $LogFilePath -LogText "Updating Backup Protection policy as per the new changes made."
                (Set-AzureRmRecoveryServicesBackupProtectionPolicy -Policy $pol -SchedulePolicy $schPol -RetentionPolicy $retPol -ErrorAction Stop -WarningAction SilentlyContinue) | Out-Null
                Write-LogFile -FilePath $LogFilePath -LogText "Backup Protection policy has been updated as per new changes made."
            }
        }
        Catch
        {
            $ObjOut = "Error while configuring backup schedule/retention policy. Check log file for more details.`r`n$($Error[0].Exception.Message)"
            $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
            Write-Output $output
            Write-LogFile -FilePath $LogFilePath -LogText "$ObjOut`r`n<#BlobFileReadyForUpload#>"
            Exit
        }

        Write-LogFile -FilePath $LogFilePath -LogText "Enabling Recovery Services Backup Protection for VM '$VMToBackup'."
        Enable-AzureRmRecoveryServicesBackupProtection -Policy $pol -Name $VMToBackup -ResourceGroupName $ResourceGroupName
        Write-LogFile -FilePath $LogFilePath -LogText "Recovery Services Backup Protection for VM '$VMToBackup' enabled successfully."

        Write-LogFile -FilePath $LogFilePath -LogText "Fetching Azure Recovery Services Backup Container object."
        $namedContainer = Get-AzureRmRecoveryServicesBackupContainer -ContainerType AzureVM -Status Registered -Name $VMToBackup
        Write-LogFile -FilePath $LogFilePath -LogText "Azure Recovery Services Backup Container object fetched successfully."

        Write-LogFile -FilePath $LogFilePath -LogText "Fetching Azure Recovery Services Backup item."
        $item = Get-AzureRmRecoveryServicesBackupItem -Container $namedContainer -WorkloadType AzureVM
        Write-LogFile -FilePath $LogFilePath -LogText "Azure Recovery Services Backup item fetched successfully."

        Write-LogFile -FilePath $LogFilePath -LogText "Initiating backup job for Azure Services Backup item."
        $job = Backup-AzureRmRecoveryServicesBackupItem -Item $item
        Write-LogFile -FilePath $LogFilePath -LogText "Backup job for Azure Services Backup item has been started succesfully."

        Write-LogFile -FilePath $LogFilePath -LogText "Backup of '$VMToBackup' has been started successfully"
        $ObjOut = "Backup of '$VMToBackup' has been started successfully"
        $output = (@{"Response" = [Array]$ObjOut; Status = "Success"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
        Write-Output $output
    }
    Catch
    {
        $ObjOut = "Error while configuring backup options. Check log file for more details.`r`n$($Error[0].Exception.Message)"
        $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
        Write-Output $output
        Write-LogFile -FilePath $LogFilePath -LogText "$ObjOut`r`n<#BlobFileReadyForUpload#>"
        Exit
    }
}

End
{
    Write-LogFile -FilePath $LogFilePath -LogText "#####[ Script execution completed successfully ]#####`r`n<#BlobFileReadyForUpload#>"
}