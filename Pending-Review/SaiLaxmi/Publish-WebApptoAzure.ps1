<#
    .SYNOPSIS
    Script to Publish on-premise Web App to Azure.

    .DESCRIPTION
    Script to Publish on-premise Web App to Azure.

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
    Name of the Azure AppServicePlan for this WebApp

    .PARAMETER WebAppName
    Name of the Azure Web App.

    .PARAMETER DeploymentFolderPath
    Path of the On-premise Web Site Deployment Folder 

    .INPUTS
     .\Publish-WebApptoAzure.ps1 -ClientID 1257 -AzureUserName sailakshmi.penta@netenrich.com -AzurePassword ********
    -AzureSubscriptionID ca68598c-ecc3-4abc-b7a2-1ecef33f278d -Location "Southeast Asia" -ResourceGroupName samplerg 
    -AppServicePlanName divadevoAppPlan -WebAppName sampleap2 
    -DeploymentFolderPath "C:\Users\NETENRICH\Documents\Visual Studio 2015\WebSites\WebSite1"

    .OUTPUTS
     WARNING: The output object type of this cmdlet will be modified in a future release.
     {
        "Status":  "Success",
        "BlobURI":  "https://nelogfiles.blob.core.windows.net/neportallogs/1257-Publish-WebApptoAzure-08-Aug-2016_144744.log",
        "Response":  [
                         "Successfully Uploaded On-premise WebApp files to Azure"
                     ]
     }

    .NOTES
     Purpose of script: Template for Publishing Azure Web App to Azure
     Minimum requirements: Azure PowerShell Version 1.4.0
     Initially written by: P S L Prasanna
     Update/revision History:
     =======================
     Updated by        Date            Reason
     ==========        ====            ======
     

    .EXAMPLE
    C:\PS> .\Publish-WebApptoAzure.ps1 -ClientID 1257 -AzureUserName sailakshmi.penta@netenrich.com -AzurePassword ********
    -AzureSubscriptionID ca68598c-ecc3-4abc-b7a2-1ecef33f278d -Location "Southeast Asia" -ResourceGroupName samplerg 
    -AppServicePlanName divadevoAppPlan -WebAppName sampleap2 
    -DeploymentFolderPath "C:\Users\NETENRICH\Documents\Visual Studio 2015\WebSites\WebSite1"

    WARNING: The output object type of this cmdlet will be modified in a future release.
    {
        "Status":  "Success",
        "BlobURI":  "https://nelogfiles.blob.core.windows.net/neportallogs/1257-Publish-WebApptoAzure-08-Aug-2016_144744.log",
        "Response":  [
                         "Successfully Uploaded On-premise WebApp files to Azure"
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
    [string]$DeploymentFolderPath

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

    # 2. Check if Resource Group exists.
    Try
    {
       Write-LogFile -FilePath $LogFilePath -LogText "Checking existance of resource group '$ResourceGroupName'"
        $ResourceGroup = $null
        ($ResourceGroup = Get-AzureRmResourceGroup -Name $ResourceGroupName -ErrorAction Stop) | Out-Null
    
        If($ResourceGroup -ne $null) # Resource Group already exists
        {
           Write-LogFile -FilePath $LogFilePath -LogText "Resource Group already exists"
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
        ($ASPCheck = Get-AzureRmAppServicePlan -Name $AppServicePlanName -ResourceGroupName $ResourceGroupName -ErrorAction Stop) | Out-Null
        
        If($ASPCheck -ne $null) # AppServicePlan already exists
        {
           Write-LogFile -FilePath $LogFilePath -LogText "AppServicePlan already exists."
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

    # 4. Check if WebApp exists. 
    Try
    {
        Write-LogFile -FilePath $LogFilePath -LogText "Checking existance of Web App '$WebAppName'"
        $WACheck = $null
        ($WACheck = Get-AzureRmWebApp -ResourceGroupName $ResourceGroupName -Name $WebAppName -ea SilentlyContinue) | Out-Null
        If($WACheck -ne $null){
            Write-LogFile -FilePath $LogFilePath -LogText "WebApp '$WebAppName' exists"
            Write-LogFile -FilePath $LogFilePath -LogText "Trying to Getting the Publishing Profile File" 
            $PPFileCheck = Get-AzureRmWebAppPublishingProfile -ResourceGroupName $ResourceGroupName -Name $WebAppName -OutputFile "C:\NEPortal\$ClientID-$WebAppName.xml"
            IF($PPFileCheck){
              Write-LogFile -FilePath $LogFilePath -LogText "Publishing Profile content is stored in xml file"
            }
              Write-LogFile -FilePath $LogFilePath -LogText "Trying to get ftp url,username and password"
              [xml]$xmldoc = Get-Content "C:\NEPortal\$ClientID-$WebAppName.xml"
              $ftparr = $xmldoc.publishData.publishProfile.publishUrl
              $ftpurl = $ftparr[1]
              $usernamearr = $xmldoc.publishData.publishProfile.userName
              $username = $usernamearr[1]             
              $userpassarr = $xmldoc.publishData.publishProfile.userPWD
              $userpass = $userpassarr[1]             
              $DeployDir = Get-ChildItem $DeploymentFolderPath -recurse
              $webclient1 = New-Object System.Net.WebClient              
              $webclient1.Credentials = New-Object System.Net.NetworkCredential($username,$userpass) 
              $pathlength = $DeploymentFolderPath.Length 
              Write-LogFile -FilePath $LogFilePath -LogText "Uploading files to $ftpurl."
              foreach($item in $DeployDir){ 
                   If($item.Mode -eq "d-----"){
                        $foldername = $item.Fullname
                        $dirname = $foldername.Substring($pathlength+1)
                        $newFolder = "$ftpurl"+"/"+"$dirname"
                        $webclient = [System.Net.WebRequest]::Create($newFolder);
	                    $webclient.Credentials = New-Object System.Net.NetworkCredential($username,$userpass);
	                    $webclient.Method = [System.Net.WebRequestMethods+FTP]::MakeDirectory;
	                    $status = $webclient.GetResponse();                                                                   
                   }
                   Else{
                        $foldername = $item.FullName                             
                        $filename = $foldername.Substring($pathlength+1)
                        $uri = New-Object System.Uri($ftpurl+"/"+$filename) 
                        $webclient1.UploadFile($uri,$item.FullName)
                   }                                                                                    
              } 
              $ObjOut = "Successfully Uploaded On-premise WebApp files to Azure"
              $output = (@{"Response" = [Array]$ObjOut; Status = "Success"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
              Write-Output $output
        }
        Else
        {            
            $ObjOut = "Azure WebApp '$WebAppName' does not exists.`r`n$($Error[0].Exception.Message)`r`n<#BlobFileReadyForUpload#>"
            $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
            Write-Output $output
            Write-LogFile -FilePath $LogFilePath -LogText "$ObjOut"
            Exit           
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
}

End
{
    Write-LogFile -FilePath $LogFilePath -LogText "####[ Script execution completed cuccessfully: $($MyInvocation.MyCommand.Name) ]####`r`n<#BlobFileReadyForUpload#>"
}