$compname = "";
$dns = Get-DnsServerResourceRecord -ComputerName srv-dc-01 -ZoneName "contoso.com" -Name $compname
if($dns)
{
  $dns | Remove-DnsServerResourceRecord -ComputerName srv-dc-01 -ZoneName "contoso.com" -Force
}
