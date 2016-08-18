<#
    .SYNOPSIS 
        This script will Enable Geo replication for already existing SQL DB

    .DESCRIPTION
        This script will Enable Geo replication for already existing SQL DB. It will also create Secondary SQL server if it not 
        existed(If required parameters provided only) and then creates New SQL DB as a copy of primary SQL DB. 

    .PARAMETER ClientID
        ClientID of the client for whom the script is being executed

    .PARAMETER AzureUserName
        Give the Azure Account Username for Login into your Azure Account

    .PARAMETER AzurePassword
        Give the Azure Account Password for Login into your Azure Account

    .PARAMETER AzureSubscriptionID
        Give the Azure Account SubscriptionID for Login into your Azure Account

    .PARAMETER SecondaryServerRG
        Name of the server Resource Group in which you have/want your Secondary SQL Server

    .PARAMETER SecondaryServerName
        Name of the SQL server that will act as Secondary

    .PARAMETER SecondarySQLAdminUser
        Secondary SQL server admin user name

    .PARAMETER SecondarySQLAdminPassword
        Secondary SQL Server admin Password

    .PARAMETER SecondaryServerLocation
        Name of the Location in which you have/Want-To-Create your Secondary SQL Server

    .PARAMETER PrimaryServerRG
        Name of Primary SQL Server Resource Group 

    .PARAMETER PrimaryServerName
        Name of Primary Server Name

    .PARAMETER PrimaryDBName
        Name of DB for which You want to create Geo copy

    .PARAMETER ReadableOrNon
        If you want to create Geo copy as Readable or not.Input Values 'All' or 'No'.Default Value is 'No'
        
    .INPUTS
        All parameter values in String format.

    .OUTPUTS
        {
        "Status":  "XXXXXX",
        "BlobURI":  "https://nelogfiles.blob.core.windows.net/neportallogs/1257-ConfigureTrafficManagerforAzureEPs2-28-Jul-2016_1
    73648.log",
        "Response":  [
                         "********"
                     ]
        }


    .NOTES
     Purpose of script: enables Geo replicaiton for SQL DB.
     Minimum requirements: Azure PowerShell Version 1.4.0
     Initially written by: Bindu
     Update/revision History:
     =======================
     Updated by    Date      Reason
     ==========    ====      ======
     Bindu         28-7-2016 


    .EXAMPLE
    C:\PS> .\Geo_Enable.ps1 -Customer-AzureUserName xxxxxxxxxx -AzurePassword xxxxxxxxx -AzureSubscriptionID XXXXXXXXXXXXXX -SecondaryServerRG secondaryRG -SecondaryServerName SecServer -SecondarySQLAdminUser adminuser -SecondarySQLAdminPassword adminpassword -SecondaryServerLocation "East Asia" -PrimaryServerRG primaryrg -PrimaryServerName primaryser -PrimaryDBName firstdb -ReadableOrNon All 
     

    .EXAMPLE
    C:\PS>  Import-csv XXX.csv | .\Geo_Enable.ps1

    .LINK
    http://www.netenrich.com/
