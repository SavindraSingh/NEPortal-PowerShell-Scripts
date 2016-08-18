<#
    .SYNOPSIS
    Script to Configure Backup Policy on Azure Backup Server 

    .DESCRIPTION
    Script to create New backup vault in Azure Resource Manager Portal

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

    Azure virtual Machine which has the backup agent and backuppolicy will be configured.

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
     Purpose of script: Template for Azure Scripts
     Minimum requirements: PowerShell Version 1.2.1
     Initially written by: Bhaskar Desharaju
     Update/revision History:
     =======================
     Updated by        Date            Reason
     ==========        ====            ======
     SavindraSingh     26-May-16       Changed Mandatory=$True to Mandatory=$False for all parameters.

    .EXAMPLE
    C:\PS> .\Configure-BackupPolicyAzure.ps1 -ClientID 123456 -AzureUserName bhaskar.desharaju@netenrich.com -AzurePassword P@55w0rd1 -AzureSubscriptionID ca68598c-ecc3-4abc-b7a2-1ecef33f278d -DaysOfWeek 'Monday,Tuesday,Wednesday,Thursday,Friday' -TimesOfDay '16:00' -Exclude 'c:\Temp,C:\Windows' -Include 'c:\,d:\' -RetentionDays 7 

    .EXAMPLE
    C:\PS> .\Configure-BackupPolicyAzure.ps1 -ClientID 123456 -AzureUserName bhaskar.desharaju@netenrich.com -AzurePassword P@55w0rd1 -AzureSubscriptionID ca68598c-ecc3-4abc-b7a2-1ecef33f278d -AzureSubscriptionID -DaysOfWeek 'Monday,Tuesday,Wednesday,Thursday,Friday' -TimesOfDay '16:00' -Exclude 'c:\Temp,C:\Windows' -Include 'c:\,d:\' -RetentionDays 7 -NonWorkHourBandwidth 1234567 -WorkHourBandwidth 123456

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
                            #Exit
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
                        #Exit
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
                        #Exit
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
                    #Exit
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
    # 1. Validate all parameters
    Validate-AllParameters

    # 2. Login into Azure Account 
    Login-ToAzureAccount

    # 3. Checking for the reosurce group existence
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

    # 3. Checking for the VM existence
    Try
    {
        Write-LogFile -FilePath $LogFilePath -LogText "Verifying the VM existence in the subscription." 

        ($VMExist = Get-AzureRMVM -ResourceGroupName $ResourceGroupName -Name $VMName -ErrorAction SilentlyContinue -WarningAction SilentlyContinue) | Out-Null
        if($VMExist)
        {
            Write-LogFile -FilePath $LogFilePath -LogText "Virtual Machine $VMName is already exist." 
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

    # 4. Install extension to configure the backuppolicy
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
                Write-LogFile -FilePath $LogFilePath -LogText "Successfully removed the existing extension and adding new handle."
            }
            else
            {
                Write-LogFile -FilePath $LogFilePath -LogText "Unable to remove the existing extension.`r`n<#BlobFileReadyForUpload#>"
                $ObjOut = "Unable to remove the existing extension."
                $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                Write-Output $output
                Exit
            }
        }

        $ExtensionName = "BackupPolicy"
        Write-LogFile -FilePath $LogFilePath -LogText "Trying to Set the Extension for Backup Policy Configuration."

        if($NonWorkHourBandwidth -and $WorkHourBandwidth)
        {
            ($BackupInstallExtensionStatus = Set-AzureRmVMCustomScriptExtension -Name $ExtensionName -FileUri "https://automationtest.blob.core.windows.net/customscriptfiles/Configure-BackupPolicyAzureCS.ps1" -Run Configure-BackupPolicyAzureCS.ps1 -Argument "$DaysOfWeek $TimesOfDay $Exclude $Include $RetentionDays $NonWorkHourBandwidth $WorkHourBandwidth" -ResourceGroupName $ResourceGroupName -Location $Location -VMName $VMName -TypeHandlerVersion 1.8 -ErrorAction Stop -WarningAction SilentlyContinue) | Out-Null
        }
        Else 
        {
            ($BackupInstallExtensionStatus = Set-AzureRmVMCustomScriptExtension -Name $ExtensionName -FileUri "https://automationtest.blob.core.windows.net/customscriptfiles/Configure-BackupPolicyAzureCS.ps1" -Run Configure-BackupPolicyAzureCS.ps1 -Argument "$DaysOfWeek $TimesOfDay $Exclude $Include $RetentionDays" -ResourceGroupName $ResourceGroupName -Location $Location -VMName $VMName -TypeHandlerVersion 1.8 -ErrorAction Stop -WarningAction SilentlyContinue) | Out-Null    
        }

        if($BackupInstallExtensionStatus.StatusCode -eq 'OK')
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
                    $message = $ExtScriptStatus.Substatuses | Where-Object {$_.code -contains 'StdOut'}
                    if($message -eq $null)
                    {
                        Write-LogFile -FilePath $LogFilePath -LogText "Backup Policies have been configured successfully on $VMName.`r`n<#BlobFileReadyForUpload#>"
                        $ObjOut = "Backup Policies have been configured successfully on $VMName."
                        $output = (@{"Response" = [Array]$ObjOut; Status = "Success"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                        Write-Output $output
                    }
                    Else 
                    {
                        Write-LogFile -FilePath $LogFilePath -LogText "Backup Policies have not been configured successfully on $VMName.$message`r`n<#BlobFileReadyForUpload#>"
                        $ObjOut = "Backup Policies have not been configured successfully on $VMName.$message"
                        $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                        Write-Output $output
                        Exit                        
                    }
                }
                else
                {
                    Write-LogFile -FilePath $LogFilePath -LogText "Provisioning the script for Backup Policy Configuration was failed on $VMName.`r`n<#BlobFileReadyForUpload#>"
                    $ObjOut = "Provisioning the script for Backup Policy Configuration was failed on $VMName."
                    $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                    Write-Output $output
                    Exit
                }
            }
            else
            {
                Write-LogFile -FilePath $LogFilePath -LogText "The extension was not installed for configuring the Backup Policy on VM $VMName.`r`n<#BlobFileReadyForUpload#>"
                $ObjOut = "Extension was installed for configuring the Backup Policy on VM $VMName."
                $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                Write-Output $output
                Exit
            }           
        }
        Else
        {
            Write-LogFile -FilePath $LogFilePath -LogText "Unable to install the custom script extension For Backup Policy Configuration for Virtual Machine $VMName.`r`n<#BlobFileReadyForUpload#>"
            $ObjOut = "Unable to install the custom script extension For Backup Policy Configuration for Virtual Machine $VMName"
            $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
            Write-Output $output
            Exit            
        }
    }
    catch
    {
        $ObjOut = "Error while setting the script for configuring the backup policy on $VMName virtual Machine.$($Error[0].Exception.Message)"
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