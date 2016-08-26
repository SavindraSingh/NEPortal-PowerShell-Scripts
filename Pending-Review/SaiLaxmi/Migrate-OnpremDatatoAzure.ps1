<#
    .SYNOPSIS.
    Script to Migrate On-premise Data to Azure Storage Container.

    .DESCRIPTION
    Script to Migrate On-premise Data to Azure Storage Container.

    .PARAMETER ClientID
    ClientID of the client for whom the script is being executed.

    .PARAMETER AzureUserName
    User name for Azure login. This should be an Organizational account (not Hotmail/Outlook account)

    .PARAMETER AzurePassword
    Password for Azure user account.

    .PARAMETER AzureSubscriptionID
    Azure Subscription ID to use for this activity.

    .PARAMETER StorageAccountName
    Name of the Classic Azure Storage Account to use for this command.

    .PARAMETER Container
    Name of the Classic Azure Storage Container to use for this command.

    .PARAMETER SourcePath
    Give On-premise Data Folder Path.


    .INPUTS
     .\Migrate-OnpremDatatoAzure.ps1 -ClientID 1246 -AzureUserName sailakshmi.penta@netenrich.com -AzurePassword **********
    -AzureSubscriptionID ca68598c-ecc3-4abc-b7a2-1ecef33f278d -StorageAccountName automationsa -ContainerName datastore 
    -SourcePath C:\Users\sailakshmi.penta\Desktop\AD 

    .OUTPUTS
     
    WARNING: GeoReplicationEnabled property will be deprecated in a future release of Azure PowerShell. The value will be merged 
    into the AccountType property.
    {
        "Status":  "Success",
        "BlobURI":  "https://nelogfiles.blob.core.windows.net/neportallogs/1246-Migrate-OnpremDatatoAzure-25-Aug-2016_130827.log"
    ,
        "Response":  [
                         "Successfully Migrated On-premises Data to Azure."
                     ]
    }
    

    .NOTES
     Purpose of script: Template for Azure Script to Migrate On-premise Data to Azure Storage Container
     Minimum requirements: Azure PowerShell Version 1.4.0
     Initially written by: Shankar
     Update/revision History:
     =======================
     Updated by        Date            Reason
     ==========        ====            ======
     Shankar           14-05-2016      Hackthon
     PSLPrasanna       24-08-2016      Change the script according to new Azure Template 

    .EXAMPLE

    .\Migrate-OnpremDatatoAzure.ps1 -ClientID 1246 -AzureUserName sailakshmi.penta@netenrich.com -AzurePassword **********
    -AzureSubscriptionID ca68598c-ecc3-4abc-b7a2-1ecef33f278d -StorageAccountName automationsa -ContainerName datastore 
    -SourcePath C:\Users\sailakshmi.penta\Desktop\AD 

    WARNING: GeoReplicationEnabled property will be deprecated in a future release of Azure PowerShell. The value will be merged 
    into the AccountType property.
    {
        "Status":  "Success",
        "BlobURI":  "https://nelogfiles.blob.core.windows.net/neportallogs/1246-Migrate-OnpremDatatoAzure-25-Aug-2016_130827.log"
    ,
        "Response":  [
                         "Successfully Migrated On-premises Data to Azure."
                     ]
    }
    
    
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
    [String]$StorageAccountName,

    [Parameter(ValueFromPipelineByPropertyName)]
    [String]$ContainerName,

    [Parameter(ValueFromPipelineByPropertyName)]
    [String]$SourcePath
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

            # Validate parameter: StorageAccountName
            Write-LogFile -FilePath $LogFilePath -LogText "Validating Parameters: StorageAccountName. Only ERRORs will be logged."
            If([String]::IsNullOrEmpty($StorageAccountName))
            {
                Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. StorageAccountName parameter value is empty.`r`n<#BlobFileReadyForUpload#>"
                $ObjOut = "Validation failed. StorageAccountName parameter value is empty."
                $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                Write-Output $output
                Exit
            }
            
            # Validate parameter: ContainerName
            Write-LogFile -FilePath $LogFilePath -LogText "Validating Parameters: ContainerName. Only ERRORs will be logged."
            If([String]::IsNullOrEmpty($ContainerName))
            {
                Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. ContainerName parameter value is empty.`r`n<#BlobFileReadyForUpload#>"
                $ObjOut = "Validation failed. ContainerName parameter value is empty."
                $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                Write-Output $output
                Exit
            }   
            
            # Validate parameter: SourcePath
            Write-LogFile -FilePath $LogFilePath -LogText "Validating Parameters: SourcePath. Only ERRORs will be logged."
            If([String]::IsNullOrEmpty($SourcePath))
            {
                Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. SourcePath parameter value is empty.`r`n<#BlobFileReadyForUpload#>"
                $ObjOut = "Validation failed. SourcePath parameter value is empty."
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

    # 2. Checking the existance of the Storage Account.
    Try
    {
        Write-LogFile -FilePath $LogFilePath -LogText "Trying to check the existance of the Storage Account"
        $sa = Get-AzureStorageAccount -StorageAccountName $StorageAccountName -ErrorAction Stop
        Write-LogFile -FilePath $LogFilePath -LogText "Storage Account does exists."
    }
    Catch
    {
        $ObjOut = "Error while getting Azure Storage Account Details.`n$($Error[0].Exception.Message)`r`n<#BlobFileReadyForUpload#>"
        Write-LogFile -FilePath $LogFilePath -LogText $ObjOut
        $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
        Write-Output $output
        Exit
    }

    # 3. Get the Primary key of the Storage Account
    Try
    {
        Write-LogFile -FilePath $LogFilePath -LogText "Trying to get the Storage Account Primary key"
        $Pkey = (Get-AzureStorageKey -StorageAccountName $StorageAccountName -ErrorAction Stop).Primary 
        Write-LogFile -FilePath $LogFilePath -LogText "Got the Storage Account Primary key" 
    }
    Catch
    {
        $ObjOut = "Error while getting Azure Storage Account Primary key.`n$($Error[0].Exception.Message)`r`n<#BlobFileReadyForUpload#>"
        Write-LogFile -FilePath $LogFilePath -LogText $ObjOut
        $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
        Write-Output $output
        Exit
    }
    
    # 4. Get the Azure Storage Account Container Details
    Try
    {
       Write-LogFile -FilePath $LogFilePath -LogText "Trying to create Azure Storage Context"
       $context = New-AzureStorageContext $StorageAccountName -StorageAccountKey $Pkey -ErrorAction Stop
       Write-LogFile -FilePath $LogFilePath -LogText "Created Azure Storage Context"
       Try
       {
          Write-LogFile -FilePath $LogFilePath -LogText "Trying to get Azure Storage Container Details"
          $container = Get-AzureStorageContainer -Context $context -Name $ContainerName -ErrorAction Stop
          Write-LogFile -FilePath $LogFilePath -LogText "Got the Azure Storage Container Details."
       }
       Catch
       {
          $ObjOut = "Error while getting Azure Storage Container Details.`n$($Error[0].Exception.Message)`r`n<#BlobFileReadyForUpload#>"
          Write-LogFile -FilePath $LogFilePath -LogText $ObjOut
          $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
          Write-Output $output
          Exit
       }
    }
    Catch
    {
        $ObjOut = "Error while creating Azure Storage Context.`n$($Error[0].Exception.Message)`r`n<#BlobFileReadyForUpload#>"
        Write-LogFile -FilePath $LogFilePath -LogText $ObjOut
        $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
        Write-Output $output
        Exit
    }

    # 5. Migrate Onpremise Data to Azure
    Try
    {
        $uri = $context.BlobEndPoint
        $uri = $uri+$ContainerName+"/"
        cd $SourcePath
        Write-LogFile -FilePath $LogFilePath -LogText "Trying to Migrate On-premise Data to Azure"
        (ls -File -Recurse | Set-AzureStorageBlobContent -Container datastore -Context $context -ErrorAction Stop) | Out-Null
        $ObjOut = "Successfully Migrated On-premises Data to Azure."
        Write-LogFile -FilePath $LogFilePath -LogText $ObjOut
        $output = (@{"Response" = [Array]$ObjOut; Status = "Success"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
        Write-Output $output
    }
    Catch
    {
        $ObjOut = "Error while Migrating Onpremise Data to Azure.`n$($Error[0].Exception.Message)`r`n<#BlobFileReadyForUpload#>"
        Write-LogFile -FilePath $LogFilePath -LogText $ObjOut
        $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
        Write-Output $output
        Exit
    }
}

End
{
    Write-LogFile -FilePath $LogFilePath -LogText "####[ Script execution completed cuccessfully: $($MyInvocation.MyCommand.Name) ]####`r`n<#BlobFileReadyForUpload#>"
}