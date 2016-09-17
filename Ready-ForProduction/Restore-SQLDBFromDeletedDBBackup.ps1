<#
    .SYNOPSIS
    Script to create New SQL DB with backup of deleted Azure SQL DB.

    .DESCRIPTION
    Script to create New SQL DB with backup of deleted Azure SQL DB.

    .PARAMETER ClientID
    ClientID of the client for whom the script is being executed.

    .PARAMETER AzureUserName
    User name for Azure login. This should be an Organizational account (not Hotmail/Outlook account)

    .PARAMETER AzurePassword
    Password for Azure user account.

    .PARAMETER AzureSubscriptionID
    Azure Subscription ID to use for this activity.

    .PARAMETER ResourceGroupName
    Name of the ResourceGroup in Which your SQL Server exists

    .PARAMETER ServerName
    Name of the Azure SQL Server Name.

    .PARAMETER DeletedDBName
    Name of the deleted SQL DB .Backup of this Deleted DB are used to create new DB

    .PARAMETER NewDBName
    Name of New SQL DB.

    .PARAMETER DeletedDBDeletionDateTime
    Deletion Date and time(24H format) of deleted DB. It must be in the format of "mm-dd-yyyy hh:<MM(Optional)>:<seconds(optional)>  

    .PARAMETER Edition
    Name of SQL DB Edition. Accepted values are "None","Premium","Basic","Standard","DataWarehouse","Free"

    .PARAMETER ServiceTierName
    Sepcify the ServiceTier like "S0","S1","S2","S3","P1","P2","P4","P6","P3","P15".

    .INPUTS
    All parameter values in String format.

    .OUTPUTS
    
    {
    "Status":  "Success",
    "BlobURI":  "https://nelogfiles.blob.core.windows.net/neportallogs/12-Restore-FromDeletedDBBackup-12-Aug-2016_102852.log",
    "Response":  [
                     "Successfully Created New DB with Backup of Deleted DB"
                 ]
    }


    .NOTES
     Purpose of script: To create New dB with Deleted SQL DB Backup
     Minimum requirements: Azure PowerShell Version 1.4.0
     Initially written by: Bindu
     Update/revision History:
     =======================
     Updated by        Date            Reason
     ==========        ====            ======
     Bindu             12-08-2016

    .EXAMPLE
    C:\PS> .\Restore-SQLDBFromDeletedDBBackup.ps1 -ClientID 12 -AzureUserName user@domain.com -AzurePassword ***** -AzureSubscriptionID ca68598c-ecc3-4abc-b7a2-1ecef33f278d -ResourceGroupName todelete3 -ServerName sampleser -DeletedDBName todelete -NewDBName todel4 -DeletedDBDeletionDateTime "8-10-2016 6:00" -Edition basic

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
    [string]$ResourceGroupName,

    [Parameter(ValueFromPipelineByPropertyName)]
    [String]$ServerName,

    [Parameter(ValueFromPipelineByPropertyName)]
    [String]$DeletedDBName,

    [Parameter(ValueFromPipelineByPropertyName)]
    [String]$NewDBName,

    [Parameter(ValueFromPipelineByPropertyName)]
    [String]$DeletedDBDeletionDateTime,

    [Parameter(ValueFromPipelineByPropertyName)]
    [String]$Edition,

    [Parameter(ValueFromPipelineByPropertyName)]
    [String]$ServiceTierName
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

            # Validate parameter: ServerName
            Write-LogFile -FilePath $LogFilePath -LogText "Validating Parameters: ServerName. Only ERRORs will be logged."
            If([String]::IsNullOrEmpty($ServerName))
            {
                Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. ServerName parameter value is empty.`r`n<#BlobFileReadyForUpload#>"
                $ObjOut = "Validation failed. ServerName parameter value is empty."
                $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                Write-Output $output
                Exit
            }

            # Validate parameter: DeletedDBName
            Write-LogFile -FilePath $LogFilePath -LogText "Validating Parameters: DeletedDBName. Only ERRORs will be logged."
            If([String]::IsNullOrEmpty($DeletedDBName))
            {
                Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. DeletedDBName parameter value is empty.`r`n<#BlobFileReadyForUpload#>"
                $ObjOut = "Validation failed. DeletedDBName parameter value is empty."
                $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                Write-Output $output
                Exit
            }

            # Validate parameter: NewDBName
            Write-LogFile -FilePath $LogFilePath -LogText "Validating Parameters: NewDBName. Only ERRORs will be logged."
            If([String]::IsNullOrEmpty($NewDBName))
            {
                Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. NewDBName parameter value is empty.`r`n<#BlobFileReadyForUpload#>"
                $ObjOut = "Validation failed. NewDBName parameter value is empty."
                $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                Write-Output $output
                Exit
            }
            
            # Validate parameter: DeletedDBDeletionDateTime
            Write-LogFile -FilePath $LogFilePath -LogText "Validating Parameters: DeletedDBDeletionDateTime. Only ERRORs will be logged."
            If([String]::IsNullOrEmpty($DeletedDBDeletionDateTime) )
            {
                $Script:FlagDBCT = 1
                Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. DeletedDBDeletionDateTime parameter value is empty/not in valid format."
                $ObjOut = "Validation failed. DeletedDBDeletionDateTime parameter value is empty/not in valid format."
                #$output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                #Write-Output $output
                #Exit
            }
            else
            {
                If(($DeletedDBDeletionDateTime -notmatch '^\d{1,2}[-/]\d{1,2}[-/](\d{2,4})\s\d{1,2}:\d{1,2}(:\d{1,2})?'))
                {
                    Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. 'DeletedDBDeletionDateTime' parameter not in valid format.`r`n<#BlobFileReadyForUpload#>"
                    $ObjOut = "Validation failed. 'DeletedDBDeletionDateTime' parameter not in valid format."
                    $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                    Write-Output $output
                    Exit
                }

                Try
                {
                    Write-LogFile -FilePath $LogFilePath -LogText "Checking if Datetime value is Valid"
                    [DateTime]$DeletedDBDeletionDateTime | Out-Null
                }
                catch
                {
                    $Script:FlagDBCT = 1
                    Write-LogFile -FilePath $LogFilePath -LogText "DeletedDBDeletionDateTime parameter value is not Valid"
                    #$ObjOut = "DeletedDBDeletionDateTime parameter value is not Valid."
                    #$output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                    #Write-Output $output
                    #Exit                    
                }
            }


            # Validate parameter: Edition
            Write-LogFile -FilePath $LogFilePath -LogText "Validating Parameters: Edition. Only ERRORs will be logged."
            If([String]::IsNullOrEmpty($Edition))
            {
                $Script:FlagEd = 1
                Write-LogFile -FilePath $LogFilePath -LogText " Edition parameter value is empty."
            }
            
            else
            {
                If(("None","Premium","Basic","Standard","DataWarehouse","Free") -notcontains $Edition )
                {
                    Write-LogFile -FilePath $LogFilePath -LogText "'Edition' parameter value is not valid. It must be 'None/Premium/Basic/Standard/Free'`r`n<#BlobFileReadyForUpload#>"
                    $ObjOut = "'Edition' parameter value is not valid. It must be 'None/Premium/Basic/Standard/Free'"
                    $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                    Write-Output $output
                    Exit
                }
            }         
            
            # Validate parameter: ServiceTierName
            Write-LogFile -FilePath $LogFilePath -LogText "Validating Parameters: ServiceTierName. Only ERRORs will be logged."
            If([String]::IsNullOrEmpty($ServiceTierName))
            {
                $Script:FlagST = 1
                Write-LogFile -FilePath $LogFilePath -LogText "ServiceTierName parameter value is empty."                
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
    Validate-AllParameters

    # 1. Login to Azure subscription
    Login-ToAzureAccount
        
    
    # 2 checking if Resource group, SQL Server & backup of deleted DB

    Try #ResourceGroup
    {
        Write-LogFile -FilePath $LogFilePath -LogText "Checking if ResourceGroup '$ResourceGroupName' Exists.Only ERRORs will be logged"
        Get-AzureRmResourceGroup -Name $ResourceGroupName -ErrorAction Stop | Out-Null       
    }
    catch
    {
        $ObjOut = "ResourceGroup '$ResourceGroupName' Doesn't exists. Cannot proceed further"
        Write-LogFile -FilePath $LogFilePath -LogText "$ObjOut`r`n<#BlobFileReadyForUpload#>"
        $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
        Write-Output $output
        Exit
    }
    
    Try #SQL Server
    {
        Write-LogFile -FilePath $LogFilePath -LogText "Checking if SQL Server '$ServerName' Exists.Only ERRORs will be logged"
        Get-AzureRmSqlServer -ResourceGroupName $ResourceGroupName -ServerName $ServerName -ErrorAction Stop | Out-Null       
    }
    catch
    {
        $ObjOut = "SQL Server '$ServerName' Doesn't exists. Cannot proceed further"
        Write-LogFile -FilePath $LogFilePath -LogText "$ObjOut`r`n<#BlobFileReadyForUpload#>"
        $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
        Write-Output $output
        Exit
    }

    # 2.1 Checking if deleted DB exists
    Try
    {
        Write-LogFile -FilePath $LogFilePath -LogText "Checking if SQL DB '$DeletedDBName' Exists.Only ERRORs will be logged"                
        Get-AzureRmSqlDatabase -ResourceGroupName $ResourceGroupName -ServerName $ServerName -DatabaseName $DeletedDBName -ErrorAction Stop | Out-Null
        $ObjOut = "SQL DB '$DeletedDBName' still exists. If you want to restore existing DB, then choose RestoreMethod as 'InTime'"
        Write-LogFile -FilePath $LogFilePath -LogText "$ObjOut`r`n<#BlobFileReadyForUpload#>"
        $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
        Write-Output $output
        Exit
    }
    catch
    {
        $ObjOut = "SQL DB '$DeletedDBName' Doesn't exists."
        Write-LogFile -FilePath $LogFilePath -LogText "$ObjOut"
        #$output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
        #Write-Output $output
        #Exit            
    } 
    
    # 2.2 Checkinf if deleted DB backups exists

    Try #DeletedDBName
    {
        Write-LogFile -FilePath $LogFilePath -LogText "Checking if backup of SQL DB '$DeletedDBName' Exists.Only ERRORs will be logged"
        ($DeletedDB = Get-AzureRMSqlDeletedDatabaseBackup -ResourceGroupName $ResourceGroupName -ServerName $ServerName $DeletedDBName -ErrorAction Stop) | Out-Null       
    }
    catch
    {
        $ObjOut = "SQL DB backups for '$DeletedDBName' Doesn't exists.`n$($Error[0].Exception.Message) "
        Write-LogFile -FilePath $LogFilePath -LogText "$ObjOut`r`n<#BlobFileReadyForUpload#>"
        $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
        Write-Output $output
        Exit
    }


    # 3. Restoring deleted database into a standalone database

    If(($DeletedDB.DeletionDate).length -gt 1)
    {
        if($FlagDBCT -eq 1)
        {
            $ObjOut = "Multiple Backups are there for deleted database '$DeletedDBName'. you must provide Valid 'DeletedDBDeletionDateTime' dd-mm-yyyy hh:mm:<ss(Optional)>"
            Write-LogFile -FilePath $LogFilePath -LogText "$ObjOut`r`n<#BlobFileReadyForUpload#>"
            $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
            Write-Output $output
            Exit                        
        }
        else
        {
            $DT = [DateTime]$DeletedDBDeletionDateTime
            [Array]$DateArr = $DeletedDB.DeletionDate 
            for($i=0;$i -le ($DateArr.length);$i++)
            {
                If((($DateArr[$i].Day) -eq ($DT.Day)) -and (($DateArr[$i].Month) -eq ($DT.Month)) -and (($DateArr[$i].year) -eq ($DT.Year)) -and (($DateArr[$i].Hour) -eq ($DT.Hour)))
                {
                    $temp = $i
                    $RID = $DeletedDB[$i].ResourceId
                    Write-LogFile -FilePath $LogFilePath -LogText "Backup Details of DB using for restore:
                                                                   '$RID'"
                    Break
                }
            }
            If($temp -eq $null)
            {
                $ObjOut = "Deletion time is not matching with provided 'DeletedDBDeletionDateTime'"
                Write-LogFile -FilePath $LogFilePath -LogText "$ObjOut`r`n<#BlobFileReadyForUpload#>"
                $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                Write-Output $output
                Exit
            }
        }
    } 
        
    
    Try
    {
        Write-LogFile -FilePath $LogFilePath -LogText "Creting New DB with Backup of deleted Database"
        If(($FlagST -ne 1) -and ($FlagEd -ne 1) -and ($temp -ne $null))
        {
            Restore-AzureRmSqlDatabase -FromDeletedDatabaseBackup -ResourceGroupName $ResourceGroupName `
                                       -ServerName $ServerName -TargetDatabaseName $NewDBName `
                                       -DeletionDate $DeletedDB[$i].DeletionDate `
                                       -ResourceId $DeletedDB[$i].ResourceID -Edition $Edition -ServiceObjectiveName $ServiceTierName -ErrorAction Stop | Out-Null
           
        }
        elseif(($temp -ne $null))
        {
            Restore-AzureRmSqlDatabase -FromDeletedDatabaseBackup -ResourceGroupName $ResourceGroupName `
                                       -ServerName $ServerName -TargetDatabaseName $NewDBName `
                                       -DeletionDate $DeletedDB[$i].DeletionDate `
                                       -ResourceId $DeletedDB[$i].ResourceID -Edition $DeletedDB[$i].Edition -ServiceObjectiveName $DeletedDB[$i].ServiceLevelObjective -ErrorAction Stop | Out-Null
            
        }

        elseif(($FlagST -ne 1) -and ($FlagEd -ne 1))
        {
            Restore-AzureRmSqlDatabase -FromDeletedDatabaseBackup -ResourceGroupName $ResourceGroupName `
                                       -ServerName $ServerName -TargetDatabaseName $NewDBName `
                                       -DeletionDate $DeletedDB.DeletionDate `
                                       -ResourceId $DeletedDB.ResourceID -Edition $Edition -ServiceObjectiveName $ServiceTierName -ErrorAction Stop | Out-Null
        }
        else
        {
            Restore-AzureRmSqlDatabase -FromDeletedDatabaseBackup -ResourceGroupName $ResourceGroupName `
                                       -ServerName $ServerName -TargetDatabaseName $NewDBName `
                                       -DeletionDate $DeletedDB.DeletionDate `
                                       -ResourceId $DeletedDB.ResourceID -Edition $DeletedDB.Edition -ServiceObjectiveName $DeletedDB.ServiceLevelObjective -ErrorAction Stop | Out-Null
        }

        $ObjOut="Successfully Created New DB with Backup of Deleted DB"
        Write-LogFile -FilePath $LogFilePath -LogText "$ObjOut`r`n<#BlobFileReadyForUpload#>"
        $output = (@{"Response" = [Array]$ObjOut; Status = "Success"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
        Write-Output $output
        Exit

    }
    Catch
    {
        $ObjOut = "Failed to restore Database.`n$($Error[0].Exception.Message)"
        Write-LogFile -FilePath $LogFilePath -LogText "$ObjOut`r`n<#BlobFileReadyForUpload#>"
        $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
        Write-Output $output
        Exit

    }           

}
End
{
    Write-LogFile -FilePath $LogFilePath -LogText "####[ Script execution completed cuccessfully: $($MyInvocation.MyCommand.Name) ]####`r`n<#BlobFileReadyForUpload#>"
}