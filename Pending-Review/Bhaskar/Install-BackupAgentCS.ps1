# Installing the Microsoft Azure Recovery Services Agent for Backup

$AgentUrl = "http://aka.ms/azurebackup_agent"
$DestinationPath = "C:\MARSAgent.exe"

try 
{
    $DownloadObj = New-Object System.Net.Webclient
    $DownloadObj.DownloadFile($AgentUrl,$DestinationPath)

    ($CurrentStatus = Get-WmiObject -Class Win32_Product -ErrorAction SilentlyContinue -WarningAction SilentlyContinue) | Out-Null
    if($CurrentStatus.Name.Contains("Microsoft Azure Recovery Services Agent"))
    {
        #
    }
    Else
    {
        if(Test-Path $DestinationPath)
        {
            ($APSInstaller = Start-Process -FilePath $DestinationPath -ArgumentList "/q /nu" -PassThru -ErrorAction Stop -WarningAction SilentlyContinue) | Out-Null 
            Do
            {
                Start-Sleep -Seconds 5
            } While(-not($APSInstaller.HasExited))

            if($APSInstaller.ExitCode -eq 0)        
            {
                ($InstalledStatus = Get-WmiObject -Class Win32_Product -ErrorAction SilentlyContinue -WarningAction SilentlyContinue) | Out-Null
                if($InstalledStatus.Name.Contains("Microsoft Azure Recovery Services Agent"))
                {
                    ($Service = Get-Service -Name 'obengine' -ErrorAction SilentlyContinue -WarningAction SilentlyContinue) | Out-Null
                    if($Service.Status -ne 'Running')
                    {
                        $Service.Start()
                    }
                }
                else 
                {
                    Write-Output "MARS Agent was not Installed properly."
                }
            }
            Else
            {
                Write-Output "MARS Agent Installation failed. $($Error[0].Exception.Message)"
            }
        }
        else 
        {
            Write-Output "MARS Agent was not downloaded. $($Error[0].Exception.Message)"        
        }
    }     
}
catch 
{
    Write-Output "There was an exception while installing the MARS Agent. $($Error[0].Exception.Message)"    
} 