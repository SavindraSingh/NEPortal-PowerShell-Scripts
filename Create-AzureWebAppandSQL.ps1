<#
    .SYNOPSIS
    Script to create Azure ARM Web App Sql Server and Sql Database.

    .DESCRIPTION
    Script to create Azure ARM Web App Sql Server and Sql Database.

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

    .PARAMETER ResourceGroupName
    Name of the Azure ARM resource group to use for this command.

    .PARAMETER AppServicePlanName
    Name of the Azure AppServicePlan for this WebApp.

    .PARAMETER WebAppName
    Name of the Azure Web App to use for this command.

    .PARAMETER SqlServerName
    Name of the Azure ARM Sql Server to use for this command

    .PARAMETER SqlAdminUsername
    Give the Sql Administrator Username

    .PARAMETER SqlAdminPassword
    Give the Sql Administrator Password.

    .PARAMETER SqlServerVersion
    Give the Sql Server Version.

    .PARAMETER SqlStartIPAddress
    Give the IP Address Range Starting Address for Sql Server Firewall Rule

    .PARAMETER SqlStartIPAddress
    Give the IP Address Range Ending Address for Sql Server Firewall Rule

    .PARAMETER SqlDatabaseName
    Name of the Azure ARM Sql Server Database to use for this command

    .PARAMETER SqlDatabaseEdition
    Choose one of the Sql Database Editons.

    .PARAMETER SqlDatabaseEditionTier
    Give value for RequestedServiceObjectiveName. 


    .INPUTS
    .\Create-AzureWebAppandSQL.ps1 -ClientID 1234 -AzureUserName sailakshmi.penta@netenrich.com -AzurePassword *********
     -AzureSubscriptionID ca68598c-ecc3-4abc-b7a2-1ecef33f278d -Location "East US 2" -ResourceGroupName "samplerg123test" 
     -AppServicePlanName "sampleplan1245" -WebAppName "testapp1256" -SqlServerName "sampleerver123" 
     -SqlAdminUsername "useradmin" -SqlAdminPassword "Pass@123" -SqlServerVersion "2.0" 
     -SqlStartIPAddress "10.10.10.4" -SqlEndIPAddress "10.10.10.16" -SqlDatabaseName "sampledb1245" -SqlDatabaseEdition Basic
    

    .OUTPUTS
    WARNING: The output object type of this cmdlet will be modified in a future release.
     {
         "Status":  "Success",
         "BlobURI":  "https://nelogfiles.blob.core.windows.net/neportallogs/1234-Create-AzureWebAppandSQL-26-Aug-2016_162418.log",
         "Response":  [
                          "Successfully created WebApp 'testapp1256',Sql Server 'sampleerver123' and Sql Database 'sampledb1245'\r\n\u
     003c#BlobFileReadyForUpload#\u003e"
                      ]
     }

    .NOTES
     Purpose of script: Template for Azure Scripts
     Minimum requirements: Azure PowerShell Version 1.4.0
     Initially written by: P S L Prasanna
     Update/revision History:
     =======================
     Updated by        Date            Reason
     ==========        ====            ======
     Pavan Konduri     14-05-2016      Hackthon
     PSLPrasanna       26-08-2016      Change the script according to new Azure Template

    .EXAMPLE
    .\Create-AzureWebAppandSQL.ps1 -ClientID 1234 -AzureUserName sailakshmi.penta@netenrich.com -AzurePassword *********
     -AzureSubscriptionID ca68598c-ecc3-4abc-b7a2-1ecef33f278d -Location "East US 2" -ResourceGroupName "samplerg123test" 
     -AppServicePlanName "sampleplan1245" -WebAppName "testapp1256" -SqlServerName "sampleerver123" 
     -SqlAdminUsername "useradmin" -SqlAdminPassword "Pass@123" -SqlServerVersion "2.0" 
     -SqlStartIPAddress "10.10.10.4" -SqlEndIPAddress "10.10.10.16" -SqlDatabaseName "sampledb1245" -SqlDatabaseEdition Basic
    
     WARNING: The output object type of this cmdlet will be modified in a future release.
     {
         "Status":  "Success",
         "BlobURI":  "https://nelogfiles.blob.core.windows.net/neportallogs/1234-Create-AzureWebAppandSQL-26-Aug-2016_162418.log",
         "Response":  [
                          "Successfully created WebApp 'testapp1256',Sql Server 'sampleerver123' and Sql Database 'sampledb1245'\r\n\u
     003c#BlobFileReadyForUpload#\u003e"
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
    [string]$Location,

    [Parameter(ValueFromPipelineByPropertyName)]
    [String]$ResourceGroupName,
    
    [Parameter(ValueFromPipelineByPropertyName)]
    [string]$AppServicePlanName,

    [Parameter(ValueFromPipelineByPropertyName)]
    [string]$WebAppName,

    [Parameter(ValueFromPipelineByPropertyName)]
    [string]$SqlServerName,

    [Parameter(ValueFromPipelineByPropertyName)]
    [string]$SqlAdminUsername,

    [Parameter(ValueFromPipelineByPropertyName)]
    [string]$SqlAdminPassword,

    [Parameter(ValueFromPipelineByPropertyName)]
    [string]$SqlServerVersion,

    [Parameter(ValueFromPipelineByPropertyName)]
    [string]$SqlStartIPAddress,

    [Parameter(ValueFromPipelineByPropertyName)]
    [string]$SqlEndIPAddress,

    [Parameter(ValueFromPipelineByPropertyName)]
    [string]$SqlDatabaseName,

    [Parameter(ValueFromPipelineByPropertyName)]
    [string]$SqlDatabaseEdition,

    [Parameter(ValueFromPipelineByPropertyName)]
    [string]$SqlDatabaseEditionTier

    # Add other parameters as required
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

            # Validate parameter: AppServicePlanName
            Write-LogFile -FilePath $LogFilePath -LogText "Validating Parameters: AppServicePlanName. Only ERRORs will be logged."
            If([String]::IsNullOrEmpty($AppServicePlanName))
            {
                Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. AppServicePlanName parameter value is empty.`r`n<#BlobFileReadyForUpload#>"
                $ObjOut = "Validation failed. AppServicePlanName parameter value is empty."
                $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                Write-Output $output
                Exit
            }

            # Validate parameter: WebAppName
            Write-LogFile -FilePath $LogFilePath -LogText "Validating Parameters: WebAppName. Only ERRORs will be logged."
            If([String]::IsNullOrEmpty($WebAppName))
            {
                Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. WebAppName parameter value is empty.`r`n<#BlobFileReadyForUpload#>"
                $ObjOut = "Validation failed. WebAppName parameter value is empty."
                $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                Write-Output $output
                Exit
            }

            # Validate parameter: SqlServerName
            Write-LogFile -FilePath $LogFilePath -LogText "Validating Parameters: SqlServerName. Only ERRORs will be logged."
            If([String]::IsNullOrEmpty($SqlServerName))
            {
                Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. SqlServerName parameter value is empty.`r`n<#BlobFileReadyForUpload#>"
                $ObjOut = "Validation failed. SqlServerName parameter value is empty."
                $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                Write-Output $output
                Exit
            }

            # Validate parameter: SqlAdminUsername
            Write-LogFile -FilePath $LogFilePath -LogText "Validating Parameters: SqlAdminUsername. Only ERRORs will be logged."
            If([String]::IsNullOrEmpty($SqlAdminUsername))
            {
                Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. SqlAdminUsername parameter value is empty.`r`n<#BlobFileReadyForUpload#>"
                $ObjOut = "Validation failed. SqlAdminUsername parameter value is empty."
                $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                Write-Output $output
                Exit
            }

            If($SqlAdminUsername.Length -ne 0){
                 Write-LogFile -FilePath $LogFilePath -LogText "Validating Parameters: SqlAdminUsername. Only ERRORs will be logged."                 
                 If($SqlAdminUsername -eq "admin" -or $SqlAdminUsername -eq "Administrator"){
                    Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. PerformanceTear '$SqlAdminUsername' is NOT a valid value for this parameter.`r`n<#BlobFileReadyForUpload#>"
                    $ObjOut = "Validation failed. PerformanceTear '$SqlAdminUsername' is not a valid value for this parameter."
                    $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                    Write-Output $output
                    Exit
                 }
                 
            }

            # Validate parameter: SqlAdminPassword
            Write-LogFile -FilePath $LogFilePath -LogText "Validating Parameters: SqlAdminPassword. Only ERRORs will be logged."
            If([String]::IsNullOrEmpty($SqlAdminPassword))
            {
                Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. SqlAdminPassword parameter value is empty.`r`n<#BlobFileReadyForUpload#>"
                $ObjOut = "Validation failed. SqlAdminPassword parameter value is empty."
                $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                Write-Output $output
                Exit
            }

            # Validate parameter: SqlServerVersion
            Write-LogFile -FilePath $LogFilePath -LogText "Validating Parameters: SqlServerVersion. Only ERRORs will be logged."
            If([String]::IsNullOrEmpty($SqlServerVersion))
            {
                Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. SqlServerVersion parameter value is empty.`r`n<#BlobFileReadyForUpload#>"
                $ObjOut = "Validation failed. SqlServerVersion parameter value is empty."
                $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                Write-Output $output
                Exit
            }

            # Validate parameter: SqlStartIPAddress
            Write-LogFile -FilePath $LogFilePath -LogText "Validating Parameters: SqlStartIPAddress. Only ERRORs will be logged."
            If([String]::IsNullOrEmpty($SqlStartIPAddress))
            {
                Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. SqlStartIPAddress parameter value is empty.`r`n<#BlobFileReadyForUpload#>"
                $ObjOut = "Validation failed. SqlStartIPAddress parameter value is empty."
                $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                Write-Output $output
                Exit
            }

            # Validate parameter: SqlEndIPAddress
            Write-LogFile -FilePath $LogFilePath -LogText "Validating Parameters: SqlEndIPAddress. Only ERRORs will be logged."
            If([String]::IsNullOrEmpty($SqlEndIPAddress))
            {
                Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. SqlEndIPAddress parameter value is empty.`r`n<#BlobFileReadyForUpload#>"
                $ObjOut = "Validation failed. SqlEndIPAddress parameter value is empty."
                $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                Write-Output $output
                Exit
            }

            # Validate parameter: SqlDatabaseName
            Write-LogFile -FilePath $LogFilePath -LogText "Validating Parameters: SqlDatabaseName. Only ERRORs will be logged."
            If([String]::IsNullOrEmpty($SqlDatabaseName))
            {
                Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. SqlDatabaseName parameter value is empty.`r`n<#BlobFileReadyForUpload#>"
                $ObjOut = "Validation failed. SqlDatabaseName parameter value is empty."
                $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                Write-Output $output
                Exit
            }

            # Validate parameter: SqlDatabaseEdition
            Write-LogFile -FilePath $LogFilePath -LogText "Validating Parameters: SqlDatabaseEdition. Only ERRORs will be logged."
            If([String]::IsNullOrEmpty($SqlDatabaseEdition))
            {
                Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. SqlDatabaseEdition parameter value is empty.`r`n<#BlobFileReadyForUpload#>"
                $ObjOut = "Validation failed. SqlDatabaseEdition parameter value is empty."
                $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                Write-Output $output
                Exit
            }

            If($SqlDatabaseEdition.Length -ne 0){
                $arr = "Basic","Standard","Premium","Free","DataWarehouse"
                If($arr -notcontains $SqlDatabaseEdition){
                    Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. PerformanceTear '$SqlDatabaseEdition' is NOT a valid value for this parameter.`r`n<#BlobFileReadyForUpload#>"
                    $ObjOut = "Validation failed. PerformanceTear '$SqlDatabaseEdition' is not a valid value for this parameter."
                    $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                    Write-Output $output
                    Exit
                }
            }

            If($SqlDatabaseEdition -eq "Standard" -or $SqlDatabaseEdition -eq "Premium" -or $SqlDatabaseEdition -eq "DataWarehouse"){

                # Validate parameter: SqlDatabaseEditionTier
                Write-LogFile -FilePath $LogFilePath -LogText "Validating Parameters: SqlDatabaseEditionTier. Only ERRORs will be logged."
                If([String]::IsNullOrEmpty($SqlDatabaseEditionTier))
                {
                    Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. SqlDatabaseEditionTier parameter value is empty.`r`n<#BlobFileReadyForUpload#>"
                    $ObjOut = "Validation failed. SqlDatabaseEditionTier parameter value is empty."
                    $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                    Write-Output $output
                    Exit
                }

                If($SqlDatabaseEditionTier -eq "Standard"){
                    $arr = "S0","S1","S2","S3"
                    If($arr -notcontains $SqlDatabaseEditionTier){
                        Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. PerformanceTear '$SqlDatabaseEditionTier' is NOT a valid value for this parameter.`r`n<#BlobFileReadyForUpload#>"
                        $ObjOut = "Validation failed. PerformanceTear '$SqlDatabaseEditionTier' is not a valid value for this parameter."
                        $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                        Write-Output $output
                        Exit
                    }
                }

                If($SqlDatabaseEditionTier -eq "Premium"){
                    $arr = "P1","P2","P4","P6","P11","P15"
                    If($arr -notcontains $SqlDatabaseEditionTier){
                        Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. PerformanceTear '$SqlDatabaseEditionTier' is NOT a valid value for this parameter.`r`n<#BlobFileReadyForUpload#>"
                        $ObjOut = "Validation failed. PerformanceTear '$SqlDatabaseEditionTier' is not a valid value for this parameter."
                        $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                        Write-Output $output
                        Exit
                    }
                }

                If($SqlDatabaseEditionTier -eq "DataWarehouse"){
                    $arr = "DW100","DW200","DW300","DW400","DW500","DW600","DW1000","DW100","DW1200","DW1500","DW2000","DW3000","DW6000"
                    If($arr -notcontains $SqlDatabaseEditionTier){
                        Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. PerformanceTear '$SqlDatabaseEditionTier' is NOT a valid value for this parameter.`r`n<#BlobFileReadyForUpload#>"
                        $ObjOut = "Validation failed. PerformanceTear '$SqlDatabaseEditionTier' is not a valid value for this parameter."
                        $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                        Write-Output $output
                        Exit
                    }
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

    Function Check-Alert
    {
        Param([String]$Name)
        $alertcheck = $null
        $alertcheck = Get-AzureRmAlertRule -ResourceGroup $ResourceGroupName -Name $Name -ErrorAction SilentlyContinue
        return $alertcheck.Id
    }
}

Process
{
    Validate-AllParameters

    # 1. Login to Azure subscription
    Login-ToAzureAccount

    $avalue = 0
    $ssvalue = 0
    $sdvalue = 0
    # 2. Check if Resource Group exists. Create Resource Group if it does not exist.
    Try
    {
       Write-LogFile -FilePath $LogFilePath -LogText "Checking existance of resource group '$ResourceGroupName'"
        $ResourceGroup = $null
        ($ResourceGroup = Get-AzureRmResourceGroup -Name $ResourceGroupName -ErrorAction SilentlyContinue) | Out-Null
    
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
                $ObjOut = "Error while creating Azure Resource Group '$ResourceGroupName'.`r`n$($Error[0].Exception.Message)`r`n<#BlobFileReadyForUpload#>"
                $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                Write-Output $output
                Write-LogFile -FilePath $LogFilePath -LogText "$ObjOut"
                Exit
            }
        }
    }
    Catch
    {
        $ObjOut = "Error while getting Azure Resource Group details.`r`n$($Error[0].Exception.Message)`r`n<#BlobFileReadyForUpload#>"
        $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
        Write-Output $output
        Write-LogFile -FilePath $LogFilePath -LogText $ObjOut
        Exit
    }

    # 3. Check if AppServicePlan exists. Create Azure AppServicePlan if it does not exist.
    Try
    {
        
       Write-LogFile -FilePath $LogFilePath -LogText "Checking existance of AppServicePlan '$AppServicePlanName'"
        $ASPCheck = $null
        ($ASPCheck = Get-AzureRmAppServicePlan -Name $AppServicePlanName -ResourceGroupName $ResourceGroupName -ErrorAction SilentlyContinue) | Out-Null
        
        If($ASPCheck -ne $null) # AppServicePlan already exists
        {
           Write-LogFile -FilePath $LogFilePath -LogText "AppServicePlan already exists"
        }
        Else
        {
            Try
            {
               Write-LogFile -FilePath $LogFilePath -LogText "AppServicePlan '$AppServicePlanName' does not exist. Creating AppServicePlan."
               ($ASPCheck =  New-AzureRmAppServicePlan -ResourceGroupName $ResourceGroupName -Name $AppServicePlanName -Location $Location -ea SilentlyContinue) | Out-Null
               Write-LogFile -FilePath $LogFilePath -LogText "AppServicePlan '$AppServicePlanName' created"

            }
            Catch
            {
                $ObjOut = "Error while creating Azure AppServicePlan '$AppServicePlanName'.`r`n$($Error[0].Exception.Message)`r`n<#BlobFileReadyForUpload#>"
                $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                Write-Output $output
                Write-LogFile -FilePath $LogFilePath -LogText "$ObjOut"
                Exit
            }
        }
    }
    Catch
    {       
        $ObjOut = "Error while getting Azure AppServicePlan details.`r`n$($Error[0].Exception.Message)`r`n<#BlobFileReadyForUpload#>"
        $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
        Write-Output $output
        Write-LogFile -FilePath $LogFilePath -LogText $ObjOut
        Exit   
    }

    # 4. Check if WebApp exists. Create Azure WebApp if it does not exist.
    Try
    {
        Write-LogFile -FilePath $LogFilePath -LogText "Checking existance of Web App '$WebAppName'"
        $WACheck = $null
        ($WACheck = Get-AzureRmWebApp -ResourceGroupName $ResourceGroupName -Name $WebAppName -ea SilentlyContinue) | Out-Null
        If($WACheck -ne $null){
            Write-LogFile -FilePath $LogFilePath -LogText "WebApp '$WebAppName' already exists"            
        }
        Else
        {
            Try
            {
               Write-LogFile -FilePath $LogFilePath -LogText "WebApp '$WebAppName' does not exist. Creating WebApp."
               ($WACheck =New-AzureRmWebApp -ResourceGroupName $ResourceGroupName -Name $WebAppName -Location $Location -AppServicePlan $AppServicePlanName -ea Stop) | Out-Null              
               $avalue = 1
               $ObjOut = "Successfully Created Azure Web App '$WebAppName'."
               Write-LogFile -FilePath $LogFilePath -LogText "$ObjOut"              
            }
            Catch
            {
                $ObjOut = "Error while creating Azure WebApp '$WebAppName'.`r`n$($Error[0].Exception.Message)`r`n<#BlobFileReadyForUpload#>"
                $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                Write-Output $output
                Write-LogFile -FilePath $LogFilePath -LogText "$ObjOut"
                Exit
            }
        }
    }
    Catch
    {
        $ObjOut = "Error while getting Azure WebApp details.`r`n$($Error[0].Exception.Message)`r`n<#BlobFileReadyForUpload#>"
        $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
        Write-Output $output
        Write-LogFile -FilePath $LogFilePath -LogText $ObjOut
        Exit
    }

    # 5. Add Metric Alerts to Web App and Service Plan
    Try
    {        
        $Name = "ServerErrors"+$WebAppName        
        $alertcheck1 = Check-Alert -Name $Name
        If($alertcheck1 -ne $null){
            Write-LogFile -FilePath $LogFilePath -LogText "Trying to Add Alert Rule '$Name'."
            Add-AzureRmMetricAlertRule -Name $Name -MetricName "Http Server Errors" -Operator GreaterThan -Threshold "0" -WindowSize PT5M  -ResourceGroup $ResourceGroupName -TargetResourceId $WACheck.Id -ErrorAction Stop
            Write-LogFile -FilePath $LogFilePath -LogText "Successfully Added Alert Rule '$Name'."
        }
        $Name = "ForbiddenRequests"+$WebAppName
        $alertcheck1 = Check-Alert -Name $Name
        If($alertcheck1 -ne $null){
            Write-LogFile -FilePath $LogFilePath -LogText "Trying to Add Alert Rule '$Name'."
            Add-AzureRmMetricAlertRule -Name $Name -MetricName "Http403" -Operator GreaterThan -Threshold "0" -WindowSize PT5M -ResourceGroup $ResourceGroupName -TargetResourceId $WACheck.Id -ErrorAction Stop
            Write-LogFile -FilePath $LogFilePath -LogText "Successfully Added Alert Rule '$Name'."
        }
        $Name = "CPUHighUtil"+$AppServicePlanName
        $alertcheck1 = Check-Alert -Name $Name
        If($alertcheck1 -ne $null){
            Write-LogFile -FilePath $LogFilePath -LogText "Trying to Add Alert Rule '$Name'."
            Add-AzureRmMetricAlertRule -Name $Name -MetricName "CPU Percentage" -Operator GreaterThan -Threshold "90" -WindowSize PT15M -ResourceGroup $ResourceGroupName -TargetResourceId $ASPCheck.Id -ErrorAction Stop
            Write-LogFile -FilePath $LogFilePath -LogText "Successfully Added Alert Rule '$Name'."
        }
        $Name = "HttpQueueLength"+$AppServicePlanName
        $alertcheck1 = Check-Alert -Name $Name
        If($alertcheck1 -ne $null){
            Write-LogFile -FilePath $LogFilePath -LogText "Trying to Add Alert Rule '$Name'."
            Add-AzureRmMetricAlertRule -Name $Name -MetricName "Http Queue Length" -Operator GreaterThan -Threshold "100" -WindowSize PT5M -ResourceGroup $ResourceGroupName -TargetResourceId $ASPCheck.Id -ErrorAction Stop
            Write-LogFile -FilePath $LogFilePath -LogText "Successfully Added Alert Rule '$Name'."
        }
    }
    Catch
    {
        $ObjOut = "Error while Adding Metric rules to Azure WebApp and App Service Plan.`r`n$($Error[0].Exception.Message)`r`n<#BlobFileReadyForUpload#>"
        $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
        Write-Output $output
        Write-LogFile -FilePath $LogFilePath -LogText $ObjOut
        Exit
    }
    
    # 6. Create SQL Server
    Try
    {
        Write-LogFile -FilePath $LogFilePath -LogText "Checking the existance of the Sql Server '$SqlServerName'."
        $sqlcheck = $null
        $sqlcheck = Get-AzureRmSqlServer -ServerName $SqlServerName -ResourceGroupName $ResourceGroupName -ErrorAction SilentlyContinue
        If($sqlcheck -ne  $null)
        {
            Write-LogFile -FilePath $LogFilePath -LogText "Sql Server '$SqlServerName' does exists."
        }
        Else
        {
            Try
            {
                Write-LogFile -FilePath $LogFilePath -LogText "Sql Server '$SqlServerName' does not exists."
                $SqlSecurePassword = ConvertTo-SecureString -AsPlainText $SqlAdminPassword -Force
                $SqlCred = New-Object System.Management.Automation.PSCredential -ArgumentList $SqlAdminUsername, $SqlSecurePassword
                Write-LogFile -FilePath $LogFilePath -LogText "Trying to create Sql Server '$SqlServerName'."
                $sqlcheck = New-AzureRmSqlServer -ServerName $SqlServerName -SqlAdministratorCredentials $SqlCred -Location $Location -ServerVersion $SqlServerVersion -ResourceGroupName $ResourceGroupName -ErrorAction Stop 
                Write-LogFile -FilePath $LogFilePath -LogText "Successfully created Sql Server '$SqlServerName'."
                Try
                {
                    Write-LogFile -FilePath $LogFilePath -LogText "Trying to create Sql Firewall Rule for Sql Server '$SqlServerName'."
                    $fwrulename = $SqlServerName+"Firewallrule"
                    $sqlfwrule = New-AzureRmSqlServerFirewallRule -FirewallRuleName "$fwrulename" -StartIpAddress $SqlStartIPAddress -EndIpAddress $SqlEndIPAddress -ServerName $SqlServerName -ResourceGroupName $ResourceGroupName -ErrorAction Stop
                    Write-LogFile -FilePath $LogFilePath -LogText "Successfully created Sql Firewall Rule for Sql Server '$SqlServerName'."
                }
                Catch
                {
                    $ObjOut = "Error while creating Firewall Rule for sql Server.`r`n$($Error[0].Exception.Message)`r`n<#BlobFileReadyForUpload#>"
                    $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                    Write-Output $output
                    Write-LogFile -FilePath $LogFilePath -LogText $ObjOut
                    Exit
                }
            }
            Catch
            {
                $ObjOut = "Error while creating sql Server.`r`n$($Error[0].Exception.Message)`r`n<#BlobFileReadyForUpload#>"
                $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                Write-Output $output
                Write-LogFile -FilePath $LogFilePath -LogText $ObjOut
                Exit            
            }
            $ssvalue = 1
        }
    }
    Catch
    {
        $ObjOut = "Error while getting sql Server Details.`r`n$($Error[0].Exception.Message)`r`n<#BlobFileReadyForUpload#>"
        $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
        Write-Output $output
        Write-LogFile -FilePath $LogFilePath -LogText $ObjOut
        Exit
    }

    # 7. Create SQL Database
    Try
    {
       Write-LogFile -FilePath $LogFilePath -LogText "Checking the existance of the Sql Database '$SqlDatabaseName'."
       $sqldbcheck = $null
       $sqldbcheck = Get-AzureRmSqlDatabase -DatabaseName $SqlDatabaseName -ServerName $SqlServerName -ResourceGroupName $ResourceGroupName -ErrorAction SilentlyContinue
       If($sqldbcheck -ne $null){
            Write-LogFile -FilePath $LogFilePath -LogText "Sql Database '$SqlDatabaseName' does exists."
       }
       Else{
            Try
            {
                If($SqlDatabaseEdition -eq "Basic" -or $SqlDatabaseEdition -eq "Free")
                {
                    Write-LogFile -FilePath $LogFilePath -LogText "Trying to create Sql Database '$SqlDatabaseName'." 
                    $sqldbcheck = New-AzureRmSqlDatabase -DatabaseName $SqlDatabaseName -ServerName $SqlServerName -ResourceGroupName $ResourceGroupName -CollationName "SQL_Latin1_General_CP1_CI_AS" -Edition $SqlDatabaseEdition -ErrorAction Stop
                    Write-LogFile -FilePath $LogFilePath -LogText "Successfully created Sql Database '$SqlDatabaseName'." 
                }
                Else
                {
                    Write-LogFile -FilePath $LogFilePath -LogText "Trying to create Sql Database '$SqlDatabaseName'." 
                    $sqldbcheck = New-AzureRmSqlDatabase -DatabaseName $SqlDatabaseName -ServerName $SqlServerName -ResourceGroupName $ResourceGroupName -CollationName "SQL_Latin1_General_CP1_CI_AS" -Edition $SqlDatabaseEdition -RequestedServiceObjectiveName $SqlDatabaseEditionTier -ErrorAction Stop
                    Write-LogFile -FilePath $LogFilePath -LogText "Successfully created Sql Database '$SqlDatabaseName'."
                }
            }
            Catch{
                $ObjOut = "Error while creating sql database.`r`n$($Error[0].Exception.Message)`r`n<#BlobFileReadyForUpload#>"
                $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                Write-Output $output
                Write-LogFile -FilePath $LogFilePath -LogText $ObjOut
                Exit
            }
       }
       $sdcheck = 1
       
    }
    Catch
    {
        $ObjOut = "Error while getting sql Database Details.`r`n$($Error[0].Exception.Message)`r`n<#BlobFileReadyForUpload#>"
        $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
        Write-Output $output
        Write-LogFile -FilePath $LogFilePath -LogText $ObjOut
        Exit
    }

    If($avalue -eq 1 -and $ssvalue -eq 1 -and $sdvalue -eq 1){
        $ObjOut = "Successfully created WebApp '$WebAppName',Sql Server '$SqlServerName' and Sql Database '$SqlDatabaseName'`r`n<#BlobFileReadyForUpload#>"
    }
    Elseif($avalue -eq 0 -and $ssvalue -eq 0 -and $sdvalue -eq 0){
        $ObjOut = "WebApp '$WebAppName',Sql Server '$SqlServerName' and Sql Database '$SqlDatabaseName' already exists`r`n<#BlobFileReadyForUpload#>"
    }
    Elseif($avalue -eq 0 -and $ssvalue -eq 1 -and $sdvalue -eq 1){
        $ObjOut = "Successfully created Sql Server '$SqlServerName' and Sql Database '$SqlDatabaseName'.WebApp '$WebAppName' already exists.`r`n<#BlobFileReadyForUpload#>"
    }
    Else{
        $ObjOut = "Successfully created WebApp '$WebAppName'.Sql Server '$SqlServerName' and Sql Database '$SqlDatabaseName' already exists.`r`n<#BlobFileReadyForUpload#>"
    }
    $output = (@{"Response" = [Array]$ObjOut; Status = "Success"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
    Write-Output $output
    Write-LogFile -FilePath $LogFilePath -LogText $ObjOut
}

End
{
    Write-LogFile -FilePath $LogFilePath -LogText "####[ Script execution completed cuccessfully: $($MyInvocation.MyCommand.Name) ]####`r`n<#BlobFileReadyForUpload#>"
}

