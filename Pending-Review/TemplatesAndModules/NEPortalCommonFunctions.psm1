<# Name the Log file based on script name
[DateTime]$LogFileTime = Get-Date
$FileTimeStamp = $LogFileTime.ToString("dd-MMM-yyyy_HHmmss")
$LogFileName = "$ClientID-$($MyInvocation.MyCommand.Name.Replace('.ps1',''))-$FileTimeStamp.log"
#>
$NEPortalFolder = "C:\NEPortal"
$ConfigFilePath = "$NEPortalFolder\NEPortalApp.Config"

Function Get-BlobURIForLogFile
{
    Try
    {
        $UC = Select-Xml -Path $ConfigFilePath -XPath configuration/appSettings -ErrorAction SilentlyContinue | Select -ExpandProperty Node | Select -ExpandProperty add
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
    Return "$($context.BlobEndPoint)$($Container)/$($LogFilename)"
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

# Check minumum required version of Azure PowerShell
Function Check-PowerShellVersion
{
    $AzurePSVersion = (Get-Module -ListAvailable -Name Azure -ErrorAction Stop).Version
    If($AzurePSVersion -gt 1.4)
    {
        Return $true
    }
    Else 
    {
        Return $false
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
