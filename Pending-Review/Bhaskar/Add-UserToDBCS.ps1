
# custom script for adding the security roles to the database
$SQLServer = $args[0]
$SQLServerPort = $args[1]
$DataBaseName = $args[2]
$LoginUserName = $args[3]
$LoginPassword = $args[4]
$UserToBeAdded = $args[5]
$RoleName = $args[6]

Try
{
        $SqlConnection = New-Object System.Data.SqlClient.SqlConnection
        $SqlConnection.ConnectionString = "Data Source="+$SQLServer+","+$SQLServerPort+";Initial Catalog="+$DataBaseName+";Integrated Security=False;User ID="+$LoginUserName+";Password="+$LoginPassword
        $SqlCmd = New-Object System.Data.SqlClient.SqlCommand
        $SqlConnection.Open()
        if($SqlConnection.State -eq 'Open')
        {
                # Creating the Login for the given domain User
                try
                {
                        $SqlCommand = New-Object System.Data.SqlClient.SqlCommand
                        $SqlCommand.CommandText = "Create login `"$UserToBeAdded`" from Windows"
                        $SqlCommand.Connection = $SqlConnection
                        $CLog = $SqlCommand.ExecuteNonQuery()
                }
                catch
                {
                        if($($Error[0].Exception.Message) -match 'already exists.')
                        {
                                # Do nothing
                        }
                        else 
                        {
                                Write-Output "There was an exception while creating the login for user"
                                exit   
                        }
                }
                
                # Creating the user for database from logins
                try  
                {
                        $SqlCommand = New-Object System.Data.SqlClient.SqlCommand
                        $SqlCommand.CommandText = "create user `"$UserToBeAdded`" for login `"$UserToBeAdded`""
                        $SqlCommand.Connection = $SqlConnection
                        $Cuser = $SqlCommand.ExecuteNonQuery()              
                }
                catch 
                {
                        if($($Error[0].Exception.Message) -match 'already exists in the current database')
                        {
                                # Do nothing
                        }
                        else 
                        {
                                Write-Output "There was an exception while adding the user to databse"
                                exit   
                        }                 
                }

                # Assign the role to the domain user for the given database 
                try  
                {
                        $SqlCommand = New-Object System.Data.SqlClient.SqlCommand
                        $SqlCommand.CommandText = "exec sp_addrolemember $RoleName,`"$UserToBeAdded`""
                        $SqlCommand.Connection = $SqlConnection
                        $Crole = $SqlCommand.ExecuteNonQuery()             
                }
                catch 
                { 
                        Write-Output "There was an exception while assigning the role for user"
                        exit               
                }
        }
        else 
        {
                Write-Output "SQL Connection was not opened"
        }
}
Catch
{
        Write-Output "There was an exception while creatting the login for user"
}        