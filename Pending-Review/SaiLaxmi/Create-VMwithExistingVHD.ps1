<#
    .SYNOPSIS
    Script to Create Azure ARM VM with existing VHD.

    .DESCRIPTION
    Script to Create Azure ARM VM with existing VHD.

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

    .PARAMETER VMName
        Give the Virtual Machine Name.

    .PARAMETER VMSize
        Give the Virtual Machine Size.

    .PARAMETER VnetName
        Give the Virtual Network Name.

    .PARAMETER SubnetName
        Give the Subnet name

    .PARAMETER OSDiskUri
        Give the Existing VHD Uri

    .INPUTS

    .\Create-VMwithExistingVHD.ps1 -ClientID 1246 -AzureUserName sailakshmi.penta@netenrich.com -AzurePassword *********
     -AzureSubscriptionID ca68598c-ecc3-4abc-b7a2-1ecef33f278d -Location "East US 2" -ResourceGroupName "testrg" 
     -VMName "samplevm" -VMSize Standard_A1 -VnetName testrg-vnet -SubnetName default 
     -OSDiskUri "https://testrgdiag229.blob.core.windows.net/vhds/testvm12201672495151.vhd"

    .OUTPUTS
     {
        "Status":  "Success",
        "BlobURI":  "https://nelogfiles.blob.core.windows.net/neportallogs/1246-Create-VMwithExistingVHD-24-Aug-2016_114324.log",
    
        "Response":  [
                         "Successfully created VM 'samplevm' with the existing OSDisk."
                     ]
    }
 

    .NOTES
     Purpose of script: Template for Azure Script to Create Azure ARM VM with existing VHD.
     Minimum requirements: Azure PowerShell Version 1.4.0
     Initially written by: P S L Prasanna.
     Update/revision History:
     =======================
     Updated by        Date            Reason
     ==========        ====            ======
     PSLPrasanna     14-05-2016        Hackthon
     PSLPrasanna     24-08-2016        Change the script according to new Azure Template

    .EXAMPLE
    .\Create-VMwithExistingVHD.ps1 -ClientID 1246 -AzureUserName sailakshmi.penta@netenrich.com -AzurePassword *********
     -AzureSubscriptionID ca68598c-ecc3-4abc-b7a2-1ecef33f278d -Location "East US 2" -ResourceGroupName "testrg" 
     -VMName "samplevm" -VMSize Standard_A1 -VnetName testrg-vnet -SubnetName default 
     -OSDiskUri "https://testrgdiag229.blob.core.windows.net/vhds/testvm12201672495151.vhd"
   
    WARNING: The output object type of this cmdlet will be modified in a future release.
    {
        "Status":  "Success",
        "BlobURI":  "https://nelogfiles.blob.core.windows.net/neportallogs/1246-Create-VMwithExistingVHD-24-Aug-2016_114324.log",
    
        "Response":  [
                         "Successfully created VM 'samplevm' with the existing OSDisk."
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
    [string]$VnetName,

    [Parameter(ValueFromPipelineByPropertyName)]
    [string]$SubnetName,

    [Parameter(ValueFromPipelineByPropertyName)]
    [string]$VMName,

    [Parameter(ValueFromPipelineByPropertyName)]
    [string]$VMSize,

    [Parameter(ValueFromPipelineByPropertyName)]
    [string]$OSDiskUri
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

            # Validate parameter: VNetName
            Write-LogFile -FilePath $LogFilePath -LogText "Validating Parameters: VNetName. Only ERRORs will be logged."
            If([String]::IsNullOrEmpty($VNetName))
            {
                Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. VNetName parameter value is empty.`r`n<#BlobFileReadyForUpload#>"
                $ObjOut = "Validation failed. VNetName parameter value is empty."
                $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                Write-Output $output
                Exit
            }

            # Validate parameter: SubnetName
            Write-LogFile -FilePath $LogFilePath -LogText "Validating Parameters: SubnetName. Only ERRORs will be logged."
            If([String]::IsNullOrEmpty($SubnetName))
            {
                Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. SubnetName parameter value is empty.`r`n<#BlobFileReadyForUpload#>"
                $ObjOut = "Validation failed. SubnetName parameter value is empty."
                $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                Write-Output $output
                Exit
            }

            # Validate parameter: VMName
            Write-LogFile -FilePath $LogFilePath -LogText "Validating Parameters: VMName. Only ERRORs will be logged."
            If([String]::IsNullOrEmpty($VMName))
            {
                Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. VMName parameter value is empty.`r`n<#BlobFileReadyForUpload#>"
                $ObjOut = "Validation failed. VMName parameter value is empty."
                $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                Write-Output $output
                Exit
            }

            # Validate parameter: VMSize
            Write-LogFile -FilePath $LogFilePath -LogText "Validating Parameters: VMSize. Only ERRORs will be logged."
            If([String]::IsNullOrEmpty($VMSize))
            {
                Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. VMSize parameter value is empty.`r`n<#BlobFileReadyForUpload#>"
                $ObjOut = "Validation failed. VMSize parameter value is empty."
                $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                Write-Output $output
                Exit
            }

            If($VMSize.Length -ne 0){
                 Write-LogFile -FilePath $LogFilePath -LogText "Validating Parameters: VMSize. Only ERRORs will be logged."
                 $arr = "Standard_A1","Standard_A2","Standard_A3","Standard_A4","Standard_A5","Standard_A6","Standard_A7","Standard_A8","Standard_A9","Standard_A10","Standard_A11","Standard_D1","Standard_D2","Standard_D3","Standard_D4","Standard_D5","Standard_D5","Standard_D6","Standard_D7","Standard_D8","Standard_D9","Standard_D10","Standard_D11","Standard_D12","Standard_D13","Standard_D14","Standard_D1_v2","Standard_D2_v2","Standard_D3_v2","Standard_D4_v2","Standard_D4_v2","Standard_D5_v2","Standard_D6_v2","Standard_D7_v2","Standard_D8_v2","Standard_D9_v2","Standard_D10_v2","Standard_D11_v2","Standard_D12_v2","Standard_D13_v2","Standard_D14_v2","Standard_D15_v2","Standard_DS1","Standard_DS2","Standard_DS3","Standard_DS4","Standard_DS5","Standard_DS6","Standard_DS7","Standard_DS8","Standard_DS9","Standard_DS10","Standard_DS11","Standard_DS12","Standard_DS13","Standard_DS14","Standard_DS15","Standard_DS16","Standard_G1","Standard_G2","Standard_G3","Standard_G4","Standard_G5","Standard_GS1","Standard_GS2","Standard_GS3","Standard_GS4","Standard_GS5"

                 If($arr -notcontains $VMSize){
                    Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. PerformanceTear '$VMSize' is NOT a valid value for this parameter.`r`n<#BlobFileReadyForUpload#>"
                    $ObjOut = "Validation failed. PerformanceTear '$VMSize' is not a valid value for this parameter."
                    $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                    Write-Output $output
                    Exit
                 }
                 
            }

            # Validate parameter: OSDiskUri
            Write-LogFile -FilePath $LogFilePath -LogText "Validating Parameters: OSDiskUri. Only ERRORs will be logged."
            If([String]::IsNullOrEmpty($OSDiskUri))
            {
                Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. OSDiskUri parameter value is empty.`r`n<#BlobFileReadyForUpload#>"
                $ObjOut = "Validation failed. OSDiskUri parameter value is empty."
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

    Login-ToAzureAccount
   
    $NICName = "$VMName-Nic"
    # 1. Check if Resource Group exists. Create Resource Group if it does not exist.
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

    # 2. Checking the existance of the Virtual Network
    Try
    {
       Write-LogFile -FilePath $LogFilePath -LogText "Checking the existance of the Vnet"
       $vnetcheck = Get-AzureRmVirtualNetwork -Name $VnetName -ResourceGroupName $ResourceGroupName -ea Stop
       IF($vnetcheck){
           Write-LogFile -FilePath $LogFilePath -LogText "'$VnetName' Vnet does exists."
       }
    }
    Catch
    {
        $ObjOut = "Error while getting Azure Virtual Network details.`r`n$($Error[0].Exception.Message)`r`n<#BlobFileReadyForUpload#>"
        $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
        Write-Output $output
        Write-LogFile -FilePath $LogFilePath -LogText $ObjOut
        Exit
    }

    # 3. Checking the existance of the Subnet
    Try
    {
       Write-LogFile -FilePath $LogFilePath -LogText "Checking the existance of the Subnet"
       $subnetcheck = Get-AzureRmVirtualNetworkSubnetConfig -Name $SubnetName -VirtualNetwork $vnetcheck -ea Stop             
       IF($subnetcheck){
           Write-LogFile -FilePath $LogFilePath -LogText "'$SubnetName' Subnet does exists."
       }
    }
    Catch
    {
        $ObjOut = "Error while getting Subnet details.`r`n$($Error[0].Exception.Message)`r`n<#BlobFileReadyForUpload#>"
        $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
        Write-Output $output
        Write-LogFile -FilePath $LogFilePath -LogText $ObjOut
        Exit
    }

    # 4. Check if NIC exists. Create NIC if it does not exist.
    Try
    {
        Write-LogFile -FilePath $LogFilePath -LogText "Checking the existance of the NIC"
        $Nic = Get-AzureRmNetworkInterface -Name $NICName -ResourceGroupName $ResourceGroupName -ea SilentlyContinue
        IF($Nic){
            Write-LogFile -FilePath $LogFilePath -LogText "'$NICName' NIC does exists."
        }
        ELSE{
            Try{
                Write-LogFile -FilePath $LogFilePath -LogText "Trying to create '$NICName' NIC."
                $Nic = New-AzureRmNetworkInterface -Name $NICName -ResourceGroupName $ResourceGroupName -Location $Location -SubnetId $subnetcheck.Id -ErrorAction Stop
                IF($Nic){
                    Write-LogFile -FilePath $LogFilePath -LogText "Successfully Created '$NICName' NIC."
                }
            }
            Catch
            {
                $ObjOut = "Error while creating NIC.`r`n$($Error[0].Exception.Message)`r`n<#BlobFileReadyForUpload#>"
                $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                Write-Output $output
                Write-LogFile -FilePath $LogFilePath -LogText $ObjOut
                Exit
            }
        }
    }
    Catch
    {
        $ObjOut = "Error while getting NIC details.`r`n$($Error[0].Exception.Message)`r`n<#BlobFileReadyForUpload#>"
        $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
        Write-Output $output
        Write-LogFile -FilePath $LogFilePath -LogText $ObjOut
        Exit
    }

    #5. Creating VM with the existing VHD
    Try
    {
        Write-LogFile -FilePath $LogFilePath -LogText "Checking the existance of the VM Name"
        $VMNamecheck = Get-AzureRmVM -Name $VMName -ResourceGroupName $ResourceGroupName -ea SilentlyContinue
        IF($VMNamecheck){
               $ObjOut = "Checked that already vm with that name existed.`r`n<#BlobFileReadyForUpload#>"
               $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
               Write-Output $output
               Write-LogFile -FilePath $LogFilePath -LogText $ObjOut
               Exit
        }
        ELSE{

            Try
            {
                Write-LogFile -FilePath $LogFilePath -LogText "Trying to Create Configuration file for vm '$VMName'."
                $vm = New-AzureRmVMConfig -Name $VMName -VMSize $VMSize -ErrorAction Stop
                Write-LogFile -FilePath $LogFilePath -LogText "Successfully Created Configuration file for vm '$VMName'."

                Write-LogFile -FilePath $LogFilePath -LogText "Trying to Add Network Interface to VM Configurations."
                $vm = Add-AzureRmVMNetworkInterface -VM $vm -Id $Nic.Id
                Write-LogFile -FilePath $LogFilePath -LogText "Successfully Added Network Interface to VM Configurations."

                Write-LogFile -FilePath $LogFilePath -LogText "Trying set existing OS disk to VM Configurations."
                $vm = Set-AzureRmVMOSDisk -VM $vm -Name $VMName -VhdUri $OSDiskUri -CreateOption attach -Windows
                Write-LogFile -FilePath $LogFilePath -LogText "Successfully set existing OS disk to VM Configurations."
                
                Write-LogFile -FilePath $LogFilePath -LogText "Trying to create VM '$VMName' with the existing OSDisk."
                $nvm = New-AzureRmVM -ResourceGroupName $ResourceGroupName -Location $Location -VM $vm 
                Write-LogFile -FilePath $LogFilePath -LogText "Successfully created VM '$VMName' with the existing OSDisk."

                $ObjOut = "Successfully created VM '$VMName' with the existing OSDisk."
                $output = (@{"Response" = [Array]$ObjOut; Status = "Success"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                Write-Output $output
            }
            Catch
            {
                $ObjOut = "Error while Creating VM '$VMName'.`r`n$($Error[0].Exception.Message)`r`n<#BlobFileReadyForUpload#>"
                $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                Write-Output $output
                Write-LogFile -FilePath $LogFilePath -LogText $ObjOut
                Exit
            }
        } 
    }
    Catch
    {
        $ObjOut = "Error while getting Virtual Machine details.`r`n$($Error[0].Exception.Message)`r`n<#BlobFileReadyForUpload#>"
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