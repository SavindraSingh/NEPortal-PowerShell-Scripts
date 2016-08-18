Try
{
    Stop-Process -Force -Id ((Get-WmiObject Win32_Service -Filter "Name='NEPortalLogUploader'").ProcessID) -ErrorAction Stop
}
Catch 
{
    Write-Output "Service not found in Running state!"
}
Try
{
    If((Get-WmiObject Win32_Service -Filter "Name='NEPortalLogUploader'").Delete().ReturnValue -eq 0)
    {
        Write-Output "Service uninstalled successfully!"
    }
    Else
    {
        Write-Output "Error while uninstalling service!"
    }
}
Catch
{
    Write-Output "Error while uninstalling service!`r`n$($Error[0].Exception.Message)"
}