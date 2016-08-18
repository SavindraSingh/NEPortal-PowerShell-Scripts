<#
    .SYNOPSIS
    Script will Modify Properties of the Azure ARM Traffic Manager Profile and it's Endpoints

    .DESCRIPTION
    Script will Modify Properties of the Azure ARM Traffic Manager Profile and it's Endpoints

    .PARAMETER ClientID
    ClientID of the client for whom the script is being executed.

    .PARAMETER AzureUserName
    User name for Azure login. This should be an Organizational account (not Hotmail/Outlook account)

    .PARAMETER AzurePassword
    Password for Azure user account.

    .PARAMETER AzureSubscriptionID
    Azure Subscription ID to use for this activity.

    .PARAMETER ResourceGroupName
    Name of the Azure ARM resource group to use for this command.

    .PARAMETER TrafficManagerProfileName
    Name of the Azure ARM Traffic Manager Profile name to use for this command.

    .PARAMETER TrafficManagerProfileStatus
    Give the Status of the Traffic Manager Profile. This parameter value must be either Enabled or Disabled.

    .PARAMETER DNSTimetolive
    Give the Time to Live period for the Traffic Manager Profile DNS

    .PARAMETER MonitorProtocol
    Select the Monitor Protocol of the Traffic Manager Profile. It must be either HTTP or HTTPS

    .PARAMETER MonitorPath
    Give the MonitorPath of the Traffic Manager Profile.

    .PARAMETER EndpointDetails
    Give the Endpoint Names and the properties values to change. It must be in format like "EndpointName:EndpointStatus:ResourceName|Type:Priorities/Weights,EndpointName1::ResourceName|Type:"

    .INPUTS
    .\UpdateTrafficManagerorEndpoints2.ps1 -AzureUserName sailakshmi.penta@netenrich.com 
    -AzurePassword ********* -AzureSubscriptionID ca68598c-ecc3-4abc-b7a2-1ecef33f278d -ClientID 1257 
    -ResourceGroupName "Todelete3" -TrafficManagerProfileName "testtmp123" -TrafficManagerProfileStatus Enabled
    -TrafficRoutingMethod Weighted -DNSTimetolive 40 -MonitorProtocol HTTPS -MonitorPath "/" 
    -EndpointDetails "hi123::sampleapp123test|Microsoft.Web/Sites:,hello:Enabled::"

    .OUTPUTS
       {
          "Status":  "Success",
          "BlobURI":  "https://nelogfiles.blob.core.windows.net/neportallogs/1257-UpdateTrafficManagerorEndpoints2-28-Jul-2016_1259
      52.log",
          "Response":  [
                           "Successfully Modified Traffic Manager Profile testtmp123."
                       ]
      }
      {
          "Status":  "Success",
          "BlobURI":  "https://nelogfiles.blob.core.windows.net/neportallogs/1257-UpdateTrafficManagerorEndpoints2-28-Jul-2016_1259
      52.log",
          "Response":  [
                           "Successfully Modified Endpoint hi123."
                       ]
      }
      {
          "Status":  "Success",
          "BlobURI":  "https://nelogfiles.blob.core.windows.net/neportallogs/1257-UpdateTrafficManagerorEndpoints2-28-Jul-2016_1259
      52.log",
          "Response":  [
                           "Successfully Modified Endpoint hello."
                       ]
      }

    .NOTES
     Purpose of script: Template for Modifying Properties of the Azure ARM Traffic Manager Profile and it's Endpoints
     Minimum requirements: Azure PowerShell Version 1.4.0
     Initially written by: P S L Prasanna
     Update/revision History:
     =======================
     

    .EXAMPLE

    PS E:\Powershell Scripts> .\UpdateTrafficManagerorEndpoints2.ps1 -AzureUserName sailakshmi.penta@netenrich.com 
    -AzurePassword ********* -AzureSubscriptionID ca68598c-ecc3-4abc-b7a2-1ecef33f278d -ClientID 1257 
    -ResourceGroupName "Todelete3" -TrafficManagerProfileName "testtmp123" -TrafficRoutingMethod Weighted 
    -DNSTimetolive 40 -MonitorProtocol HTTPS -EndpointDetails "hi123::sampleapp123test|Microsoft.Web/Sites:,hello:Enabled::"

    WARNING: The output object type of this cmdlet will be modified in a future release.
    
    {
        "Status":  "Success",
        "BlobURI":  "https://nelogfiles.blob.core.windows.net/neportallogs/1257-UpdateTrafficManagerorEndpoints2-28-Jul-2016_1259
    52.log",
        "Response":  [
                         "Successfully Modified Traffic Manager Profile testtmp123."
                     ]
    }
    {
        "Status":  "Success",
        "BlobURI":  "https://nelogfiles.blob.core.windows.net/neportallogs/1257-UpdateTrafficManagerorEndpoints2-28-Jul-2016_1259
    52.log",
        "Response":  [
                         "Successfully Modified Endpoint hi123."
                     ]
    }
    {
        "Status":  "Success",
        "BlobURI":  "https://nelogfiles.blob.core.windows.net/neportallogs/1257-UpdateTrafficManagerorEndpoints2-28-Jul-2016_1259
    52.log",
        "Response":  [
                         "Successfully Modified Endpoint hello."
                     ]
    }
    

    .LINK
    http://www.netenrich.com/#>

