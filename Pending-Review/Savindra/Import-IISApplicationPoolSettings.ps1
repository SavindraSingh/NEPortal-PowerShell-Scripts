[CmdletBinding()]
Param
(
    [Parameter(Mandatory,HelpMessage='File or folder path where AppPool settings XML files are located.')]
    [string[]]$ApplicationPoolSettingsPath
)

Begin
{
        If(Test-Path $ApplicationPoolSettingsPath -ErrorAction SilentlyContinue) {}
        Else
        {
            Write-Host "Path not found '$ApplicationPoolSettingsPath'" -ForegroundColor Red
            Exit
        }
}

Process
{
    Try
    {
        (Import-Module WebAdministration -ErrorAction Stop -WarningAction SilentlyContinue) | Out-Null
        
        $PathToAppCmd = "$Env:windir\system32\inetsrv\appcmd.exe"
        $CommandOutput += @{}
        If((Get-Item $ApplicationPoolSettingsPath -ErrorAction SilentlyContinue) -is [System.IO.DirectoryInfo])
        {
            $AppPoolSettingFiles = (Get-ChildItem -Path $ApplicationPoolSettingsPath | Where { $_.Extension -eq '.xml' }).FullName

            foreach ($AppPoolSettingFile in $AppPoolSettingFiles)
            {
                $ImportResult = type $AppPoolSettingFile | .$PathToAppCmd add apppool /in
                Try { $CommandOutput += @{$AppPoolSettingFile = $ImportResult} } Catch {}
                If($ImportResult -like "ERROR*")
                {
                    Write-Host "ERROR while importing app pool settings file '$AppPoolSettingFile':`r`n`t`t$ImportResult"
                }
                Else
                {
                    Write-Host "Success: AppPool settings were imported successfully from '$AppPoolSettingFile'." -ForegroundColor Green
                }
            }
        }
        Else
        {
            $AppPoolSettingFile = $ApplicationPoolSettingsPath
            $ImportResult = type $AppPoolSettingFile | .$PathToAppCmd add apppool /in
            Try { $CommandOutput += @{$AppPoolSettingFile = $ImportResult} } Catch {}
            
            If($ImportResult -like "ERROR*")
            {
                    Write-Host "ERROR while importing app pool settings file '$AppPoolSettingFile':`r`n`t`t$ImportResult"
            }
            Else
            {
                Write-Host "Success: AppPool settings were imported successfully from '$AppPoolSettingFile'." -ForegroundColor Green
            }
       }
    }
    Catch
    {
        Write-Host "Error while Importing AppPool settings.`r`n$($Error[0].Exception.Message)" -ForegroundColor Red
        Exit
    }
}

End {}