$ps_creds = New-Object System.Management.Automation.PSCredential ("", (ConvertTo-SecureString "" -AsPlainText -Force))
$smtp_creds = New-Object System.Management.Automation.PSCredential ("", (ConvertTo-SecureString "" -AsPlainText -Force))

$smtp_from = "orchestrator@contoso.com"
$smtp_to = "admin@contoso.com"
$smtp_server = "smtp.contoso.com"

$body = @'
<html>
<head>
	<meta http-equiv="Content-Type" content="text/html; charset=utf-8">
	<style>
		body{font-family: Courier New; font-size: 8pt;}
		h1{font-size: 16px;}
		h2{font-size: 14px;}
		h3{font-size: 12px;}
		table{border: 1px solid black; border-collapse: collapse; font-size: 8pt;}
		th{border: 1px solid black; background: #dddddd; padding: 5px; color: #000000;}
		td{border: 1px solid black; padding: 5px; }
		.pass {background: #7FFF00;}
		.warn {background: #FFE600;}
		.error {background: #FF0000; color: #ffffff;}
		</style>
	</head>
	<body>
	<h1>Hyper-V snapshots list</h1>
'@

$session = New-PSSession -ComputerName localhost -Credential $ps_creds -Authentication Credssp

$snapshots = Invoke-Command -Session $session -ScriptBlock {
	Import-Module -Name FailoverClusters
	Import-Module -Name Hyper-V

	$snapshots = @()
	$nodes = Get-ClusterNode -Cluster BRC-HVCL-01
	foreach($node in $nodes)
	{
		$snapshots += Get-VM -ComputerName $node.Name | Get-VMSnapshot | select VMName, Name, CreationTime
	}
	
	return $snapshots
}

Remove-PSSession $session

$body += @'
<table>
<tr>
<td>VM</td>
<td>Name</td>
<td>Date</td>
</tr>
'@

foreach($snapshot in $snapshots)
{
		$body += @'
<td>{0}</td>
<td>{1}</td>
<td>{2}</td>
</tr>
'@ -f $snapshot.VMName, $snapshot.Name, $snapshot.CreationTime
}

$body += '</table>'

$body += @'
</body>
</html>
'@

Send-MailMessage -from $smtp_from -to $smtp_to -Encoding UTF8 -subject "Hyper-V snapshots list" -bodyashtml -body $body -smtpServer $smtp_server -Credential $smtp_creds
