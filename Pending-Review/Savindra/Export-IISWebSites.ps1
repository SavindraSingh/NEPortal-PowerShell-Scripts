# NOTE: This script is written for manual execution. NOT for Diva/NE Portal.

[CmdletBinding()]
Param
(
    [Parameter(Mandatory,HelpMessage="Specify name/s of the WebSite/s you want to export.`r`nInput '*' if you want to export all Websites.")]
    [string[]]$IISWebSiteName = '*',

    [Parameter()]
    $OutputFolder = "C:\Temp\WebSitesBackup"
)

Begin
{
    Try
    {
        If(Test-Path $OutputFolder -ErrorAction SilentlyContinue) {}
        Else { (mkdir -Path $OutputFolder -Force -ErrorAction Stop) | Out-Null }
    }
    Catch
    {
        Write-Host "Error while creating output folder '$OutputFolder'.`r`n$($Error[0].Exception.Message)" -ForegroundColor Red
        Exit
    }
}

Process
{
    Try
    {
        (Import-Module WebAdministration -ErrorAction Stop -WarningAction SilentlyContinue) | Out-Null

        if ($IISWebSiteName -eq '*')
        {
            $IISWebSites = (Get-ChildItem -Path IIS:\Sites).Name

            foreach ($IISWebSite in $IISWebSites)
            {
                # %windir%\system32\inetsrv\appcmd list site “CustomWebsite” /config /xml > c:\customwebsite.xml
                $wsXml = & "$Env:windir\system32\inetsrv\appcmd.exe" "list" "site" "$IISWebSite" "/config" "/xml"
                $wsXml | Out-File "$OutputFolder\$IISWebSite.xml" -Encoding utf8
            }
        }
        Else
        {
            foreach ($IISWebSite in $IISWebSiteName)
            {
                $wsXml = & "$Env:windir\system32\inetsrv\appcmd.exe" "list" "site" "$IISWebSite" "/config" "/xml"
                $wsXml | Out-File "$OutputFolder\$IISWebSite.xml" -Encoding utf8
            }
        }
        Write-Host "Success: IISWebSite settings were exported successfully to '$OutputFolder'" -ForegroundColor Green
    }
    Catch
    {
        Write-Host "Error while exporting IISWebSite settings.`r`n$($Error[0].Exception.Message)" -ForegroundColor Red
        Exit
    }
}

End {}