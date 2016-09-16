# Parameters from the script in a comma seperated form. This works for Windows 2012 and above
# Domain Name for Additional DC
$DBUserName = $args[0]
# Domin Admin UserName
$DBPassword = $args[1]
# Password string for the Domain Admin
$DatabaseName = $args[2]
# Url of the backup file
$BackupFileUrl = $args[3]

try
{
    $DownloadObj = New-Object System.Net.WebClient
    $DestinationFile = "C:\$DatabaseName.bak"
    $DownloadObj.DownloadFile($BackupFileUrl,$DestinationFile)

    if(Test-Path -Path $DestinationFile)
    {
        $DBBit = 0
        # Creating the new Database
        $SQLServerName = "localhost"
        $SqlConnection = New-Object System.Data.SqlClient.SqlConnection
        $SqlConnection.ConnectionString = "Server=$SQLServerName;Integrated Security=True;User Id=$DBUserName;Password=$DBPassword"
        $SqlCmd = New-Object System.Data.SqlClient.SqlCommand
        #$SqlCmd.CommandText = "CREATE DATABASE $DatabaseName"
        $SqlCmd.Connection = $SqlConnection
        #$SqlConnection.Open()
        #$SqlCmd.ExecuteNonQuery()
        if($? -eq $true)
        {
            $SqlCmd.CommandText = "Select name from master.dbo.sysdatabases"
            #$SqlCmd.Connection = $SqlConnection
            $SqlConnection.Open()
            $SqlAdapter = New-Object System.Data.SqlClient.SqlDataAdapter
            $SqlAdapter.SelectCommand = $SqlCmd
            $DataSet = New-Object System.Data.DataSet
            $Res = $SqlAdapter.Fill($DataSet)
            if(($Res -ne $null) -and !($DataSet.Tables.name.Contains($DatabaseName)))
            {
                $Expression = "Sqlcmd -S localhost -U $DBUserName -P $DBPassword -Q `"RESTORE DATABASE $DatabaseName FROM DISK='"+$DestinationFile+"'`""
                $Status = Invoke-Expression -Command $Expression
                if($Status -and $Status.Contains("successfully processed"))
                {
                    Write-Output "Database has been restored successfully"
                }
                else 
                {
                    Write-Output "Database restoration has been failed.$Status"
                }
            }
            else 
            {
                Write-Output "Database is already exist. Cannot restore into existing database"
            }
        }
        $SqlConnection.Close()
    }
    else 
    {
        Write-Output "Database backup file does not exist or has not been downloaded."
    }
}
catch
{
    Write-Output "There was an exception in creating and restoring the database."
}