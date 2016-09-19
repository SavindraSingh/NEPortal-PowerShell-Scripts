<#
    .SYNOPSIS
    Script to Configure Backup Policy on Azure Backup Server 

    .DESCRIPTION
    Script to create New backup vault in Azure Resource Manager Portal

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

    .PARAMETER Exclude
    List of files you want to exclude from backup schedule. This should be a valid path.
    e.g. C:\Temp\test.txt,"C:\My Files\TestFile.txt",C:\TestFolder\TestFile.txt

    .PARAMETER Include
    List of files you want to include in backup schedule. This should be a valid path.
    e.g. C:\Temp\test.txt,"C:\My Files\TestFile.txt",C:\TestFolder\TestFile.txt

    .PARAMETER RetentionDays
    Specify number of days you wnat to retain the backup data.

    .PARAMETER NonWorkHourBandwidth
    Specifies the bandwidth throttling setting to be used to limit the network bandwidth consumed by data transfers during non-work hours. 

    .PARAMETER WorkHourBandwidth
    Specifies the bandwidth throttling setting to be used to limit the network bandwidth consumed by data transfers during work hours.

    .INPUTS
    All parameter values in String format.

    .OUTPUTS
    String. Result of the command output.

    .NOTES
     Purpose of script: The script is to create a backup policy.
     Minimum requirements: PowerShell Version 2.0.0
     Initially written by: SavindraSingh Shahoo
     Update/revision History:
     =======================
     Updated by        Date            Reason
     ==========        ====            ======
     SavindraSingh     26-May-16       Changed Mandatory=$True to Mandatory=$False for all parameters.

    .EXAMPLE
    C:\PS> .\Configure-BackupPolicy.ps1 -DaysOfWeek 'Monday,Tuesday,Wednesday,Thursday,Friday' -TimesOfDay '16:00' -Exclude 'c:\Temp,C:\Windows' -Include 'c:\,d:\' -RetentionDays 7 

    .EXAMPLE
    C:\PS> .\Configure-BackupPolicy.ps1 -DaysOfWeek 'Monday,Tuesday,Wednesday,Thursday,Friday' -TimesOfDay '16:00' -Exclude 'c:\Temp,C:\Windows' -Include 'c:\,d:\' -RetentionDays 7 -NonWorkHourBandwidth 1234567 -WorkHourBandwidth 123456

    .LINK
#>

