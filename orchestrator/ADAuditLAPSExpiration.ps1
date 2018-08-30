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
<h>Компьютеры с просроченным паролем локального Администратора</h1>
'@

$table = @'
<table>
<tr>
<th>Name</th>
<th>Expired</th>
<th>lastLogonTimestamp</th>
</tr>
'@

$objects = Get-ADObject -Filter {(objectClass -eq 'computer')} -SearchBase "OU=Company,DC=contoso,DC=com" -Properties ms-Mcs-AdmPwdExpirationTime, lastLogonTimestamp | Sort-Object -Property lastLogonTimestamp
if(!$objects)
{
	exit
}

$today = (Get-Date).AddDays(-28)
$comps_count = 0

foreach($object in $objects)
{ 
	if($object.'ms-Mcs-AdmPwdExpirationTime')
	{
		if([datetime]::FromFileTime($object.'ms-Mcs-AdmPwdExpirationTime') -lt $today)
		{
			$pwdexp = [datetime]::FromFileTime($object.'ms-Mcs-AdmPwdExpirationTime').ToString("dd.MM.yyyy HH:mm")
		}
		else
		{
			continue
		}
	}
	else
	{
		$pwdexp = "Not set"
	}

	$lastLogon = [datetime]::FromFileTime($object.lastLogonTimestamp).ToString("dd.MM.yyyy HH:mm")

	$comp_count++

	$table += @'
<tr>
<td>{0}</td>
<td>{1}</td>
<td>{2}</td>
</tr>
'@ -f $object.Name, $pwdexp, $lastLogon
}


$body += @'
</table>
<p>Всего: {0}</p>
{1}
</body>
</html>
'@ -f $comp_count, $table

Send-MailMessage -from $smtp_from -to $smtp_to -Encoding UTF8 -subject "Expired LAPS passwords" -bodyashtml -body $body -smtpServer $smtp_server -Credential $smtp_creds