#>


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
    [string]$PrimaryServerRG,

    [Parameter(ValueFromPipelineByPropertyName)]
    [string]$PrimaryServerName,

    [Parameter(ValueFromPipelineByPropertyName)]
    [string]$PrimaryDBName,

    [Parameter(ValueFromPipelineByPropertyName)]
    [string]$SecondaryServerLocation,

    [Parameter(ValueFromPipelineByPropertyName)]
    [string]$SecondaryServerRG,

    [Parameter(ValueFromPipelineByPropertyName)]
    [string]$SecondaryServerName,

    [Parameter(ValueFromPipelineByPropertyName)]
    [string]$SecondarySQLAdminUser,

    [Parameter(ValueFromPipelineByPropertyName)]
    [string]$SecondarySQLAdminPassword,

    [Parameter(ValueFromPipelineByPropertyName)]
    [validateset("All","No")]
    [string]$ReadableOrNon,

    [string]$FlagSL = 1,
 
    [String]$FlagSRG = 1,

    [String]$FlagSUN = 1,

    [String]$FlagSP = 1 

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

            #Validate parameter: PrimaryServerRG
            Write-LogFile -FilePath $LogFilePath -LogText "Validating Parameters: PrimaryServerRG. Only ERRORs will be logged."
            If([String]::IsNullOrEmpty($PrimaryServerRG))
            {
                Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. PrimaryServerRG parameter value is empty.`r`n<#BlobFileReadyForUpload#>"
                $ObjOut = "Validation failed. PrimaryServerRG parameter value is empty."
                $output = (@{"Response" = [Array]$ObjOut; "Status" = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                Write-Output $output
                Exit
            }

            #Validate parameter: PrimaryServerName
            Write-LogFile -FilePath $LogFilePath -LogText "Validating Parameters: PrimaryServerName Only ERRORs will be logged."
            If([String]::IsNullOrEmpty($PrimaryServerName))
            {
                Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. PrimaryServerName parameter value is empty.`r`n<#BlobFileReadyForUpload#>"
                $ObjOut = "Validation failed. PrimaryServerName parameter value is empty."
                $output = (@{"Response" = [Array]$ObjOut; "Status" = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                Write-Output $output
                Exit
            }

            #Validate parameter: PrimaryDBName
            Write-LogFile -FilePath $LogFilePath -LogText "Validating Parameters: PrimaryDBName Only ERRORs will be logged."
            If([String]::IsNullOrEmpty($PrimaryDBName))
            {
                Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. PrimaryDBName parameter value is empty.`r`n<#BlobFileReadyForUpload#>"
                $ObjOut = "Validation failed. PrimaryDBName parameter value is empty."
                $output = (@{"Response" = [Array]$ObjOut; "Status" = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                Write-Output $output
                Exit
            }

            #Validate parameter: SecondaryServerLocation
            $FlagSL=1
            Write-LogFile -FilePath $LogFilePath -LogText "Validating Parameter: SecondaryServerLocation Only ERRORs will be logged."
            If([String]::IsNullOrEmpty($SecondaryServerLocation))
            {
                Write-LogFile -FilePath $LogFilePath -LogText "SecondaryServerLocation parameter value is empty"
                $Script:FlagSL = 0                
            }

            #Validate parameter: SecondaryServerRG
            Write-LogFile -FilePath $LogFilePath -LogText "Validating Parameters: SecondaryServerRG Only ERRORs will be logged."
            If([String]::IsNullOrEmpty($SecondaryServerRG))
            {
                Write-LogFile -FilePath $LogFilePath -LogText "SecondaryServerRG parameter value is empty."
                $Script:FlagSRG = 0
            }

            #Validate parameter: SecondaryServerName
            Write-LogFile -FilePath $LogFilePath -LogText "Validating Parameters: SecondaryServerName Only ERRORs will be logged."
            If([String]::IsNullOrEmpty($SecondaryServerName))
            {
                Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. SecondaryServerName parameter value is empty.`r`n<#BlobFileReadyForUpload#>"
                $ObjOut = "Validation failed. SecondaryServerName parameter value is empty."
                $output = (@{"Response" = [Array]$ObjOut; "Status" = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                Write-Output $output
                Exit
            }

            #Validate parameter: SecondarySQLAdminUser
            Write-LogFile -FilePath $LogFilePath -LogText "Validating Parameters: SecondarySQLAdminUser Only ERRORs will be logged."
            If([String]::IsNullOrEmpty($SecondarySQLAdminUser))
            {
                Write-LogFile -FilePath $LogFilePath -LogText "SecondarySQLAdminUser parameter value is empty."
                $Script:FlagSUN = 0
                
            }

            #Validate parameter: SecondarySQLAdminPassword
            $FlagSP = 1
            Write-LogFile -FilePath $LogFilePath -LogText "Validating Parameters: SecondarySQLAdminPassword Only ERRORs will be logged."
            If([String]::IsNullOrEmpty($SecondarySQLAdminPassword))
            {
                Write-LogFile -FilePath $LogFilePath -LogText "SecondarySQLAdminPassword parameter value is empty."
                $Script:FlagSP = 0
                
            }

            #Validate parameter: ReadableOrNon
            Write-LogFile -FilePath $LogFilePath -LogText "Validating Parameters: ReadableOrNon Only ERRORs will be logged."
            If([String]::IsNullOrEmpty($ReadableOrNon))
            {
                Write-LogFile -FilePath $LogFilePath -LogText "ReadableOrNon parameter value is empty. Taking Default Value 'No'"
                $Script:ReadableOrNon = "No"                
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
            $ObjOut = "Error logging in to Azure Account.`n$($Error[0].Exception.Message)"
            Write-LogFile -FilePath $LogFilePath -LogText "$ObjOut`r`n<#BlobFileReadyForUpload#>"
            $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
            Write-Output $output
            Exit
        }
    }

    #To check if Secondary SQL server is exists
    Function Check-SecondaryServer($SecSerName, $SecRG)
    {
        Try
        {
            #Write-host $SecSerName 
            #write-host $SecRG
            Write-LogFile -FilePath $LogFilePath -LogText "Checking if Secondary SQL server existed" 
            $CheckSSN = 1
            Get-AzureRmSqlServer -ResourceGroupName $SecRG -ServerName $SecSerName -ErrorAction Stop | Out-null
            Write-LogFile -FilePath $LogFilePath -LogText "Secondary SQL Server Existed"
        }
        Catch
        {
            Write-LogFile -FilePath $LogFilePath -LogText "Secondary SQL Server does not Exists"
            $CheckSSN =0
            return $CheckSSN
        }

    }

    #To create Secondary SQL Server
    Function Create-SecondaryServer($SecSerName, $SecRG, $Loc, $UserName, $Passwd)
    {
        Try
        {
            Write-LogFile -FilePath $LogFilePath -LogText "Creating Secondary SQL Server with the Parameters::
                                                           ServerName: '$SecSerName'
                                                           ResourceGroup: '$SecRG'
                                                           Location: '$Loc'
                                                           UserName: '$UserName'"
            
            $SecurePass = ConvertTo-SecureString $Passwd -AsPlainText -Force
            $PSCred = New-Object System.Management.Automation.PSCredential($UserName, $SecurePass)
            New-azurermsqlserver -ServerName $SecondaryServerName `
                                 -ResourceGroupName $SecondaryServerRG `
                                 -Location $SecondaryServerLocation `
                                 -SqlAdministratorCredentials $PSCred `
                                 -ServerVersion $ServerVersion -ErrorAction Stop | Out-Null
            
            Write-LogFile -FilePath $LogFilePath -LogText "Successfully created of Secondary SQL server"
        }
        catch
        {
            $ObjOut = "Secondary SQL Server creation Failed.`n$($Error[0].Exception.Message)"
            Write-LogFile -FilePath $LogFilePath -LogText "$ObjOut`r`n<#BlobFileReadyForUpload#>"
            $output = (@{"Response" = [Array]$ObjOut; "Status" = "Failed; BlobURI = $LogFileBlobURI"} | ConvertTo-Json).ToString().Replace('\u0027',"'")
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

    #Validating Name of the Location:
    If($FlagSL -eq 1)
    {
        Try
        {
            
            ($temp = Get-AzureRmLocation | Select -Property "Location" -ErrorAction Stop) |Out-Null
            $temp1 = $SecondaryServerLocation -replace '\s',''
            $temp2 = $temp | foreach{$($_.Location)}
            
            if($temp2 -notcontains $temp1)
            {
                $ObjOut = "Location name Does not Exist."
                Write-LogFile -FilePath $LogFilePath -LogText "$ObjOut`r`n<#BlobFileReadyForUpload#>"
                $output = (@{"Response" = [Array]$ObjOut; "Status" = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                Write-Output $output
                Exit 
            }
        }
        catch
        {
            $ObjOut = "$($Error[0].Exception.Message)"
            Write-LogFile -FilePath $LogFilePath -LogText "$ObjOut`r`n<#BlobFileReadyForUpload#>"
            $output = (@{"Response" = [Array]$ObjOut; "Status" = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
            Write-Output $output
            Exit  
        }
    }

    <#--------------------------------------------------------------------
     2. Checking the existence of Primary SQL server RG, Primary SQL Server & Primary SQL Server DB 
    -------------------------------------------------------------------------#>

    Try  #Primary DB RG
    {
        Write-LogFile -FilePath $LogFilePath -LogText "Checking if Primary DB RG Existed"
        $ChkPrimary = Get-AzureRmResourceGroup -ResourceGroupName $PrimaryServerRG -ErrorAction Stop | Out-Null
        Write-LogFile -FilePath $LogFilePath -LogText "Primary DB RG existed"
    }
    catch
    {
        
       $ObjOut = "Primary DB RG Does not exist. Cannot Proceed further."
       Write-LogFile -FilePath $LogFilePath -LogText "$ObjOut`r`n<#BlobFileReadyForUpload#>" 
       $output = (@{"Response" = [Array]$ObjOut; "Status" = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
       Write-Output $output
       Exit
    }
    
    Try #Primary DB Server  
    {
        Write-LogFile -FilePath $LogFilePath -LogText "Checking if Primary DB Server Existed"
        $ChkPrimary = Get-AzureRmSqlServer -ResourceGroupName $PrimaryServerRG -ServerName $PrimaryServerName -ErrorAction Stop | Out-Null
        Write-LogFile -FilePath $LogFilePath -LogText "Primary DB Server existed"
    }
    catch
    {
        
       $ObjOut = "Primary DB Server doesnot Exist. Cannot proceed further."
       Write-LogFile -FilePath $LogFilePath -LogText "$ObjOut`r`n<#BlobFileReadyForUpload#>"
       $output = (@{"Response" = [Array]$ObjOut; "Status" = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
       Write-Output $output
       Exit
    }

    Try  #Primary DB  
    {
        Write-LogFile -FilePath $LogFilePath -LogText "Checking if Primary DB Existed"
        $ChkPrimary = Get-AzureRmSqlDatabase -ResourceGroupName $PrimaryServerRG -ServerName $PrimaryServerName `
                                                                                 -DatabaseName $PrimaryDBName `
                                                                                 -ErrorAction Stop | Out-Null
        Write-LogFile -FilePath $LogFilePath -LogText "Primary DB existed"
    }
    catch
    {
        
       $ObjOut = "Primary DB doesnot Exist. Cannot proceed further"
       Write-LogFile -FilePath $LogFilePath -LogText "$ObjOut`r`n<#BlobFileReadyForUpload#>"
       $output = (@{"Response" = [Array]$ObjOut; "Status" = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
       Write-Output $output
       Exit
    }
    $ServerVersion = (Get-AzureRmSqlServer -ServerName $PrimaryServerName -ResourceGroupName $PrimaryServerRG -ErrorAction Stop).ServerVersion 

    <#--------------------------------------------
     3. Creating Secondary Server if not exists
    --------------------------------------------#>
    If(($FlagSL -eq 0) -and ($FlagSRG -eq 0))
    {
       Write-LogFile -FilePath $LogFilePath -LogText "condition1" 
       $ObjOut = "Cannot Proceed further without 'SecondaryServerLocation' and 'SecondaryServerRG'."
       Write-LogFile -FilePath $LogFilePath -LogText "$ObjOut`r`n<#BlobFileReadyForUpload#>"
       $output = (@{"Response" = [Array]$ObjOut; "Status" = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
       Write-Output $output
       Exit        
    }
    Elseif(($FlagSL -eq 0) -and ($FlagSRG -eq 1))
    {
        Write-LogFile -FilePath $LogFilePath -LogText "condition2"
        Try
        {
            Get-AzureRmResourceGroup -Name $SecondaryServerRG -ErrorAction Stop | Out-Null
        }
        Catch
        {
            $ObjOut = "Resource Group with '$SecondaryServerRG' does not exist."
            Write-LogFile -FilePath $LogFilePath -LogText "$ObjOut`r`n<#BlobFileReadyForUpload#>"
            $output = (@{"Response" = [Array]$ObjOut; "Status" = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
            Write-Output $output
            Exit            
        }
        $temp = Check-SecondaryServer -SecSerName $SecondaryServerName -SecRG $SecondaryServerRG
        If($temp -eq 0)
        {
            $ObjOut = "Cannot create Secondary SQL Server without 'SecondaryServerLocation' Parameter."
            Write-LogFile -FilePath $LogFilePath -LogText "$ObjOut`r`n<#BlobFileReadyForUpload#>"
            $output = (@{"Response" = [Array]$ObjOut; "Status" = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
            Write-Output $output
            Exit 
        }         
    }
    Else
    {
        Write-LogFile -FilePath $LogFilePath -LogText "condition3"
        If((($FlagSL -eq 1) -and ($FlagSRG -eq 0)))
        {
            Write-LogFile -FilePath $LogFilePath -LogText "Secondary RG not provided, So using Primary Server RG('$PrimaryServerRG') as Secondary" 
            Write-LogFile -FilePath $LogFilePath -LogText "condition3.1"
            $SecondaryServerRG = $PrimaryServerRG 
        }
        Else
        {
            Try
            {
                Write-LogFile -FilePath $LogFilePath -LogText "checking if Secondary server RG('$SecondaryServerRG') valid or not"
                Get-AzureRmResourceGroup -Name $SecondaryServerRG -ErrorAction stop | Out-Null
                Write-LogFile -FilePath $LogFilePath -LogText "Secondary server RG exists."
            }
            catch
            {
                Write-LogFile -FilePath $LogFilePath -LogText "Secondary Server Rg does not Exists. Creating RG with Parameters::
                                                                                                    RG Name: '$SecondaryServerRG'
                                                                                                    RG Location: '$SecondaryServerLocation' "
                Try
                {
                    New-AzureRmResourceGroup -Name $SecondaryServerRG -Location $SecondaryServerLocation -ErrorAction Stop | Out-Null
                    Write-LogFile -FilePath $LogFilePath -LogText "Secondary Server RG creation Success"
                }
                catch
                {
                    $ObjOut = "Unable to create Secondary Server RG.`n$($Error[0].Exception.Message)."
                    Write-LogFile -FilePath $LogFilePath -LogText "$ObjOut`r`n<#BlobFileReadyForUpload#>"
                    $output = (@{"Response" = [Array]$ObjOut; "Status" = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                    Write-Output $output
                    Exit                    
                }
            }
        }        
        $temp = Check-SecondaryServer -SecSerName $SecondaryServerName -SecRG $SecondaryServerRG
        If($temp -eq 0)
        {

            If(($FlagSUN -eq 1) -and ($FlagSP -eq 1))
            {
                Create-SecondaryServer -SecSerName $SecondaryServerName -SecRG $SecondaryServerRG `
                                                                        -Loc $SecondaryServerLocation `
                                                                        -UserName $SecondarySQLAdminUser `
                                                                       -Passwd $SecondarySQLAdminPassword                
            }
            Else
            {
                $ObjOut = "Cannot create Secondary SQL Server without 'SecondarySQLAdminUser' and 'SecondarySQLAdminPassword' Parameter."
                Write-LogFile -FilePath $LogFilePath -LogText "$ObjOut`r`n<#BlobFileReadyForUpload#>"
                $output = (@{"Response" = [Array]$ObjOut; "Status" = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                Write-Output $output
                Exit                
                
            }
        }
    }

    <#-------------------------------------------------------
    4. Creating Geo-Enabled copy of Primary Azure SQL DB
    --------------------------------------------------------#>

    Write-Logfile -FilePath $LogFilePath -LogText "Creating Geo enabled (Secondary)copy of primary DB with Parameters::
                                                                 Primary SQL Server RG Name: '$PrimaryServerRG'
                                                                 Primary SQL Server Name: '$PrimaryServerName'
                                                                 Primary SQL Server DB: '$PrimaryDBName'
                                                                 Secondary SQL Server RG Name: '$SecondaryServerRG'
                                                                 Secondary SQL Server Name: '$SecondaryServerName'
                                                                 Secondary Server Readable(ALL) or not?: '$ReadableOrNon'" 
    #Write-host $ReadableOrNon
    Try
    {
        New-AzureRmSqlDatabaseSecondary -DatabaseName $PrimaryDBName -ResourceGroupName $PrimaryServerRG `
                                        -ServerName $PrimaryServerName -PartnerResourceGroupName $SecondaryServerRG `
                                        -PartnerServerName $SecondaryServerName -AllowConnections $ReadableOrNon -ErrorAction Stop | Out-Null
        $ObjOut = "Secondary DB created Successfully."
        Write-Logfile -FilePath $LogFilePath -LogText $ObjOut
    }
    catch
    {
        $ObjOut = "Geo enabled copy of DB Failed.`n$($Error[0].Exception.Message)."
        Write-LogFile -FilePath $LogFilePath -LogText "$ObjOut`r`n<#BlobFileReadyForUpload#>"
        $output = (@{"Response" = [Array]$ObjOut; "Status" = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
        Write-Output $output
        Exit
    }

    <#-----------   
     5. Testing
    -------------#>

    Try
    {
        ($temp =Get-AzureRmSqlDatabase -ResourceGroupName $SecondaryServerRG `
                                       -ServerName $SecondaryServerName `
                                       -DatabaseName $PrimaryDBName -ErrorAction Stop) | Out-Null
                      
        
        if(($temp.Status) -eq "Online")
        {
            $ObjOut = "Secondary DataBase is Online"
            Write-LogFile -FilePath $LogFilePath -LogText $ObjOut
            Try
            {
                ($temp=Get-AzureRmSqlDatabaseReplicationLink -ResourceGroupName $PrimaryServerRG `
                                                            -ServerName $PrimaryServerName -DatabaseName $PrimaryDBName `
                                                            -PartnerResourceGroupName $SecondaryServerRG `
                                                            -PartnerServerName $SecondaryServerName -ErrorAction Stop) | Out-Null
                
                If ((($temp.PartnerRole) -eq "Secondary") -or (($temp.PartnerRole) -eq "NonReadableSecondary"))
                {
                    $ObjOut = "Successfully Created Geo Replication.Testing completed."
                    Write-LogFile -FilePath $LogFilePath -LogText "$ObjOut`r`n<#BlobFileReadyForUpload#>"
                    $output = (@{"Response" = [Array]$ObjOut; "Status" = "Success"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")                    
                    Write-Host $output
                    Exit
                }
                else
                {
                    $ObjOut = "Testing failed. Secondary DB role is not showing as Secondary"
                    Write-LogFile -FilePath $LogFilePath -LogText "$ObjOut`r`n<#BlobFileReadyForUpload#>"
                    $output = (@{"Response" = [Array]$ObjOut; "Status" = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")                    
                    Write-Host $output
                    Exit
                }                  
            }
            catch
            {
                $ObjOut = "Testing failed. Unable to Get replicaiton link. `n$($Error[0].Exception.Message)"
                Write-LogFile -FilePath $LogFilePath -LogText "$ObjOut`r`n<#BlobFileReadyForUpload#>"
                $output = (@{"Response" = [Array]$ObjOut; "Status" = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")                    
                Write-Host $output
                Exit   
            }
                
        }
        Else
        {
            $ObjOut = "Testing failed. Secondary DB is not online"
            Write-LogFile -FilePath $LogFilePath -LogText "$ObjOut`r`n<#BlobFileReadyForUpload#>"
            $output = (@{"Response" = [Array]$ObjOut; "Status" = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")                    
            Write-Host $output
            Exit
        }                          
    }
    catch
    {
        $ObjOut = "Testing failed. Unable to Get Secondary DB"
        Write-LogFile -FilePath $LogFilePath -LogText "$ObjOut`r`n<#BlobFileReadyForUpload#>" 
        $output = (@{"Response" = [Array]$ObjOut; "Status" = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")                   
        Write-Host $output
        Exit
    }

}
End
{
    Write-LogFile -FilePath $LogFilePath -LogText "####[ Script execution completed cuccessfully: $($MyInvocation.MyCommand.Name) ]####`r`n<#BlobFileReadyForUpload#>"
}