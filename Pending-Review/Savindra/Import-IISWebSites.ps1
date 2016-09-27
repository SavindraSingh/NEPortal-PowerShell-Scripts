# NOTE: This script is written for manual execution. NOT for Diva/NE Portal.

[CmdletBinding()]
Param
(
    [Parameter(Mandatory,HelpMessage='File or folder path where IISWebSite settings XML files are located.')]
    [string[]]$IISWebSiteSettingsPath
)

Begin
{
        If(Test-Path $IISWebSiteSettingsPath -ErrorAction SilentlyContinue) {}
        Else
        {
            Write-Host "Path not found '$IISWebSiteSettingsPath'" -ForegroundColor Red
            Exit
        }
}

Process
{
    Try
    {
        (Import-Module WebAdministration -ErrorAction Stop -WarningAction SilentlyContinue) | Out-Null
 
        # %windir%\system32\inetsrv\appcmd.exe add site /in < c:\customwebsite.xml       
        $PathToAppCmd = "$Env:windir\system32\inetsrv\appcmd.exe"
        $CommandOutput += @{}
        If((Get-Item $IISWebSiteSettingsPath -ErrorAction SilentlyContinue) -is [System.IO.DirectoryInfo])
        {
            $IISWebSiteSettingFiles = (Get-ChildItem -Path $IISWebSiteSettingsPath | Where { $_.Extension -eq '.xml' }).FullName

            foreach ($IISWebSiteSettingFile in $IISWebSiteSettingFiles)
            {
                $ImportResult = type $IISWebSiteSettingFile | .$PathToAppCmd add site /in
                Try { $CommandOutput += @{$IISWebSiteSettingFile = $ImportResult} } Catch {}
                If($ImportResult -like "ERROR*")
                {
                    Write-Host "ERROR while importing IIS WebSite settings file '$IISWebSiteSettingFile':`r`n`t`t$ImportResult"
                }
                Else
                {
                    Write-Host "Success: IISWebSite settings were imported successfully from '$IISWebSiteSettingFile'." -ForegroundColor Green
                }
            }
        }
        Else
        {
            $IISWebSiteSettingFile = $IISWebSiteSettingsPath
            $ImportResult = type $IISWebSiteSettingFile | .$PathToAppCmd add site /in
            Try { $CommandOutput += @{$IISWebSiteSettingFile = $ImportResult} } Catch {}
            
            If($ImportResult -like "ERROR*")
            {
                    Write-Host "ERROR while importing IIS WebSite settings file '$IISWebSiteSettingFile':`r`n`t`t$ImportResult"
            }
            Else
            {
                Write-Host "Success: IISWebSite settings were imported successfully from '$IISWebSiteSettingFile'." -ForegroundColor Green
            }
       }
    }
    Catch
    {
        Write-Host "Error while Importing IISWebSite settings.`r`n$($Error[0].Exception.Message)" -ForegroundColor Red
        Exit
    }
}

End {}