<#
    .SYNOPSIS
    Script is to create a Protection Group with backup policies for the target server

    .DESCRIPTION
    Script is to create a Protection Group with backup policies for the target server

    .PARAMETER DPMServerName
    
    Azure MABS Server name, FQDN.

    .PARAMETER TargetServerName

    Server Name to be protected. FQDN.

    .PARAMETER ProtectionGroupName

    Protection group name to be used.

    .PARAMETER ProtectedVolumes

    Protection Volume names,File Paths or database names in case of SQL.

    .PARAMETER Initialreplication

    When the initial replication takes place i.e Now or Later

    .PARAMETER InitialreplicationDateTime

    Date and time of Initial replication time in case if Later is given for Initialreplication

    .PARAMETER LongTerm

    Is it long term for cloud(Online) or short term (Disk)

    .PARAMETER DailyScheduleTime

    Daily scheduled time when the backup has to takes place for online i.e 02:00, 13:00 etc

    .PARAMETER WeeklyScheduleTime

    Weekly Scheduled time when the backup has to takes place for online i.e 02:00, 13:00 etc

    .PARAMETER WeeklyScheduleDays

    Weekly days When the backup has to be taken place at the time specified for WeeklyScheduleTime param.

    week days are: su,mo,tu,we,th,fr,sa

    .PARAMETER WeeksInterval

    Weeks interval i.e every 1 week or 2 weeks

    .PARAMETER MonthlyScheduleTime

    Monthly Scheduled time when the backup has to takes place for online i.e 02:00, 13:00 etc

    .PARAMETER RelativeIntervals

    On which days the backup has to takes place i.e first, second saturday etc.

    .PARAMETER MonthDays

    Monthly days of week When the backup has to be taken place at the time specified for MonthlyScheduleTime param.

    week days are: su,mo,tu,we,th,fr,sa

    .PARAMETER YearlyScheduleTime

    Yearly  Scheduled time when the backup has to takes place for online i.e 02:00, 13:00 etc

    .PARAMETER DaysOfMonth

    The day number of the month when the backup has to takes place i.e 1,2,4,9

    .PARAMETER MonthsInYear

    The name of month in which the backup has to takes place

    .PARAMETER RetensionDays

    Retension days for Shorterm

    .PARAMETER SychronizationFrequencyInMin

    Backup Synchronization Frequency in Minutes.

    .PARAMETER Passphrase

    Encryption Passphrase for Initial Setup for data Encryption.

    .PARAMETER DailyRetension  

    RetensionDays for Daily Backup schedules 

    .PARAMETER WeeklyRetension

    RetensionDays for Weekly backup schedules

    .PARAMETER MonthlyRetension

    RetensionDays for Monthly backup schedules

    .PARAMETER YearlyRetension

    RetensionDays for Yearly backup schedules

    .INPUTS
    All parameter values in String format.

    .OUTPUTS
    String. Result of the command output.

    .NOTES
     Purpose of script:     The script is a standalone script to configure protection group on MABS Server.
     Minimum requirements: Azure PowerShell Version 2.0.0
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
    SavindraSingh      9-Sep-2016      1. Added a variable at script level (line 89) - $ScriptUploadConfig = $null
                                       2. $Script:ScriptUploadConfig will now hold the value for the current required version
                                          of Azure PowerShell. Which is used at line 176 with - If($AzurePSVersion -gt $ScriptUploadConfig.RequiredPSVersion)
                                          to check if we have Azure PowerShell version available.
                                       3. The required version of Azure PowerShell should now be mentioned in the NEPortalApp.Config as given below:
                                          Under <appSettings> tag - <add key="RequiredPSVersion" value="2.0.1"/>

    .EXAMPLE
    C:\PS> .\Create-ProtectionGrpStandalone.ps1 -DPMServerName TargetVm-BKP -TargetServerName SQLServer -ProtectionGroupName testGrp -ProtectedVolumes testdb -Initialreplication Now -LongTerm $true -DailyScheduleTime "2:00 AM" -RetensionDays 14 -SychronizationFrequencyInMin 240 -DailyRetension 100

    .EXAMPLE
    C:\PS> .\Create-ProtectionGrpStandalone.ps1 -DPMServerName TargetVm-BKP -TargetServerName SQLServer -ProtectionGroupName testGrp -ProtectedVolumes testdb -Initialreplication Now -LongTerm $true -WeeklyScheduleTime -WeeklyScheduleDays -WeeksInterval 1 -RetensionDays 14 -SychronizationFrequencyInMin 240 -WeeklyRetension 50

    .EXAMPLE
    C:\PS> .\Create-ProtectionGrpStandalone.ps1 -DPMServerName TargetVm-BKP -TargetServerName SQLServer -ProtectionGroupName testGrp -ProtectedVolumes testdb -Initialreplication Now -LongTerm $true -MonthlyScheduleTime -MonthDays -RelativeIntervals First -RetensionDays 14 -SychronizationFrequencyInMin 240 -MonthlyRetension 40

    .EXAMPLE
    C:\PS> .\Create-ProtectionGrpStandalone.ps1 -DPMServerName TargetVm-BKP -TargetServerName SQLServer -ProtectionGroupName testGrp -ProtectedVolumes testdb -Initialreplication Now -LongTerm $true -YearlyScheduleTime -DaysOfMonth -MonthsInYear -RetensionDays 14 -SychronizationFrequencyInMin 240 -YearlyRetension 10
 
    .LINK
    http://www.netenrich.com/
#>
[CmdletBinding()]
Param
(
    [Parameter(ValueFromPipelineByPropertyName)]
    [string]$DPMServerName,

    [Parameter(ValueFromPipelineByPropertyName)]
    [string]$TargetServerName,

    [Parameter(ValueFromPipelineByPropertyName)]
    [string]$ProtectionGroupName,

    [Parameter(ValueFromPipelineByPropertyName)]
    [string]$ProtectedVolumes,

    [Parameter(ValueFromPipelineByPropertyName)]
    [string]$Initialreplication,

    [Parameter(ValueFromPipelineByPropertyName)]
    [string]$InitialreplicationDateTime,

    [Parameter(ValueFromPipelineByPropertyName)]
    [Bool]$LongTerm,

    [Parameter(ValueFromPipelineByPropertyName)]
    [String]$DailyScheduleTime,

    [Parameter(ValueFromPipelineByPropertyName)]
    [String]$WeeklyScheduleTime,

    [Parameter(ValueFromPipelineByPropertyName)]
    [String]$WeeklyScheduleDays,

    [Parameter(ValueFromPipelineByPropertyName)]
    [String]$WeeksInterval,

	[Parameter(ValueFromPipelineByPropertyName)]
    [String]$MonthlyScheduleTime,

    [Parameter(ValueFromPipelineByPropertyName)]
    [String]$RelativeIntervals,

    [Parameter(ValueFromPipelineByPropertyName)]
    [String]$MonthDays,

    [Parameter(ValueFromPipelineByPropertyName)]
    [String]$YearlyScheduleTime,

    [Parameter(ValueFromPipelineByPropertyName)]
    [string]$DaysOfMonth,

    [Parameter(ValueFromPipelineByPropertyName)]
    [String]$MonthsInYear,

    [Parameter(ValueFromPipelineByPropertyName)]
    [String]$RetensionDays,

    [Parameter(ValueFromPipelineByPropertyName)]
    [String]$SychronizationFrequencyInMin,

    [Parameter(ValueFromPipelineByPropertyName)]
    [String]$Passphrase,
   
    [Parameter(ValueFromPipelineByPropertyName)]
    [String]$DailyRetension,

    [Parameter(ValueFromPipelineByPropertyName)]
    [String]$WeeklyRetension,

    [Parameter(ValueFromPipelineByPropertyName)]
    [String]$MonthlyRetension,

    [Parameter(ValueFromPipelineByPropertyName)]
    [String]$YearlyRetension
)

