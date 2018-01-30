$compname = "";
$dns = Get-DnsServerResourceRecord -ComputerName brc-dc-01 -ZoneName "contoso.com" -Name $compname
if($dns)
{
  $dns | Remove-DnsServerResourceRecord -ComputerName brc-dc-01 -ZoneName "contoso.com" -Force
}
