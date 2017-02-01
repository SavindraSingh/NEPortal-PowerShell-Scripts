<#
    .SYNOPSIS
    Script to add the application to the Azure AD for Rest API usage

    .DESCRIPTION
    Script to add the application to the Azure AD for Rest API usage

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

    .PARAMETER ApplicationURL
    Name of the Azure ARM resource group to use for this command.

    .PARAMETER ResourceGroupName
    Name of the Azure ARM resource group to use for this command.

    .INPUTS
    All parameter values in String format.

    .OUTPUTS
    String. Result of the command output.

    .NOTES
     Purpose of script: To add an application to AD
     Minimum requirements: Azure PowerShell Version 1.4.0
     Initially written by: Bhaskar Desharaju
     Update/revision History:
     =======================
     Updated by        Date            Reason
     ==========        ====            ======


    .EXAMPLE
    C:\PS> .\Add-ApplicationToAD.ps1 -ClientID 12345 -AzureUserNamer bhaskar@netenrich.com -AzurePassword Passw0rd1 -AzureSubscriptID ca68598c-ecc3-4abc-b7a2-1ecef33f278d
 -Location 'East Asia' -ResourceGroupName testgrp -AppDisplayName ContosoApp -ApplicationURL https://www.contoso.com -ApplicationHomePage https://www.contoso.com/example -Passowrd 123456789

    .EXAMPLE
    C:\PS> 

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
    [String]$AppDisplayName,

    [Parameter(ValueFromPipelineByPropertyName)]
    [String]$ApplicationURI, 

    [Parameter(ValueFromPipelineByPropertyName)]
    [String]$ApplocationHomePage, 

    [Parameter(ValueFromPipelineByPropertyName)]
    [String]$Password
)


