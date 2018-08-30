$fixid = ""

$smtp_creds = New-Object System.Management.Automation.PSCredential ("", (ConvertTo-SecureString "" -AsPlainText -Force))

$smtp_from = "orchestrator@contoso.com"
$smtp_to = "admin@contoso.com"
$smtp_server = "smtp.contoso.com"

$servers = @("srv-hv-01", "srv-hv-02", "srv-hv-03", "srv-hv-04", "srv-hv-05", "srv-hv-06", "srv-hv-07", "srv-exch-01", "srv-exch-02", "srv-exch-05", "srv-exch-06", "srv-sql-01", "srv-sql-02", "srv-file-01", "srv-file-02", "srv-1c-01", "srv-1c-02", "srv-1c-03", "srv-1c-04", "srv-ora-01", "srv-dev-01", "srv-dev-02")

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
'@

$body += @'
    <h3>HotFix: {0}</h3>
    <table>
    <tr>
        <th>Server</th>
        <th>Installed</th>
    </tr>
'@ -f $fixid

foreach($server in $servers)
{
    $body += @'
<tr>
<td>{0}</td>
'@ -f $server

	try
	{
		if(Get-HotFix -Id $fixid -ComputerName $server -ErrorAction SilentlyContinue)
		{
			$body += '<td class="pass">YES</td>'
		}
		else
		{
			$body += '<td class="error">NO</td>'
		}
	}
	catch
	{
        $body += '<td class="warn">Get info failed</td>'
	}
    $body += '</tr>'
}

$body += @'
</table>
</body>
</html>
'@

Send-MailMessage -from $smtp_from -to $smtp_to -Encoding UTF8 -subject ("HotFix intallation status: " + $fixid) -bodyashtml -body $body -smtpServer $smtp_server -Credential $smtp_creds
