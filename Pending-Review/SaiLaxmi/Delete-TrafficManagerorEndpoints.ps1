<#
    .SYNOPSIS
    Script to Delete the existing Azure ARM Traffic Manager Profile and it's Endpoints

    .DESCRIPTION
    Script to Delete the existing Azure ARM Traffic Manager Profile and it's Endpoints

    .PARAMETER ClientID
    ClientID of the client for whom the script is being executed.

    .PARAMETER AzureUserName
    User name for Azure login. This should be an Organizational account (not Hotmail/Outlook account)

    .PARAMETER AzurePassword
    Password for Azure user account.

    .PARAMETER AzureSubscriptionID
    Azure Subscription ID to use for this activity.

    .PARAMETER ResourceGroupName
    Name of the Azure ARM resource group.

    .PARAMETER TrafficManagerProfileName
    Name of the Azure ARM Traffic Manager Profile to Delete.

    .PARAMETER EndpointNames
    Names of the Azure ARM Traffic Manager Profile Endpoints to Delete.

    .INPUTS
    .\DeleteTrafficManagerorEndpoints2.ps1 -AzureUserName sailakshmi.penta@netenrich.com 
    -AzurePassword ************ -AzureSubscriptionID ca68598c-ecc3-4abc-b7a2-1ecef33f278d -ClientID 1257 
    -ResourceGroupName "Todelete3" -TrafficManagerProfileName "testtmp123"

    .OUTPUTS

    {
        "Status":  "Success",
        "BlobURI":  "https://nelogfiles.blob.core.windows.net/neportallogs/1257-DeleteTrafficManagerorEndpoints2-28-Jul-2016_1523
    42.log",
        "Response":  [
                         "Successfully Removed Traffic Manager Profile 'testtmp123'."
                     ]
    }

    .NOTES
     Purpose of script: Template for Deleting Azure ARM Traffic Manager Profile and Endpoints
     Minimum requirements: Azure PowerShell Version 1.4.0
     Initially written by: P S L Prasanna.
     Update/revision History:
     =======================
     Updated by        Date            Reason
     ==========        ====            ======
     


    .EXAMPLE
    PS E:\Powershell Scripts> .\DeleteTrafficManagerorEndpoints2.ps1 -AzureUserName sailakshmi.penta@netenrich.com 
    -AzurePassword ************ -AzureSubscriptionID ca68598c-ecc3-4abc-b7a2-1ecef33f278d -ClientID 1257 
    -ResourceGroupName "Todelete3" -TrafficManagerProfileName "testtmp123"

    WARNING: The output object type of this cmdlet will be modified in a future release.
    {
        "Status":  "Success",
        "BlobURI":  "https://nelogfiles.blob.core.windows.net/neportallogs/1257-DeleteTrafficManagerorEndpoints2-28-Jul-2016_1523
    42.log",
        "Response":  [
                         "Successfully Removed Traffic Manager Profile 'testtmp123'."
                     ]
    }

    .EXAMPLE
    PS E:\Powershell Scripts> .\DeleteTrafficManagerorEndpoints2.ps1 -AzureUserName sailakshmi.penta@netenrich.com 
    -AzurePassword ************ -AzureSubscriptionID ca68598c-ecc3-4abc-b7a2-1ecef33f278d -ClientID 1257 
    -ResourceGroupName "Todelete3" -TrafficManagerProfileName "testtmp123" -EndpointNames "hi123"

    WARNING: The output object type of this cmdlet will be modified in a future release.
    
    {
        "Status":  "Success",
        "BlobURI":  "https://nelogfiles.blob.core.windows.net/neportallogs/1257-DeleteTrafficManagerorEndpoints2-28-Jul-2016_1513
    44.log",
        "Response":  [
                         "Successfully Removed 'hi123' End Points of 'testtmp123'."
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
    [String]$ResourceGroupName,

    [Parameter(ValueFromPipelineByPropertyName)]
    [string]$TrafficManagerProfileName,

    [Parameter(ValueFromPipelineByPropertyName)]
    [string]$EndpointNames

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

            # Validate parameter: TrafficManagerProfileName
            Write-LogFile -FilePath $LogFilePath -LogText "Validating Parameters: TrafficManagerProfileName. Only ERRORs will be logged."
            If([String]::IsNullOrEmpty($ResourceGroupName))
            {
                Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. TrafficManagerProfileName parameter value is empty.`r`n<#BlobFileReadyForUpload#>"
                $ObjOut = "Validation failed. TrafficManagerProfileName parameter value is empty."
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

    $EndpointType = "AzureEndpoints"
    # 2. Check if Resource Group exists. Create Resource Group if it does not exist.
    Try
    {
       Write-LogFile -FilePath $LogFilePath -LogText "Checking existance of resource group '$ResourceGroupName'"
        $ResourceGroup = $null
        ($ResourceGroup = Get-AzureRmResourceGroup -Name $ResourceGroupName -ErrorAction SilentlyContinue) | Out-Null
    
        If($ResourceGroup -ne $null) # Resource Group already exists
        {
           Write-LogFile -FilePath $LogFilePath -LogText "Resource Group exists"
        }
        Else # Resource Group does not exist. Can't continue without creating resource group.
        {          
           $ObjOut = "Azure Resource Group '$ResourceGroupName' does not exist.`r`n$($Error[0].Exception.Message)`r`n<#BlobFileReadyForUpload#>"
           $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
           Write-Output $output
           Write-LogFile -FilePath $LogFilePath -LogText "$ObjOut"
           Exit           
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

   # 3. Check if Traffic Manager Profile exists.
    Try
    {
        Write-LogFile -FilePath $LogFilePath -LogText "Checking existance of Traffic Manager Profile '$TrafficManagerProfileName'."
        $TMProfileCheck = $null
        ($TMProfileCheck = Get-AzureRmTrafficManagerProfile -Name $TrafficManagerProfileName -ResourceGroupName $ResourceGroupName -ea SilentlyContinue)|Out-Null
        
        IF(($TMProfileCheck -ne $null) -and ($EndpointNames.Length -ne 0) ){ 
            Write-LogFile -FilePath $LogFilePath -LogText "Traffic Manager Profile '$TrafficManagerProfileName' does exists"          
            $endpointarr = $EndpointNames.Split(',')
            $arr = $TMProfileCheck.Endpoints.Name
            foreach($i in $endpointarr){
                Try{
                    If($arr -contains $i){
                       Write-LogFile -FilePath $LogFilePath -LogText "Removing $i End point of $TrafficManagerProfileName."
                       $ep = Remove-AzureRmTrafficManagerEndpoint -Name $i -Type $EndpointType -ProfileName $TrafficManagerProfileName  -ResourceGroupName $ResourceGroupName -Force
                       Write-LogFile -FilePath $LogFilePath -LogText "Successfully Removed $i End point."
                    }
                    Else{
                       $ObjOut = "'$i' is not the Endpoint of the '$TrafficManagerProfileName' Traffic Manager Profile."
                       $output = (@{"Response" = [Array]$ObjOut; "Status" = "Failed"} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                       Write-Output $output
                       Write-LogFile -FilePath $LogFilePath -LogText "$ObjOut"
                       Exit
                    }
                }
                Catch{
                 $ObjOut = "Error while Removing End Point $i.`r`n$($Error[0].Exception.Message)"
                 $output = (@{"Response" = [Array]$ObjOut; "Status" = "Failed"} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                 Write-Output $output
                 Write-LogFile -FilePath $LogFilePath -LogText "$ObjOut"
                 Exit
                }
            }
            Write-LogFile -FilePath $LogFilePath -LogText "Successfully Removed '$EndpointNames' End Points of '$TrafficManagerProfileName'."
            $ObjOut = "Successfully Removed '$EndpointNames' End Points of '$TrafficManagerProfileName'."
            $output = (@{"Response" = [Array]$ObjOut; Status = "Success"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
            Write-Output $output 
        }
        ELSEIF($TMProfileCheck -ne $null){
           Write-LogFile -FilePath $LogFilePath -LogText "Traffic Manager Profile '$TrafficManagerProfileName' does exists"
           Try{
             Write-LogFile -FilePath $LogFilePath -LogText "Removing $TrafficManagerProfileName Traffic Manager Profile."
             $tmp = Remove-AzureRmTrafficManagerProfile -Name $TrafficManagerProfileName -ResourceGroupName $ResourceGroupName
             Write-LogFile -FilePath $LogFilePath -LogText "Successfully Removed $TrafficManagerProfileName Traffic Manager Profile."
           }
           Catch{
             $ObjOut = "Error while Removing Azure Traffic Manager Profile $TrafficManagerProfileName.`r`n$($Error[0].Exception.Message)"
             $output = (@{"Response" = [Array]$ObjOut; "Status" = "Failed"} | ConvertTo-Json).ToString().Replace('\u0027',"'")
             Write-Output $output
             Write-LogFile -FilePath $LogFilePath -LogText "$ObjOut"
             Exit
           }
            
            $ObjOut = "Successfully Removed Traffic Manager Profile '$TrafficManagerProfileName'."
            $output = (@{"Response" = [Array]$ObjOut; Status = "Success"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
            Write-Output $output 
        }
        Else{
            $ObjOut = "Azure Traffic Manager Profile '$TrafficManagerProfileName' does not exist.`r`n<#BlobFileReadyForUpload#>"
            $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
            Write-Output $output
            Write-LogFile -FilePath $LogFilePath -LogText $ObjOut
            Exit       
        }
        
    }
    Catch
    {
        $ObjOut = "Error while getting Azure Traffic Manager Profile details.`r`n$($Error[0].Exception.Message)`r`n<#BlobFileReadyForUpload#>"
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