[CmdletBinding()]
Param
(
    [Parameter(ValueFromPipelineByPropertyName)]
    [string]$ClientID,

    [Parameter(ValueFromPipelineByPropertyName)]
    [string]$DaysOfWeek,

    [Parameter(ValueFromPipelineByPropertyName)]
    [string]$TimesOfDay,

    [Parameter(ValueFromPipelineByPropertyName)]
    [string]$Exclude,

    [Parameter(ValueFromPipelineByPropertyName)]
    [string]$Include,

    [Parameter(ValueFromPipelineByPropertyName)]
    [string]$RetentionDays,

    [Parameter(ValueFromPipelineByPropertyName)]
    [string]$NonWorkHourBandwidth,

    [Parameter(ValueFromPipelineByPropertyName)]
    [string]$WorkHourBandwidth
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

    Function Validate-AllParameters
    {
        # 1. Validate all parameters
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

            Write-LogFile -FilePath $LogFilePath -LogText "Validating Parameters: DaysOfWeek"
            If([String]::IsNullOrEmpty($DaysOfWeek))
            {
                Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. DaysOfWeek parameter value is empty.`r`n<#BlobFileReadyForUpload#>"
                $ObjOut = "Validation failed. DaysOfWeek parameter value is empty.'"
                $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                Write-Output $output
                Exit
            }
            If($DaysOfWeek.Contains(","))
            {
                Write-LogFile -FilePath $LogFilePath -LogText "DaysOfWeek parameter value is received as an Array. Splitting the values."
                $arrDaysOfWeek = $DaysOfWeek.Split(",")
                ForEach ($Day in $arrDaysOfWeek)
                {
                    Try
                    { [Dayofweek]$Day | Out-Null }
                    Catch
                    {
                        Write-LogFile -FilePath $LogFilePath -LogText "Invalid value passed through parameter DaysOfWeek: $Day`r`n<#BlobFileReadyForUpload#>"
                        $ObjOut = "Invalid value passed through parameter DaysOfWeek: '$Day'"
                        $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                        Write-Output $output
                        Exit
                    }
                }
            }
            Else
            {
                Try
                { [Dayofweek]$DaysOfWeek | Out-Null }
                Catch
                {
                    Write-LogFile -FilePath $LogFilePath -LogText "Invalid value passed through parameter DaysOfWeek: $DaysOfWeek`r`n<#BlobFileReadyForUpload#>"
                    $ObjOut = "Invalid value passed through parameter DaysOfWeek: '$DaysOfWeek'"
                    $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                    Write-Output $output
                    Exit
                }
            }

            Write-LogFile -FilePath $LogFilePath -LogText "Validating Parameters: TimesOfDay"
            If([String]::IsNullOrEmpty($TimesOfDay))
            {
                Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. TimesOfDay parameter value is empty.`r`n<#BlobFileReadyForUpload#>"
                $ObjOut = "Validation failed. TimesOfDay parameter value is empty.'"
                $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                Write-Output $output
                Exit
            }
            If($TimesOfDay.Contains(","))
            {
                Write-LogFile -FilePath $LogFilePath -LogText "TimesOfDay parameter value is received as an Array. Splitting the values."
                $arrTimesOfDay = $TimesOfDay.Split(",")
                ForEach ($Time in $arrTimesOfDay)
                {
                    Try
                    { [timespan]$Time | Out-Null }
                    Catch
                    {
                        Write-LogFile -FilePath $LogFilePath -LogText "Invalid value passed through parameter TimesOfDay: $Time`r`n<#BlobFileReadyForUpload#>"
                        $ObjOut = "Invalid value passed through parameter TimesOfDay: '$Time'"
                        $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                        Write-Output $output
                        Exit
                    }
                }
            }
            Else
            {
                Try
                { [timespan]$TimesOfDay | Out-Null }
                Catch
                {
                    Write-LogFile -FilePath $LogFilePath -LogText "Invalid value passed through parameter TimesOfDay: $TimesOfDay"
                    $ObjOut = "Invalid value passed through parameter TimesOfDay: '$TimesOfDay'"
                    $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                    Write-Output $output
                    Exit
                }
            }

            Write-LogFile -FilePath $LogFilePath -LogText "Validating Parameters: Exclude"
            If([String]::IsNullOrEmpty($Exclude))
            {
                Write-LogFile -FilePath $LogFilePath -LogText "Exclude parameter value is empty. The value was optional."
            }
            Else
            {
                If($Exclude.Contains(","))
                {
                    Write-LogFile -FilePath $LogFilePath -LogText "Exclude parameter value is received as an Array. Splitting the values."
                    $arrExclude = $Exclude.Split(",")
                    ForEach ($ExFilePath in $arrExclude)
                    {
                        If (Test-Path $ExFilePath)
                        {  }
                        Else
                        {
                            Write-LogFile -FilePath $LogFilePath -LogText "Can not validate path passed through parameter Exclude: $ExFilePath`r`n<#BlobFileReadyForUpload#>"
                            $ObjOut = "Can not validate path passed through parameter Exclude: '$ExFilePath'"
                            $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                            Write-Output $output
                            Exit
                        }
                    }
                }
                Else
                {
                    If (Test-Path $Exclude)
                    {  }
                    Else
                    {
                        Write-LogFile -FilePath $LogFilePath -LogText "Can not validate path passed through parameter Exclude: $Exclude`r`n<#BlobFileReadyForUpload#>"
                        $ObjOut = "Can not validate path passed through parameter Exclude: '$Exclude'"
                        $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                        Write-Output $output
                        Exit
                    }
                }
            }

            Write-LogFile -FilePath $LogFilePath -LogText "Validating Parameters: Include"
            If([String]::IsNullOrEmpty($Include))
            {
                Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. Include parameter value is empty.`r`n<#BlobFileReadyForUpload#>"
                $ObjOut = "Validation failed. Include parameter value is empty.'"
                $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                Write-Output $output
                Exit
            }
            If($Include.Contains(","))
            {
                Write-LogFile -FilePath $LogFilePath -LogText "Include parameter value is received as an Array. Splitting the values."
                $arrInclude = $Include.Split(",")
                ForEach ($InFilePath in $arrInclude)
                {
                    If (Test-Path $InFilePath)
                    {  }
                    Else
                    {
                        Write-LogFile -FilePath $LogFilePath -LogText "Can not validate path passed through parameter Include: $InFilePath`r`n<#BlobFileReadyForUpload#>"
                        $ObjOut = "Can not validate path passed through parameter Include: '$InFilePath'"
                        $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                        Write-Output $output
                        Exit
                    }
                }
            }
            Else
            {
                If (Test-Path $Include)
                {  }
                Else
                {
                    Write-LogFile -FilePath $LogFilePath -LogText "Can not validate path passed through parameter Include: $Include`r`n<#BlobFileReadyForUpload#>"
                    $ObjOut = "Can not validate path passed through parameter Include: '$Include'"
                    $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                    Write-Output $output
                    Exit
                }
            }

            Write-LogFile -FilePath $LogFilePath -LogText "Validating Parameters: RetentionDays"
            If([String]::IsNullOrEmpty($RetentionDays))
            {
                Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. RetentionDays parameter value is empty.`r`n<#BlobFileReadyForUpload#>"
                $ObjOut = "Validation failed. RetentionDays parameter value is empty.'"
                $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                Write-Output $output
                Exit
            }
            Try
            {
                [Int32]$RetentionDays = $RetentionDays
            }
            Catch
            {
                Write-LogFile -FilePath $LogFilePath -LogText "Invalid value passed through parameter RetentionDays (Integer expectd): $RetentionDays`r`n<#BlobFileReadyForUpload#>"
                $ObjOut = "Invalid value passed through parameter RetentionDays (Integer expectd): '$RetentionDays'"
                $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                Write-Output $output
                Exit
            }

            Write-LogFile -FilePath $LogFilePath -LogText "Validating Parameters: NonWorkHourBandwidth"
            If([String]::IsNullOrEmpty($NonWorkHourBandwidth))
            {
                Write-LogFile -FilePath $LogFilePath -LogText "NonWorkHourBandwidth parameter value is empty. The value was optional."
            }
            Else
            {
                Try
                {
                    [Int32]$NonWorkHourBandwidth = $NonWorkHourBandwidth
                }
                Catch
                {
                    Write-LogFile -FilePath $LogFilePath -LogText "Invalid value passed through parameter NonWorkHourBandwidth (Integer expectd): $NonWorkHourBandwidth`r`n<#BlobFileReadyForUpload#>"
                    $ObjOut = "Invalid value passed through parameter NonWorkHourBandwidth (Integer expectd): '$NonWorkHourBandwidth'"
                    $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                    Write-Output $output
                    Exit
                }
            }

            Write-LogFile -FilePath $LogFilePath -LogText "Validating Parameters: WorkHourBandwidth"
            If([String]::IsNullOrEmpty($WorkHourBandwidth))
            {
                Write-LogFile -FilePath $LogFilePath -LogText "WorkHourBandwidth parameter value is empty. The value was optional."
            }
            Else
            {
                Try
                {
                    [Int32]$WorkHourBandwidth = $WorkHourBandwidth
                }
                Catch
                {
                    Write-LogFile -FilePath $LogFilePath -LogText "Invalid value passed through parameter WorkHourBandwidth (Integer expectd): $WorkHourBandwidth`r`n<#BlobFileReadyForUpload#>"
                    $ObjOut = "Invalid value passed through parameter WorkHourBandwidth (Integer expectd): '$WorkHourBandwidth'"
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
}

Process
{
    # 1. Validate all parameters
    Validate-AllParameters

    # 2. Create and apply New Backup Policy.
    Try
    {
        # Set Machine settings
        Write-LogFile -FilePath $LogFilePath -LogText "Setting up OB Machine settings as specified."
        If([Int32]$WorkHourBandwidth -gt 0 -and [Int32]$NonWorkHourBandwidth -gt 0)
        { (Set-OBMachineSetting -WorkHourBandwidth $WorkHourBandwidth -NonWorkHourBandwidth $NonWorkHourBandwidth -ErrorAction Stop) | Out-Null }
        Write-LogFile -FilePath $LogFilePath -LogText "OB Machine settings were setup as specified."

        # Define new policy object
        Write-LogFile -FilePath $LogFilePath -LogText "Creating new backup policy object"
        ($newpolicy = New-OBPolicy -ErrorAction Stop) | Out-Null
        Write-LogFile -FilePath $LogFilePath -LogText "Created new backup policy object"

        # Configuring the backup schedule
        Write-LogFile -FilePath $LogFilePath -LogText "Configuring the backup schedule object"
        ($sched = New-OBSchedule -DaysofWeek $DaysOfWeek -TimesofDay $TimesOfDay -ErrorAction Stop) | Out-Null
        Write-LogFile -FilePath $LogFilePath -LogText "Configured the backup schedule object"

        # Associate schedule with the New policy
        Write-LogFile -FilePath $LogFilePath -LogText "Associating schedule with the New policy"
        (Set-OBSchedule -Policy $newpolicy -Schedule $sched -ErrorAction Stop) | Out-Null
        Write-LogFile -FilePath $LogFilePath -LogText "Associated schedule with the New policy"

        # Configuring a retention policy
        Write-LogFile -FilePath $LogFilePath -LogText "Configuring a retention policy object"
        ($retentionpolicy = New-OBRetentionPolicy -RetentionDays $RetentionDays -ErrorAction Stop) | Out-Null
        Write-LogFile -FilePath $LogFilePath -LogText "Configured a retention policy object"

        # Associate the retention policy with the New policy
        Write-LogFile -FilePath $LogFilePath -LogText "Associating the retention policy object with the New policy"
        (Set-OBRetentionPolicy -Policy $newpolicy -RetentionPolicy $retentionpolicy -ErrorAction Stop) | Out-Null
        Write-LogFile -FilePath $LogFilePath -LogText "Associated the retention policy object with the New policy"

        # Including and excluding files to be backed up
        If([String]::IsNullOrEmpty($Exclude))
        {
            # No Exclusions defined. Only inclusions
            Write-LogFile -FilePath $LogFilePath -LogText "No Exclusions defined. Adding Included paths"
            ($inclusions = New-OBFileSpec -FileSpec $Include -ErrorAction Stop) | Out-Null
            (Add-OBFileSpec -Policy $newpolicy -FileSpec $inclusions -ErrorAction Stop) | Out-Null
            Write-LogFile -FilePath $LogFilePath -LogText "Added Included paths"
        }
        Else
        {
            # Exclude files from backup
            Write-LogFile -FilePath $LogFilePath -LogText "Excluding files from backup. Adding Included paths"
            ($exclusions = New-OBFileSpec -FileSpec $Exclude -Exclude -ErrorAction Stop) | Out-Null
            ($inclusions = New-OBFileSpec -FileSpec $Include -ErrorAction Stop) | Out-Null
            (Add-OBFileSpec -Policy $newpolicy -FileSpec $inclusions -ErrorAction Stop) | Out-Null
            (Add-OBFileSpec -Policy $newpolicy -FileSpec $exclusions -ErrorAction Stop) | Out-Null
            Write-LogFile -FilePath $LogFilePath -LogText "Excluded files from backup. Added Included paths"
        }

        # Applying the policy
        # Remove old policies before applying New policy
        Write-LogFile -FilePath $LogFilePath -LogText "Removing old policies before applying New policy"
        (Get-OBPolicy -ErrorAction Stop | Remove-OBPolicy -Confirm:$false -ErrorAction SilentlyContinue) | Out-Null
        Write-LogFile -FilePath $LogFilePath -LogText "Old policies removed"

        # Apply new Policy
        Write-LogFile -FilePath $LogFilePath -LogText "Applying new Policy"
        (Set-OBPolicy -Policy $newpolicy -Confirm:$false -ErrorAction Stop) | Out-Null
        Write-LogFile -FilePath $LogFilePath -LogText "New Policy applied successfully"

        # Verify new policy
        Try
        {
            Write-LogFile -FilePath $LogFilePath -LogText "Verifying new Policy"
            ($newPolicyObject = Get-OBPolicy -ErrorAction Stop | Get-OBSchedule -ErrorAction Stop) | Out-Null
            Write-LogFile -FilePath $LogFilePath -LogText "Verified new Policy"

            $Result = "New Backup policy created successfully."
            $output = (@{"Response" = $Result; Status = "Success"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
            Write-Output $output
        }
        Catch
        {
            Write-LogFile -FilePath $LogFilePath -LogText "Error while Verifying New Backup Policy: $($Error[0].Exception.Message)`r`n<#BlobFileReadyForUpload#>"
            $ObjOut = "Error while Verifying New Backup Policy: $($Error[0].Exception.Message)"
            $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
            Write-Output $output
            Exit
        }
    }
    Catch
    {
        Write-LogFile -FilePath $LogFilePath -LogText "Error while creating/applying new Backup Policy: $($Error[0].Exception.Message)`r`n<#BlobFileReadyForUpload#>"
        $ObjOut = "Error while creating/applying new Backup Policy: $($Error[0].Exception.Message)"
        $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
        Write-Output $output
        Exit
    }
}

End
{
    Write-LogFile -FilePath $LogFilePath -LogText "####[ Script execution completed cuccessfully: $($MyInvocation.MyCommand.Name) ]####`r`n<#BlobFileReadyForUpload#>"
}