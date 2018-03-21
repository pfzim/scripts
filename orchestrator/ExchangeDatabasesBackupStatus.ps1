Add-PSSnapin Microsoft.Exchange.Management.PowerShell.SnapIn;

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
<h1>Exchange databases backup status</h1>
<table>
<tr><th>Server</th><th>Database</th><th>Last Full</th><th>Last Incremental</th></tr>
'@

$result = Get-MailboxDatabase -Status

$date7 = (Get-Date).AddDays(-7)
$date1 = (Get-Date).AddDays(-1)
foreach($row in $result)
{
	if(!($row.LastFullBackup))
	{
	   $s_full = '<td class="error">Never</td>'
	}
	elseif($row.LastFullBackup -le $date7)
	{
	   $s_full = '<td class="error">'+$row.LastFullBackup.ToString("dd.MM.yyyy HH:mm")+'</td>'
	}
	elseif($row.LastFullBackup -le $date1)
	{
	   $s_full = '<td class="warn">'+$row.LastFullBackup.ToString("dd.MM.yyyy HH:mm")+'</td>'
	}
	else
	{
	   $s_full = '<td class="pass">'+$row.LastFullBackup.ToString("dd.MM.yyyy HH:mm")+'</td>'
	}

	if(!($row.LastIncrementalBackup))
	{
	   $s_diff = '<td class="error">Never</td>'
	}
	elseif($row.LastIncrementalBackup -le $date7)
	{
	   $s_diff = '<td class="error">'+$row.LastIncrementalBackup.ToString("dd.MM.yyyy HH:mm")+'</td>'
	}
	elseif($row.LastIncrementalBackup -le $date1)
	{
	   $s_diff = '<td class="warn">'+$row.LastIncrementalBackup.ToString("dd.MM.yyyy HH:mm")+'</td>'
	}
	else
	{
	   $s_diff = '<td class="pass">'+$row.LastIncrementalBackup.ToString("dd.MM.yyyy HH:mm")+'</td>'
	}

	$body += '<tr><td>'+ $row.server + '</td><td>'+ $row.name + '</td>' + $s_full + $s_diff + '</tr>'
}

$body += @'
</table>
</body>
</html>
'@

Send-MailMessage -from $smtp_from -to $smtp_to -Encoding UTF8 -subject "Exchange databases backup status" -bodyashtml -body $body -smtpServer $smtp_server -Credential $smtp_creds
