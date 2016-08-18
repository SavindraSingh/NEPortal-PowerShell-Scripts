$ComputerName = hostname

#Importing SeverManager Module
Import-Module ServerManager

Try
{
    #Checking the existance of the web server role in this machine
    $GetWebServer = Get-WindowsFeature -Name Web-Server -ComputerName $ComputerName 

    If($GetWebServer.Installed -eq $false){
        #Installing Web-Server Role
        $InstallWebServer = Install-WindowsFeature -Name Web-Server -IncludeAllSubFeature -IncludeManagementTools -ComputerName $ComputerName 
        If($InstallWebServer.ExitCode -eq "Success"){
            Write-Output "Webserver Role and Features Installed Successfully."
        }    
        Else{
            Write-Output "Webserver Role and Features not Installed Successfully."
        }
    }

    Else{
        Write-Output "Webserver Role already exists in this computer '$ComputerName'."  
    }
}
Catch
{
    $ErrorMessage = $Error[0].Exception
    Write-Output "Error While Installing Webserver Role and Features.$ErrorMessage"
}