Begin
{
    # Name the Log file based on script name
    [DateTime]$LogFileTime = Get-Date
    $FileTimeStamp = $LogFileTime.ToString("dd-MMM-yyyy_HHmmss")
    $LogFileName = "$ClientID-$($MyInvocation.MyCommand.Name.Replace('.ps1',''))-$FileTimeStamp.log"
    $LogFilePath = "C:\NEPortal\$LogFileName"

    $ScriptUploadConfig = $null
    Function Get-BlobURIForLogFile
    {
        Try
        {
            $UC = Select-Xml -Path "C:\NEPortal\NEPortalApp.Config" -XPath configuration/appSettings -ErrorAction SilentlyContinue | Select -ExpandProperty Node | Select -ExpandProperty add
            $UploadConfig = [ordered]@{}; $UC | % { $UploadConfig += @{ $_.key = $_.Value } }
            $Script:ScriptUploadConfig = [PSCustomObject]$UploadConfig

            $Container = $ScriptUploadConfig.Container
            $StorageAccName = $ScriptUploadConfig.StorageAccName
            $StorageAccKey = $ScriptUploadConfig.StorageAccKey

            ($context = New-AzureStorageContext -StorageAccountName $StorageAccName -StorageAccountKey $StorageAccKey -ErrorAction Stop) | Out-Null
        }
        Catch
        {
            Return "Error processing blob URI. Check if storage credentials are correct in 'C:\NEPortal\NEPortalApp.Config'"
        }
        Return "$($context.BlobEndPoint)$($ScriptUploadConfig.Container)/$($LogFilename)"
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
    If($AzurePSVersion -ge $ScriptUploadConfig.RequiredPSVersion)
    {
        Write-LogFile -FilePath $LogFilePath -LogText "Required version of Azure PowerShell is available."
    }
    Else 
    {
        $ObjOut = "Required version of Azure PowerShell not available. Stopping execution.`nDownload and install required version from: http://aka.ms/webpi-azps.`
        `r`nRequired version of Azure PowerShell is $($ScriptUploadConfig.RequiredPSVersion). Current version on host machine is $($AzurePSVersion.ToString())."
        $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"} | ConvertTo-Json).ToString().Replace('\u0027',"'")
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
                $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                Write-Output $output
                Exit
            }

            # Validate parameter: AzureUserName
            Write-LogFile -FilePath $LogFilePath -LogText "Validating Parameters: AzureUserName. Only ERRORs will be logged."
            If([String]::IsNullOrEmpty($AzureUserName))
            {
                Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. AzureUserName parameter value is empty.`r`n<#BlobFileReadyForUpload#>"
                $ObjOut = "Validation failed. AzureUserName parameter value is empty."
                $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                Write-Output $output
                Exit
            }

            # Validate parameter: AzurePassword
            Write-LogFile -FilePath $LogFilePath -LogText "Validating Parameters: AzurePassword. Only ERRORs will be logged."
            If([String]::IsNullOrEmpty($AzurePassword))
            {
                Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. AzurePassword parameter value is empty.`r`n<#BlobFileReadyForUpload#>"
                $ObjOut = "Validation failed. AzurePassword parameter value is empty."
                $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                Write-Output $output
                Exit
            }

            # Validate parameter: AzureSubscriptionID
            Write-LogFile -FilePath $LogFilePath -LogText "Validating Parameters: AzureSubscriptionID. Only ERRORs will be logged."
            If([String]::IsNullOrEmpty($AzureSubscriptionID))
            {
                Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. AzureSubscriptionID parameter value is empty.`r`n<#BlobFileReadyForUpload#>"
                $ObjOut = "Validation failed. AzureSubscriptionID parameter value is empty."
                $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                Write-Output $output
                Exit
            }

            # Validate parameter: Location
            Write-LogFile -FilePath $LogFilePath -LogText "Validating Parameters: Location. Only ERRORs will be logged."
            If([String]::IsNullOrEmpty($Location))
            {
                Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. Location parameter value is empty.`r`n<#BlobFileReadyForUpload#>"
                $ObjOut = "Validation failed. Location parameter value is empty."
                $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                Write-Output $output
                Exit
            }

            # Validate parameter: ResourceGroupName
            Write-LogFile -FilePath $LogFilePath -LogText "Validating Parameters: ResourceGroupName. Only ERRORs will be logged."
            If([String]::IsNullOrEmpty($ResourceGroupName))
            {
                Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. ResourceGroupName parameter value is empty.`r`n<#BlobFileReadyForUpload#>"
                $ObjOut = "Validation failed. ResourceGroupName parameter value is empty."
                $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                Write-Output $output
                Exit
            }

            # Validate parameter: AppDisplayName
            Write-LogFile -FilePath $LogFilePath -LogText "Validating Parameters: AppDisplayName. Only ERRORs will be logged."
            If([String]::IsNullOrEmpty($AppDisplayName))
            {
                Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. AppDisplayName parameter value is empty.`r`n<#BlobFileReadyForUpload#>"
                $ObjOut = "Validation failed. AppDisplayName parameter value is empty."
                $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                Write-Output $output
                Exit
            }

            # Validate parameter: ApplicationURI
            Write-LogFile -FilePath $LogFilePath -LogText "Validating Parameters: ApplicationURI. Only ERRORs will be logged."
            If([String]::IsNullOrEmpty($ApplicationURI))
            {
                Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. ApplicationURI parameter value is empty.`r`n<#BlobFileReadyForUpload#>"
                $ObjOut = "Validation failed. ApplicationURI parameter value is empty."
                $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                Write-Output $output
                Exit
            }

            # Validate parameter: ApplicationHomePage
            Write-LogFile -FilePath $LogFilePath -LogText "Validating Parameters: ApplocationHomePage. Only ERRORs will be logged."
            If([String]::IsNullOrEmpty($ApplocationHomePage))
            {
                Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. ApplocationHomePage parameter value is empty.`r`n<#BlobFileReadyForUpload#>"
                $ObjOut = "Validation failed. ApplocationHomePage parameter value is empty."
                $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                Write-Output $output
                Exit
            }

            # Validate parameter: Password
            Write-LogFile -FilePath $LogFilePath -LogText "Validating Parameters: Password. Only ERRORs will be logged."
            If([String]::IsNullOrEmpty($Password))
            {
                Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. Password parameter value is empty.`r`n<#BlobFileReadyForUpload#>"
                $ObjOut = "Validation failed. Password parameter value is empty."
                $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                Write-Output $output
                Exit
            }
        }
        Catch
        {
            Write-LogFile -FilePath $LogFilePath -LogText "Error while validating parameters: $($Error[0].Exception.Message)`r`n<#BlobFileReadyForUpload#>"
            $ObjOut = "Error while validating parameters: $($Error[0].Exception.Message)"
            $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"} | ConvertTo-Json).ToString().Replace('\u0027',"'")
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
            $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"} | ConvertTo-Json).ToString().Replace('\u0027',"'")
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

    # 2. Register application and Assign Roles.

    try 
    {
        Write-LogFile -FilePath $LogFilePath -LogText "Getting the Tenant ID.."
        ($TenantID = (Get-AzureRmSubscription -SubscriptionId $AzureSubscriptionID -ErrorAction SilentlyContinue -WarningAction SilentlyContinue).TenantId ) | Out-Null

        Write-LogFile -FilePath $LogFilePath -LogText "Checking for the Application URI existence in the subscription.."
        ($ExistingApps = Get-AzureRmADApplication -IdentifierUri $ApplicationURI -ErrorAction SilentlyContinue -WarningAction SilentlyContinue) | Out-Null
        if($ExistingApps -eq $null)
        {       
            ($NewAppStatus = New-AzureRmADApplication -DisplayName $AppDisplayName -IdentifierUris $ApplicationURI -HomePage $ApplocationHomePage -EndDate ($(Get-Date).AddDays(365)) -Password $Password -ErrorAction Stop -WarningAction SilentlyContinue) | Out-Null
            if($NewAppStatus -ne $null)
            {
                Write-LogFile -FilePath $LogFilePath -LogText "New application has been created successfully."
                $ApplicationID = $NewAppStatus.ApplicationId

                Write-LogFile -FilePath $LogFilePath -LogText "Creating the new Service Principal"
                ($NewServicePrincipal = New-AzureRmADServicePrincipal -ApplicationId $ApplicationID -ErrorAction Stop -WarningAction SilentlyContinue) | Out-Null
                if($NewServicePrincipal -ne $null)
                {
                    Write-LogFile -FilePath $LogFilePath -LogText "Service Principal has been created successfully."
                    Write-LogFile -FilePath $LogFilePath -LogText "Assigning AD Role permissions to the application."

                    ($RoleStatus = New-AzureRmRoleAssignment -RoleDefinitionName Reader -ServicePrincipalName $($NewAppStatus.ApplicationId.Guid) -ErrorAction Stop -WarningAction SilentlyContinue) | Out-Null

                    if($RoleStatus -ne $null)
                    {
                        Write-LogFile -FilePath $LogFilePath -LogText "Application has been created and added to Azure Active Directory.`r`n<#BlobFileReadyForUpload#>"
                        $ObjOut = "Application has been created and added to Azure Active Directory."
                        $output = (@{"Response" = [Array]$ObjOut; Status = "Success";TenantID = $TenantID; SubscriptionID = $AzureSubscriptionID; ApplicationID = $ApplicationID; SecretKey = $Password} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                        Write-Output $output
                    }
                    else
                    {
                        Write-LogFile -FilePath $LogFilePath -LogText "Application Registration was failed.`r`n<#BlobFileReadyForUpload#>"
                        $ObjOut = "Application Registration was failed."
                        $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                        Write-Output $output
                        Exit
                    }
                }
                Else
                {
                    Write-LogFile -FilePath $LogFilePath -LogText "Creating the New Service Principal was failed.`r`n<#BlobFileReadyForUpload#>"
                    $ObjOut = "Creating the New Service Principal was failed."
                    $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                    Write-Output $output
                    Exit                
                }
            }
            Else
            {
                Write-LogFile -FilePath $LogFilePath -LogText "Creating the New Application was failed.`r`n<#BlobFileReadyForUpload#>"
                $ObjOut = "Creating the New Application was failed."
                $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                Write-Output $output
                Exit
            }
        }
        else
        {
            Write-LogFile -FilePath $LogFilePath -LogText "Application with this URI $ApplicationURI is already exist.`r`n<#BlobFileReadyForUpload#>"
            $ObjOut = "Application with this URI $ApplicationURI is already exist."
            $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"} | ConvertTo-Json).ToString().Replace('\u0027',"'")
            Write-Output $output
            Exit            
        }
    }
    Catch
    {
        Write-LogFile -FilePath $LogFilePath -LogText "There was an exception in Creating and Adding the Application to Azure AD.$($Error[0].Exception.Message).`r`n<#BlobFileReadyForUpload#>"
        $ObjOut = "There was an exception in Creating and Adding the Application to Azure AD.$($Error[0].Exception.Message)."
        $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"} | ConvertTo-Json).ToString().Replace('\u0027',"'")
        Write-Output $output
        Exit
    }
}
End
{
    Write-LogFile -FilePath $LogFilePath -LogText "####[ Script execution completed Successfully: $($MyInvocation.MyCommand.Name) ]####`r`n<#BlobFileReadyForUpload#>"
}