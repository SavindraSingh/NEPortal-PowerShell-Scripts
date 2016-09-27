[CmdletBinding()]
Param
(
    [Parameter(Mandatory)]
    [string[]]$ApplicationPoolName = '*'
)

Begin
{
    $OutputFolder = "C:\Temp\AppPoolBackup"
    Try
    {
        If(Test-Path $OutputFolder -ErrorAction SilentlyContinue) {}
        Else { (mkdir -Path $OutputFolder -Force -ErrorAction Stop) | Out-Null }
    }
    Catch
    {
        Write-Host "Error while creating output folder 'C:\Temp\AppPoolBackup'.`r`n$($Error[0].Exception.Message)" -ForegroundColor Red
        Exit
    }
}

Process
{
    Try
    {
        (Import-Module WebAdministration -ErrorAction Stop -WarningAction SilentlyContinue) | Out-Null

        if ($ApplicationPoolName -eq '*')
        {
            $AppPools = (Get-ChildItem -Path IIS:\AppPools).Name

            foreach ($AppPool in $AppPools)
            {
                $APXml = & "$Env:windir\system32\inetsrv\appcmd.exe" "list" "apppool" "$AppPool" "/config" "/xml"
                $APXml | Out-File "$OutputFolder\$AppPool.xml" -Encoding utf8
            }
        }
        Else
        {
            foreach ($AppPool in $ApplicationPoolName)
            {
                $APXml = & "$Env:windir\system32\inetsrv\appcmd.exe" "list" "apppool" "$AppPool" "/config" "/xml"
                $APXml | Out-File "$OutputFolder\$AppPool.xml" -Encoding utf8
            }
        }
        Write-Host "Success: AppPool settings were exported successfully to '$OutputFolder'" -ForegroundColor Green
    }
    Catch
    {
        Write-Host "Error while exporting AppPool settings.`r`n$($Error[0].Exception.Message)" -ForegroundColor Red
        Exit
    }
}

End {}