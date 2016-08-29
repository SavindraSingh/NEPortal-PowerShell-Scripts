<#
    .SYNOPSIS
    Script to create Azure Web App and Redis Cache.

    .DESCRIPTION
    Script to create Azure Web App and Redis Cache.

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
    Name of the Azure Web App.

    .PARAMETER RedisCacheName
    Name of the Azure Redis Cache 

    .PARAMETER RedisCacheSkuName
    Choose one of the Azure Redis Cache Sku Names.

    .PARAMETER RedisCacheSize
    Choose one of the Azure Redis Cache Sizes .

   
    .INPUTS
    .\Create-AzureWebAppandStorageAccount.ps1 -ClientID 1246 -AzureUserName sailakshmi.penta@netenrich.com 
    -AzurePassword ********* -AzureSubscriptionID ca68598c-ecc3-4abc-b7a2-1ecef33f278d -Location "East US 2" 
    -ResourceGroupName "testrg" -AppServicePlanName "sampleappplan" -WebAppName "testsampleapp1257" 
    -StorageAccountName "testsamplesa12" -StorageSkuName "Standard_LRS" -StorageKind "Storage"

    .OUTPUTS
     WARNING: The output object type of this cmdlet will be modified in a future release.
    {
        "Status":  "Success",
        "BlobURI":  "https://nelogfiles.blob.core.windows.net/neportallogs/1246-Create-AzureWebAppandStorageAccount-26-Aug-2016_112619.log",
        "Response":  [
                         "Successfully created WebApp 'testsampleapp1257' and Storage account 'testsamplesa12'.\r\n\u003c#BlobFileRea
    dyForUpload#\u003e"
                     ]
    }

    .NOTES
     Purpose of script: Template for Azure Scripts to create Azure Web App and Redis Cache
     Minimum requirements: Azure PowerShell Version 1.4.0
     Initially written by: Pavan Konduri
     Update/revision History:
     =======================
     Updated by        Date            Reason
     ==========        ====            ======
     Pavan Konduri     14-05-2016      Hackthon
     PSLPrasanna       26-08-2016      Change the script according to new Azure Template

    .EXAMPLE
    .\Create-AzureWebAppandRedisCache.ps1 -ClientID 1245 -AzureUserName sailakshmi.penta@netenrich.com 
    -AzurePassword ******** -AzureSubscriptionID ca68598c-ecc3-4abc-b7a2-1ecef33f278d -Location "East US 2" 
    -ResourceGroupName samplerg123test -AppServicePlanName sampleplan1245 -WebAppName testapp1246 
    -RedisCacheName samplecachetest1245 -RedisCacheSkuName Basic -RedisCacheSize C0

    WARNING: The output object type of this cmdlet will be modified in a future release.
    {
        "Status":  "Success",
        "BlobURI":  "https://nelogfiles.blob.core.windows.net/neportallogs/1245-Create-AzureWebAppandRedisCache-29-Aug-2016_122128.lo
    g",
        "Response":  [
                         "Sucessfully created WebApp 'testapp1246' and Azure Redis Cache 'samplecachetest1245'.\r\n\u003c#BlobFileRea
    dyForUpload#\u003e"
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
    [string]$RedisCacheName,

    [Parameter(ValueFromPipelineByPropertyName)]
    [string]$RedisCacheSkuName,

    [Parameter(ValueFromPipelineByPropertyName)]
    [string]$RedisCacheSize

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

            # Validate parameter: RedisCacheName
            Write-LogFile -FilePath $LogFilePath -LogText "Validating Parameters: RedisCacheName. Only ERRORs will be logged."
            If([String]::IsNullOrEmpty($RedisCacheName))
            {
                Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. RedisCacheName parameter value is empty.`r`n<#BlobFileReadyForUpload#>"
                $ObjOut = "Validation failed. RedisCacheName parameter value is empty."
                $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                Write-Output $output
                Exit
            }

            # Validate parameter: RedisCacheSkuName
            Write-LogFile -FilePath $LogFilePath -LogText "Validating Parameters: RedisCacheSkuName. Only ERRORs will be logged."
            If([String]::IsNullOrEmpty($RedisCacheSkuName))
            {
                Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. RedisCacheSkuName parameter value is empty.`r`n<#BlobFileReadyForUpload#>"
                $ObjOut = "Validation failed. RedisCacheSkuName parameter value is empty."
                $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                Write-Output $output
                Exit
            }

            If($RedisCacheSkuName.Length -ne 0){
                 Write-LogFile -FilePath $LogFilePath -LogText "Validating Parameters: StorageSkuName. Only ERRORs will be logged."
                 $arr = "Premium","Standard","Basic"
                 If($arr -notcontains $RedisCacheSkuName){
                    Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. PerformanceTear '$RedisCacheSkuName' is NOT a valid value for this parameter.`r`n<#BlobFileReadyForUpload#>"
                    $ObjOut = "Validation failed. PerformanceTear '$RedisCacheSkuName' is not a valid value for this parameter."
                    $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                    Write-Output $output
                    Exit
                 }                
            }

            # Validate parameter: RedisCacheSize
            Write-LogFile -FilePath $LogFilePath -LogText "Validating Parameters: RedisCacheSize. Only ERRORs will be logged."
            If([String]::IsNullOrEmpty($RedisCacheSize))
            {
                Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. RedisCacheSize parameter value is empty.`r`n<#BlobFileReadyForUpload#>"
                $ObjOut = "Validation failed. RedisCacheSize parameter value is empty."
                $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                Write-Output $output
                Exit
            }

            If($RedisCacheSize.Length -ne 0){
                 Write-LogFile -FilePath $LogFilePath -LogText "Validating Parameters: RedisCacheSize. Only ERRORs will be logged."
                 If($RedisCacheSkuName -eq "Premium"){
                    $arr = "P1","P2","P3","P4","6GB","13GB","26GB","53GB"
                    If($arr -notcontains $RedisCacheSize){
                       Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. PerformanceTear '$RedisCacheSize' is NOT a valid value for this parameter.`r`n<#BlobFileReadyForUpload#>"
                       $ObjOut = "Validation failed. PerformanceTear '$RedisCacheSize' is not a valid value for this parameter."
                       $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                       Write-Output $output
                       Exit
                    }    
                 }
                 Else{
                    $arr = "C0","C1","C2","C3","C4","C5","C6","250MB","1GB","2.5GB","6GB","13GB","26GB","53GB"
                    If($arr -notcontains $RedisCacheSize){
                       Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. PerformanceTear '$RedisCacheSize' is NOT a valid value for this parameter.`r`n<#BlobFileReadyForUpload#>"
                       $ObjOut = "Validation failed. PerformanceTear '$RedisCacheSize' is not a valid value for this parameter."
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
    $savalue = 0
    $rcvalue = 0
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
               $wavalue = 1
               $ObjOut = "Successfully Created Azure Web App '$WebAppName'."
               Write-LogFile -FilePath $LogFilePath -LogText "$ObjOut"      
               $value         
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
        If($alertcheck1 -eq $null){
            Write-LogFile -FilePath $LogFilePath -LogText "Trying to Add Alert Rule '$Name'."
            $addalert = Add-AzureRmMetricAlertRule -Name $Name -MetricName "Http5xx" -Operator GreaterThan -Threshold "0" -WindowSize 00:05:00  -ResourceGroup $ResourceGroupName -TargetResourceId $WACheck.Id -TimeAggre Total -Location $Location -ErrorAction Stop
            Write-LogFile -FilePath $LogFilePath -LogText "Successfully Added Alert Rule '$Name'."
        }
        $Name = "ForbiddenRequests"+$WebAppName
        $alertcheck1 = Check-Alert -Name $Name
        If($alertcheck1 -eq $null){
            Write-LogFile -FilePath $LogFilePath -LogText "Trying to Add Alert Rule '$Name'."
            $addalert = Add-AzureRmMetricAlertRule -Name $Name -MetricName "Http403" -Operator GreaterThan -Threshold "0" -WindowSize 00:05:00 -ResourceGroup $ResourceGroupName -TargetResourceId $WACheck.Id -TimeAggre Total -Location $Location -ErrorAction Stop
            Write-LogFile -FilePath $LogFilePath -LogText "Successfully Added Alert Rule '$Name'."
        }
        $Name = "CPUHighUtil"+$AppServicePlanName
        $alertcheck1 = Check-Alert -Name $Name
        If($alertcheck1 -eq $null){
            Write-LogFile -FilePath $LogFilePath -LogText "Trying to Add Alert Rule '$Name'."
            $addalert = Add-AzureRmMetricAlertRule -Name $Name -MetricName "CpuPercentage" -Operator GreaterThan -Threshold "90" -WindowSize 00:15:00 -ResourceGroup $ResourceGroupName -TargetResourceId $ASPCheck.Id -TimeAggre Total -Location $Location -ErrorAction Stop
            Write-LogFile -FilePath $LogFilePath -LogText "Successfully Added Alert Rule '$Name'."
        }
        $Name = "HttpQueueLength"+$AppServicePlanName
        $alertcheck1 = Check-Alert -Name $Name
        If($alertcheck1 -eq $null){
            Write-LogFile -FilePath $LogFilePath -LogText "Trying to Add Alert Rule '$Name'."
            $addalert = Add-AzureRmMetricAlertRule -Name $Name -MetricName "HttpQueueLength" -Operator GreaterThan -Threshold "100" -WindowSize 00:05:00 -ResourceGroup $ResourceGroupName -TargetResourceId $ASPCheck.Id -TimeAggre Total -Location $Location -ErrorAction Stop
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

    # 6. Create Azure Redis Cache
    Try
    {
        $RCCheck = $null
        Write-LogFile -FilePath $LogFilePath -LogText "Checking the existance of the Redis Cache '$RedisCacheName'."
        $RCCheck = Get-AzureRmRedisCache -Name $RedisCacheName -ResourceGroupName $ResourceGroupName -ErrorAction SilentlyContinue
        If($RCCheck -ne $null){
            Write-LogFile -FilePath $LogFilePath -LogText "Redis Cache '$RedisCacheName' does exists."
        }
        Else{
            Try{
                Write-LogFile -FilePath $LogFilePath -LogText "Redis Cache '$RedisCacheName' does not exists.Creating Redis Cache."
                $RCCheck = New-AzureRmRedisCache -Name $RedisCacheName -ResourceGroupName $ResourceGroupName -Location $Location -Size $RedisCacheSize -Sku $RedisCacheSkuName -ErrorAction Stop
                Write-LogFile -FilePath $LogFilePath -LogText "Successfully created Redis Cache '$RedisCacheName'"
                $rcvalue = 1
            }
            Catch{
                $ObjOut = "Error while creating Azure Redis Cache.`r`n$($Error[0].Exception.Message)`r`n<#BlobFileReadyForUpload#>"
                $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                Write-Output $output
                Write-LogFile -FilePath $LogFilePath -LogText $ObjOut
                Exit
            }
        }

        If($wavalue -eq 0 -and $rcvalue -eq 0){
            $ObjOut = "WebApp '$WebAppName' and Storage account '$RedisCacheName' already exists.`r`n<#BlobFileReadyForUpload#>"
        } 
        Elseif($wavalue -eq 0 -and $rcvalue -eq 1){
            $ObjOut = "WebApp '$WebAppName' already exists. Sucessfully created Azure Redis Cache '$RedisCacheName'.`r`n<#BlobFileReadyForUpload#>"
        }
        Elseif($wavalue -eq 1 -and $rcvalue -eq 0){
            $ObjOut = "Azure Redis Cache '$RedisCacheName' already exists. Sucessfully created WebApp '$WebAppName'.`r`n<#BlobFileReadyForUpload#>"
        }
        Else{
            $ObjOut = "Sucessfully created WebApp '$WebAppName' and Azure Redis Cache '$RedisCacheName'.`r`n<#BlobFileReadyForUpload#>"
        }
        $output = (@{"Response" = [Array]$ObjOut; Status = "Success"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
        Write-Output $output
        Write-LogFile -FilePath $LogFilePath -LogText $ObjOut 
    }
    Catch
    {
        $ObjOut = "Error while getting Azure Redis Cache Details.`r`n$($Error[0].Exception.Message)`r`n<#BlobFileReadyForUpload#>"
        $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
        Write-Output $output
        Write-LogFile -FilePath $LogFilePath -LogText $ObjOut
        Exit
    }
}

End
{
    Write-LogFile -FilePath $LogFilePath -LogText "####[ Script execution completed cuccessfully: $($MyInvocation.MyCommand.Name) ]####`r`n<#BlobFileReadyForUpload#>"
}