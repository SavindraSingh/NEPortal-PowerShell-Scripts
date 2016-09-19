<#
    .SYNOPSIS
    The script is to create/sets the share with permissions for a user or a computer

    .DESCRIPTION
    The script is to create/sets the share with permissions for a user or a computer

    .PARAMETER ShareName
    Share name to be created or to be set

    .PARAMETER HostName
    computer name on which the Share has to be created.

    .PARAMETER FolderPath
    Folder path to be shared

    .PARAMETER PermissionType
    Permission to be enabled for the user i.e Read,Write,Full Control etc

    .PARAMETER AccessType
    Access Type i.e Allow or Deny

    .PARAMETER UserOrComputerName
    Domain user name or computer name for which the permissions have to be set

    .INPUTS
    All parameter values in String format.

    .OUTPUTS
    String. Result of the command output.

    .NOTES
     Purpose of script:     The script is to create a share and set permissions.
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
    C:\PS> .\Create-ShareAndSetPermissions.ps1 -ShareName TestShare -HostName localhost -FolderPath C:\Test -PermissionType Read -AccessType Allow -UserOrComputerName testuser@mylab.local

    .EXAMPLE
    C:\PS> 

    .LINK
    http://www.netenrich.com/#>

[CmdletBinding()]
Param
(
    [Parameter(ValueFromPipelineByPropertyName)]
    [string]$ShareName,

    [Parameter(ValueFromPipelineByPropertyName)]
    [string]$HostName,

    [Parameter(ValueFromPipelineByPropertyName)]
    [string]$FolderPath,

    [Parameter(ValueFromPipelineByPropertyName)]
    [string]$PermissionType,

    [Parameter(ValueFromPipelineByPropertyName)]
    [string]$AccessType,

    [Parameter(ValueFromPipelineByPropertyName)]
    [string]$UserOrComputerName
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

    Write-LogFile -FilePath $LogFilePath -LogText "####[ Script Execution started: $($MyInvocation.MyCommand.Name). For Client ID: $ClientID ]####" -Overwrite

    Function Validate-AllParameters
    {
        Try
        {
            # Validate parameter: ShareName
            Write-LogFile -FilePath $LogFilePath -LogText "Validating Parameters: ShareName. Only ERRORs will be logged."
            If([String]::IsNullOrEmpty($ShareName))
            {
                Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. ShareName parameter value is empty.`r`n<#BlobFileReadyForUpload#>"
                $ObjOut = "Validation failed. ShareName parameter value is empty."
                $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                Write-Output $output
                Exit
            }

            # Validate parameter: HostName
            Write-LogFile -FilePath $LogFilePath -LogText "Validating Parameters: HostName. Only ERRORs will be logged."
            If([String]::IsNullOrEmpty($HostName))
            {
                Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. HostName parameter value is empty.`r`n<#BlobFileReadyForUpload#>"
                $ObjOut = "Validation failed. HostName parameter value is empty."
                $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                Write-Output $output
                Exit
            }

            # Validate parameter: FolderPath
            Write-LogFile -FilePath $LogFilePath -LogText "Validating Parameters: FolderPath. Only ERRORs will be logged."
            If([String]::IsNullOrEmpty($FolderPath))
            {
                Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. FolderPath parameter value is empty.`r`n<#BlobFileReadyForUpload#>"
                $ObjOut = "Validation failed. FolderPath parameter value is empty."
                $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                Write-Output $output
                Exit
            }

            # Validate parameter:PermissionType
            Write-LogFile -FilePath $LogFilePath -LogText "Validating Parameters: PermissionType. Only ERRORs will be logged."
            If([String]::IsNullOrEmpty($PermissionType))
            {
                Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. PermissionType parameter value is empty.`r`n<#BlobFileReadyForUpload#>"
                $ObjOut = "Validation failed. PermissionType parameter value is empty."
                $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                Write-Output $output
                Exit
            }

            # Validate parameter: AccessType
            Write-LogFile -FilePath $LogFilePath -LogText "Validating Parameters: AccessType. Only ERRORs will be logged."
            If([String]::IsNullOrEmpty($AccessType))
            {
                Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. AccessType parameter value is empty.`r`n<#BlobFileReadyForUpload#>"
                $ObjOut = "Validation failed. AccessType parameter value is empty."
                $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                Write-Output $output
                Exit
            }
            else 
            {
                If($AccessType -notin ('Allow','Deny'))
                {
                    Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. AccessType parameter value is not a Valid type.`r`n<#BlobFileReadyForUpload#>"
                    $ObjOut = "Validation failed. AccessType parameter value is not a Valid type."
                    $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                    Write-Output $output
                    Exit
                }
            }

            # Validate parameter: UserOrComputerName
            Write-LogFile -FilePath $LogFilePath -LogText "Validating Parameters: UserOrComputerName. Only ERRORs will be logged."
            If([String]::IsNullOrEmpty($UserOrComputerName))
            {
                Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. UserOrComputerName parameter value is empty.`r`n<#BlobFileReadyForUpload#>"
                $ObjOut = "Validation failed. UserOrComputerName parameter value is empty."
                $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                Write-Output $output
                Exit
            }
        }
        Catch
        {
            Write-LogFile -FilePath $LogFilePath -LogText "Error while validating parameters: $($Error[0].Exception.Message)`r`n<#BlobFileReadyForUpload#>"
            $ObjOut = "Error while validating parameters: $($Error[0].Exception.Message)"
            $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"} | ConvertTo-Json).ToString().Replace('\u0027',"'")
            Write-Output $output
            Exit
        }
    }
}

