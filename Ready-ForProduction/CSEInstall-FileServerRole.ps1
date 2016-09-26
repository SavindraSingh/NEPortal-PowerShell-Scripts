# Parameters from the script in a comma seperated form. This works for Windows 2012 and above

try
{
    # Installing ServerManager Module
    Import-Module ServerManager
    #Installing the Active Directory and Domain Services roles
    (Install-WindowsFeature -name AD-Domain-Services -IncludeManagementTools -ErrorAction Stop -WarningAction SilentlyContinue) | Out-Null

    $RoleStatus = Get-WindowsFeature -Name "AD*"
    if($RoleStatus -ne $null)
    {
        # Configuring the Active Directory and Domain Services
        ($DomainStatus = Install-ADDSForest -DomainName $DomainName -safemodeadministratorpassword $SecurePassword -domainnetbiosname $DomainNetBiosName -databasepath $DatabasePath -logpath $LogfilePath -sysvolpath $SysVolume -DomainMode $DomainMode -skipprechecks -SkipAutoConfigureDNS -InstallDns -Force -ErrorAction Stop -WarningAction SilentlyContinue) | Out-Null   
        # Importing the Active Directory Module
        Import-Module ActiveDirectory
        $DomainDetails = (Get-ADDomain).DNSRoot
        If($DomainDetails -ne $null)
        {
            Write-Output "Active Directory forest has been configured with $DomainDetails successfully"
        }
        Else
        {
            Write-Output "Active Directory forest was not configured successfully"
        }
    }
    Else
    {
        Write-Output "Active Directory Domain Services role was not installed successfully"
    }
}
catch
{
    Write-Output "There was an error in Installing and Configuring the Active Directory"
}