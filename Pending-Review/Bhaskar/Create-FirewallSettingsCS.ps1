# Get the Filewall specific arguments from the main script
Function CreateRule
{
    Param
    (
        $FirewallRuleName,
        $SAction,
        $FirewallAction,
        $FlowDirection,
        $LocalPort,
        $RemotePort,
        $FirewallProtocol,
        $FirewallProfile
    )

    Try
    {
        $OSType = (Get-WmiObject Win32_OperatingSystem).Name     
        if($OSType -like 'Microsoft Windows Server 2008*')
        {
            if($FlowDirection -eq 'Inbound')
            {
                $FlowDirection = 'In'
            }
            elseif($FlowDirection -eq 'Outbound')
            {
                $FlowDirection = 'Out'
            }
        }

        Switch ($SAction)
        {
            New          {
                            if($OSType -like 'Microsoft Windows Server 2008*')
                            {
                                ($ExistingRule = netsh advfirewall firewall show rule name="$FirewallRuleName") | Out-Null
                                if($ExistingRule -ne $null)
                                {
                                    Return 2
                                }
                                Else
                                {
                                    $cmd = "netsh advfirewall firewall add rule name=`""+$FirewallRuleName+"`" dir=$FlowDirection action=$FirewallAction protocol=$FirewallProtocol localport=$LocalPort remoteport=$RemotePort profile=$FirewallProfile"
                                    $NewFirewall = Invoke-Expression -Command $cmd
                                    if($NewFirewall -eq 'Ok.')
                                    {
                                        Return 0
                                    }
                                    Else
                                    {
                                        return 1
                                    }
                                }
                            }
                            Elseif($OSType -like 'Microsoft Windows Server 2012*')
                            {
                                ($ExistingRule = Get-NetFirewallRule -DisplayName $FirewallRuleName -ErrorAction SilentlyContinue -WarningAction SilentlyContinue) | Out-Null
                                if($ExistingRule -ne $null)
                                {
                                    Return 2
                                }
                                Else
                                {
                                    ($NewFirewall = New-NetFirewallRule -DisplayName $FirewallRuleName -Profile $FirewallProfile -Action $firewallAction -Direction $FlowDirection -Enabled True -Protocol $FirewallProtocol -RemotePort $RemotePort -LocalPort $LocalPort -ErrorAction Stop -WarningAction SilentlyContinue) | Out-Null
                                    if($NewFirewall.PrimaryStatus -eq 'OK')
                                    {
                                        Return 0
                                    }
                                    Else
                                    {
                                        return 1
                                    }
                                }
                            }
                            Else {return 1}
                            Break                            
                        }
            Set         {
                            if($OSType -like 'Microsoft Windows Server 2008*')
                            {
                                ($ExistingRule = netsh advfirewall firewall show rule name="$FirewallRuleName") | Out-Null
                                if($ExistingRule -eq $null)
                                {
                                    Return 2
                                }
                                Else
                                {
                                    $cmd = "netsh advfirewall firewall set rule name=`""+$FirewallRuleName+"`" dir=$FlowDirection action=$FirewallAction protocol=$FirewallProtocol localport=$LocalPort remoteport=$RemotePort profile=$FirewallProfile"
                                    $NewFirewall = Invoke-Expression -Command $cmd
                                    if($NewFirewall -eq 'Ok.')
                                    {
                                        Return 0
                                    }
                                    Else
                                    {
                                        return 1
                                    }
                                }
                            }
                            Elseif($OSType -like 'Microsoft Windows Server 2012*')
                            {
                                ($ExistingRule = Get-NetFirewallRule -DisplayName $FirewallRuleName -ErrorAction SilentlyContinue -WarningAction SilentlyContinue) | Out-Null
                                if($ExistingRule -eq $null)
                                {
                                    Return 2
                                }
                                Else
                                {
                                    ($NewFirewall = Set-NetFirewallRule -DisplayName $FirewallRuleName -Profile $FirewallProfile -Action $firewallAction -Direction $FlowDirection -Enabled True -Protocol $FirewallProtocol -RemotePort $RemotePort -LocalPort $LocalPort -ErrorAction Stop -WarningAction SilentlyContinue) | Out-Null
                                    if($NewFirewall.PrimaryStatus -eq 'OK')
                                    {
                                        Return 0
                                    }
                                    Else
                                    {
                                        return 1
                                    }
                                }
                            }
                            Else {return 1}
                            Break
                        }
            Remove      {
                            if($OSType -like 'Microsoft Windows Server 2008*')
                            {
                                ($ExistingRule = netsh advfirewall firewall show rule name="$FirewallRuleName") | Out-Null
                                if($ExistingRule -eq $null)
                                {
                                    Return 2
                                }
                                Else
                                {
                                    $cmd = netsh advfirewall firewall delete rule name="$FirewallRuleName"
                                    #$NewFirewall = Invoke-Expression -Command $cmd
                                    if($cmd -eq 'Ok.')
                                    {
                                        Return 0
                                    }
                                    Else
                                    {
                                        return 1
                                    }
                                }
                            }
                            Elseif($OSType -like 'Microsoft Windows Server 2012*')
                            {
                                ($ExistingRule = Get-NetFirewallRule -DisplayName $FirewallRuleName -ErrorAction SilentlyContinue -WarningAction SilentlyContinue) | Out-Null
                                if($ExistingRule -eq $null)
                                {
                                    Return 2
                                }
                                Else
                                {
                                    ($NewFirewall = Remove-NetFirewallRule -DisplayName $FirewallRuleName -ErrorAction Stop -WarningAction SilentlyContinue) | Out-Null
                                    if($NewFirewall.PrimaryStatus -eq 'OK')
                                    {
                                        Return 0
                                    }
                                    Else
                                    {
                                        return 1
                                    }
                                }
                            }
                            Else {return 1}
                            Break                            
                        }
        }
    }
    Catch
    {
        #Write-Output "There was an error in creating the fireall rule. $($Error[0].Exception.Message)"
        return 1
    }
}


