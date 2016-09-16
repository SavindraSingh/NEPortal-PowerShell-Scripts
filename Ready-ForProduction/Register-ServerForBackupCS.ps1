# Registering the server with backup vault for protection
# Pre-req: MARS Agent must be installaed prior to this

# Valut Credentials content
$VaultCredsUrl = $args[0]
# Passphrase for encryption
$Passphrase = $args[1]

$SAS1 = $args[2]
$SAS2 = $args[3]
$SAS3 = $args[4]
$SAS4 = $args[5]
$SAS5 = $args[6]
$SAS6 = $args[7]

try
{
    $downloadUrl = $VaultCredsUrl + $SAS1 +"&"+ $SAS2 +"&"+ $SAS3 +"&"+ $SAS4 +"&"+ $SAS5 +"&"+$SAS6
    $downloadUrl | Out-File -FilePath C:\bloburl.txt -Force
    $DownloadObj = New-Object System.Net.WebClient
    $DownloadObj.DownloadFile("$downloadUrl","C:\BackupVaultCredentials.VaultCredentials")

    if(Test-Path "C:\BackupVaultCredentials.VaultCredentials")
    {
        $ExtModule = "C:\Program Files\Microsoft Azure Recovery Services Agent\bin\Modules\MSOnlineBackup\MSOnlineBackup.psd1"
        if(Test-Path $ExtModule)
        {
            Import-Module $ExtModule
            ($state = Start-OBRegistration -VaultCredentials "C:\BackupVaultCredentials.VaultCredentials" -Confirm:$false -ErrorAction Stop -WarningAction SilentlyContinue) | Out-Null
            if($state -and ($state[-1] -eq 'Machine registration succeeded.'))
            {
                $Setfile = $Passphrase | Out-File -FilePath C:\Passphrase.txt -Force
                ($SetPassPhrase = ConvertTo-SecureString -AsPlainText -Force -String $Passphrase | Set-OBMachineSetting -ErrorAction Stop -WarningAction SilentlyContinue) | Out-Null
                if($SetPassPhrase -eq 'Server properties updated successfully.')
                {
                    #
                }
                else 
                {
                    Write-Output "Setting the Passphrase for encryption was failed."  
                }
            }
            else
            {
                Write-Output "Machine registration was failed"
            }
        }
        Else 
        {
            Write-Output "the MARS Agent Module was not installed."
        }
    }
    else 
    {
        Write-Output "Vault Credential files was not created."
    }
} 
catch 
{
    Write-Output "There was an exception while registering the machine for backup.$($Error[0].Exception.Message)"
}