Process
{
    #1. Validate parameters
    Validate-AllParameters

    #2. Creating and Setting the Permissions to the share
    try 
    {
        Write-LogFile -FilePath $LogFilePath -LogText "Checking for the provided share existence. if it does exist, creates a new share."

        $ShareDetails = $null
        ($ExistingShares = Get-WmiObject -Class Win32_Share -ComputerName $HostName -ErrorAction SilentlyContinue -WarningAction SilentlyContinue) | Out-Null
        $ShareDetails = $ExistingShares | Where-Object {$_.Name -eq $ShareName}

        if($ShareDetails -eq $null)
        {
            if(Test-Path -Path $FolderPath)
            {
                Write-LogFile -FilePath $LogFilePath -LogText "The folder is already exist."                
            }
            else 
            {
                Write-LogFile -FilePath $LogFilePath -LogText "The folder is does not exist, creating new directory."
                ($Status = New-Item $FolderPath -ItemType Directory -Force -ErrorAction Stop -WarningAction SilentlyContinue) | Out-Null
            }

            Write-LogFile -FilePath $LogFilePath -LogText "Creating the new Share $ShareName."
            $NewShare = (Get-WmiObject -Class Win32_Share -List).Create($FolderPath,$ShareName,0)
            if($NewShare.ReturnValue -eq 0)
            {
                Write-LogFile -FilePath $LogFilePath -LogText "The Share $ShareName has been created successfully."                 
            }
            Else 
            {
                Write-LogFile -FilePath $LogFilePath -LogText "Unable to create the share $ShareName.`r`n<#BlobFileReadyForUpload#>"
                $ObjOut = "Unable to create the share $ShareName."
                $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                Write-Output $output
                Exit
            }
        } 
        
        Write-LogFile -FilePath $LogFilePath -LogText "Fetching the existing Permissions on the share for $UserOrComputerName.." 
        ($ExistingDetails = Get-WmiObject -Class Win32_Share -Filter "Name=$ShareName" -ErrorAction SilentlyContinue -WarningAction SilentlyContinue) | Out-Null

        $UserOrComputerDetails = $ExistingDetails.Access | Where-Object {$_.IdentityReference -eq $UserOrComputerName}
        if($UserOrComputerDetails -ne $null)
        {
            Write-LogFile -FilePath $LogFilePath -LogText "User is already having the $UserOrComputerDetails permissions. Updating to the new permissions"             
        }

        Write-LogFile -FilePath $LogFilePath -LogText "Setting the Permissions on the share for $UserOrComputerName."
        $NSharePath = "\\$HostName\$ShareName"
        $Acl = Get-Acl $NSharePath
        $PermissionSet = $UserOrComputerName,$PermissionType,$AccessType
        $AccessRule = New-Object System.Security.AccessControl.FileSystemAccessRule $PermissionSet
        $Acl.SetAccessRule($AccessRule)

        #$acl | Set-Acl \\localhost\TestShare1
        ($AclStatus = Set-Acl -AclObject $Acl -Path $NSharePath -ErrorAction Stop -WarningAction SilentlyContinue) | Out-Null
        if($? -eq $true)
        {
            Write-LogFile -FilePath $LogFilePath -LogText "Share Permissions have been set successfully.`r`n<#BlobFileReadyForUpload#>"
            $ObjOut = "Share Permissions have been set successfully."
            $output = (@{"Response" = [Array]$ObjOut; Status = "Success"} | ConvertTo-Json).ToString().Replace('\u0027',"'")
            Write-Output $output               
        }
        Else 
        {
            Write-LogFile -FilePath $LogFilePath -LogText "Setting the Permissions was failed.`r`n<#BlobFileReadyForUpload#>"
            $ObjOut = "Setting the Permissions was failed."
            $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"} | ConvertTo-Json).ToString().Replace('\u0027',"'")
            Write-Output $output
            Exit
        }
    }
    catch 
    {
        Write-LogFile -FilePath $LogFilePath -LogText "There was exception while creating and setting the Share permissions. $($Error[0].Exception.Message)`r`n<#BlobFileReadyForUpload#>"
        $ObjOut = "There was exception while creating and setting the Share permissions. $($Error[0].Exception.Message)"
        $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"} | ConvertTo-Json).ToString().Replace('\u0027',"'")
        Write-Output $output
        Exit        
    }
}
End
{
    Write-LogFile -FilePath $LogFilePath -LogText "####[ Script execution completed Successfully: $($MyInvocation.MyCommand.Name) ]####`r`n<#BlobFileReadyForUpload#>"
}