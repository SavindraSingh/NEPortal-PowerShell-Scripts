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
    Specify the time value in HH:MM (24 Hrs) time format. Only specify values in multipals of 00:30.
    e.g. 00:30, 01:00, 01:30 ... 12:00, 12:30 so on..

    .PARAMETER ScheduleRunFrequency
    Use this parameter to specify the Backup frequency.
    Valid values "Daily","Weekly"

    .PARAMETER VMBackupPolicyName
    Name of the backup policy object you want to create or use with this backup schedule.

    .PARAMETER EnableWeeklyRetentionSchedule
    Use this parameter to specify if you want to enable Weekly retention schedule.
    Valid values: 'Yes','No'

    .PARAMETER EnableMonthlyRetentionSchedule
    Use this parameter to specify if you want to enable Monthly retention schedule.
    Valid values: 'Yes','No'

    .PARAMETER EnableYearlyRetentionSchedule
    Use this parameter to specify if you want to enable Yearly retention schedule.
    Valid values: 'Yes','No'

    .PARAMETER VMToBackup
    Name of the ARM VMs to Backup. Multipal values can be supplied seperated by comma.

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
    C:\PS> .\Backup-AzureVM.ps1 -ClientID VMBackupTest1 -AzureUserName 'savindrasingh.shahoo@netenrich.com' -AzurePassword 'pass@1234' -AzureSubscriptionID 'ca68598c-ecc3-4abc-b7a2-1ecef33f278d' -ResourceGroupName 'resourcegrp-bhaskar' -Location 'East Asia' -RSVaultName 'SavindraRSTest' -BackupStorageRedundancy 'LocallyRedundant' -DaysOfWeek 'Sunday' -TimesOfDay '01:00' -ScheduleRunFrequency 'Daily' -VMBackupPolicyName 'VMBackupPolicy' -EnableWeeklyRetentionSchedule 'Yes' -EnableMonthlyRetentionSchedule 'Yes' -EnableYearlyRetentionSchedule 'No' -VMToBackup 'SCCM-Bhaskar','testvm-bhaskar'

    .EXAMPLE
    C:\PS> .\Backup-AzureVM.ps1 -ClientID 'VMBackupTest10' -AzureUserName 'savindrasingh.shahoo@netenrich.com' -AzurePassword 'Pass@1234' -AzureSubscriptionID 'ca68598c-ecc3-4abc-b7a2-1ecef33f278d' -ResourceGroupName 'resourcegrp-bhaskar' -Location 'East Asia' -RSVaultName 'SavindraRSTest' -BackupStorageRedundancy 'LocallyRedundant' -DaysOfWeek 'Sunday','Wednesday' -TimesOfDay '01:00' -ScheduleRunFrequency 'Weekly' -VMBackupPolicyName 'VMBackupPolicy' -EnableWeeklyRetentionSchedule 'Yes' -EnableMonthlyRetentionSchedule 'Yes' -EnableYearlyRetentionSchedule 'No' -VMToBackup 'testvm-bhaskar','SQLServer'

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
    If($AzurePSVersion -gt $ScriptUploadConfig.RequiredPSVersion)
    {
        Write-LogFile -FilePath $LogFilePath -LogText "Required version of Azure PowerShell is $($ScriptUploadConfig.RequiredPSVersion). Current version on host machine is $($AzurePSVersion.ToString())."
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

    # Function to validate all parameters
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
            If([String]::IsNullOrWhiteSpace($VMToBackup))
            {
                Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. 'VMToBackup' parameter value is empty.`r`n<#BlobFileReadyForUpload#>"
                $ObjOut = "Validation failed. 'VMToBackup' parameter value is empty."
                $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                Write-Output $output
                Exit
            }

            # Validate parameter: DaysOfWeek
            Write-LogFile -FilePath $LogFilePath -LogText "Validating Parameters: 'DaysOfWeek'. Only ERRORs will be logged."
            If([String]::IsNullOrWhiteSpace($DaysOfWeek))
            {
                Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. DaysOfWeek parameter value is empty.`r`n<#BlobFileReadyForUpload#>"
                $ObjOut = "Validation failed. DaysOfWeek parameter value is empty.'"
                $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                Write-Output $output
                Exit
            }
            Else
            {
                $ValidDays = @('Sunday','Monday','Tuesday','Wednesday','Thursday','Friday','Saturday')
                If(((Compare-Object $ValidDays $DaysOfWeek | Where { $_.sideIndicator -eq '=>' }).InputObject) -eq $null)
                { <# Parameter value is valid #> }
                Else
                {
                    Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. DaysOfWeek: '$(((Compare-Object $ValidDays $DaysOfWeek | Where { $_.sideIndicator -eq '=>' }).InputObject) -join "','")' is NOT a valid value for this parameter.`r`n<#BlobFileReadyForUpload#>"
                    $ObjOut = "Validation failed. DaysOfWeek: '$(((Compare-Object $ValidDays $DaysOfWeek | Where { $_.sideIndicator -eq '=>' }).InputObject) -join "','")' is not a valid value for this parameter."
                    $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                    Write-Output $output
                    Exit
                }
            }

            # Validate parameter: TimesOfDay
            Write-LogFile -FilePath $LogFilePath -LogText "Validating Parameters: 'TimesOfDay'. Only ERRORs will be logged."
            If([String]::IsNullOrWhiteSpace($TimesOfDay))
            {
                Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. TimesOfDay parameter value is empty.`r`n<#BlobFileReadyForUpload#>"
                $ObjOut = "Validation failed. TimesOfDay parameter value is empty.'"
                $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                Write-Output $output
                Exit
            }
            Else
            {
                $ValidTimes = @('00:00','00:30','01:00','01:30','02:00','02:30','03:00','03:30','04:00','04:30','05:00','05:30',`
                '06:00','06:30','07:00','07:30','08:00','08:30','09:00','09:30','10:00','10:30','11:00','11:30','12:00','12:30',`
                '13:00','13:30','14:00','14:30','15:00','15:30','16:00','16:30','17:00','17:30','18:00','18:30','19:00','19:30',`
                '20:00','20:30','21:00','21:30','22:00','22:30','23:00','23:30')
                If($TimesOfDay -in $ValidTimes)
                { <# Parameter value is valid #> }
                Else
                {
                    Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. TimesOfDay: '$(((Compare-Object $ValidTimes $TimesOfDay | Where { $_.sideIndicator -eq '=>' }).InputObject) -join "','")' is NOT a valid value for this parameter.`r`n<#BlobFileReadyForUpload#>"
                    $ObjOut = "Validation failed. TimesOfDay: '$(((Compare-Object $ValidTimes $TimesOfDay | Where { $_.sideIndicator -eq '=>' }).InputObject) -join "','")' is not a valid value for this parameter."
                    $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                    Write-Output $output
                    Exit
                }
            }

            # Validate parameter: ScheduleRunFrequency - Daily, Weekly
            Write-LogFile -FilePath $LogFilePath -LogText "Validating Parameters: ScheduleRunFrequency. Only ERRORs will be logged."
            If([String]::IsNullOrEmpty($ScheduleRunFrequency))
            {
                Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. ScheduleRunFrequency parameter value is empty.`r`n<#BlobFileReadyForUpload#>"
                $ObjOut = "Validation failed. ScheduleRunFrequency parameter value is empty.'"
                $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                Write-Output $output
                Exit
            }
            Else
            {
                $ScheduleRunFrequencyValues = @("Daily", "Weekly")
                If($ScheduleRunFrequency -in $ScheduleRunFrequencyValues)
                { <# Parameter value is valid #> }
                Else
                {
                    Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. ScheduleRunFrequency - '$ScheduleRunFrequency' is NOT a valid value for this parameter.`r`n<#BlobFileReadyForUpload#>"
                    $ObjOut = "Validation failed. ScheduleRunFrequency - '$ScheduleRunFrequency' is not a valid value for this parameter."
                    $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                    Write-Output $output
                    Exit
                }
            }

            # Validate parameter: VMBackupPolicyName
            Write-LogFile -FilePath $LogFilePath -LogText "Validating Parameters: 'VMBackupPolicyName'. Only ERRORs will be logged."
            If([String]::IsNullOrWhiteSpace($VMBackupPolicyName))
            {
                Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. 'VMBackupPolicyName' parameter value is empty.`r`n<#BlobFileReadyForUpload#>"
                $ObjOut = "Validation failed. 'VMBackupPolicyName' parameter value is empty."
                $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                Write-Output $output
                Exit
            }

            # Validate parameter: EnableWeeklyRetentionSchedule - Yes, No
            Write-LogFile -FilePath $LogFilePath -LogText "Validating Parameters: EnableWeeklyRetentionSchedule. Only ERRORs will be logged."
            If([String]::IsNullOrEmpty($EnableWeeklyRetentionSchedule))
            {
                Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. EnableWeeklyRetentionSchedule parameter value is empty.`r`n<#BlobFileReadyForUpload#>"
                $ObjOut = "Validation failed. EnableWeeklyRetentionSchedule parameter value is empty.'"
                $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                Write-Output $output
                Exit
            }
            Else
            {
                $EnableWeeklyRetentionScheduleValues = @("Yes", "No")
                If($EnableWeeklyRetentionSchedule -in $EnableWeeklyRetentionScheduleValues)
                { <# Parameter value is valid #> }
                Else
                {
                    Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. EnableWeeklyRetentionSchedule - '$EnableWeeklyRetentionSchedule' is NOT a valid value for this parameter.`r`n<#BlobFileReadyForUpload#>"
                    $ObjOut = "Validation failed. EnableWeeklyRetentionSchedule - '$EnableWeeklyRetentionSchedule' is not a valid value for this parameter."
                    $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                    Write-Output $output
                    Exit
                }
            }

            # Validate parameter: EnableMonthlyRetentionSchedule - Yes, No
            Write-LogFile -FilePath $LogFilePath -LogText "Validating Parameters: EnableMonthlyRetentionSchedule. Only ERRORs will be logged."
            If([String]::IsNullOrEmpty($EnableMonthlyRetentionSchedule))
            {
                Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. EnableMonthlyRetentionSchedule parameter value is empty.`r`n<#BlobFileReadyForUpload#>"
                $ObjOut = "Validation failed. EnableMonthlyRetentionSchedule parameter value is empty.'"
                $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                Write-Output $output
                Exit
            }
            Else
            {
                $EnableMonthlyRetentionScheduleValues = @("Yes", "No")
                If($EnableMonthlyRetentionSchedule -in $EnableMonthlyRetentionScheduleValues)
                { <# Parameter value is valid #> }
                Else
                {
                    Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. EnableMonthlyRetentionSchedule - '$EnableMonthlyRetentionSchedule' is NOT a valid value for this parameter.`r`n<#BlobFileReadyForUpload#>"
                    $ObjOut = "Validation failed. EnableMonthlyRetentionSchedule - '$EnableMonthlyRetentionSchedule' is not a valid value for this parameter."
                    $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                    Write-Output $output
                    Exit
                }
            }

            # Validate parameter: EnableYearlyRetentionSchedule - Yes, No
            Write-LogFile -FilePath $LogFilePath -LogText "Validating Parameters: EnableYearlyRetentionSchedule. Only ERRORs will be logged."
            If([String]::IsNullOrEmpty($EnableYearlyRetentionSchedule))
            {
                Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. EnableYearlyRetentionSchedule parameter value is empty.`r`n<#BlobFileReadyForUpload#>"
                $ObjOut = "Validation failed. EnableYearlyRetentionSchedule parameter value is empty.'"
                $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                Write-Output $output
                Exit
            }
            Else
            {
                $EnableYearlyRetentionScheduleValues = @("Yes", "No")
                If($EnableYearlyRetentionSchedule -in $EnableYearlyRetentionScheduleValues)
                { <# Parameter value is valid #> }
                Else
                {
                    Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. EnableYearlyRetentionSchedule - '$EnableYearlyRetentionSchedule' is NOT a valid value for this parameter.`r`n<#BlobFileReadyForUpload#>"
                    $ObjOut = "Validation failed. EnableYearlyRetentionSchedule - '$EnableYearlyRetentionSchedule' is not a valid value for this parameter."
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
        If((Get-AzureRmResourceProvider -ListAvailable | Where { $_.ProviderNamespace -eq "Microsoft.RecoveryServices" }).RegistrationState -ne 'Registered')
        {
            (Register-AzureRmResourceProvider -ProviderNamespace "Microsoft.RecoveryServices" -ErrorAction Stop -WarningAction SilentlyContinue) | Out-Null
        }
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
        #Write-LogFile -FilePath $LogFilePath -LogText "Setting-up Backup properties (type of storage/redundancy)."
        #(Set-AzureRmRecoveryServicesBackupProperties  -Vault $RSVault -BackupStorageRedundancy $BackupStorageRedundancy -ErrorAction Stop -WarningAction SilentlyContinue) | Out-Null
        #Write-LogFile -FilePath $LogFilePath -LogText "Backup properties (type of storage/redundancy) set to '$BackupStorageRedundancy' successfully."

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

    # Update Policy run Schedule and Retention policy object 
    Try
    {
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
            <#Write-LogFile -FilePath $LogFilePath -LogText "Creating Backup schedule policy object."
            $schPol = $pol.SchedulePolicy
            Write-LogFile -FilePath $LogFilePath -LogText "Backup schedule policy object created successfully."

            Write-LogFile -FilePath $LogFilePath -LogText "Creating Backup retention policy object."
            $retPol = $pol.RetentionPolicy
            Write-LogFile -FilePath $LogFilePath -LogText "Backup retention policy object created successfully."#>

            Write-LogFile -FilePath $LogFilePath -LogText "Creating Backup schedule policy object."
            $schPol = Get-AzureRmRecoveryServicesBackupSchedulePolicyObject -WorkloadType AzureVM
            Write-LogFile -FilePath $LogFilePath -LogText "Backup schedule policy object created successfully."

            Write-LogFile -FilePath $LogFilePath -LogText "Creating Backup retention policy object."
            $retPol = Get-AzureRmRecoveryServicesBackupRetentionPolicyObject -WorkloadType AzureVM
            Write-LogFile -FilePath $LogFilePath -LogText "Backup retention policy object created successfully."

            Write-LogFile -FilePath $LogFilePath -LogText "Updating Policy run Schedule and retention policy object."

            # Remove existing Schedules
            Write-LogFile -FilePath $LogFilePath -LogText "Removing existing schedule and configuring new schedule based on user inputs."
            $SchRunTimesCount = $schPol.ScheduleRunTimes.Count
            If($SchRunTimesCount -gt 0)
            {
             Write-LogFile -FilePath $LogFilePath -LogText "Removing existing Run times."
               for ($i = 0; $i -lt $SchRunTimesCount; $i++)
                {
                    $schPol.ScheduleRunTimes.RemoveAt($i);
                }
             Write-LogFile -FilePath $LogFilePath -LogText "Existing Run times removed successfully."
            }
            $SchRunDaysCount = $schPol.ScheduleRunDays.Count
            If($SchRunDaysCount -gt 0)
            {
             Write-LogFile -FilePath $LogFilePath -LogText "Removing Existing Run days."
                for ($j = 0; $j -lt $SchRunDaysCount; $j++)
                {
                    $schPol.ScheduleRunDays.RemoveAt($j);
                }
                 Write-LogFile -FilePath $LogFilePath -LogText "Existing Run days removed successfully."
            }

            If($ScheduleRunFrequency -eq "Daily")
            {
                Write-LogFile -FilePath $LogFilePath -LogText "Setting schedule run frequency to Daily."
                $schPol.ScheduleRunFrequency = $ScheduleRunFrequency

                $schPol.ScheduleRunDays.Add($DaysOfWeek[0])
                Write-LogFile -FilePath $LogFilePath -LogText "Setting schedule run Days, set to '$($DaysOfWeek[0])'."

                $schPol.ScheduleRunTimes.Add((Get-Date -Date $TimesOfDay).ToUniversalTime())
                Write-LogFile -FilePath $LogFilePath -LogText "Setting schedule run Time, set to '$((Get-Date -Date $TimesOfDay).ToUniversalTime())' UTC."

                $retPol.IsDailyScheduleEnabled = $true
                Write-LogFile -FilePath $LogFilePath -LogText "Enabled Daily Schedule in retention policy."

                $retPol.DailySchedule = [Microsoft.Azure.Commands.RecoveryServices.Backup.Cmdlets.Models.DailyRetentionSchedule]::new()
                $retPol.DailySchedule.RetentionTimes = [System.Collections.Generic.List[datetime]]::new()
                $retPol.DailySchedule.RetentionTimes.Add((Get-Date -Date $TimesOfDay).ToUniversalTime());
                Write-LogFile -FilePath $LogFilePath -LogText "Daily schedule retention time set to '$((Get-Date -Date $TimesOfDay).ToUniversalTime())' UTC."
                
                $retPol.DailySchedule.DurationCountInDays = 30 # Setting as defult to 30 days
                Write-LogFile -FilePath $LogFilePath -LogText "Set Daily Retention days to 30 in daily retention policy."

                If($EnableWeeklyRetentionSchedule -eq "Yes")
                {
                    $retPol.IsWeeklyScheduleEnabled = $true

                    Write-LogFile -FilePath $LogFilePath -LogText "Removing existing weekly Retention schedule Times."
                    $RetPolTimesCount = $retPol.WeeklySchedule.RetentionTimes.Count
                    If($RetPolTimesCount -gt 0)
                    {
                        for ($k = 0; $k -lt $RetPolTimesCount; $k++)
                        { 
                            $retPol.WeeklySchedule.RetentionTimes.RemoveAt($k);
                        }
                    }
                    Write-LogFile -FilePath $LogFilePath -LogText "Removed existing weekly Retention schedule Times successfuly. Adding new time."

                    $retPol.WeeklySchedule.RetentionTimes.Add((Get-Date -Date $TimesOfDay).ToUniversalTime())
                    Write-LogFile -FilePath $LogFilePath -LogText "New weekly Retention schedule time set to '$((Get-Date -Date $TimesOfDay).ToUniversalTime())' UTC."

                    Write-LogFile -FilePath $LogFilePath -LogText "Removing existing weekly Retention schedule Days."
                    $WeeklyRetPolDaysCount = $retPol.WeeklySchedule.DaysOfTheWeek.Count
                    If($WeeklyRetPolDaysCount -gt 0)
                    {
                        for ($l = 0; $l -lt $WeeklyRetPolDaysCount; $l++)
                        { 
                            $retPol.WeeklySchedule.DaysOfTheWeek.RemoveAt($l);
                        }
                    }
                    Write-LogFile -FilePath $LogFilePath -LogText "Removed existing weekly Retention schedule Days successfuly. Adding new Day(s)."

                    $retPol.WeeklySchedule.DaysOfTheWeek = [System.Collections.Generic.List[System.DayOfWeek]]::new()
                    $retPol.WeeklySchedule.DaysOfTheWeek.Add($DaysOfWeek[0])
                    Write-LogFile -FilePath $LogFilePath -LogText "New weekly Retention schedule Day(s) set to '$($DaysOfWeek[0])'."
                }
                Else
                {
                    $retPol.IsWeeklyScheduleEnabled = $false

                    Write-LogFile -FilePath $LogFilePath -LogText "Removing existing weekly Retention schedule Times."
                    $RetPolTimesCount = $retPol.WeeklySchedule.RetentionTimes.Count
                    If($RetPolTimesCount -gt 0)
                    {
                        for ($k = 0; $k -lt $RetPolTimesCount; $k++)
                        { 
                            $retPol.WeeklySchedule.RetentionTimes.RemoveAt($k);
                        }
                    }
                    Write-LogFile -FilePath $LogFilePath -LogText "Removed existing weekly Retention schedule Times successfuly. Adding new time."

                    $retPol.WeeklySchedule.RetentionTimes.Add((Get-Date -Date $TimesOfDay).ToUniversalTime())
                    Write-LogFile -FilePath $LogFilePath -LogText "New weekly Retention schedule time set to '$((Get-Date -Date $TimesOfDay).ToUniversalTime())' UTC."

                    Write-LogFile -FilePath $LogFilePath -LogText "Removing existing weekly Retention schedule Days."
                    $WeeklyRetPolDaysCount = $retPol.WeeklySchedule.DaysOfTheWeek.Count
                    If($WeeklyRetPolDaysCount -gt 0)
                    {
                        for ($l = 0; $l -lt $WeeklyRetPolDaysCount; $l++)
                        { 
                            $retPol.WeeklySchedule.DaysOfTheWeek.RemoveAt($l);
                        }
                    }
                    Write-LogFile -FilePath $LogFilePath -LogText "Removed existing weekly Retention schedule Days successfuly. Adding new Day(s)."

                    $retPol.WeeklySchedule.DaysOfTheWeek = [System.Collections.Generic.List[System.DayOfWeek]]::new()
                    $retPol.WeeklySchedule.DaysOfTheWeek.Add($DaysOfWeek[0])
                    Write-LogFile -FilePath $LogFilePath -LogText "New weekly Retention schedule Day(s) set to '$($DaysOfWeek[0])'."
                }

                If($EnableMonthlyRetentionSchedule -eq "Yes")
                {
                    $retPol.IsMonthlyScheduleEnabled = $true
                    Write-LogFile -FilePath $LogFilePath -LogText "Monthly retention schedule is Enabled."

                    $MonthlyScheduleRetentionTimesCount = $retPol.MonthlySchedule.RetentionTimes.Count
                    If($MonthlyScheduleRetentionTimesCount -gt 0)
                    {
                        for ($m = 0; $m -lt $MonthlyScheduleRetentionTimesCount; $m++)
                        { 
                            $retPol.MonthlySchedule.RetentionTimes.RemoveAt($m);
                        }
                    }
                    $retPol.MonthlySchedule.RetentionTimes.Add((Get-Date -Date $TimesOfDay).ToUniversalTime())
                }
                Else
                {
                    $retPol.IsMonthlyScheduleEnabled = $false
                    Write-LogFile -FilePath $LogFilePath -LogText "Monthly retention schedule is Disabled."

                    $MonthlyScheduleRetentionTimesCount = $retPol.MonthlySchedule.RetentionTimes.Count
                    If($MonthlyScheduleRetentionTimesCount -gt 0)
                    {
                        for ($m = 0; $m -lt $MonthlyScheduleRetentionTimesCount; $m++)
                        { 
                            $retPol.MonthlySchedule.RetentionTimes.RemoveAt($m);
                        }
                    }
                    $retPol.MonthlySchedule.RetentionTimes.Add((Get-Date -Date $TimesOfDay).ToUniversalTime())
                }

                If($EnableYearlyRetentionSchedule -eq "Yes")
                {
                    $retPol.IsYearlyScheduleEnabled = $true
                    Write-LogFile -FilePath $LogFilePath -LogText "Yearly retention schedule is Enabled."

                    Write-LogFile -FilePath $LogFilePath -LogText "Removing existing yearly retention schedule times."
                    $YearlyScheduleRetentionTimesCount = $retPol.YearlySchedule.RetentionTimes.Count
                    If($YearlyScheduleRetentionTimesCount -gt 0)
                    {
                        for ($n = 0; $n -lt $YearlyScheduleRetentionTimesCount; $n++)
                        { 
                            $retPol.YearlySchedule.RetentionTimes.RemoveAt($n);
                        }
                    }
                    $retPol.YearlySchedule.RetentionTimes.Add((Get-Date -Date $TimesOfDay).ToUniversalTime())
                    Write-LogFile -FilePath $LogFilePath -LogText "Yearly retention schedule times added."
                }
                Else
                {
                    $retPol.IsYearlyScheduleEnabled = $false
                    Write-LogFile -FilePath $LogFilePath -LogText "Yearly retention schedule is Diabled."

                    $YearlyScheduleRetentionTimesCount = $retPol.YearlySchedule.RetentionTimes.Count
                    If($YearlyScheduleRetentionTimesCount -gt 0)
                    {
                        for ($o = 0; $o -lt $YearlyScheduleRetentionTimesCount; $o++)
                        { 
                            $retPol.YearlySchedule.RetentionTimes.RemoveAt($o);
                        }
                    }
                    $retPol.YearlySchedule.RetentionTimes.Add((Get-Date -Date $TimesOfDay).ToUniversalTime())
                }

                Write-LogFile -FilePath $LogFilePath -LogText "Updating Backup policy with new schedule."
                (Set-AzureRmRecoveryServicesBackupProtectionPolicy -Policy $pol -SchedulePolicy $schPol -RetentionPolicy $retPol -ErrorAction Stop -WarningAction SilentlyContinue) | Out-Null
                Write-LogFile -FilePath $LogFilePath -LogText "Backup policy has been updated successfully for new schedule."
            }
            ElseIf($ScheduleRunFrequency -eq "Weekly")
            {
                Write-LogFile -FilePath $LogFilePath -LogText "Setting schedule run frequency to Weekly."
                $schPol.ScheduleRunFrequency = $ScheduleRunFrequency

                Write-LogFile -FilePath $LogFilePath -LogText "Removing existing weekly Retention schedule Days."
                $RetPolDaysCount = $retPol.WeeklySchedule.DaysOfTheWeek.Count
                If($RetPolDaysCount -gt 0)
                {
                    for ($p = 0; $p -lt $RetPolDaysCount; $p++)
                    { 
                        $retPol.WeeklySchedule.DaysOfTheWeek.RemoveAt($p)
                    }
                }

                Write-LogFile -FilePath $LogFilePath -LogText "Removing existing weekly Retention schedule Times."
                $RetPolTimesCount = $retPol.WeeklySchedule.RetentionTimes.Count
                If($RetPolTimesCount -gt 0)
                {
                    for ($q = 0; $q -lt $RetPolTimesCount; $q++)
                    { 
                        $retPol.WeeklySchedule.RetentionTimes.RemoveAt($q)
                    }
                }
                Write-LogFile -FilePath $LogFilePath -LogText "Removed existing weekly Retention schedule Times successfuly. Adding new time."
                $retPol.WeeklySchedule.RetentionTimes.Add((Get-Date -Date $TimesOfDay).ToUniversalTime())
                Write-LogFile -FilePath $LogFilePath -LogText "Added new weekly retention time successfully."

                Write-LogFile -FilePath $LogFilePath -LogText "Updating weekly Retention schedule and schedule run days."
                foreach ($day in $DaysOfWeek)
                {
                    $schPol.ScheduleRunDays.Add($day)
                    $retPol.WeeklySchedule.DaysOfTheWeek.Add($day)
                }
                Write-LogFile -FilePath $LogFilePath -LogText "Added '$($DaysOfWeek -join "','")' days as weekely schedule/retention schedule days."

                $SchRunTimesCount = $schPol.ScheduleRunTimes.Count
                If($SchRunTimesCount -gt 0)
                {
                    Write-LogFile -FilePath $LogFilePath -LogText "Removing existing schedule run times."
                    for ($r = 0; $i -lt $SchRunTimesCount; $r++)
                    {
                        $schPol.ScheduleRunTimes.RemoveAt($r);
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
                Write-LogFile -FilePath $LogFilePath -LogText "Daily Retention schedule has been set to Disabled."

                $retPol.IsWeeklyScheduleEnabled = $true
                Write-LogFile -FilePath $LogFilePath -LogText "Weekly Retention schedule has been set to Enabled."
                If($EnableMonthlyRetentionSchedule -eq "Yes")
                {
                    $retPol.IsMonthlyScheduleEnabled = $true
                    Write-LogFile -FilePath $LogFilePath -LogText "Monthly Retention schedule has been set to Enabled."

                    Write-LogFile -FilePath $LogFilePath -LogText "Updating montly retention schedule times."
                    $MonthlyScheduleRetentionTimesCount = $retPol.MonthlySchedule.RetentionTimes.Count
                    If($MonthlyScheduleRetentionTimesCount -gt 0)
                    {
                        for ($s = 0; $s -lt $MonthlyScheduleRetentionTimesCount; $s++)
                        { 
                            $retPol.MonthlySchedule.RetentionTimes.RemoveAt($s);
                        }
                    }
                    $retPol.MonthlySchedule.RetentionTimes.Add((Get-Date -Date $TimesOfDay).ToUniversalTime())
                    Write-LogFile -FilePath $LogFilePath -LogText "Montly retention schedule times updated successfully."
                }
                Else
                {
                    $retPol.IsMonthlyScheduleEnabled = $false
                    Write-LogFile -FilePath $LogFilePath -LogText "Montly retention schedule is Disabled."

                    $MonthlyScheduleRetentionTimesCount = $retPol.MonthlySchedule.RetentionTimes.Count
                    If($MonthlyScheduleRetentionTimesCount -gt 0)
                    {
                        for ($t = 0; $t -lt $MonthlyScheduleRetentionTimesCount; $t++)
                        { 
                            $retPol.MonthlySchedule.RetentionTimes.RemoveAt($t);
                        }
                    }
                    $retPol.MonthlySchedule.RetentionTimes.Add((Get-Date -Date $TimesOfDay).ToUniversalTime())
                }

                If($EnableYearlyRetentionSchedule -eq "Yes")
                {
                    $retPol.IsYearlyScheduleEnabled = $true
                    Write-LogFile -FilePath $LogFilePath -LogText "Yearly retention schedule is Enabled."

                    Write-LogFile -FilePath $LogFilePath -LogText "Updating Yearly retention schedule."
                    $YearlyScheduleRetentionTimesCount = $retPol.YearlySchedule.RetentionTimes.Count
                    If($YearlyScheduleRetentionTimesCount -gt 0)
                    {
                        for ($u = 0; $u -lt $YearlyScheduleRetentionTimesCount; $u++)
                        { 
                            $retPol.YearlySchedule.RetentionTimes.RemoveAt($u);
                        }
                    }
                    $retPol.YearlySchedule.RetentionTimes.Add((Get-Date -Date $TimesOfDay).ToUniversalTime())
                    Write-LogFile -FilePath $LogFilePath -LogText "Yearly retention schedule updated successfully."
                }
                Else
                {
                    $retPol.IsYearlyScheduleEnabled = $false
                    Write-LogFile -FilePath $LogFilePath -LogText "Yearly retention schedule is Disabled."

                    $YearlyScheduleRetentionTimesCount = $retPol.YearlySchedule.RetentionTimes.Count
                    If($YearlyScheduleRetentionTimesCount -gt 0)
                    {
                        for ($v = 0; $v -lt $YearlyScheduleRetentionTimesCount; $v++)
                        { 
                            $retPol.YearlySchedule.RetentionTimes.RemoveAt($v);
                        }
                    }
                    $retPol.YearlySchedule.RetentionTimes.Add((Get-Date -Date $TimesOfDay).ToUniversalTime())
                }
                Write-LogFile -FilePath $LogFilePath -LogText "Retention schedule updated successfully."

                Write-LogFile -FilePath $LogFilePath -LogText "Updating Backup Protection policy as per the new changes made."
                (Set-AzureRmRecoveryServicesBackupProtectionPolicy -Policy $pol -SchedulePolicy $schPol -RetentionPolicy $retPol -ErrorAction Stop -WarningAction SilentlyContinue) | Out-Null
                Write-LogFile -FilePath $LogFilePath -LogText "Backup Protection policy has been updated as per new changes made."
            }
        }
        Catch
        {
            $ObjOut = "Error while configuring backup schedule/retention policy. Check log file for more details.`r`n$($Error[0].Exception.Message)`r`n$($Error[0])`r`nLine: $($Error[0].InvocationInfo.ScriptLineNumber) Char: $($Error[0].InvocationInfo.OffsetInLine)"
            $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
            Write-Output $output
            Write-LogFile -FilePath $LogFilePath -LogText "$ObjOut`r`n<#BlobFileReadyForUpload#>"
            Exit
        }

        $ErrorWhileAddingVMsToProtection = $false
        $ErrorItems = @()
        $SuccessfullyAddedItems = @()
        Try
        {
            foreach ($VMName in $VMToBackup)
            {
                Try
                {
                    Write-LogFile -FilePath $LogFilePath -LogText "Enabling Recovery Services Backup Protection for VM '$VMName'."
                    (Enable-AzureRmRecoveryServicesBackupProtection -Policy $pol -ResourceGroupName $ResourceGroupName -Name $VMName -ErrorAction Stop -WarningAction SilentlyContinue) | Out-Null
                    Write-LogFile -FilePath $LogFilePath -LogText "Recovery Services Backup Protection for VM '$VMName' enabled successfully."

                    Write-LogFile -FilePath $LogFilePath -LogText "Fetching Azure Recovery Services Backup Container object."
                    ($namedContainer = Get-AzureRmRecoveryServicesBackupContainer -ContainerType AzureVM -Status Registered -Name $VMName -ErrorAction Stop -WarningAction SilentlyContinue) | Out-Null
                    Write-LogFile -FilePath $LogFilePath -LogText "Azure Recovery Services Backup Container object fetched successfully."

                    Write-LogFile -FilePath $LogFilePath -LogText "Fetching Azure Recovery Services Backup item."
                    ($item = Get-AzureRmRecoveryServicesBackupItem -Container $namedContainer -WorkloadType AzureVM -ErrorAction Stop -WarningAction SilentlyContinue) | Out-Null
                    Write-LogFile -FilePath $LogFilePath -LogText "Azure Recovery Services Backup item fetched successfully."

                    Write-LogFile -FilePath $LogFilePath -LogText "Initiating backup job for Azure Services Backup item."
                    ($job = Backup-AzureRmRecoveryServicesBackupItem -Item $item -ErrorAction Stop -WarningAction SilentlyContinue) | Out-Null
                    Write-LogFile -FilePath $LogFilePath -LogText "Backup of '$VMName' has been started successfully"
                    
                    $SuccessfullyAddedItems += $VMName
                }
                Catch
                {
                    # log the error for current VM and move to next VM
                    Write-LogFile -FilePath $LogFilePath -LogText "Error while adding '$VMName' as preotection item.`r`n$($Error[0].Exception.Message)."
                    $ErrorWhileAddingVMsToProtection = $true
                    $ErrorItems += $VMName
                }
            }
        }
        Catch
        {
            $ObjOut = "Error while Enabling Backup protection for VMs. Check Error log file for more details.`r`n$($Error[0].Exception.Message)`r`n$($Error[0])`r`nLine: $($Error[0].InvocationInfo.ScriptLineNumber) Char: $($Error[0].InvocationInfo.OffsetInLine)"
            $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
            Write-LogFile -FilePath $LogFilePath -LogText "$ObjOut`r`n<#BlobFileReadyForUpload#>"
            Write-Output $output
            Exit
        }
        If($ErrorWhileAddingVMsToProtection)
        {
            $ObjOut = "VMs successfully added to backup job: '$($SuccessfullyAddedItems -join ",")'.`r`nHowever, cannot add these VMs to Backup: '$($ErrorItems -join "','")'"
            $output = (@{"Response" = [Array]$ObjOut; Status = "Success"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
            Write-LogFile -FilePath $LogFilePath -LogText "$ObjOut`r`n<#BlobFileReadyForUpload#>"
            Write-Output $output
            Exit
        }
        Else
        {
            $ObjOut = "Backup of '$($VMToBackup -join "','")' has been started successfully for all items."
            $output = (@{"Response" = [Array]$ObjOut; Status = "Success"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
            Write-LogFile -FilePath $LogFilePath -LogText "$ObjOut`r`n<#BlobFileReadyForUpload#>"
            Write-Output $output
            Exit
        }
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