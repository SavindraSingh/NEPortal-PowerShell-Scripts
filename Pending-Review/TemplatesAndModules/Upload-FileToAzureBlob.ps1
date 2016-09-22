Function Upload-LogFileToBlob
{
    Param
    (
        [Parameter(Mandatory,ValueFromPipeline)]
        $UploadFilePath,
        $Container = "customscriptfiles",
        $StorageAccName = "automationtest",
        $StorageAccKey = "CxUZnWGoisXssYljud3i13ei8WB06PXvXWE2vfV3TSptF4iO3DT1wxzr2/JnqLleVMNhQMkQqSrdUcgkJwaTjg=="
    )

    Try
    {
        ($context = New-AzureStorageContext -StorageAccountName $StorageAccName -StorageAccountKey $StorageAccKey -ErrorAction Stop) | Out-Null

        (Set-AzureStorageBlobContent -File $UploadFilePath -Container $Container -Context $context -Force -ErrorAction Stop) | Out-Null

        Write-Host "File has been uploaded successfully!" -ForegroundColor Green
    }
    Catch
    {
        Write-Host "ERROR while uploading file to blob: $($Error[0].Exception.Message)"
    }
}