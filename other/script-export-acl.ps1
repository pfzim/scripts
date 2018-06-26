$client = "VM_NAME_HERE"

$list = Get-VMNetworkAdapterExtendedAcl -VMName $client | sort weight

foreach($rule in $list)
{
    ("Add-VMNetworkAdapterAcl -Name `$client -Direction " + $rule.Direction + " -Action " + $rule.Action + " -LocalIPAddress " + $rule.LocalIPAddress + " -RemoteIPAddress " + $rule.RemoteIPAddress + " -LocalPort " +  $rule.LocalPort + " -RemotePort  " + $rule.RemotePort + " -Protocol " + $rule.Protocol + " -Weight " + $rule.Weight)
}
