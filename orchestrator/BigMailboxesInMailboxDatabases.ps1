$username = "contoso.com\orchestrator"
$password = ""

Add-PSSnapin Microsoft.Exchange.Management.PowerShell.SnapIn;

$body = @'
<html>
<head>
<meta http-equiv="Content-Type" content="text/html; charset=utf-8"></head>
<style>
	BODY{font-family: Tahoma; font-size: 8pt;}
	H1{font-size: 16px;}
	H2{font-size: 14px;}
	H3{font-size: 12px;}
	TABLE{border: 1px solid black; border-collapse: collapse; font-size: 8pt;}
	TH{border: 1px solid black; background: #dddddd; padding: 5px; color: #000000;}
	TD{border: 1px solid black; padding: 5px; }
	</style>
	<body>
	<h3>Top 10 biggest maiboxes</h1>
<table>
<tr>
<th>DisplayName</th>
<th>TotalItemSize</th>
<th>Database</th>
</tr>
'@

$now = Get-Date
$databases = @("MDB01", "MDB02", "MDB03", "MDB04", "MDB05", "MDB06", "MDB07", "MDB08", "MDB09", "MDB10", "MDB11", "MDB12", "MDB13", "MDB14", "MDB15", "MDB16", "MDB17", "MDB18", "MDB19_Journal", "MDB20_Journal")

$messageSubject = "10 самых больших почтовых ящиков в определенной MailboxDatabase - $now "                                                                                                
foreach($db in $databases)
{
	$res = Get-Mailbox -Database $db -ResultSize Unlimited | Get-MailboxStatistics | Sort-Object TotalItemSize -Descending | Select-Object DisplayName,TotalItemSize,Database -First 10
	foreach($box in $res)
	{
			$body += @'
<tr>
<td>{0}</td>
<td>{1}</td>
<td>{2}</td>
</tr>
'@ -f $box.DisplayName, $box.TotalItemSize, $box.Database
	}
}

$body += @'
</table>
</body>
</html>
'@

$secstr = New-Object -TypeName System.Security.SecureString
$password.ToCharArray() | ForEach-Object {$secstr.AppendChar($_)}
$cred = new-object -typename System.Management.Automation.PSCredential -argumentlist $username, $secstr

Send-MailMessage -from "orchestrator@contoso.com" -to "admin@contoso.com" -Encoding UTF8 -subject $messageSubject -bodyashtml -body $body -smtpServer smtp.contoso.com -Credential $cred
