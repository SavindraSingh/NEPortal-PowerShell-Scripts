# Parameters from the script in a comma seperated form. This works for Windows 2012 and above

Try
{
    # Installing ServerManager Module
    Import-Module ServerManager
    #Installing the Web Server (IIS) role
    If((Get-WindowsFeature -Name web-server -ErrorAction SilentlyContinue).InstallState -ne 'Installed')
    {
        Try
        {
            ($InstallationResult = Install-WindowsFeature -Name web-server -IncludeAllSubFeature -IncludeManagementTools -ErrorAction Stop -WarningAction SilentlyContinue) | Out-Null

            if ($InstallationResult.Success)
            {
                $RestartStatus = if ($InstallationResult.RestartNeeded -eq 'Yes') { 'requires Restart.' } else { 'does not require Restart.'}
                Write-Output "SUCCESS: IIS role successfully installed on this Server. The server $RestartStatus"
            }
            else
            {
                Write-Output "ERROR: Unable to install IIS role successfully. Check server event logs for details."
            }
        }
        catch
        {
            Write-Output "ERROR: Unable to install IIS role. Reason: $($Error[0].Exception.Message)."
        }
    }
    else
    {
        Write-Output "SUCCESS: IIS role was already installed on this Server."
    }
}
Catch
{
    Write-Output "ERROR: There was an error in Installing IIS Web Server role."
}