$ParamCount = $args[0]
$FirewallRuleNames = $args[1]
$ScriptActions = $args[2]
$FirewallActions = $args[3]
$FlowDirections = $args[4]
$LocalPorts = $args[5]
$RemotePorts = $args[6]
$Protocols = $args[7]
$FirewallProfiles = $args[8]


if($ParamCount -gt 1)
{
    $ExitCode = 0
    for($i=0;$i -lt $ParamCount;$i++)
    {
        $ReturnCode = CreateRule -FirewallRuleName $FirewallRuleNames[$i] -SAction $ScriptActions[$i] -FirewallAction $FirewallActions[$i] -FlowDirection $FlowDirections[$i] -LocalPort $LocalPorts[$i] -RemotePort $RemotePorts[$i] -FirewallProtocol $Protocols[$i] -FirewallProfile $FirewallProfiles[$i]
        if($ReturnCode -ne 0)
        {
            $ExitCode = 1
        }
    }
    if($ExitCode -eq 1)
    {
        Write-Output "Error while configuring the firewall rules."
        Exit 1
    }
    else
    {
        Write-Output "Firewall rules have been configured successfully"
        exit 0
    }
}
Else
{
    $ReturnCode = CreateRule -FirewallRuleName $FirewallRuleNames -SAction $ScriptActions -FirewallAction $FirewallActions -FlowDirection $FlowDirections -LocalPort $LocalPorts -RemotePort $RemotePorts -FirewallProtocol $Protocols -FirewallProfile $FirewallProfiles
    if($ReturnCode -in (1,2))
    {
        Write-Output "Firewall rules have not been configured successfully"
        exit 1
    }
    Else
    {
        Write-Output "Firewall rules have been configured successfully"
        exit 0
    }  
}


