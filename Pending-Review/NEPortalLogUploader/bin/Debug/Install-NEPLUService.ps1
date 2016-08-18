Try
{
    Write-Host "Installing service 'NEPortal Log Uploader'.." -ForegroundColor Green
    Try
    {
	$ScriptPath = Split-path $MyInvocation.MyCommand.Source
	Set-Location -Path $ScriptPath
	New-Service -Name 'NEPortalLogUploader' -BinaryPathName (Get-ChildItem .\NEPortalLogUploader.exe).FullName -DisplayName 'NEPortal Log Uploader' `
        -Description 'Uploads the log files available in local logs folder to Azure Blob' -StartupType 'Automatic' -ErrorAction Stop

        Write-Host "Service installed successfully!" -ForegroundColor Green
    }
    Catch
    {
        Write-Host "Error while installing service!`r`n$($Error[0].Exception.Message)" -ForegroundColor Red
    }

    Try
    {
        Write-Host "Starting service..." -ForegroundColor Green
        Start-Service -Name 'NEPortalLogUploader' -ErrorAction Stop
        Write-Host "Service started successfully!" -ForegroundColor Green -NoNewline
    }
    Catch
    {
        Write-Host "Error while starting service!`r`n$($Error[0].Exception.Message)" -ForegroundColor Red
    }
}
Catch
{
    Write-Host "Error while installing/starting service!`r`n$($Error[0].Exception.Message)" -ForegroundColor Red
}
