workflow Stop-AllClassicVMs
{
    Param
    (
        [Parameter(Mandatory=$false)]
        [String]$ExcludeVirtualMachines
    )
    # Fetch the Azure Creadentials stored in Azure Assets
    $StoredCredentialsName = "AzureCredentials"

    # Fecth the Credential Object
    $Credentials = Get-AutomationPSCredential -Name $StoredCredentialsName

    if(!$Credentials)
    {
        Throw "Credentials were not found in assets"
    }

    write-output "Connecting to Azure"
    Add-AzureAccount -Credential $Credentials
    Select-AzureSubscription -SubscriptionID ca68598c-ecc3-4abc-b7a2-1ecef33f278d

    $VirtualMachineObjects = Get-AzureVM
    $AllVirtualMachines = [System.Collections.ArrayList]($VirtualMachineObjects).Name  

    if($ExcludeVirtualMachines -ne $null)
    {
        $FinalVirtualMachines = InlineScript {
            $EVMs = $using:ExcludeVirtualMachines
            $AllVMs = $using:AllVirtualMachines
            $NewVMArray = New-Object System.Collections.ArrayList
            $NewVMArray = [System.Collections.ArrayList]$AllVMs
            if($EVMs.Contains(","))
            {
                $EAllVMs = $EVMs.Split(",")
                foreach($vm in $EAllVMs)
                {
                    if($NewVMArray.Contains($vm))
                    { 
                        $NewVMArray.Remove($vm)
                    }
                }
            }
            Else
            {
                if($NewVMArray.Contains($EVMs))
                { 
                    $NewVMArray.Remove($EVMs)
                }                
            }
            $NewVMArray
        }
    }
    Else
    {
        $FinalVirtualMachines = $AllVirtualMachines
    }

    foreach ($VirtualMachine in $FinalVirtualMachines)
    {
        $VmObject = $VirtualMachineObjects | Where-Object {$_.Name -eq $VirtualMachine}
        if($vmObject.Status -eq 'StoppedDeallocated')
        {
            # Do nothing
        }
        else
        {
            Write-Output "Stopping Virtual Machine $($VmObject.Name)"
            Stop-AzureVM -Name $($VmObject.Name) -ServiceName $($VmObject.ServiceName) -Force
        }
    }
}