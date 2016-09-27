$IISResetResult = invoke-command -scriptblock {iisreset}

Write-Output "$($IISResetResult | Out-String)"