[CmdletBinding()]
Param
(
    [Parameter(ValueFromPipelineByPropertyName)]
    [string]$ClientID,

    [Parameter(ValueFromPipelineByPropertyName=$true)]
    [string]$AzureUserName,
  
    [Parameter(ValueFromPipelineByPropertyName=$true)]
    [string]$AzurePassword,
  
    [Parameter(ValueFromPipelineByPropertyName=$true)]
    [string]$AzureSubscriptionID,
   
    [Parameter(ValueFromPipelineByPropertyName=$true)]
    [string]$ResourceGroupName, 

    [Parameter(ValueFromPipelineByPropertyName=$true)]
    [string]$TrafficManagerProfileName,
   
    [Parameter(ValueFromPipelineByPropertyName=$true)]
    [Validateset("Disabled","Enabled")]
    [string]$TrafficManagerProfileStatus,
    
    [Parameter(ValueFromPipelineByPropertyName=$true)]
   # [ValidateSet("Performance","Priority","Weighted")]
    [string]$TrafficRoutingMethod,
   
    [Parameter(ValueFromPipelineByPropertyName=$true)]
    [string]$DNSTimetolive, 
   
    [Parameter(ValueFromPipelineByPropertyName=$true)]
   # [ValidateSet("HTTP","HTTPS")]
    [string]$MonitorProtocol,
   
    [Parameter(ValueFromPipelineByPropertyName=$true)]
    [string]$MonitorPath,
   
    [Parameter(ValueFromPipelineByPropertyName=$true)]
    [string]$EndpointDetails

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
            If([String]::IsNullOrEmpty($TrafficManagerProfileName))
            {
                Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. TrafficManagerProfileName parameter value is empty.`r`n<#BlobFileReadyForUpload#>"
                $ObjOut = "Validation failed. TrafficManagerProfileName parameter value is empty."
                $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                Write-Output $output
                Exit
            }

                     
            If($TrafficRoutingMethod.Length -ne 0){
                 Write-LogFile -FilePath $LogFilePath -LogText "Validating Parameters: TrafficRoutingMethod. Only ERRORs will be logged."
                 $arr = "Performance","Priority","Weighted"
                 If($arr -notcontains $TrafficRoutingMethod){
                    Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. PerformanceTear '$TrafficRoutingMethod' is NOT a valid value for this parameter.`r`n<#BlobFileReadyForUpload#>"
                    $ObjOut = "Validation failed. PerformanceTear '$TrafficRoutingMethod' is not a valid value for this parameter."
                    $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                    Write-Output $output
                    Exit
                 }
                 
            }

            If($MonitorProtocol.Length -ne 0){
                 Write-LogFile -FilePath $LogFilePath -LogText "Validating Parameters: MonitorProtocol. Only ERRORs will be logged."
                 $arr = "HTTP","HTTPS"
                 If($arr -notcontains $MonitorProtocol){
                    Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. PerformanceTear '$MonitorProtocol' is NOT a valid value for this parameter.`r`n<#BlobFileReadyForUpload#>"
                    $ObjOut = "Validation failed. PerformanceTear '$MonitorProtocol' is not a valid value for this parameter."
                    $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                    Write-Output $output
                    Exit
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

    Function Get-TargetResourceID
    {       
        Param([String]$ResourceName, [String]$ResourceType)
        Try{ 
             $Array = "Microsoft.Network/publicIPAddresses","Microsoft.Web/sites","Microsoft.ClassicCompute/domainNames"
             IF($Array -notcontains $ResourceType){
                Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. PerformanceTear '$ResourceType' is NOT a valid value for this parameter.`r`n<#BlobFileReadyForUpload#>"
                $ObjOut = "Validation failed. PerformanceTear '$ResourceType' is not a valid value for this parameter."
                $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                Write-Output $output
                Exit   
             }
             Write-LogFile -FilePath $LogFilePath -LogTeFxt "Trying to get Endpoint Resource '$ResourceName'"                        
             IF($ResourceType -eq "Microsoft.Web/sites"){
                 $azres = Get-AzureRmWebApp -Name $ResourceName
             }
             ELSEIF($ResourceType -eq "Microsoft.Network/publicIPAddresses"){
                 $azres = Get-AzureRmResource | Where {$_.Name -eq $ResourceName -and $_.ResourceType -eq  "Microsoft.Network/publicIPAddresses"}
             }
             ELSE{
                 $azres = Get-AzureRmResource | Where {$_.Name -eq $ResourceName -and $_.ResourceType -eq  "Microsoft.ClassicCompute/domainNames"}
             }
              
        }
        Catch{
             $ObjOut = "Error while Getting Endpoint Resource.`r`n$($Error[0].Exception.Message)`r`n<#BlobFileReadyForUpload#>"
             $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
             Write-Output $output
             Write-LogFile -FilePath $LogFilePath -LogText $ObjOut
             Exit
        }
        $id = $azres.ResourceId
        IF($id.Length -eq 0){
            $id = $azres.Id 
            If($id.Length -eq 0){
                    $ObjOut = "Endpoint Resource Not Found.`r`n<#BlobFileReadyForUpload#>"
                    $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                    Write-Output $output
                    Write-LogFile -FilePath $LogFilePath -LogText $ObjOut
                    Exit
            }          
        }
        Write-LogFile -FilePath $LogFilePath -LogText "Found the '$ResourceName'"
        $s = $id+':'+$azres.Location           
        return $s                                 
    }
}

Process
{
    Validate-AllParameters

    # 1. Login to Azure subscription
    Login-ToAzureAccount

    $EndpointType = "AzureEndpoints"  
    
    $RelativeDnsName = $TrafficManagerProfileName  
     
    $MonitorPort=80 


    # 2. Check if Resource Group exists. 
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
           $ObjOut = "Resource Group with Name $ResourceGroupName does not exist.`r`n<#BlobFileReadyForUpload#>"
           $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
           Write-Output $output
           Write-LogFile -FilePath $LogFilePath -LogText $ObjOut
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

    # 3. Check if Traffic Manager Profile exists. Modify if details given by user.
    Try
    {
       IF($MonitorProtocol -eq "HTTPS"){
             $MonitorPort = 443
       }
       $TMProfileCheck = $null
       Write-LogFile -FilePath $LogFilePath -LogText "Checking the existance of Traffic Manager Profile '$TrafficManagerProfileName'"
       ($TMProfileCheck = Get-AzureRmTrafficManagerProfile -Name $TrafficManagerProfileName -ResourceGroupName $ResourceGroupName -ErrorAction SilentlyContinue)|Out-Null           
       IF($TMProfileCheck -ne $null){
             Write-LogFile -FilePath $LogFilePath -LogText "Traffic Manager Profile '$TrafficManagerProfileName' does exists."
             IF($TrafficManagerProfileStatus.Length -ne 0){
                 $TMProfileCheck.ProfileStatus = $TrafficManagerProfileStatus
             }             
             IF($DNSTimetolive.Length -ne 0){
                 $TMProfileCheck.Ttl = $DNSTimetolive
             }
             IF($TrafficRoutingMethod.Length -ne 0){
                 $TMProfileCheck.TrafficRoutingMethod = $TrafficRoutingMethod
             }
             IF($MonitorProtocol.Length -ne 0){
                 $TMProfileCheck.MonitorProtocol = $MonitorProtocol
             }
             IF($MonitorPath.Length -ne 0){
                 $TMProfileCheck.MonitorPath = $MonitorPath
             }
             
             $TMProfileCheck.MonitorPort = $MonitorPort

             Try{
                Write-LogFile -FilePath $LogFilePath -LogText "Modifying the '$TrafficManagerProfileName' Traffic Manager Profile with the given details"
                $tmp = Set-AzureRmTrafficManagerProfile -TrafficManagerProfile $TMProfileCheck  
                Write-LogFile -FilePath $LogFilePath -LogText "Successfully Modified the '$TrafficManagerProfileName' Traffic Manager Profile"           
                
                $ObjOut = "Successfully Modified Traffic Manager Profile $TrafficManagerProfileName."
                $output = (@{"Response" = [Array]$ObjOut; Status = "Success"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                Write-Output $output 
             }
             Catch{
                $ObjOut = "Error while Modifying '$TrafficManagerProfileName'.`r`n$($Error[0].Exception.Message)`r`n<#BlobFileReadyForUpload#>"
                $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                Write-Output $output
                Write-LogFile -FilePath $LogFilePath -LogText $ObjOut
                Exit
             }
       }         
       Else{
            $ObjOut = "Traffic Manager Profile '$TrafficManagerProfileName' does not exists.`r`n$($Error[0].Exception.Message)`r`n<#BlobFileReadyForUpload#>"
            $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
            Write-Output $output
            Write-LogFile -FilePath $LogFilePath -LogText $ObjOut
            Exit
       }
    
    }
    Catch
    {
        $ObjOut = "Error while Getting Azure Traffic Manager Profile details.`r`n$($Error[0].Exception.Message)`r`n<#BlobFileReadyForUpload#>"
        $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
        Write-Output $output
        Write-LogFile -FilePath $LogFilePath -LogText $ObjOut
        Exit
    }

    # 4. Check if End points exists. Modify those if details given by user.
    Try
    {
       $endpoints = $TMProfileCheck.Endpoints.Name
       $epdetails = $EndpointDetails.Split(',')
       foreach($i in $epdetails){
            $eparr = $i.Split(':')
            If($eparr.Count -gt 4){
                $ObjOut = "EndpointDetails must have this format 'EndpointName:EndpointStatus:ResourceName|Type:Priorities/Weights'.`r`n<#BlobFileReadyForUpload#>"
                $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                Write-Output $output
                Write-LogFile -FilePath $LogFilePath -LogText $ObjOut
                Exit
            }
            $epname = $eparr[0]
            Write-LogFile -FilePath $LogFilePath -LogText "Checking the existance of Endpoint '$epname'"
            $epcheck = $null
            ($epcheck = Get-AzureRmTrafficManagerEndpoint -Name $epname -Type AzureEndpoints -ProfileName $TrafficManagerProfileName -ResourceGroupName $ResourceGroupName -ErrorAction SilentlyContinue) | Out-Null           
            If($epcheck -ne $null){
                Write-LogFile -FilePath $LogFilePath -LogText "Endpoint '$epname' does exists."
                Try{
                 Write-LogFile -FilePath $LogFilePath -LogText "Trying to Modify Endpoint '$epname' Properties."
                 If($eparr[1].Length -ne 0 -and ($eparr[1] -eq "Enabled" -or $eparr[1] -eq "Disabled")){
                     $epcheck.EndpointStatus = $eparr[1]
                 }
                 If($eparr[2].Length -ne 0){
                     $rsntypes = ($eparr[2]).Split('|')
                     $resourcename = $rsntypes[0]
                     $resourcetype = $rsntypes[1]
                     $idloc = Get-TargetResourceID -ResourceName $resourcename -ResourceType $resourcetype
                     $idlocarr = $idloc.Split(':')
                     $epcheck.TargetResourceId = $idlocarr[0]
                     $epcheck.Location = $idlocarr[1]
                 }

                 If($eparr[3].Length -ne 0 -and ($TrafficRoutingMethod -eq "Priority" -or $TrafficRoutingMethod -eq "Weighted")){
                     [int]$number = $eparr[3]
                     If($TrafficRoutingMethod -eq "Priority"){
                        $arr = $TMProfileCheck.Endpoints.Priority
                        If($arr -notcontains $number){
                            $epcheck.Priority = $number
                        }
                        Else{
                            $ObjOut = "This Priority is assigned to other Endpoint in this Traffic Manager.`r`n<#BlobFileReadyForUpload#>"
                            $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                            Write-Output $output
                            Write-LogFile -FilePath $LogFilePath -LogText $ObjOut
                            Exit
                        }
                     }
                     Else{
                        $arr = $TMProfileCheck.Endpoints.Weight
                        If($arr -notcontains $number){
                            $epcheck.Weight = $number
                        }
                        Else{
                            $ObjOut = "This Weight is assigned to other Endpoint in this Traffic Manager.`r`n<#BlobFileReadyForUpload#>"
                            $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                            Write-Output $output
                            Write-LogFile -FilePath $LogFilePath -LogText $ObjOut
                            Exit
                        }
                     }
                 }
                 Try{
                    Write-LogFile -FilePath $LogFilePath -LogText "Trying to Modify Endpoint '$epname'"
                    $ep = Set-AzureRmTrafficManagerEndpoint -TrafficManagerEndpoint $epcheck
                    Write-LogFile -FilePath $LogFilePath -LogText "Successfully Modified the Endpoint '$epname'."

                    $ObjOut = "Successfully Modified Endpoint $epname."
                    $output = (@{"Response" = [Array]$ObjOut; Status = "Success"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                    Write-Output $output                   
                 }
                 Catch{
                    $ObjOut = "Error while Modifying Azure Traffic Manager Profile Endpoint Properties.`r`n$($Error[0].Exception.Message)`r`n<#BlobFileReadyForUpload#>"
                    $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                    Write-Output $output
                    Write-LogFile -FilePath $LogFilePath -LogText $ObjOut
                    Exit
                 }
            }
                Catch{
                  $ObjOut = "Error while Modifying Azure Traffic Manager Profile Endpoint Properties.`r`n$($Error[0].Exception.Message)`r`n<#BlobFileReadyForUpload#>"
                  $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                  Write-Output $output
                  Write-LogFile -FilePath $LogFilePath -LogText $ObjOut
                  Exit
            }
            }
            Else{
                $ObjOut = "Endpoint Name '$epname' does not exists.`r`n$($Error[0].Exception.Message)`r`n<#BlobFileReadyForUpload#>"
                $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                Write-Output $output
                Write-LogFile -FilePath $LogFilePath -LogText $ObjOut
                Exit
            }
       } 
    }
    Catch
    {
        $ObjOut = "Error while Getting Azure Traffic Manager Profile Endpoint details.`r`n$($Error[0].Exception.Message)`r`n<#BlobFileReadyForUpload#>"
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