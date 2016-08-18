<#
    .SYNOPSIS
    Script to create New DB with geo backup of sql db

    .DESCRIPTION
    Script to create New DB with geo backup of sql db

    .PARAMETER ClientID
    ClientID of the client for whom the script is being executed.

    .PARAMETER AzureUserName
    User name for Azure login. This should be an Organizational account (not Hotmail/Outlook account)

    .PARAMETER AzurePassword
    Password for Azure user account.

    .PARAMETER AzureSubscriptionID
    Azure Subscription ID to use for this activity.

    .PARAMETER ResourceGroupName
    Name of the resource Group in which you have SQL DB (this SQL DB Geo backup will be used to restore)

    .PARAMETER ServerName
    Name of the Azure SQL Server name which has SQL DB.

    .PARAMETER DBName
    Name of the Azure SQL DB (which has geo backup)

    .PARAMETER TargetResourceGroupName
    Name of the Resource group in which you want to deploy new SQL DB.

    .PARAMETER TargetServerName
    Name of the Azure SQL Server Name in which you want to deploy new SQL DB.

    .PARAMETER TargetDBName
    Name of the  New Azure SQL DB Name.

    .PARAMETER Edition
    SQL DB Edition. Accepted values are "None","Premium","Basic","Standard","DataWarehouse","Free"

    .PARAMETER ServiceTierNam
    Sepcify the ServiceTier like "S0","S1","S2","S3","P1","P2","P4","P6","P3","P15".

    .INPUTS
    All parameter values in String format.

    .OUTPUTS
    {
    "Status":  "Success",
    "BlobURI":  "https://nelogfiles.blob.core.windows.net/neportallogs/12-Create-DatabaseAndRestoreData-12-Aug-2016_121039.log",
    "Response":  [
                     "Successfully restored Database."
                 ]
    }

    .NOTES
     Purpose of script: Script to restore DB using Geo backup
     Minimum requirements: Azure PowerShell Version 1.4.0
     Initially written by: Bindu
     Update/revision History:
     =======================
     Updated by        Date            Reason
     ==========        ====            ======
     Bindu             12-08-2016

    .EXAMPLE
    C:\PS> .\Restore-SQLDBFromGeoBackup.ps1 -ClientID 12 -AzureUserName user@domain.com -AzurePassword ****** -AzureSubscriptionID ca68598c-ecc3-4abc-b7a2-1ecef33f278d -ResourceGroupName todelete3 -ServerName sampleser -DBName targetdb -TargetResourceGroupName todelete2 -TargetServerName sampleser1 -TargetDBName newdb

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
    [String]$DBName,

    [Parameter(ValueFromPipelineByPropertyName)]
    [string]$TargetResourceGroupName,

    [Parameter(ValueFromPipelineByPropertyName)]
    [String]$TargetServerName,

    [Parameter(ValueFromPipelineByPropertyName)]
    [String]$TargetDBName,

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

            # Validate parameter: DBName
            Write-LogFile -FilePath $LogFilePath -LogText "Validating Parameters: DBName. Only ERRORs will be logged."
            If([String]::IsNullOrEmpty($DBName))
            {
                Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. DBName parameter value is empty.`r`n<#BlobFileReadyForUpload#>"
                $ObjOut = "Validation failed. PreviousDBName parameter value is empty."
                $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                Write-Output $output
                Exit
            }

            # Validate parameter: TargetResourceGroupName
            Write-LogFile -FilePath $LogFilePath -LogText "Validating Parameters: TargetResourceGroupName. Only ERRORs will be logged."
            If([String]::IsNullOrEmpty($TargetResourceGroupName))
            {
                Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. TargetResourceGroupName parameter value is empty.`r`n<#BlobFileReadyForUpload#>"
                $ObjOut = "Validation failed. TargetResourceGroupName parameter value is empty."
                $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                Write-Output $output
                Exit
            }

            # Validate parameter: TargetServerName
            Write-LogFile -FilePath $LogFilePath -LogText "Validating Parameters: TargetServerName. Only ERRORs will be logged."
            If([String]::IsNullOrEmpty($TargetServerName))
            {
                Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. TargetServerName parameter value is empty.`r`n<#BlobFileReadyForUpload#>"
                $ObjOut = "Validation failed. TargetServerName parameter value is empty."
                $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                Write-Output $output
                Exit
            }

            # Validate parameter: TargetDBName
            Write-LogFile -FilePath $LogFilePath -LogText "Validating Parameters: TargetDBName. Only ERRORs will be logged."
            If([String]::IsNullOrEmpty($TargetDBName))
            {
                Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. TargetDBName parameter value is empty.`r`n<#BlobFileReadyForUpload#>"
                $ObjOut = "Validation failed. TargetDBName parameter value is empty."
                $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                Write-Output $output
                Exit
            }

            # Validate parameter: Edition
            Write-LogFile -FilePath $LogFilePath -LogText "Validating Parameters: Edition. Only ERRORs will be logged."
            If([String]::IsNullOrEmpty($Edition))
            {
                $Script:FlagEd = 1
                Write-LogFile -FilePath $LogFilePath -LogText " Edition parameter value is empty."
                #$ObjOut = "Validation failed. Edition parameter value is empty."
                #$output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
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
                #$ObjOut = "Validation failed. ServiceTierName parameter value is empty."
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
        
    
    # 2 checking Resources existance

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
        $ObjOut = "SQL Server '$ResourceGroupName' Doesn't exists. Cannot proceed further"
        Write-LogFile -FilePath $LogFilePath -LogText "$ObjOut`r`n<#BlobFileReadyForUpload#>"
        $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
        Write-Output $output
        Exit
    }

    Try #DBName
    {
        Write-LogFile -FilePath $LogFilePath -LogText "Checking if SQL DB '$DBName' Exists.Only ERRORs will be logged"
        ($DB=Get-AzureRmSqlDatabase -ResourceGroupName $ResourceGroupName -ServerName $ServerName  -DatabaseName $DBName -ErrorAction Stop )| Out-Null       
    }
    catch
    {
        $ObjOut = "SQL DB '$DBName' Doesn't exists. Cannot proceed further"
        Write-LogFile -FilePath $LogFilePath -LogText "$ObjOut`r`n<#BlobFileReadyForUpload#>"
        $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
        Write-Output $output
        Exit
    }

    Try #TargetResourceGroup
    {
        Write-LogFile -FilePath $LogFilePath -LogText "Checking if Target ResourceGroup '$TargetResourceGroupName' Exists.Only ERRORs will be logged"
        Get-AzureRmResourceGroup -Name $TargetResourceGroupName -ErrorAction Stop | Out-Null       
    }
    catch
    {
        $ObjOut = "ResourceGroup '$TargetResourceGroupName' Doesn't exists. Cannot proceed further"
        Write-LogFile -FilePath $LogFilePath -LogText "$ObjOut`r`n<#BlobFileReadyForUpload#>"
        $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
        Write-Output $output
        Exit
    }
    
    Try #Target SQL Server
    {
        Write-LogFile -FilePath $LogFilePath -LogText "Checking if Target SQL Server '$TargetServerName' Exists.Only ERRORs will be logged"
        Get-AzureRmSqlServer -ResourceGroupName $TargetResourceGroupName -ServerName $TargetServerName -ErrorAction Stop | Out-Null       
    }
    catch
    {
        $ObjOut = "Target SQL Server '$TargetResourceGroupName' Doesn't exists. Cannot proceed further"
        Write-LogFile -FilePath $LogFilePath -LogText "$ObjOut`r`n<#BlobFileReadyForUpload#>"
        $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
        Write-Output $output
        Exit
    }

    # 3. Restoring Db With Geo Backup
    
    Write-LogFile -FilePath $LogFilePath -LogText "Restoring DB"
    #Write-Host (($FlagEd -ne 1) -and ($FlagST -ne 1))
    if (($FlagEd -ne 1) -and ($FlagST -ne 1))
    {
        #write-host "if"
        Try
        {
            Restore-AzureRmSqlDatabase -FromGeoBackup -ResourceGroupName $TargetResourceGroupName -ServerName $TargetServerName -TargetDatabaseName $TargetDBName `
                                    -ResourceId $DB.ResourceID -Edition $Edition -ServiceObjectiveName $ServiceTierName -ErrorAction Stop | out-null
            $ObjOut = "Successfully restored Database."
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
    else
    {
        #write-host "else"
        Try
        {
            Restore-AzureRmSqlDatabase -FromGeoBackup -ResourceGroupName $TargetResourceGroupName -ServerName $TargetServerName -TargetDatabaseName $TargetDBName `
                                    -ResourceId $DB.ResourceID -Edition $DB.Edition -ServiceObjectiveName $DB.CurrentServiceObjectiveName -ErrorAction Stop | out-null
            $ObjOut = "Successfully restored Database."
            Write-LogFile -FilePath $LogFilePath -LogText "$ObjOut`r`n<#BlobFileReadyForUpload#>"
            $output = (@{"Response" = [Array]$ObjOut; Status = "Success"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
            Write-Output $output
            Exit
        }
        catch
        {
            $ObjOut = "Failed to restore Database.`n$($Error[0].Exception.Message)"
            Write-LogFile -FilePath $LogFilePath -LogText "$ObjOut`r`n<#BlobFileReadyForUpload#>"
            $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
            Write-Output $output
            Exit            
        }

    }
                      
}
End
{
    Write-LogFile -FilePath $LogFilePath -LogText "####[ Script execution completed cuccessfully: $($MyInvocation.MyCommand.Name) ]####`r`n<#BlobFileReadyForUpload#>"
}