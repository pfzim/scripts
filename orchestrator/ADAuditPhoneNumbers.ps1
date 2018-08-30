$smtp_from = "orchestrator@contoso.com"
$smtp_to = "admin@contoso.com"
$smtp_creds = New-Object System.Management.Automation.PSCredential ("", (ConvertTo-SecureString "" -AsPlainText -Force))
$smtp_server = "smtp.contoso.com"

$body = @'
<html>
<head>
	<meta http-equiv="Content-Type" content="text/html; charset=utf-8">
	<style type="text/css">
		body{font-family: Courier New; font-size: 9pt;}
		h1{font-size: 16px;}
		h2{font-size: 14px;}
		h3{font-size: 12px;}
		table{border: 1px solid black; border-collapse: collapse; font-size: 8pt;}
		th{border: 1px solid black; background: #dddddd; padding: 5px; color: #000000;}
		td{border: 1px solid black; padding: 5px; }
	</style>
</head>
<body>
<h>Пользователи с неправильным форматом телефонных номеров</h1>
<table>
<tr>
<th>Name</th>
<th>Phone</th>
</tr>
'@

$objects = Get-ADUser -Filter * -SearchBase "OU=Users,OU=БРЛ Москва,OU=Company,DC=contoso,DC=com" -Properties telephoneNumber | ?{ $_.telephoneNumber -notmatch '\+\d \d+ \d+-\d\d-\d\d, ext\.\d+' } | Sort-Object Name
if(!$objects)
{
	exit
}

foreach($object in $objects)
{ 
	$body += @'
<tr>
<td>{0}</td>
<td>{1}</td>
</tr>
'@ -f $object.Name, $object.telephoneNumber
}


$body += @'
</table>
</body>
</html>
'@

Send-MailMessage -from $smtp_from -to $smtp_to -Encoding UTF8 -subject "Invalid phone numbers format" -bodyashtml -body $body -smtpServer $smtp_server -Credential $smtp_creds
