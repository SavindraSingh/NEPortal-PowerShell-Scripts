# Checking the pre-reqs
# Check the MARS Agent installation
# Check .Net Framework Status
# Check the VM Cores

$InstallCode = 0
$FrameWorkCode = 0
$VMCores = 0

try 
{
    ($InstalledStatus = Get-WmiObject -Class Win32_Product -ErrorAction SilentlyContinue -WarningAction SilentlyContinue) | Out-Null
    if($InstalledStatus.Name.Contains("Microsoft Azure Recovery Services Agent"))
    {
        Write-Output "Microsoft Azure Recovery Services Agent installed. Please remove the agent for MABS"
        $InstallCode =1
    }

    ($DNetFeature = Get-WindowsFeature -Name 'NET-Framework-Features' -ErrorAction SilentlyContinue -warningAction SilentlyContinue) | Out-Null
    if($DNetFeature.Installed -eq $false)
    {
        Write-Output ".Net Framework 3.5 was not Installed"
        $FrameWorkCode = 1
    }

    ($Memory = Get-WmiObject -class Win32_ComputerSystem -ErrorAction SilentlyContinue -warningAction SilentlyContinue) | Out-Null
    $MemInGb = ((($($Memory.TotalPhysicalMemory)/1024)/1024)/1024)
    if($MemInGb -lt 3.5)
    {
        Write-Output "Physical Memory does not meet the requirement"
        $VMCores = 1
    }

    if(($InstallCode -eq 0) -and ($FrameworkCode -eq 0) -and ($VMCores -eq 0))
    {
        Write-Output "All Pre-requisites are met the requirement"
    }
    else 
    {
        Write-Output "All Pre-requisites are not met the requirement. Pre-Check is failed."
    }    
}
catch [System.Exception] 
{
    Write-Output "There was an exception while checking the pre-requisites. $($error[0].Exception.Message)"
}
