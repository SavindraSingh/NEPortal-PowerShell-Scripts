# Parameters from the script in a comma seperated form. This works for Windows 2012 and above
# Domain Name for Additional DC
$DomainName = $args[0]
# Domin Admin UserName
$DomainAdmin = $args[1]
# Password string for the Domain Admin
$Password = $args[2]

# Hardcoded values for the AD
$DatabasePath = "C:\Windows\NTDS"
$LogfilePath = "C:\Windows\NTDS"
$SysVolume = "C:\Windows\SYSVOL"
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
        $SecurePassword = ConvertTo-SecureString -AsPlainText -String $Password -Force
        $Credential = New-Object System.Management.Automation.PSCredential($DomainAdmin,$SecurePassword)
        ($DomainStatus = Install-ADDSDomainController -InstallDns -Credential $Credential -DomainName $DomainName -CreateDnsDelegation:$false -DatabasePath $DatabasePath -logpath $LogfilePath -sysvolpath $SysVolume -SafeModeAdministratorPassword $SecurePassword -Confirm:$false -ErrorAction Stop -WarningAction SilentlyContinue) | Out-Null   
        # Importing the Active Directory Module
        Import-Module ActiveDirectory
        $DomainDetails = (Get-ADDomain).DNSRoot
        If($DomainDetails -ne $null)
        {
            Write-Output "Additional Domain controller has been configured with $DomainDetails successfully"
        }
        Else
        {
            Write-Error "Additional Domain controller has not been configured successfully"
        }
    }
    Else
    {
        Write-Error "Active Directory Domain Services role was not installed successfully"
    }
}
catch
{
    Write-Error "There was an error in Installing and Configuring the Active Directory"
}