Begin
{
    # Name the Log file based on script name
    [DateTime]$LogFileTime = Get-Date
    $FileTimeStamp = $LogFileTime.ToString("dd-MMM-yyyy_HHmmss")
    $LogFileName = "$ClientID-$($MyInvocation.MyCommand.Name.Replace('.ps1',''))-$FileTimeStamp.log"
    $LogFilePath = "C:\NEPortal\$LogFileName"
    
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

    Write-LogFile -FilePath $LogFilePath -LogText "####[ Script Execution started: $($MyInvocation.MyCommand.Name).]####" -Overwrite
    
    Function Validate-AllParameters
    {
        Try
        {
            # Validate parameter: DPMServerName
            Write-LogFile -FilePath $LogFilePath -LogText "Validating Parameters: DPMServerName. Only ERRORs will be logged."
            If([String]::IsNullOrEmpty($DPMServerName))
            {
                Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. DPMServerName parameter value is empty.`r`n<#BlobFileReadyForUpload#>"
                $ObjOut = "Validation failed. DPMServerName parameter value is empty."
                $output = (@{"Response" = $ObjOut; "Status" = "Failed"} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                Write-Output $output
                Exit
            }

			# Validate parameter: TargetServerName
            Write-LogFile -FilePath $LogFilePath -LogText "Validating Parameters: TargetServerName. Only ERRORs will be logged."
            If([String]::IsNullOrEmpty($TargetServerName))
            {
                Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. TargetServerName parameter value is empty.`r`n<#BlobFileReadyForUpload#>"
                $ObjOut = "Validation failed. TargetServerName parameter value is empty."
                $output = (@{"Response" = $ObjOut; "Status" = "Failed"} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                Write-Output $output
                Exit
            }
			
            # Validate parameter: ProtectionGroupName
            Write-LogFile -FilePath $LogFilePath -LogText "Validating Parameters: ProtectionGroupName. Only ERRORs will be logged."
            If([String]::IsNullOrEmpty($ProtectionGroupName))
            {
                Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. ProtectionGroupName parameter value is empty.`r`n<#BlobFileReadyForUpload#>"
                $ObjOut = "Validation failed. ProtectionGroupName parameter value is empty."
                $output = (@{"Response" = $ObjOut; "Status" = "Failed"} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                Write-Output $output
                Exit
            }

             # Validate parameter: ProtectedVolumes
            Write-LogFile -FilePath $LogFilePath -LogText "Validating Parameters: ProtectedVolumes. Only ERRORs will be logged."
            If([String]::IsNullOrEmpty($ProtectedVolumes))
            {
                Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. ProtectedVolumes parameter value is empty.`r`n<#BlobFileReadyForUpload#>"
                $ObjOut = "Validation failed. ProtectedVolumes parameter value is empty."
                $output = (@{"Response" = $ObjOut; "Status" = "Failed"} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                Write-Output $output
                Exit
            }

             # Validate parameter: Initialreplication
            Write-LogFile -FilePath $LogFilePath -LogText "Validating Parameters: Initialreplication. Only ERRORs will be logged."
            If([String]::IsNullOrEmpty($Initialreplication))
            {
                Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. Initialreplication parameter value is empty.`r`n<#BlobFileReadyForUpload#>"
                $ObjOut = "Validation failed. Initialreplication parameter value is empty."
                $output = (@{"Response" = $ObjOut; "Status" = "Failed"} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                Write-Output $output
                Exit
            }
            if($Initialreplication -eq 'Now'){}
            elseif($Initialreplication -eq 'Later')
            {
                If([String]::IsNullOrEmpty($InitialreplicationDateTime))
                {
                    Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. InitialreplicationDateTime parameter value is empty.`r`n<#BlobFileReadyForUpload#>"
                    $ObjOut = "Validation failed. InitialreplicationDateTime parameter value is empty."
                    $output = (@{"Response" = $ObjOut; "Status" = "Failed"} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                    Write-Output $output
                    Exit
                }
                try
                {
                    $InitialreplicationDateTime = [DateTime]::Parse($InitialreplicationDateTime)
                }
                catch
                {
                    Write-LogFile -FilePath $LogFilePath -LogText "Invalid valus is passed though $InitialreplicationDateTime parameter.DateTime is expected.`r`n<#BlobFileReadyForUpload#>"
                    $ObjOut = "Invalid valus is passed though $InitialreplicationDateTime parameter.DateTime is expected."
                    $output = (@{"Response" = $ObjOut; "Status" = "Failed"} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                    Write-Output $output
                    Exit
                }
            }

            if($DailyScheduleTime)
            {
                # Validate parameter: DailyScheduleTime
                Write-LogFile -FilePath $LogFilePath -LogText "Validating Parameters: DailyScheduleTime. Only ERRORs will be logged."
                If([String]::IsNullOrEmpty($DailyScheduleTime))
                {
                    Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. DailyScheduleTime parameter value is empty,but the parameter is optional.`r`n<#BlobFileReadyForUpload#>"
                    $ObjOut = "Validation failed. DailyScheduleTime parameter value is empty, but the parameter is optional."
                    $output = (@{"Response" = $ObjOut; "Status" = "Failed"} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                    Write-Output $output
                    Exit
                }
                
                $Script:DScheduleTimes = @()
                if($DailyScheduleTime.Contains(","))
                {

                    Write-LogFile -FilePath $LogFilePath -LogText "DailyScheduleTime parameter value is received as an Array. Splitting the values."
                    $DailySche = $DailyScheduleTime.Split(",")
                    foreach($DailyS in $DailySche)
                    {
                        try
                        {
                            $Script:DScheduleTimes += $DailyS
                        }
                        catch
                        {
                            Write-LogFile -FilePath $LogFilePath -LogText "Invalid value passed through parameter DailyScheduleTime: $Time.`r`n<#BlobFileReadyForUpload#>"
                            $ObjOut = "Invalid value passed through parameter DailyScheduleTime: '$Time'"
                            $output = (@{"Response" = $ObjOut; "Status" = "Failed"} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                            Write-Output $output
                            Exit
                        }
                    }
                }
                else
                {
                    try
                    {
                        $Script:DScheduleTimes += $DailyScheduleTime
                    }
                    catch
                    {
                        Write-LogFile -FilePath $LogFilePath -LogText "Invalid value passed through parameter DailyScheduleTime: $Time.`r`n<#BlobFileReadyForUpload#>"
                        $ObjOut = "Invalid value passed through parameter DailyScheduleTime: '$Time'"
                        $output = (@{"Response" = $ObjOut; "Status" = "Failed"} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                        Write-Output $output
                        Exit
                    }
                }

                # Validate parameter: DailyRetension
                Write-LogFile -FilePath $LogFilePath -LogText "Validating Parameters: DailyRetension. Only ERRORs will be logged."
                If([String]::IsNullOrEmpty($DailyRetension))
                {
                    Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. DailyRetension parameter value is empty,but the parameter is optional.`r`n<#BlobFileReadyForUpload#>"
                    $ObjOut = "Validation failed. DailyRetension parameter value is empty,but the parameter is optional."
                    $output = (@{"Response" = $ObjOut; "Status" = "Failed"} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                    Write-Output $output
                }
                Else 
                {
                    try
                    {
                        $Script:DailyRet = [int32]$DailyRetension
                    }
                    catch
                    {
                        Write-LogFile -FilePath $LogFilePath -LogText "Invalid value passed through parameter DailyRetesion: $DailyRetension.`r`n<#BlobFileReadyForUpload#>"
                        $ObjOut = "Invalid value passed through parameter DailyRetesion: $DailyRetension"
                        $output = (@{"Response" = $ObjOut; "Status" = "Failed"} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                        Write-Output $output
                        Exit
                    }                 
                }
            }
            elseif ($WeeklyScheduleTime) 
            {
                # Validate parameter: WeeklyScheduleTime
                Write-LogFile -FilePath $LogFilePath -LogText "Validating Parameters: WeeklyScheduleTime. Only ERRORs will be logged."
                If([String]::IsNullOrEmpty($WeeklyScheduleTime))
                {
                    Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. WeeklyScheduleTime parameter value is empty,but the parameter is optional.`r`n<#BlobFileReadyForUpload#>"
                    $ObjOut = "Validation failed. WeeklyScheduleTime parameter value is empty,but the parameter is optional."
                    $output = (@{"Response" = $ObjOut; "Status" = "Failed"} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                    Write-Output $output
                    Exit
                }

                $Script:WeeklyScheduleTimes = @()
                if($WeeklyScheduleTime.Contains(","))
                {
                    Write-LogFile -FilePath $LogFilePath -LogText "WeeklyScheduleTime parameter value is received as an Array. Splitting the values."
                    $WeeklySche = $WeeklyScheduleTime.Split(",")
                    foreach($WS in $WeeklySche)
                    {
                        try
                        {
                            $Script:WeeklyScheduleTimes += $WS
                        }
                        catch
                        {
                            Write-LogFile -FilePath $LogFilePath -LogText "Invalid value passed through parameter WeeklyScheduleTime: $WS.`r`n<#BlobFileReadyForUpload#>"
                            $ObjOut = "Invalid value passed through parameter WeeklyScheduleTime: '$WS'"
                            $output = (@{"Response" = $ObjOut; "Status" = "Failed"} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                            Write-Output $output
                            Exit
                        }
                    }
                }
                else
                {
                    try
                    {
                        $Script:WeeklyScheduleTimes += $WeeklyScheduleTime
                    }
                    catch
                    {
                        Write-LogFile -FilePath $LogFilePath -LogText "Invalid value passed through parameter WeeklyScheduleTime: $WeeklyScheduleTime.`r`n<#BlobFileReadyForUpload#>"
                        $ObjOut = "Invalid value passed through parameter WeeklyScheduleTime: '$WeeklyScheduleTime'"
                        $output = (@{"Response" = $ObjOut; "Status" = "Failed"} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                        Write-Output $output
                        Exit
                    }
                }

                # Validate parameter: WeeklyScheduleDays
                Write-LogFile -FilePath $LogFilePath -LogText "Validating Parameters: WeeklyScheduleDays. Only ERRORs will be logged."
                If([String]::IsNullOrEmpty($WeeklyScheduleDays))
                {
                    Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. WeeklyScheduleDays parameter value is empty,but the parameter is optional.`r`n<#BlobFileReadyForUpload#>"
                    $ObjOut = "Validation failed. WeeklyScheduleDays parameter value is empty,but the parameter is optional."
                    $output = (@{"Response" = $ObjOut; "Status" = "Failed"} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                    Write-Output $output
                    Exit
                }

                $Script:weekDays = @()
                if($WeeklyScheduleDays.Contains(","))
                {
                    Write-LogFile -FilePath $LogFilePath -LogText "WeeklyScheduleTime parameter value is received as an Array. Splitting the values."
                    $WeeklyScheDays = $WeeklyScheduleDays.Split(",")
                    foreach($WSD in $WeeklyScheDays)
                    {
                        try
                        {
                            $Script:weekDays += $WSD
                        }
                        catch
                        {
                            Write-LogFile -FilePath $LogFilePath -LogText "Invalid value passed through parameter WeeklyScheduleDays: $WSD.`r`n<#BlobFileReadyForUpload#>"
                            $ObjOut = "Invalid value passed through parameter WeeklyScheduleDays: '$WSD'"
                            $output = (@{"Response" = $ObjOut; "Status" = "Failed"} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                            Write-Output $output
                            Exit
                        }
                    }
                }
                else
                {
                    try
                    {
                        $Script:weekDays += $WeeklyScheduleDays
                    }
                    catch
                    {
                        Write-LogFile -FilePath $LogFilePath -LogText "Invalid value passed through parameter WeeklyScheduleDays: $WeeklyScheduleDays`r`n<#BlobFileReadyForUpload#>"
                        $ObjOut = "Invalid value passed through parameter WeeklyScheduleDays: '$WeeklyScheduleDays'"
                        $output = (@{"Response" = $ObjOut; "Status" = "Failed"} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                        Write-Output $output
                        Exit
                    }
                }

                # Validate parameter: WeeksInterval
                Write-LogFile -FilePath $LogFilePath -LogText "Validating Parameters: WeeksInterval. Only ERRORs will be logged."
                If([String]::IsNullOrEmpty($WeeksInterval))
                {
                    Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. WeeksInterval parameter value is empty or It is not a valid week number,but the parameter is optional.`r`n<#BlobFileReadyForUpload#>"
                    $ObjOut = "Validation failed. WeeksInterval parameter value is empty or It is not a valid week number,but the parameter is optional."
                    $output = (@{"Response" = $ObjOut; "Status" = "Failed"} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                    Write-Output $output
                    Exit
                }
                else
                {
                    try
                    {
                        $WeeksInterval = [Int32]$WeeksInterval
                    }
                    catch
                    {
                        Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. WeeksInterval parameter value is empty.`r`n<#BlobFileReadyForUpload#>"
                        $ObjOut = "Validation failed. WeeksInterval parameter value is empty."
                        $output = (@{"Response" = $ObjOut; "Status" = "Failed"} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                        Write-Output $output
                        Exit
                    }
                }  

                # Validate parameter: WeeklyRetension
                Write-LogFile -FilePath $LogFilePath -LogText "Validating Parameters: WeeklyRetension. Only ERRORs will be logged."
                If([String]::IsNullOrEmpty($WeeklyRetension))
                {
                    Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. WeeklyRetension parameter value is empty,but the parameter is optional.`r`n<#BlobFileReadyForUpload#>"
                    $ObjOut = "Validation failed. WeeklyRetension parameter value is empty,but the parameter is optional."
                    $output = (@{"Response" = $ObjOut; "Status" = "Failed"} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                    Write-Output $output
                } 
                Else
                { 
                    try
                    {
                        $Script:WeeklyRet = [int32]$WeeklyRetension
                    }
                    catch
                    {
                        Write-LogFile -FilePath $LogFilePath -LogText "Invalid value passed through parameter DailyRetesion: $WeeklyRetension.`r`n<#BlobFileReadyForUpload#>"
                        $ObjOut = "Invalid value passed through parameter DailyRetesion: $WeeklyRetension"
                        $output = (@{"Response" = $ObjOut; "Status" = "Failed"} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                        Write-Output $output
                        Exit
                    }                 
                }
            }
            Elseif($MonthlyScheduleTime) 
            {
                # Validate parameter: MonthlyScheduleTime
                Write-LogFile -FilePath $LogFilePath -LogText "Validating Parameters: MonthlyScheduleTime. Only ERRORs will be logged."
                If([String]::IsNullOrEmpty($MonthlyScheduleTime))
                {
                    Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. MonthlyScheduleTime parameter value is empty,but the parameter is optional.`r`n<#BlobFileReadyForUpload#>"
                    $ObjOut = "Validation failed. MonthlyScheduleTime parameter value is empty,but the parameter is optional."
                    $output = (@{"Response" = $ObjOut; "Status" = "Failed"} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                    Write-Output $output
                    Exit
                }
                $script:MonthlySechduledTimes = @()
                if($MonthlyScheduleTime.Contains(","))
                {
                    Write-LogFile -FilePath $LogFilePath -LogText "MonthlyScheduleTime parameter value is received as an Array. Splitting the values.`n"
                    $MonScheTime = $MonthlyScheduleTime.Split(",")
                    foreach($MST in $MonScheTime)
                    {
                        try
                        {
                            $script:MonthlySechduledTimes += $MST
                        }
                        catch
                        {
                            Write-LogFile -FilePath $LogFilePath -LogText "Invalid value passed through parameter MonthlyScheduleTime: $MST.`r`n<#BlobFileReadyForUpload#>"
                            $ObjOut = "Invalid value passed through parameter MonthlyScheduleTime: '$MST'"
                            $output = (@{"Response" = $ObjOut; "Status" = "Failed"} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                            Write-Output $output
                            Exit
                        }
                    }
                }
                else
                {
                    try
                    {
                        $script:MonthlySechduledTimes += $MonthlyScheduleTime
                    }
                    catch
                    {
                        Write-LogFile -FilePath $LogFilePath -LogText "Invalid value passed through parameter MonthlyScheduleTime: $MonthlyScheduleTime.`r`n<#BlobFileReadyForUpload#>"
                        $ObjOut = "Invalid value passed through parameter MonthlyScheduleTime: '$MonthlyScheduleTime'"
                        $output = (@{"Response" = $ObjOut; "Status" = "Failed"} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                        Write-Output $output
                        Exit
                    }
                }

                # Validate parameter: RelativeIntervals
                Write-LogFile -FilePath $LogFilePath -LogText "Validating Parameters: RelativeIntervals. Only ERRORs will be logged."
                If([String]::IsNullOrEmpty($RelativeIntervals))
                {
                    Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. RelativeIntervals parameter value is empty,but the parameter is optional.`r`n<#BlobFileReadyForUpload#>"
                    $ObjOut = "Validation failed. RelativeIntervals parameter value is empty,but the parameter is optional."
                    $output = (@{"Response" = $ObjOut; "Status" = "Failed"} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                    Write-Output $output
                    Exit
                }
                $Script:RelIntervalsArray = @()
                if($RelativeIntervals.Contains(","))
                {
                    Write-LogFile -FilePath $LogFilePath -LogText "RelativeIntervals parameter value is received as an Array. Splitting the values."
                    $ReIntervals = $RelativeIntervals.Split(",")
                    foreach($rel in $ReIntervals)
                    {
                        $Script:RelIntervalsArray += $rel
                        if($rel -notin ('First','Second','Third','Fourth','Last'))
                        {
                            Write-LogFile -FilePath $LogFilePath -LogText "Invalid value passed through parameter RelativeIntervals: $rel.`r`n<#BlobFileReadyForUpload#>"
                            $ObjOut = "Invalid value passed through parameter RelativeIntervals: '$rel'"
                            $output = (@{"Response" = $ObjOut; "Status" = "Failed"} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                            Write-Output $output
                            Exit
                        }
                    }
                }
                else
                {
                    $Script:RelIntervalsArray += $RelativeIntervals
                    if($RelativeIntervals -notin ('First','Second','Third','Fourth','Last'))
                    {
                        Write-LogFile -FilePath $LogFilePath -LogText "Invalid value passed through parameter RelativeIntervals: $RelativeIntervals.`r`n<#BlobFileReadyForUpload#>"
                        $ObjOut = "Invalid value passed through parameter RelativeIntervals: '$RelativeIntervals'"
                        $output = (@{"Response" = $ObjOut; "Status" = "Failed"} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                        Write-Output $output
                        Exit
                    }
                }

                # Validate parameter: MonthDays
                Write-LogFile -FilePath $LogFilePath -LogText "Validating Parameters: MonthDays. Only ERRORs will be logged."
                If([String]::IsNullOrEmpty($MonthDays))
                {
                    Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. MonthDays parameter value is empty,but the parameter is optional.`r`n<#BlobFileReadyForUpload#>"
                    $ObjOut = "Validation failed. MonthDays parameter value is empty,but the parameter is optional."
                    $output = (@{"Response" = $ObjOut; "Status" = "Failed"} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                    Write-Output $output
                    Exit
                }
                $Script:MDays = @()
                if($MonthDays.Contains(","))
                {
                    Write-LogFile -FilePath $LogFilePath -LogText "YearlyScheduleTime parameter value is received as an Array. Splitting the values."
                    $MonDays = $MonthDays.Split(",")
                    foreach($MD in $MonDays)
                    {
                        try
                        {
                            #$Script:MDays +=[Microsoft.Internal.EnterpriseStorage.Dls.Scheduler.WeekDayType]$MD
                            $Script:MDays +=$MD
                        }
                        catch
                        {
                            Write-LogFile -FilePath $LogFilePath -LogText "Invalid value passed through parameter MonthDays: $MD.`r`n<#BlobFileReadyForUpload#>"
                            $ObjOut = "Invalid value passed through parameter MonthDays: '$MD'"
                            $output = (@{"Response" = $ObjOut; "Status" = "Failed"} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                            Write-Output $output
                            Exit
                        }
                    }
                }
                else
                {
                    try
                    {
                        $Script:MDays += $MonthDays
                    }
                    catch
                    {
                        Write-LogFile -FilePath $LogFilePath -LogText "Invalid value passed through parameter MonthDays: $MonthDays.`r`n<#BlobFileReadyForUpload#>"
                        $ObjOut = "Invalid value passed through parameter MonthDays: '$MonthDays'"
                        $output = (@{"Response" = $ObjOut; "Status" = "Failed"} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                        Write-Output $output
                        Exit
                    }
                }

                # Validate parameter: MonthlyRetension
                Write-LogFile -FilePath $LogFilePath -LogText "Validating Parameters: MonthlyRetension. Only ERRORs will be logged."
                If([String]::IsNullOrEmpty($MonthlyRetension))
                {
                    Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. MonthlyRetension parameter value is empty,but the parameter is optional.`r`n<#BlobFileReadyForUpload#>"
                    $ObjOut = "Validation failed. MonthlyRetension parameter value is empty,but the parameter is optional."
                    $output = (@{"Response" = $ObjOut; "Status" = "Failed"} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                    Write-Output $output
                } 
                Else
                { 
                    try
                    {
                        $Script:MonthlyRet = [int32]$MonthlyRetension
                    }
                    catch
                    {
                        Write-LogFile -FilePath $LogFilePath -LogText "Invalid value passed through parameter DailyRetesion: $MonthlyRetension.`r`n<#BlobFileReadyForUpload#>"
                        $ObjOut = "Invalid value passed through parameter DailyRetesion: $MonthlyRetension"
                        $output = (@{"Response" = $ObjOut; "Status" = "Failed"} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                        Write-Output $output
                        Exit
                    }                 
                }
            }
            Elseif($YearlyScheduleTime)
            {
                # Validate parameter: YearlyScheduleTime
                Write-LogFile -FilePath $LogFilePath -LogText "Validating Parameters: YearlyScheduleTime. Only ERRORs will be logged."
                If([String]::IsNullOrEmpty($YearlyScheduleTime))
                {
                    Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. YearlyScheduleTime parameter value is empty,but the parameter is optional.`r`n<#BlobFileReadyForUpload#>"
                    $ObjOut = "Validation failed. YearlyScheduleTime parameter value is empty,but the parameter is optional."
                    $output = (@{"Response" = $ObjOut; "Status" = "Failed"} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                    Write-Output $output
                    Exit
                }
                $Script:YearlyScheduledtimeArray = @()
                if($YearlyScheduleTime.Contains(","))
                {
                    Write-LogFile -FilePath $LogFilePath -LogText "YearlyScheduleTime parameter value is received as an Array. Splitting the values.`n"
                    $yearlSche = $YearlyScheduleTime.Split(",")
                    foreach($ys in $yearlSche)
                    {
                        try
                        {
                            $Script:YearlyScheduledtimeArray += $ys
                        }
                        catch
                        {
                            Write-LogFile -FilePath $LogFilePath -LogText "Invalid value passed through parameter YearlyScheduleTime: $ys.`r`n<#BlobFileReadyForUpload#>"
                            $ObjOut = "Invalid value passed through parameter YearlyScheduleTime: '$ys'"
                            $output = (@{"Response" = $ObjOut; "Status" = "Failed"} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                            Write-Output $output
                            Exit
                        }
                    }
                }
                else
                {
                    try
                    {
                            $Script:YearlyScheduledtimeArray += $YearlyScheduleTime
                    }
                    catch
                    {
                        Write-LogFile -FilePath $LogFilePath -LogText "Invalid value passed through parameter YearlyScheduleTime: $YearlyScheduleTime.`r`n<#BlobFileReadyForUpload#>"
                        $ObjOut = "Invalid value passed through parameter YearlyScheduleTime: '$YearlyScheduleTime'"
                        $output = (@{"Response" = $ObjOut; "Status" = "Failed"} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                        Write-Output $output
                        Exit
                    }
                }

                # Validate parameter: DaysOfMonth
                Write-LogFile -FilePath $LogFilePath -LogText "Validating Parameters: DaysOfMonth. Only ERRORs will be logged."
                If([String]::IsNullOrEmpty($DaysOfMonth))
                {
                    Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. DaysOfMonth parameter value is empty,but the parameter is optional.`r`n<#BlobFileReadyForUpload#>"
                    $ObjOut = "Validation failed. DaysOfMonth parameter value is empty,but the parameter is optional."
                    $output = (@{"Response" = $ObjOut; "Status" = "Failed"} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                    Write-Output $output
                    Exit
                }
                $Script:DoM = @()
                if($DaysOfMonth.Contains(","))
                {
                    Write-LogFile -FilePath $LogFilePath -LogText "DaysOfMonth parameter value is received as an Array. Splitting the values."
                    $DaysMon = $DaysOfMonth.Split(",")
                    foreach($dm in $DaysMon)
                    {
                        try
                        {
                            [Int32]$dm = $dm
                            $Script:DoM += $dm
                            if($dm -notin (1..30))
                            {
                                Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. Invalid day is passed though parameter DaysOfMonth.$dm.`r`n<#BlobFileReadyForUpload#>"
                                $ObjOut = "Validation failed. Invalid day is passed though parameter DaysOfMonth.'$dm'"
                                $output = (@{"Response" = $ObjOut; "Status" = "Failed"} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                                Write-Output $output
                                Exit
                            }
                        }
                        catch
                        {
                            Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. Invalid day is passed though parameter DaysOfMonth.$dm.`r`n<#BlobFileReadyForUpload#>"
                            $ObjOut = "Validation failed. Invalid day is passed though parameter DaysOfMonth.'$dm'"
                            $output = (@{"Response" = $ObjOut; "Status" = "Failed"} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                            Write-Output $output
                            Exit
                        }     
                    }
                }
                else
                {
                    try
                    {
                        [Int32]$DaysOfMonth = $DaysOfMonth
                        $Script:DoM +=$DaysOfMonth
                        if($DaysOfMonth -notin (1..30))
                        {
                            Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. Invalid day is passed though parameter DaysOfMonth.'$DaysOfMonth'.`r`n<#BlobFileReadyForUpload#>"
                            $ObjOut = "Validation failed. Invalid day is passed though parameter DaysOfMonth.'$DaysOfMonth'"
                            $output = (@{"Response" = $ObjOut; "Status" = "Failed"} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                            Write-Output $output
                            Exit
                        }
                    }
                    catch
                    {
                        Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. Invalid day is passed though parameter DaysOfMonth.'$DaysOfMonth'`r`n<#BlobFileReadyForUpload#>"
                        $ObjOut = "Validation failed. Invalid day is passed though parameter DaysOfMonth.'$DaysOfMonth'"
                        $output = (@{"Response" = $ObjOut; "Status" = "Failed"} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                        Write-Output $output
                        Exit
                    }
                }

                # Validate parameter: MonthsInYear
                Write-LogFile -FilePath $LogFilePath -LogText "Validating Parameters: MonthsInYear. Only ERRORs will be logged."
                If([String]::IsNullOrEmpty($MonthsInYear))
                {
                    Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. MonthsInYear parameter value is empty,but the parameter is optional.`r`n<#BlobFileReadyForUpload#>"
                    $ObjOut = "Validation failed. MonthsInYear parameter value is empty,but the parameter is optional."
                    $output = (@{"Response" = $ObjOut; "Status" = "Failed"} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                    Write-Output $output
                    Exit
                }
                $Script:MnInYr = @()
                if($MonthsInYear.Contains(","))
                {
                    Write-LogFile -FilePath $LogFilePath -LogText "MonthsInYear parameter value is received as an Array. Splitting the values."
                    $months = $MonthsInYear.Split(",")
                    foreach($mon in $months)
                    {
                        try
                        {
                            #[Microsoft.Internal.EnterpriseStorage.Dls.Scheduler.MonthType]$mon = $mon
                            $Script:MnInYr += $mon
                        }
                        catch
                        {
                            Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. Invalid day is passed though parameter DaysOfMonth.'$mon'`r`n<#BlobFileReadyForUpload#>"
                            $ObjOut = "Validation failed. Invalid day is passed though parameter DaysOfMonth.'$mon'"
                            $output = (@{"Response" = $ObjOut; "Status" = "Failed"} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                            Write-Output $output
                            Exit
                        } 
                    }
                }
                else
                {
                    try
                    {
                        #$Script:MnInYr += [Microsoft.Internal.EnterpriseStorage.Dls.Scheduler.MonthType]$MonthsInYear
                        $Script:MnInYr += $MonthsInYear
                    }
                    catch
                    {
                        Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. Invalid day is passed though parameter DaysOfMonth.'$MonthsInYear'`r`n<#BlobFileReadyForUpload#>"
                        $ObjOut = "Validation failed. Invalid day is passed though parameter DaysOfMonth.'$MonthsInYear'"
                        $output = (@{"Response" = $ObjOut; "Status" = "Failed"} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                        Write-Output $output
                        Exit
                    } 
                }

                # Validate parameter: YearlyRetension
                Write-LogFile -FilePath $LogFilePath -LogText "Validating Parameters: YearlyRetension. Only ERRORs will be logged."
                If([String]::IsNullOrEmpty($YearlyRetension))
                {
                    Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. YearlyRetension parameter value is empty,but the parameter is optional.`r`n<#BlobFileReadyForUpload#>"
                    $ObjOut = "Validation failed. YearlyRetension parameter value is empty,but the parameter is optional."
                    $output = (@{"Response" = $ObjOut; "Status" = "Failed"} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                    Write-Output $output
                } 
                Else
                { 
                    try
                    {
                        $script:YearlyRet = [int32]$YearlyRetension
                    }
                    catch
                    {
                        Write-LogFile -FilePath $LogFilePath -LogText "Invalid value passed through parameter DailyRetesion: $YearlyRetension.`r`n<#BlobFileReadyForUpload#>"
                        $ObjOut = "Invalid value passed through parameter DailyRetesion: $YearlyRetension"
                        $output = (@{"Response" = $ObjOut; "Status" = "Failed"} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                        Write-Output $output
                        Exit
                    }                 
                }
            }
            else {
                #
            }

			# Validate parameter: RetensionDays
			Write-LogFile -FilePath $LogFilePath -LogText "Validating Parameters: RetensionDays`n"
            If([String]::IsNullOrEmpty($RetensionDays))
            {
                Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. RetensionDays parameter value is empty.`r`n<#BlobFileReadyForUpload#>"
                $ObjOut = "Validation failed. RetensionDays parameter value is empty."
                $output = (@{"Response" = $ObjOut; "Status" = "Failed"} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                Write-Output $output
                Exit
            }
            Try
            {
                $RetensionDays = [Int32]$RetensionDays
            }
            Catch
            {
                Write-LogFile -FilePath $LogFilePath -LogText "Invalid value passed through parameter RetensionDays (Integer expectd): $RetensionDays.`r`n<#BlobFileReadyForUpload#>"
                $ObjOut = "Invalid value passed through parameter RetensionDays (Integer expectd): '$RetensionDays'"
                $output = (@{"Response" = $ObjOut; "Status" = "Failed"} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                Write-Output $output
                Exit
            }
			
			# Validate parameter: SychronizationFrequencyInMin
			Write-LogFile -FilePath $LogFilePath -LogText "Validating Parameters: SychronizationFrequencyInMin`n"
            If([String]::IsNullOrEmpty($SychronizationFrequencyInMin))
            {
                Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. SychronizationFrequencyInMin parameter value is empty.`r`n<#BlobFileReadyForUpload#>"
                $ObjOut = "Validation failed. SychronizationFrequencyInMin parameter value is empty."
                $output = (@{"Response" = $ObjOut; "Status" = "Failed"} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                Write-Output $output
                Exit
            }
            Try
            {
                $SychronizationFrequencyInMin = [Int32]$SychronizationFrequencyInMin
            }
            Catch
            {
                Write-LogFile -FilePath $LogFilePath -LogText "Invalid value passed through parameter SychronizationFrequencyInMin (Integer expectd): $SychronizationFrequencyInMin.`r`n<#BlobFileReadyForUpload#>"
                $ObjOut = "Invalid value passed through parameter SychronizationFrequencyInMin (Integer expectd): '$SychronizationFrequencyInMin'"
                $output = (@{"Response" = $ObjOut; "Status" = "Failed"} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                Write-Output $output
                Exit
            }

            if($Passphrase)
            {
                # Validate parameter: Passphrase
                Write-LogFile -FilePath $LogFilePath -LogText "Validating Parameters: Passphrase. Only ERRORs will be logged."
                If([String]::IsNullOrEmpty($Passphrase))
                {
                    Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. Passphrase parameter value is empty,but the parameter is optional.`r`n<#BlobFileReadyForUpload#>"
                    $ObjOut = "Validation failed. Passphrase parameter value is empty,but the parameter is optional."
                    $output = (@{"Response" = $ObjOut; "Status" = "Failed"} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                    Write-Output $output
                    Exit
                }
            }

        }
        Catch
        {
            Write-LogFile -FilePath $LogFilePath -LogText "Error while validating parameters: $($Error[0].Exception.Message).`r`n<#BlobFileReadyForUpload#>"
            $ObjOut = "Error while validating parameters: $($Error[0].Exception.Message)"
            $output = (@{"Response" = $ObjOut; "Status" = "Failed"} | ConvertTo-Json).ToString().Replace('\u0027',"'")
            Write-Output $output
            Exit
        }
    }
}
Process
{
    # Validating all Parameters
    Validate-AllParameters

	# Configuring the MABS
	Try
    {
		Write-LogFile -FilePath $LogFilePath -LogText " Getting the connection to the Azure Backup Server"
        ($ProtectionGroupSetting = Get-DPMCloudSubscriptionSetting -DPMServerName $DPMServerName -ErrorAction SilentlyContinue -WarningAction SilentlyContinue) | Out-Null

        Set-DPMCloudSubscriptionSetting -SubscriptionSetting $ProtectionGroupSetting -Commit -ErrorAction Stop -WarningAction SilentlyContinue | Out-Null

        Write-LogFile -FilePath $LogFilePath -LogText " Adding the Network Settings"
        Set-DPMCloudSubscriptionSetting -SubscriptionSetting $ProtectionGroupSetting -NoProxy -ErrorAction Stop -WarningAction SilentlyContinue | Out-Null
        Set-DPMCloudSubscriptionSetting -SubscriptionSetting $ProtectionGroupSetting -NoThrottle -ErrorAction Stop -WarningAction SilentlyContinue | Out-Null

        if($ProtectionGroupSetting.EncryptionSetting.EncryptionKeyStatus -ne 'Set')
        {
            Write-LogFile -FilePath $LogFilePath -LogText " Setting the Passphrase"
            if($Passphrase -ne $null)
            {
                $SecurePassphrase = ConvertTo-SecureString -string $Passphrase -AsPlainText -Force
                Set-DPMCloudSubscriptionSetting -SubscriptionSetting $ProtectionGroupSetting -EncryptionPassphrase $SecurePassphrase -ErrorAction Stop -WarningAction SilentlyContinue | Out-Null
            }
            else
            {
                $SecurePassphrase = ConvertTo-SecureString -string 'passphrase123456789' -AsPlainText -Force
                Set-DPMCloudSubscriptionSetting -SubscriptionSetting $ProtectionGroupSetting -EncryptionPassphrase $SecurePassphrase -ErrorAction Stop -WarningAction SilentlyContinue | Out-Null
            } 
        }

        Write-LogFile -FilePath $LogFilePath -LogText " Creating the New Protection group. Setting the properties before it gets created"
        ($ExistingGroups = Get-DPMProtectionGroup -DPMServerName $DPMServerName -ErrorAction SilentlyContinue -WarningAction SilentlyContinue ) | Out-Null
        if($ExistingGroups -and ($ExistingGroups.Name).Contains($ProtectionGroupName))
        {
            $ObjOut = "The protection group with this name is already exist.`r`n$($Error[0].Exception.Message)"
            $output = (@{"Response" = $ObjOut; "Status" = "Failed"} | ConvertTo-Json).ToString().Replace('\u0027',"'")
            Write-Output $output
            Write-LogFile -FilePath $LogFilePath -LogText "$ObjOut`r`n<#BlobFileReadyForUpload#>"
            Exit
        }
        else
        {
            ($PG = New-DPMProtectionGroup -Name $ProtectionGroupName -ErrorAction Stop -WarningAction SilentlyContinue) | Out-Null
            ($MPG = Get-ModifiableProtectionGroup $PG -ErrorAction SilentlyContinue -WarningAction Silentlycontinue) | Out-Null
        }

        Write-LogFile -FilePath $LogFilePath -LogText " Fecthing the details of the given server to be protected."
        ($server = Get-DPMProductionServer -DPMServerName $DPMServerName -ErrorAction SilentlyContinue -WarningAction SilentlyContinue | where {($_.ServerName) -eq $TargetServerName}) | Out-Null
        if(!$server)
        {
            $ObjOut = "The Azure Backup Server did not find the server to be protected."
            $output = (@{"Response" = $ObjOut; "Status" = "Failed"} | ConvertTo-Json).ToString().Replace('\u0027',"'")
            Write-Output $output
            Write-LogFile -FilePath $LogFilePath -LogText "$ObjOut`r`n<#BlobFileReadyForUpload#>"
            Exit
        }
 
        Write-LogFile -FilePath $LogFilePath -LogText " Getting the available data sources for the given server."
        ($DS = Get-Datasource -ProductionServer $server -Inquire -ErrorAction SilentlyContinue -WarningAction SilentlyContinue) | Out-Null
        if(!$DS)
        {
            $ObjOut = "Datasources are not available for the Server."
            $output = (@{"Response" = $ObjOut; "Status" = "Failed"} | ConvertTo-Json).ToString().Replace('\u0027',"'")
            Write-Output $output
            Write-LogFile -FilePath $LogFilePath -LogText "$ObjOut`r`n<#BlobFileReadyForUpload#>"
            Exit
        }

		Write-LogFile -FilePath $LogFilePath -LogText " Verifying the given data source with the server data sources."
        $DataSources = @()
        $DataInput = $ProtectedVolumes.Split(",")
        foreach($Data in $DataInput)
        {
            $AvailableData = $DS | Where {$_.Name -contains $Data}
            if($AvailableData)
            {
                $DataSources += $AvailableData
            }
			else
			{
				$ObjOut = "The given data $Data was not found in the data sources."
                $output = (@{"Response" = $ObjOut; "Status" = "Failed"} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                Write-Output $output
                Write-LogFile -FilePath $LogFilePath -LogText "$ObjOut`r`n<#BlobFileReadyForUpload#>"
                Exit
			}
        }

        Write-LogFile -FilePath $LogFilePath -LogText " Adding the Datasource to the protection group."
		try
		{
			Add-DPMChildDatasource -ProtectionGroup $MPG -ChildDatasource $DataSources -ErrorAction SilentlyContinue -WarningAction SilentlyContinue | Out-Null
			if($LongTerm -eq $true)
			{
				Set-DPMProtectionType -ProtectionGroup $MPG -ShortTerm Disk -LongTerm Online -ErrorAction Stop -WarningAction SilentlyContinue | Out-Null
				Add-DPMChildDatasource -ProtectionGroup $MPG -ChildDatasource $DataSources -Online -ErrorAction Stop -WarningAction SilentlyContinue | Out-Null
				Set-DPMPolicyObjective -ProtectionGroup $MPG -RetentionRangeInDays $RetensionDays -SynchronizationFrequencyMinutes $SychronizationFrequencyInMin -ErrorAction Stop -WarningAction SilentlyContinue | Out-Null
			}
			else
			{
				Set-DPMProtectionType -ProtectionGroup $MPG -ShortTerm Disk -ErrorAction Stop -WarningAction SilentlyContinue | Out-Null #-LongTerm Online 
				Add-DPMChildDatasource -ProtectionGroup $MPG -ChildDatasource $DataSources -ErrorAction Stop -WarningAction SilentlyContinue | Out-Null #–Online
				Set-DPMPolicyObjective -ProtectionGroup $MPG -RetentionRangeInDays $RetensionDays -SynchronizationFrequencyMinutes $SychronizationFrequencyInMin -ErrorAction Stop -WarningAction SilentlyContinue | Out-Null
			}
		}
		catch
		{
			$ObjOut = "Error while adding the data sources to the protection group.`r`n$($Error[0].Exception.Message)"
			$output = (@{"Response" = $ObjOut; "Status" = "Failed"} | ConvertTo-Json).ToString().Replace('\u0027',"'")
			Write-Output $output
			Write-LogFile -FilePath $LogFilePath -LogText "$ObjOut`r`n<#BlobFileReadyForUpload#>"
			Exit
		}
        
		Write-LogFile -FilePath $LogFilePath -LogText " Setting the disk allocation for the data"
        for($i=0;$i -lt $DataSources.length;$i++)
        {
            try
            {
                ($a = Get-DatasourceDiskAllocation -Datasource $DataSources[$i] -ErrorAction SilentlyContinue -WarningAction SilentlyContinue) | Out-Null
                Set-DPMDatasourceDiskAllocation -Datasource $DataSources[$i] -ProtectionGroup $MPG -ErrorAction Stop -WarningAction SilentlyContinue | Out-Null
            }
            catch
            {
                $ObjOut = "Error while setting the disk allocation for the data.`r`n$($Error[0].Exception.Message)"
				$output = (@{"Response" = $ObjOut; "Status" = "Failed"} | ConvertTo-Json).ToString().Replace('\u0027',"'")
				Write-Output $output
				Write-LogFile -FilePath $LogFilePath -LogText "$ObjOut`r`n<#BlobFileReadyForUpload#>"
				Exit
            }

        }

        Write-LogFile -FilePath $LogFilePath -LogText " Setting the Policy type i.e Disk / Online."
        if($LongTerm -eq $true)
        {
            #($onlineSch = Get-DPMPolicySchedule -ProtectionGroup $MPG -LongTerm Online -ErrorAction SilentlyContinue -WarningAction SilentlyContinue) | Out-Null

            if($DailyScheduleTime)
            {               
                Write-LogFile -FilePath $LogFilePath -LogText " Adding the settings for retension policys for online backup."
                $RRlist = @()
                $RRList += (New-Object -TypeName Microsoft.Internal.EnterpriseStorage.Dls.UI.ObjectModel.OMCommon.RetentionRange -ArgumentList $Script:DailyRet, Days)
                Set-DPMPolicyObjective -ProtectionGroup $MPG -OnlineRetentionRangeList $RRlist -ErrorAction Stop -WarningAction SilentlyContinue | Out-Null

                Write-LogFile -FilePath $LogFilePath -LogText " Adding the Dailys schedules for Online backup.`r`n"
                ($onlineSch = Get-DPMPolicySchedule -ProtectionGroup $MPG -LongTerm Online -ErrorAction SilentlyContinue -WarningAction SilentlyContinue) | Out-Null
                Set-DPMPolicySchedule -ProtectionGroup $MPG -Schedule $onlineSch -TimesOfDay $Script:DScheduleTimes -ErrorAction Stop -WarningAction SilentlyContinue | Out-Null
            }
            Elseif($WeeklyScheduleTime)    
            {
                $ConvertedWeekDays = @()
                foreach($WDays in $Script:weekDays)
                {
                    [Microsoft.Internal.EnterpriseStorage.Dls.Scheduler.WeekDayType]$wd =  $WDays
                    $ConvertedWeekDays += $wd
                }
                Write-LogFile -FilePath $LogFilePath -LogText " Adding the settings for retension policys for online backup."
                $RRlist = @()
                $RRList += (New-Object -TypeName Microsoft.Internal.EnterpriseStorage.Dls.UI.ObjectModel.OMCommon.RetentionRange -ArgumentList $Script:WeeklyRet, Weeks)
                Set-DPMPolicyObjective -ProtectionGroup $MPG -OnlineRetentionRangeList $RRlist -ErrorAction Stop -WarningAction SilentlyContinue | Out-Null

                Write-LogFile -FilePath $LogFilePath -LogText " Adding the Weekly schedules for Online backup.`r`n"
                ($onlineSch = Get-DPMPolicySchedule -ProtectionGroup $MPG -LongTerm Online -ErrorAction SilentlyContinue -WarningAction SilentlyContinue) | Out-Null
                Set-DPMPolicySchedule -ProtectionGroup $MPG -Schedule $onlineSch -TimesOfDay $Script:WeeklyScheduleTimes -DaysOfWeek $ConvertedWeekDays -Interval $WeeksInterval -ErrorAction Stop -WarningAction SilentlyContinue | Out-Null
            }
            elseif($MonthlyScheduleTime) 
            {
                $ConvertedMonthWeekDays = @()
                foreach($MnthDays in $Script:MDays)
                {
                    [Microsoft.Internal.EnterpriseStorage.Dls.Scheduler.RelativeWeekDayType]$MDs = $MnthDays
                    $ConvertedMonthWeekDays += $MDs
                }

                Write-LogFile -FilePath $LogFilePath -LogText " Adding the settings for retension policys for online backup."
                $RRlist = @()
                $RRList += (New-Object -TypeName Microsoft.Internal.EnterpriseStorage.Dls.UI.ObjectModel.OMCommon.RetentionRange -ArgumentList $Script:MonthlyRet, Month)
                Set-DPMPolicyObjective -ProtectionGroup $MPG -OnlineRetentionRangeList $RRlist -ErrorAction Stop -WarningAction SilentlyContinue | Out-Null

                Write-LogFile -FilePath $LogFilePath -LogText " Adding the Monthly schedules for Online backup.`r`n"
                ($onlineSch = Get-DPMPolicySchedule -ProtectionGroup $MPG -LongTerm Online -ErrorAction SilentlyContinue -WarningAction SilentlyContinue) | Out-Null
                Set-DPMPolicySchedule -ProtectionGroup $MPG -Schedule $onlineSch -TimesOfDay $script:MonthlySechduledTimes -RelativeIntervals $Script:RelIntervalsArray -DaysOfWeek $ConvertedMonthWeekDays -ErrorAction Stop -WarningAction SilentlyContinue | Out-Null
            }
            Elseif($YearlyScheduleTime)
            {
                $ConvertedMonths = @()
                foreach($Mnth in $Script:MnInYr)
                {
                     [Microsoft.Internal.EnterpriseStorage.Dls.Scheduler.MonthType]$Mnths = $Mnth
                     $ConvertedMonths += $Mnths
                }

                Write-LogFile -FilePath $LogFilePath -LogText " Adding the settings for retension policys for online backup."
                $RRlist = @()
                $RRList += (New-Object -TypeName Microsoft.Internal.EnterpriseStorage.Dls.UI.ObjectModel.OMCommon.RetentionRange -ArgumentList $Script:YearlyRet, Years)
                Set-DPMPolicyObjective -ProtectionGroup $MPG -OnlineRetentionRangeList $RRlist -ErrorAction Stop -WarningAction SilentlyContinue | Out-Null
                
                Write-LogFile -FilePath $LogFilePath -LogText " Adding the Yearly schedules for Online backup.`r`n"
                ($onlineSch = Get-DPMPolicySchedule -ProtectionGroup $MPG -LongTerm Online -ErrorAction SilentlyContinue -WarningAction SilentlyContinue) | Out-Null                
                Set-DPMPolicySchedule -ProtectionGroup $MPG -Schedule $onlineSch -TimesOfDay $Script:YearlyScheduledtimeArray -DaysOfMonth $Script:DoM -Months $ConvertedMonths -ErrorAction Stop -WarningAction SilentlyContinue | Out-Null
            }
            else {}
        }
        
        Write-LogFile -FilePath $LogFilePath -LogText " Set the replication method i.e Now or Later or Manual."
        if ($Initialreplication -eq 'Now')
        {
            Set-DPMReplicaCreationMethod -ProtectionGroup $MPG -NOW -ErrorAction Stop -WarningAction SilentlyContinue | Out-Null
        }
        elseif ($Initialreplication -eq 'Later')
        {
            $DateTime = [DateTime]::Parse($InitialreplicationDateTime)
            Set-DPMReplicaCreationMethod -ProtectionGroup $MPG -Later $DateTime -ErrorAction Stop -WarningAction SilentlyContinue | Out-Null
        }
        else
        {
            Set-DPMReplicaCreationMethod -ProtectionGroup $MPG -ErrorAction Stop -WarningAction SilentlyContinue | Out-Null
        }
        Write-LogFile -FilePath $LogFilePath -LogText " Commiting the settings and creating the protection group."
        Set-DPMProtectionGroup -ProtectionGroup $MPG -ErrorAction Stop -WarningAction SilentlyContinue | Out-Null

        Write-LogFile -FilePath $LogFilePath -LogText " Verifiying the Configuration."
        try
        {
            ($ExistingGroups = Get-DPMProtectionGroup -DPMServerName $DPMServerName -ErrorAction SilentlyContinue -WarningAction SilentlyContinue ) | Out-Null
            if($ExistingGroups -and ($ExistingGroups.Name).Contains($ProtectionGroupName))
            {
                Write-LogFile -FilePath $LogFilePath -LogText "The $ProtectionGroupName protection group with the Ptotected Items $DataInput has been configures successfully .`r`n<#BlobFileReadyForUpload#>"
                $ObjOut = "The $ProtectionGroupName protection group with the Ptotected Items $DataInput has been configures successfully."
                $output = (@{"Response" = $ObjOut; "Status" = "Success"} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                Write-Output $output
            }
            else
            {
                $ObjOut = "The Protection Group $ProtectionGroupName has not been configured successfully."
                $output = (@{"Response" = $ObjOut; "Status" = "Failed"} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                Write-Output $output
                Write-LogFile -FilePath $LogFilePath -LogText "$ObjOut`r`n<#BlobFileReadyForUpload#>"
                exit
            }
        }
        catch
        {
            $ObjOut = "Error while checking created Protection Group $ProtectionGroupName configuration."
            $output = (@{"Response" = $ObjOut; "Status" = "Failed"} | ConvertTo-Json).ToString().Replace('\u0027',"'")
            Write-Output $output
            Write-LogFile -FilePath $LogFilePath -LogText "$ObjOut`r`n<#BlobFileReadyForUpload#>"
        }
    }
    Catch
    {
        $ObjOut = "Error while creating and configuring the Protection group $ProtectionGroupName.`r`n$($Error[0].Exception.Message)"
        $output = (@{"Response" = $ObjOut; "Status" = "Failed"} | ConvertTo-Json).ToString().Replace('\u0027',"'")
        Write-Output $output
        Write-LogFile -FilePath $LogFilePath -LogText "$ObjOut`r`n<#BlobFileReadyForUpload#>"
        Exit
    }
}
End
{
    Write-LogFile -FilePath $LogFilePath -LogText "####[ Script execution completed cuccessfully: $($MyInvocation.MyCommand.Name) ]####`r`n<#BlobFileReadyForUpload#>"
}
	