<#
    .SYNOPSIS
    Script to Create Azure ARM TrafficManagerProfile and configure Endpoints for that.

    .DESCRIPTION
    Script to Create Azure ARM TrafficManagerProfile and configure Endpoints for that.

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

    .PARAMETER TrafficManagerProfileName
    Name of the Azure ARM resource group to use for this command.

    .PARAMETER TrafficManagerRoutingMethod
    Choose one of the Routing Method.

    .PARAMETER MonitorProtocol
    Choose either HTTP or HTTPS

    .PARAMETER ResourceNamesandTypes
    Give the Endpoint Resource Names and Types in a format like "ResourceName|Type,ResourceName1|Type1"

    .INPUTS

    .\Configure-TrafficManagerforAzureEPs.ps1 -AzureUserName sailakshmi.penta@netenrich.com 
    -AzurePassword ******** -AzureSubscriptionID ca68598c-ecc3-4abc-b7a2-1ecef33f278d -ClientID 1257 
    -ResourceGroupName "Todelete3" -TrafficManagerProfileName "testtmp12354" -Location "Southeast Asia" 
    -ResourceNamesandTypes "sampleapp123test|Microsoft.Web/sites,testcs123|Microsoft.ClassicCompute/domainNames"

    .OUTPUTS
     {
        "Status":  "Success",
        "BlobURI":  "https://nelogfiles.blob.core.windows.net/neportallogs/1257-ConfigureTrafficManagerforAzureEPs2-28-Jul-2016_1
    73648.log",
        "Response":  [
                         "Traffic Manager Profile is successfully created and Endpoints are configured Successfully"
                     ]
    } 

    .NOTES
     Purpose of script: Template for Azure Scripts
     Minimum requirements: Azure PowerShell Version 1.4.0
     Initially written by: P S L Prasanna.
     Update/revision History:
     =======================
     Updated by        Date            Reason
     ==========        ====            ======
     PSLPrasanna     01-Aug-16       Add code for validating TrafficRoutingMethod and Monitor Protocol

    .EXAMPLE
    PS E:\Powershell Scripts> .\Configure-TrafficManagerforAzureEPs.ps1 -AzureUserName sailakshmi.penta@netenrich.com 
    -AzurePassword ******** -AzureSubscriptionID ca68598c-ecc3-4abc-b7a2-1ecef33f278d -ClientID 1257 
    -ResourceGroupName "Todelete3" -TrafficManagerProfileName "testtmp12354" -Location "Southeast Asia" 
    -ResourceNamesandTypes "sampleapp123test|Microsoft.Web/sites,testcs123|Microsoft.ClassicCompute/domainNames"
    WARNING: The output object type of this cmdlet will be modified in a future release.
    {
        "Status":  "Success",
        "BlobURI":  "https://nelogfiles.blob.core.windows.net/neportallogs/1257-ConfigureTrafficManagerforAzureEPs2-28-Jul-2016_1
    73648.log",
        "Response":  [
                         "Traffic Manager Profile is successfully created and Endpoints are configured Successfully"
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
    [string]$TrafficManagerProfileName,
   
    [Parameter(ValueFromPipelineByPropertyName)]
    #[ValidateSet("Performance","Priority","Weighted")]
    [string]$TrafficRoutingMethod="Priority",
    
    [Parameter(ValueFromPipelineByPropertyName)]
    #[ValidateSet("HTTP","HTTPS")]
    [string]$MonitorProtocol="HTTP",
    
    [Parameter(ValueFromPipelineByPropertyName)]
    [string]$ResourceNamesandTypes

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

            # Validate parameter: ResourceNamesandTypes
            Write-LogFile -FilePath $LogFilePath -LogText "Validating Parameters: ResourceNamesandTypes. Only ERRORs will be logged."
            If([String]::IsNullOrEmpty($ResourceNamesandTypes))
            {
                Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. ResourceNamesandTypes parameter value is empty.`r`n<#BlobFileReadyForUpload#>"
                $ObjOut = "Validation failed. ResourceNamesandTypes parameter value is empty."
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

    Function Validate-ParamResourceNamesandTypes
    {   
        Try{
            $webapparr = $ResourceNamesandTypes.Split(',')
            $resourcetypes = "Microsoft.Network/publicIPAddresses","Microsoft.Web/sites","Microsoft.ClassicCompute/domainNames"                 
            foreach($i in $webapparr){
                $webapparr2 = $i.Split('|')
                $rtype = $webapparr2[1]
                $rname = $webapparr2[0]
                IF($resourcetypes -notcontains $rtype){                    
                    Write-LogFile -FilePath $LogFilePath -LogText "$rtype is not a valid Resource Type.`r`n<#BlobFileReadyForUpload#>"
                    $ObjOut = "Error while validating $rtype. It is not a valid Resource Type."
                    $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                    Write-Output $output
                    Exit
                } 
                IF($webapparr2[0].Length -eq 0){
                    Write-LogFile -FilePath $LogFilePath -LogText "$rname is empty.`r`n<#BlobFileReadyForUpload#>"
                    $ObjOut = "Error while validating $rname. $rname must not be empty."
                    $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                    Write-Output $output
                    Exit
                }       
            }
            return ($webapparr.Count)
        }
        Catch{          
            $ObjOut = "Error while Processing Resource Names and Types.`r`n$($Error[0].Exception.Message)`r`n<#BlobFileReadyForUpload#>"
            $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
            Write-Output $output
            Write-LogFile -FilePath $LogFilePath -LogText $ObjOut
            Exit
        }
        
    }
}

Process
{
    Validate-AllParameters

    $resourcecount = Validate-ParamResourceNamesandTypes
    # 1. Login to Azure subscription
    Login-ToAzureAccount

    $EndpointType = "AzureEndpoints"  
    $ProfileStatus = "Enabled"    
    $RelativeDnsName = $TrafficManagerProfileName  
    $Ttl=300   
    $MonitorPort=80 
    $MonitorPath = "/"

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

    #3. Check if Traffic Manager Profile exists. Create Traffic Manager Profile if it does not exist.

    Try
    {

        IF($MonitorProtocol -eq "HTTPS"){
            $MonitorPort = 443
        }
        Write-LogFile -FilePath $LogFilePath -LogText "Checking existance of Traffic Manager Profile '$TrafficManagerProfileName'"      
        $TMProfileCheck = $null
        $TMProfileCheck = Get-AzureRmTrafficManagerProfile -Name $TrafficManagerProfileName -ResourceGroupName $ResourceGroupName -ea SilentlyContinue
        IF($TMProfileCheck -ne $null){
            $count = $TMProfileCheck.Endpoints.Count
            IF($count -gt 0){
               Write-LogFile -FilePath $LogFilePath -LogText "Traffic Manager Profile already exists with $count End points"
            }
            ELSE{
                Write-LogFile -FilePath $LogFilePath -LogText "Traffic Manager Profile already exists. But It has no End points configured yet"
            }
        }
        Else{
             Try{
                 Write-LogFile -FilePath $LogFilePath -LogText "Creating $TrafficManagerProfileName Traffic Manager Profile."
                 $NewTmp = New-AzureRmTrafficManagerProfile -Name $TrafficManagerProfileName -ResourceGroupName $ResourceGroupName -ProfileStatus $ProfileStatus -RelativeDnsName $RelativeDnsName -Ttl $Ttl -TrafficRoutingMethod $TrafficRoutingMethod -MonitorProtocol $MonitorProtocol -MonitorPort $MonitorPort -MonitorPath $MonitorPath -ErrorAction Stop                        
                 Write-LogFile -FilePath $LogFilePath -LogText "Successfully Created Traffic Manager Profile $TrafficManagerProfileName"  
             }
             Catch{
                 $ObjOut = "Error while Creating Azure Traffic Manager Profile details.`r`n$($Error[0].Exception.Message)`r`n<#BlobFileReadyForUpload#>"
                 $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                 Write-Output $output
                 Write-LogFile -FilePath $LogFilePath -LogText $ObjOut
                 Exit            
            }                                       
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

     # 3. Add other steps as required.

    Try
    {
         Write-LogFile -FilePath $LogFilePath -LogText "Trying to Add $resourcecount End points to the '$TrafficManagerProfileName'"
         
         $resouorcesarr = $ResourceNamesandTypes.Split(',')
         $resourcecount1 = $resouorcesarr.Count
         $profile = Get-AzureRmTrafficManagerProfile -Name $TrafficManagerProfileName -ResourceGroupName $ResourceGroupName 
         
         foreach($i in $resouorcesarr){
            $resourcentype = $i.Split('|')
            $resourcename = $resourcentype[0]
            $resourcetype = $resourcentype[1]

            Try{
                  Write-LogFile -FilePath $LogFilePath -LogText "Trying to get Endpoint Resource '$resourcename'"                   
                  IF($resourcetype -eq "Microsoft.Web/sites"){
                      $azres = Get-AzureRmWebApp -Name $resourcename
                  }
                  ELSEIF($resourcetype -eq "Microsoft.Network/publicIPAddresses"){
                      $azres = Get-AzureRmResource | Where {$_.Name -eq $resourcename -and $_.ResourceType -eq  "Microsoft.Network/publicIPAddresses"}
                  }
                  ELSE{
                      $azres = Get-AzureRmResource | Where {$_.Name -eq $resourcename -and $_.ResourceType -eq  "Microsoft.ClassicCompute/domainNames"}
                  }
            }
            Catch{
                $ObjOut = "Error while Getting Endpoint Resource $resourcename.`r`n$($Error[0].Exception.Message)`r`n<#BlobFileReadyForUpload#>"
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
            Write-LogFile -FilePath $LogFilePath -LogText "Got Endpoint Resource '$endpointname'" 

            Try{
                 Write-LogFile -FilePath $LogFilePath -LogText "Creating '$resourcename' Endpoint."
                 $s = Add-AzureRmTrafficManagerEndpointConfig –EndpointName $resourcename –TrafficManagerProfile $profile –Type $EndpointType -TargetResourceId $id –EndpointStatus Enabled -EndpointLocation $azres.Location -ErrorAction Stop    
                 Write-LogFile -FilePath $LogFilePath -LogText "Successfully created $resourcename Endpoint."
                 
            }
            Catch{
                 $ObjOut = "Error while Adding Endpoint Resource '$resourcename' to Traffic Manager Profile.`r`n$($Error[0].Exception.Message)`r`n<#BlobFileReadyForUpload#>"
                 $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                 Write-Output $output
                 Write-LogFile -FilePath $LogFilePath -LogText $ObjOut
                 Exit       
            }  
         
         }  
         Try{
            Write-LogFile -FilePath $LogFilePath -LogText "Adding Endpoints to the Traffic Manager Profile '$TrafficManagerProfileName'."
            $result = Set-AzureRmTrafficManagerProfile –TrafficManagerProfile $profile -ErrorAction Stop
            Write-LogFile -FilePath $LogFilePath -LogText "Successfully added EndPoints to the Traffic Manager Profile '$TrafficManagerProfileName'."
         }
         Catch{
            $ObjOut = "Error while Adding End point configurations to the Traffic Manager Profile`r`n$($Error[0].Exception.Message)`r`n<#BlobFileReadyForUpload#>"
            $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
            Write-Output $output
            Write-LogFile -FilePath $LogFilePath -LogText $ObjOut
            Exit       
         }
         Write-LogFile -FilePath $LogFilePath -LogText "Successfully Configured End Points for this Traffic Manager Profile"
         $ObjOut = "Traffic Manager Profile is successfully created and Endpoints are configured Successfully"
         $output = (@{"Response" = [Array]$ObjOut; Status = "Success"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
         Write-Output $output

    }
    Catch
    {
        $ObjOut = "Error while Configuring Azure Traffic Manager Profile Endpoints.`r`n$($Error[0].Exception.Message)`r`n<#BlobFileReadyForUpload#>"
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