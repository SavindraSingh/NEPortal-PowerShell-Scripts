<#
    .SYNOPSIS
    Script to create, edit and delete Azure SQL Server Firewall rules.

    .DESCRIPTION
    Script to create, edit and delete Azure SQL Server Firewall rules.

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

    .PARAMETER SQLServerName
    Name of the Azure SQL server Name for which you want to do firewall settings

    .PARAMETER RuleDetails
    Rule details. Format is"<RuleName>:<Starting IP Address>:<Ending IP Address>:<Action>". If you want to process multiple rules, then seperate rules with ","

    .INPUTS
    All parameter values in String format.

    .OUTPUTS

        {
        "Status":  "Failed",
        "BlobURI":  "https://nelogfiles.blob.core.windows.net/neportallogs/-Set-AzureSQLServerFirewallRules-09-Aug-2016_135553.log",
        "Response":  [
                         "Firewall rule 'r2' doesnot exists"
                     ]
        }
    


    .NOTES
     Purpose of script: To create,edit & Delete firewall rules
     Minimum requirements: Azure PowerShell Version 1.4.0
     Initially written by: Bindu
     Update/revision History:
     =======================
     Updated by        Date            Reason
     ==========        ====            ======
     Bindu             09-08-2016      

    .EXAMPLE
    C:\PS>  .\Set-AzureSQLServerFirewallRules.ps1 -ClientID 124 -AzureUserName himabindu.thati@netenrich.com -AzurePassword ****** -AzureSubscriptionID ca68598c-ecc3-4abc-b7a2-1ecef33f278d -ResourceGroupName todelete -SQLServerName sampleser -RuleDetails Rule1:1.2.3.4:2.3.4.5:c,Rule2:::d

    .EXAMPLE
    C:\PS> Import-Csv .\In.csv |.\ Set-AzureSQLServerFirewallRules.ps1

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
    [string]$ResourceGroupName,

    [Parameter(ValueFromPipelineByPropertyName)]
    [String]$SQLServerName,

    [Parameter(ValueFromPipelineByPropertyName)]
    [String]$RuleDetails
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
#    Write-Host $LogFileBlobURI

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

            # Validate parameter: SQLServerName
            Write-LogFile -FilePath $LogFilePath -LogText "Validating Parameters: SQLServerName. Only ERRORs will be logged."
            If([String]::IsNullOrEmpty($SQLServerName))
            {
                Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. SQLServerName parameter value is empty.`r`n<#BlobFileReadyForUpload#>"
                $ObjOut = "Validation failed. SQLServerName parameter value is empty."
                $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                Write-Output $output
                Exit
            }

            # Validate parameter: RuleDetails
            Write-LogFile -FilePath $LogFilePath -LogText "Validating Parameters: RuleDetails. Only ERRORs will be logged."
            If([String]::IsNullOrEmpty($RuleDetails))
            {
                Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. RuleDetails parameter value is empty.`r`n<#BlobFileReadyForUpload#>"
                $ObjOut = "Validation failed. RuleDetails value is empty."
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

    # 2. Checking if ResourceGroupName and SQLServerName exists

    try #resourceGroupName
    {
        Write-LogFile -FilePath $LogFilePath -LogText "Checking if Resource Group '$ResourceGroupName' exists"
        Get-AzureRmResourceGroup -Name $ResourceGroupName -ErrorAction Stop | Out-Null
        Write-LogFile -FilePath $LogFilePath -LogText "Resource Group '$ResourceGroupName' exists"
    }
    catch
    {
        $ObjOut = "Provided ResourceGroup '$ResourceGroupName' doesnt exists.`n$($Error[0].Exception.Message)`r`n<#BlobFileReadyForUpload#>"
        Write-LogFile -FilePath $LogFilePath -LogText $ObjOut
        $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
        Write-Output $output
        Exit
    }

    Try #SQLServerName
    {
        Write-LogFile -FilePath $LogFilePath -LogText "Checking if SQL Server '$SQLServerName' exists"
        Get-AzureRmSqlServer -ResourceGroupName $ResourceGroupName -ServerName $SQLServerName -ErrorAction Stop | Out-Null
        Write-LogFile -FilePath $LogFilePath -LogText "SQL Server '$SQLServerName' exists"
    }
    catch
    {
        $ObjOut = "Provided SQL Server '$SQLServerName' doesnt exists.`n$($Error[0].Exception.Message)"
        Write-LogFile -FilePath $LogFilePath -LogText "$ObjOut`r`n<#BlobFileReadyForUpload#>"
        $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
        Write-Output $output
        Exit        
    }
    # 3. Validating Rule Name, StartingIP, EndIP, Action values in RuleDetails parameter & updating Firewall Rules
    $Arr1 = $RuleDetails -split ","
    for($i=1;$i -le ($Arr1.length);$i++)
    {
        $Arry2 = $Arr1[$i-1] -split ":"
        If($Arry2.length -ne 4)
        {
            $ObjOut = "'"+$Arr1[$i-1]+"' Firewall rule details must have this format'RuleName:StatringIP:EndingIP:Action' If you want to process multiple rules then seperate with ',' "
            Write-LogFile -FilePath $LogFilePath -LogText "$ObjOut`r`n<#BlobFileReadyForUpload#>"
            $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
            Write-Output $output
            Exit
        }
        else
        {
            if([string]::IsNullOrWhiteSpace($Arry2[0]))
            {
                $ObjOut = "RuleName cannot be empty."
                Write-LogFile -FilePath $LogFilePath -LogText "$ObjOut`r`n<#BlobFileReadyForUpload#>"
                $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                Write-Output $output
                Exit
            }
            else
            {
                $ObjOut = "RuleName is '"+$Arry2[0]+"'"
                Write-LogFile -FilePath $LogFilePath -LogText $ObjOut
            }
            If([string]::IsNullOrWhiteSpace($Arry2[1]))
            {
                $ObjOut = "Starting IP address of rule name '"+$Arry2[0]+"'is null"
                Write-LogFile -FilePath $LogFilePath -LogText $ObjOut
            }
            else
            {
                If((($Arry2[1].Split('.')).length) -ne 4)
                {
                    $ObjOut = "Starting IPAddress '"+$Arry2[1]+"' is not valid.IPAddress must have Four octants"
                    Write-LogFile -FilePath $LogFilePath -LogText "$ObjOut`r`n<#BlobFileReadyForUpload#>"
                    $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                    Write-Output $output
                    exit
                }
                try
                {                    
                    $Arry2[1] -eq [ipaddress]$Arry2[1] | Out-Null
                }
                catch
                {
                    $ObjOut = "Starting IPAddress "+$Arry2[1]+" is not valid"
                    Write-LogFile -FilePath $LogFilePath -LogText "$ObjOut`r`n<#BlobFileReadyForUpload#>"
                    $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                    Write-Output $output
                    exit              
                }
            }
            If([string]::IsNullOrWhiteSpace($Arry2[2]))
            {
                $ObjOut = "Ending IP address of rule name '"+$Arry2[0]+"' is null"
                Write-LogFile -FilePath $LogFilePath -LogText $ObjOut
            }
            else
            {
                If((($Arry2[2].Split('.')).length) -ne 4)
                {
                    $ObjOut = "Ending IPAddress '"+$Arry2[2]+"' is not valid.IPAddress must have Four octants"
                    Write-LogFile -FilePath $LogFilePath -LogText "$ObjOut`r`n<#BlobFileReadyForUpload#>"
                    $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                    Write-Output $output
                    exit
                }
                try
                {
                    $Arry2[2] -eq [ipaddress]$Arry2[2] | Out-Null
                }
                catch
                {
                    $ObjOut = "Ending IPAddress "+$Arry2[2]+" is not valid"
                    Write-LogFile -FilePath $LogFilePath -LogText "$ObjOut`r`n<#BlobFileReadyForUpload#>"
                    $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                    Write-Output $output
                    exit              
                }
            }
            If([string]::IsNullOrWhiteSpace($Arry2[3]))
            {
                $ObjOut =  "Action is null. With out specifying action, cannot do any thing"
               Write-LogFile -FilePath $LogFilePath -LogText "$ObjOut`r`n<#BlobFileReadyForUpload#>"
               $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
               Write-Output $output
               exit
            }
            else
            {
                if(($Arry2[3] -eq "edit") -or($Arry2[3] -eq "e") -or ($Arry2[3] -eq "delete") -or($Arry2[3] -eq "d"))
                {
                    $ObjOut = "Checking if the firewall rule '"+$Arry2[0]+"' exists"
                    Write-LogFile -FilePath $LogFilePath -LogText $ObjOut
                    Try
                    {
                        Get-AzureRmSqlServerFirewallRule -ResourceGroupName $ResourceGroupName -ServerName $SQLServerName -FirewallRuleName $Arry2[0] -ErrorAction Stop | Out-Null
                        $ObjOut = "Firewall rule '"+$Arry2[0]+"' exists"                                                        
                        Write-LogFile -FilePath $LogFilePath -LogText $ObjOut
                    }
                    catch
                    {
                        $ObjOut =  "Firewall rule '"+$Arry2[0]+"' doesnot exists" 
                        Write-LogFile -FilePath $LogFilePath -LogText "$ObjOut`r`n<#BlobFileReadyForUpload#>"
                        $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                        Write-Output $output
                        exit                                                                        
                    }
                    if(($Arry2[3] -eq "edit") -or($Arry2[3] -eq "e"))
                    {
                        Try
                        {
                            $ObjOut = "Updating firewall rule '"+$Arry2[0]+"'"
                            Write-LogFile -FilePath $LogFilePath -LogText $ObjOut
                            set-AzureRmSqlServerFirewallRule -ResourceGroupName $ResourceGroupName -ServerName $SQLServerName -FirewallRuleName $Arry2[0] `
                                                     -StartIpAddress $Arry2[1] -EndIpAddress $Arry2[2] -ErrorAction Stop | Out-Null 
                            $ObjOut = "Updated server rule with Parameters:
                                                                           Rulename: '"+$Arry2[0]+"'
                                                                           Starting IP: '"+$Arry2[1]+"'
                                                                           Ending IP: '"+$Arry2[2]+"'"                                                     
                            Write-LogFile -FilePath $LogFilePath -LogText "$ObjOut`r`n<#BlobFileReadyForUpload#>" 
                            $ObjOut = "Successfully Edited firewall rules."
                            $output = (@{"Response" = [Array]$ObjOut; Status = "Success"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                            Write-Output $output
                            exit                                                                                                  
                        }
                        catch
                        {
                            $ObjOut = "Failed to update firewall rules.`n$($Error[0].Exception.Message) "
                            Write-LogFile -FilePath $LogFilePath -LogText "$ObjOut`r`n<#BlobFileReadyForUpload#>"
                            $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                            Write-Output $output
                            exit                            
                        }

                    }
                    If(($Arry2[3] -eq "delete") -or($Arry2[3] -eq "d"))
                    {
                        Try
                        {
                            $ObjOut = "Deleting firewall rule '"+$Arry2[0]+"'"
                            Write-LogFile -FilePath $LogFilePath -LogText $ObjOut
                            Remove-AzureRmSqlServerFirewallRule -ResourceGroupName $ResourceGroupName -ServerName $SQLServerName -FirewallRuleName $Arry2[0] `
                                                                -Force -ErrorAction Stop | Out-Null 
                            $ObjOut =  "Deleted firewall rule with: Rulename: '"+$Arry2[0]+"'"   
                            Write-LogFile -FilePath $LogFilePath -LogText "$ObjOut`r`n<#BlobFileReadyForUpload#>"
                            #$ObjOut = "Successfully deleted firewall rules."
                            $output = (@{"Response" = [Array]$ObjOut; Status = "Success"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                            Write-Output $output
                            exit                                                                                                                                                                                             
                        }
                        catch
                        {
                            $ObjOut = "Failed to delete firewall rules.`n$($Error[0].Exception.Message) "
                            Write-LogFile -FilePath $LogFilePath -LogText "$ObjOut`r`n<#BlobFileReadyForUpload#>"
                            $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                            Write-Output $output
                            exit                            
                        }
                    }
                }
                elseif(($Arry2[3] -eq "create") -or($Arry2[3] -eq "c"))
                {
                    Try
                    {
                        $ObjOut = "Creating firewall rule '"+$Arry2[0]+"'"
                        Write-LogFile -FilePath $LogFilePath -LogText $ObjOut
                        New-AzureRmSqlServerFirewallRule -ResourceGroupName $ResourceGroupName -ServerName $SQLServerName -FirewallRuleName $Arry2[0] `
                                                         -StartIpAddress $Arry2[1] -EndIpAddress $Arry2[2] -ErrorAction Stop | Out-Null
                        $ObjOut = "Created server rule with Parameters:
                                                                       Rulename: '"+$Arry2[0]+"'
                                                                       Starting IP: '"+$Arry2[1]+"'
                                                                       Ending IP: '"+$Arry2[2]+"'"                                            
                        Write-LogFile -FilePath $LogFilePath -LogText "$ObjOut`r`n<#BlobFileReadyForUpload#>"
                        $ObjOut = "Successfully created firewall rules."
                        $output = (@{"Response" = [Array]$ObjOut; Status = "Success"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                        Write-Output $output
                        exit                            
                    }
                    catch
                    {
                        $ObjOut = "Failed to create firewall rules.`n$($Error[0].Exception.Message) "
                        Write-LogFile -FilePath $LogFilePath -LogText "$ObjOut`r`n<#BlobFileReadyForUpload#>"
                        $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                        Write-Output $output
                        exit                            
                    }
                }
                else
                {
                    ObjOut = "Invalid Action '"+$Arry2[3]+"' provided. Action must be 'delete/d or edit/e or create/c'" 
                    Write-LogFile -FilePath $LogFilePath -LogText "$ObjOut`r`n<#BlobFileReadyForUpload#>"           
                    $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                    Write-Output $output
                    exit                                                
                }
            }
        }
    }
}
End
{
    Write-LogFile -FilePath $LogFilePath -LogText "####[ Script execution completed cuccessfully: $($MyInvocation.MyCommand.Name) ]####`r`n<#BlobFileReadyForUpload#>"
}



                 
                    

                   
