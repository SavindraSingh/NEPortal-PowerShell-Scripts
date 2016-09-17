<#
    .SYNOPSIS
        This script will do failver of SQL DB  

    .DESCRIPTION
        This script will swap primary and Secondary DB(failover).

    .PARAMETER ClientID
        ClientID of the client for whom the script is being executed.

    .PARAMETER AzureUserName
        Give the Azure Account Username for Login into your Azure Account

    .PARAMETER AzurePassword
        Give the Azure Account Password for Login into your Azure Account

    .PARAMETER AzureSubscriptionID
        Give the Azure Account SubscriptionID for Login into your Azure Account

    .PARAMETER SecondaryResourceGrpName
        Name of the Resource group in which you have secondary DB
        
    .PARAMETER SecondaryServerName
        Name of the secondary Server which you want to be primary

    .PARAMETER SecondaryDataBaseName        
        The name of the Secondary Azure SQL Database to act as primary.

    .PARAMETER PrimaryResourceGrpName
        Name of the resource group which has primary SQL DB(later it will be converted to Secondary DB) 

    .INPUTS
        All parameter values in String format.

    .OUTPUTS
        {
        "Status":  "XXXXXX",
        "BlobURI":  "https://nelogfiles.blob.core.windows.net/neportallogs/1257-ConfigureTrafficManagerforAzureEPs2-28-Jul-2016_1
    73648.log",
        "Response":  [
                         "********"
                     ]
        }


    .NOTES
     Purpose of script: To do Azure SQL DB failover.
     Minimum requirements: Azure PowerShell Version 1.4.0
     Initially written by: Bindu
     Update/revision History:
     =======================
     Updated by    Date      Reason
     ==========    ====      ======
     Bindu        19-07-2016   
     Bindu        27-07-2016
     Bindu        28-07-2016

    .EXAMPLE
    C:\PS> Import-Csv Book2.csv | .\Perform-FailoverOfSQLDB.ps1

    .EXAMPLE
    C:\PS> .Perform-FailoverOfSQLDB.ps1 -AzureUserName xxxxxxxx `
                          -AzurePassword xxxxxx `
                          -AzureSubscriptionID xx-xx-xx-xx-xx `
                          -ResourceGrpName xxxxxxxx `
                          -DatabaseName xxxxx -ServerName xxxxx `
                          -PartnerResourceGrpName xxxxx

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
    [string]$SecondaryResourceGrpName,

    [Parameter(ValueFromPipelineByPropertyName)]
    [String]$SecondaryServerName,

    [Parameter(ValueFromPipelineByPropertyName)]
    [string]$SecondaryDatabaseName,
    
    [Parameter(ValueFromPipelineByPropertyName)]
    [string]$PrimaryResourceGrpName        
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
            # Validate parameter: SecondaryResourceGrpName
            Write-LogFile -FilePath $LogFilePath -LogText "Validating Parameters: SecondaryResourceGrpName. Only ERRORs will be logged."
            If([String]::IsNullOrEmpty($SecondaryResourceGrpName))
            {
                Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. SecondaryResourceGrpName parameter value is empty.`r`n<#BlobFileReadyForUpload#>"
                $ObjOut = "Validation failed. SecondaryResourceGrpName parameter value is empty."
                $output = (@{"Response" = [Array]$ObjOut; "Status" = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                Write-Output $output
                Exit
            }
            
            # Validate parameter: SecondaryServerName
            Write-LogFile -FilePath $LogFilePath -LogText "Validating Parameters: SecondaryServerName. Only ERRORs will be logged."
            If([String]::IsNullOrEmpty($SecondaryServerName))
            {
                Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. SecondaryServerName parameter value is empty.`r`n<#BlobFileReadyForUpload#>"
                $ObjOut = "Validation failed. SecondaryServerName parameter value is empty."
                $output = (@{"Response" = [Array]$ObjOut; "Status" = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                Write-Output $output
                Exit
            }
            
            # Validate parameter: SecondaryDatabaseName
            Write-LogFile -FilePath $LogFilePath -LogText "Validating Parameters: SecondaryDatabaseName. Only ERRORs will be logged."
            If([String]::IsNullOrEmpty($SecondaryDatabaseName))
            {
                Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. SecondaryDatabaseName parameter value is empty.`r`n<#BlobFileReadyForUpload#>"
                $ObjOut = "Validation failed. SecondaryDatabaseName parameter value is empty."
                $output = (@{"Response" = [Array]$ObjOut; "Status" = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                Write-Output $output
                Exit
            }
             
            # Validate parameter: PrimaryResourceGrpName
            Write-LogFile -FilePath $LogFilePath -LogText "Validating Parameters: PrimaryResourceGrpName. Only ERRORs will be logged."
            If([String]::IsNullOrEmpty($PrimaryResourceGrpName))
            {
                Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. PrimaryResourceGrpName parameter value is empty.`r`n<#BlobFileReadyForUpload#>"
                $ObjOut = "Validation failed. PrimaryResourceGrpName parameter value is empty."
                $output = (@{"Response" = [Array]$ObjOut; "Status" = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
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
            $ObjOut = "Error logging in to Azure Account.`n$($Error[0].Exception.Message)`r`n<#BlobFileReadyForUpload#>"
            Write-LogFile -FilePath $LogFilePath -LogText $ObjOut
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

    #2. Checking the existance of Resources.

    Try # SecondaryResource Group
    {
        Get-AzureRmResourceGroup -Name $SecondaryResourceGrpName -ErrorAction Stop | out-null

    }
    catch
    {
       $ObjOut = "Secondary Resource Group '$SecondaryResourceGrpName' does not Exist. Can not proceed further"
       Write-LogFile -FilePath $LogFilePath -LogText "$ObjOut`r`n<#BlobFileReadyForUpload#>"
       $output = (@{"Response" = [Array]$ObjOut; "Status" = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
       Write-Output $output
       Exit
    }

    Try  #Secondary SQL server
    {
        Get-AzureRmSqlServer -ResourceGroupName $SecondaryResourceGrpName -ServerName $SecondaryServerName  -ErrorAction Stop | Out-Null
    }
    catch
    {
       $ObjOut = "Secondary SQL Server '$SecondaryServerName' does not Exist. Can not proceed further)"
       Write-LogFile -FilePath $LogFilePath -LogText "$ObjOut`r`n<#BlobFileReadyForUpload#>"
       $output = (@{"Response" = [Array]$ObjOut; "Status" = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
       Write-Output $output
       Exit  
    }

    Try  #Secondary SQL DB
    {
        Get-AzureRmSqlDatabase -ResourceGroupName $SecondaryResourceGrpName `
                               -ServerName $SecondaryServerName `
                               -DatabaseName $SecondaryDatabaseName -ErrorAction Stop | Out-Null
    }
    catch
    {
       $ObjOut = "Secondary SQL DB '$SecondaryDatabaseName' does not Exist in '$SecondaryServerName' server. Can not proceed further"
       Write-LogFile -FilePath $LogFilePath -LogText "$ObjOut`r`n<#BlobFileReadyForUpload#>"
       $output = (@{"Response" = [Array]$ObjOut; "Status" = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
       Write-Output $output
       Exit  
    }

    Try #Primary Resource Group
    {
        Get-AzureRmResourceGroup -Name $PrimaryResourceGrpName -ErrorAction Stop | out-null

    }
    catch
    {
       $ObjOut = "Primary Resource Group '$PrimaryResourceGrpName' does not Existed.Can not proceed further "
       Write-LogFile -FilePath $LogFilePath -LogText "$ObjOut`r`n<#BlobFileReadyForUpload#>"
       $output = (@{"Response" = [Array]$ObjOut; "Status" = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
       Write-Output $output
       Exit
    }


    # 3. Failover

    Try
    {
       $ObjOut = "Stating failover with parameters::
                                                    Secondary RG: '$SecondaryResourceGrpName' ;
                                                    Secondary ServerName: '$SecondaryServerName' ; 
                                                    Secondary DB: '$SecondaryDatabaseName' ; 
                                                    Primary Server RG: '$PrimaryResourceGrpName'.)"
       Write-LogFile -FilePath $LogFilePath -LogText $ObjOut 
       Set-AzureRmSqlDatabaseSecondary  -ResourceGroupName $SecondaryResourceGrpName `
                                                              -ServerName $SecondaryServerName -DatabaseName $SecondaryDatabaseName `
                                                              -PartnerResourceGroupName $PrimaryResourceGrpName `
                                                              -Failover -ErrorAction Stop| Out-Null
       $ObjOut = "Failover Succes."
       Write-LogFile -FilePath $LogFilePath -LogText $ObjOut 
       $PartnerServerName =  (Set-AzureRmSqlDatabaseSecondary  -ResourceGroupName $SecondaryResourceGrpName `
                                                               -ServerName $SecondaryServerName `
                                                               -DatabaseName $SecondaryDatabaseName `
                                                               -PartnerResourceGroupName $PrimaryResourceGrpName `
                                                               -ErrorAction Stop).PartnerServerName     
    }
    catch
    {
       $ObjOut = "failover failed.`n$($Error[0].Exception.Message)"
       Write-LogFile -FilePath $LogFilePath -LogText "$ObjOut`r`n<#BlobFileReadyForUpload#>"
       $output = (@{"Response" = [Array]$ObjOut; "Status" = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
       Write-Output $output
       exit
    } 

    # 4. Testing.   

    Try
    {
        ($temp = Get-AzureRmSqlDatabase -ResourceGroupName $SecondaryResourceGrpName `
                               -ServerName $SecondaryServerName `
                               -DatabaseName $SecondaryDatabaseName -ErrorAction Stop) |Out-Null
                      
        if(($temp.Status) -eq "Online")
        {
            $ObjOut = "Primary DataBase '$SecondaryDatabaseName' in '$SecondaryServerName' server is Online"
            Write-LogFile -FilePath $LogFilePath -LogText $ObjOut
            Try
            {
                ($temp=Get-AzureRmSqlDatabaseReplicationLink -ResourceGroupName $SecondaryResourceGrpName `
                                                             -ServerName $SecondaryServerName -DatabaseName $SecondaryDatabaseName `
                                                             -PartnerResourceGroupName $PrimaryResourceGrpName `
                                                             -PartnerServerName $PartnerServerName -ErrorAction Stop) |Out-Null
                If(($temp.Role) -eq "Primary")
                {
                    $ObjOut = "Failover Succcess. Testing Also completed.Everything is OK."
                    Write-LogFile -FilePath $LogFilePath -LogText $ObjOut
                    $output = (@{"Response" = [Array]$ObjOut; "Status" = "Success"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")                    
                    Write-Host $output
                    Exit                    
                }
                else
                {
                    $ObjOut = "Failover successful, but testing failed.Failover DB not showing as Primary"
                    Write-LogFile -FilePath $LogFilePath -LogText "$ObjOut`r`n<#BlobFileReadyForUpload#>"
                    $output = (@{"Response" = [Array]$ObjOut; "Status" = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")                    
                    Write-Host $output
                    Exit   
                }
            }
            catch
            {
                $ObjOut = "Failover successful, but testing Failed. Unable to Get replicaiton link`n$($Error[0].Exception.Message)"
                Write-LogFile -FilePath $LogFilePath -LogText "$ObjOut`r`n<#BlobFileReadyForUpload#>"
                $output = (@{"Response" = [Array]$ObjOut; "Status" = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                write-host $output
                Exit
            }
        }
        else
        {
            $ObjOut = "Failover successful, but testing Failed. DB not showing as online"
            Write-LogFile -FilePath $LogFilePath -LogText "$ObjOut`r`n<#BlobFileReadyForUpload#>"
            $output = (@{"Response" = [Array]$ObjOut; "Status" = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
            write-host $output
            Exit            
        }
    
    }
    catch
    {
        $ObjOut = "Failover successful, but testing failed. Unable to get the DB.`n$($Error[0].Exception.Message)"
        Write-LogFile -FilePath $LogFilePath -LogText "$ObjOut`r`n<#BlobFileReadyForUpload#>" 
        $output = (@{"Response" = [Array]$ObjOut; "Status" = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")                   
        Write-Host $output
        Exit
    }
  
}
End
{
    Write-LogFile -FilePath $LogFilePath -LogText "####[ Script execution completed cuccessfully: $($MyInvocation.MyCommand.Name) ]####`r`n<#BlobFileReadyForUpload#>"
}