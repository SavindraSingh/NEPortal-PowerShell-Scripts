# Custom script for testing the SQL Connection from Azure VM
$SQLServerName = $args[0]
$SQLUserName = $args[1]
$SQLPassword = $args[2]

# checking the SQL Connection
Try 
{
    $SqlConnection = New-Object System.Data.SqlClient.SqlConnection
    $SqlConnection.ConnectionString = (“Data Source=$SQLServerName;Integrated Security=False;User ID=$SQLUserName;Password=$SQLPassword”)
    $SqlCmd = New-Object System.Data.SqlClient.SqlCommand
    $SqlConnection.Open()

    if($SqlConnection.State -eq 'Open')
    {
        Write-Output "Success."
        $SqlConnection.Open()
    }
    Else 
    {
        Write-Output "Failed"
    }
}
Catch
{
    Write-Output "Error while checking SQL connection. $($Error[0].Exception.Message)"
}