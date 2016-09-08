Param
(
    [Parameter(ValueFromPipelineByPropertyName)]
    [string]$AzureUserName,

    [Parameter(ValueFromPipelineByPropertyName)]
    [string]$AzurePassword,

    [Parameter(ValueFromPipelineByPropertyName)]
    [string]$AzureSubscriptionID,

    [Parameter(ValueFromPipelineByPropertyName)]
    [string]$Location,

    [Parameter(ValueFromPipelineByPropertyName)]
    [string]$OSDiskUri,

    [Parameter(ValueFromPipelineByPropertyName)]
    [string]$OSType,
    
    [Parameter(ValueFromPipelineByPropertyName)]
    [string]$VMName,
    
    [Parameter(ValueFromPipelineByPropertyName)]
    [string]$VMSize,
    
    [Parameter(ValueFromPipelineByPropertyName)]
    [string]$AvailabilitySetName,

    [Parameter(ValueFromPipelineByPropertyName)]
    [string]$StorageAccountName,
    
    [Parameter(ValueFromPipelineByPropertyName)]
    [string]$VirtualNetworkName,

    [Parameter(ValueFromPipelineByPropertyName)]
    [string]$SubnetName,

    [Parameter(ValueFromPipelineByPropertyName)]
    [string]$DNSNameForPublicIP,

    [Parameter(ValueFromPipelineByPropertyName)]
    [String]$ResourceGroupName
)

# Fetching the Network details
$VNet = Get-AzureRmVirtualNetwork -Name $VirtualNetworkName -ResourceGroupName $ResourceGroupName

#Fetching the Subnet Details
$SNet = Get-AzureRmVirtualNetworkSubnetConfig -Name $SubnetName -VirtualNetwork $VNet



# Create Public IP
$PublicIPStatus = New-AzureRmPublicIpAddress -Name $DNSNameForPublicIP -ResourceGroupName $ResourceGroupName -Location $Location -AllocationMethod Dynamic

# Create Network Interface Card
$NICStatus = New-AzureRmNetworkInterface -Name $VMName -ResourceGroupName $ResourceGroupName -Location $Location -SubnetId $SNet.Id -PublicIpAddressId $PublicIPStatus.Id

$VMConfig = New-AzureRmVMConfig -VMName $VMName -VMSize $VMSize


$VMConfig = Set-AzureRmVMOSDisk -VM $VMConfig -Name $VMName -VhdUri $OSDiskUri -Caching ReadWrite -CreateOption Attach -Linux

Add-AzureRmVMNetworkInterface -VM $VMConfig -Id $NICStatus.Id -Primary

$Status = New-AzureRmVM -ResourceGroupName $ResourceGroupName -Location $Location -VM $VMConfig

     