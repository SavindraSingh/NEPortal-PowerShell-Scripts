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
#>
$DaysOfWeek = $args[0]

$TimesOfDay = $args[1]

$Exclude = $args[2]

$Include = $args[3]

$RetentionDays = $args[4]

$NonWorkHourBandwidth = $args[5]

$WorkHourBandwidth = $args[6]

Try
{
    $ExtModule = (Get-Module -ListAvailable -Name 'MSOnlineBackup').Path
    if($ExtModule)
    {
        Import-Module $ExtModule
        # Set Machine settings
        If([Int32]$WorkHourBandwidth -gt 0 -and [Int32]$NonWorkHourBandwidth -gt 0)
        { 
            (Set-OBMachineSetting -WorkHourBandwidth $WorkHourBandwidth -NonWorkHourBandwidth $NonWorkHourBandwidth -ErrorAction Stop) | Out-Null 
        }

        # Define new policy object
        ($newpolicy = New-OBPolicy -ErrorAction Stop) | Out-Null

        # Configuring the backup schedule
        ($sched = New-OBSchedule -DaysofWeek $DaysOfWeek -TimesofDay $TimesOfDay -ErrorAction Stop) | Out-Null

        # Associate schedule with the New policy
        (Set-OBSchedule -Policy $newpolicy -Schedule $sched -ErrorAction Stop) | Out-Null

        # Configuring a retention policy
        ($retentionpolicy = New-OBRetentionPolicy -RetentionDays $RetentionDays -ErrorAction Stop) | Out-Null
        
        # Associate the retention policy with the New policy
        (Set-OBRetentionPolicy -Policy $newpolicy -RetentionPolicy $retentionpolicy -ErrorAction Stop) | Out-Null
        
        # Including and excluding files to be backed up
        If([String]::IsNullOrEmpty($Exclude))
        {
            # No Exclusions defined. Only inclusions
            ($inclusions = New-OBFileSpec -FileSpec $Include -ErrorAction Stop) | Out-Null
            (Add-OBFileSpec -Policy $newpolicy -FileSpec $inclusions -ErrorAction Stop) | Out-Null
        }
        Else
        {
            # Exclude files from backup
            ($exclusions = New-OBFileSpec -FileSpec $Exclude -Exclude -ErrorAction Stop) | Out-Null
            ($inclusions = New-OBFileSpec -FileSpec $Include -ErrorAction Stop) | Out-Null
            (Add-OBFileSpec -Policy $newpolicy -FileSpec $inclusions -ErrorAction Stop) | Out-Null
            (Add-OBFileSpec -Policy $newpolicy -FileSpec $exclusions -ErrorAction Stop) | Out-Null
        }

        # Applying the policy
        # Remove old policies before applying New policy
        (Get-OBPolicy -ErrorAction Stop | Remove-OBPolicy -Confirm:$false -ErrorAction SilentlyContinue) | Out-Null

        # Apply new Policy
        (Set-OBPolicy -Policy $newpolicy -Confirm:$false -ErrorAction Stop) | Out-Null

        # Verify new policy
        Try
        {
            ($newPolicyObject = Get-OBPolicy -ErrorAction Stop | Get-OBSchedule -ErrorAction Stop) | Out-Null
            
            if($newPolicyObject -ne $null)
            {
                # Do nothing. It is Success.
            }
            else 
            {
                Write-Output "Backup Policy was not created successfully"    
            }
        }
        Catch
        {
            Write-Output "There was an exception while fetching the backup policy created.$($Error[0].Exception.Message)"
        }
    }
    Else 
    {
        Write-Output "MSOnlinebackup module was not found."   
    }    
}
Catch
{
    Write-Output "Exception occured while Configuring the backup policies.$($Error[0].Exception.Message)"
}