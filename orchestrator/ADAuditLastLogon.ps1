$smtp_from = "orchestrator@contoso.com"
$smtp_to = "uib@contoso.com"
$smtp_cc = "admin@contoso.com"
$smtp_creds = New-Object System.Management.Automation.PSCredential ("", (ConvertTo-SecureString "" -AsPlainText -Force))
$smtp_server = "smtp.contoso.com"

$ChangeDate = (Get-Date).AddDays(-14)

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
	.red {color: red;}
	.green {color: green;}
	.yellow {color: yellow;}
	</style>
	<body>
	<h1>Ноутбуки, которые не подключались к сети более <span class="green">14</span> и <span class="red">30</span> дней</h1>
<table>
<tr>
<th>Name</th>
<th>Last logon*</th>
</tr>
'@

$objects = Get-ADObject -Filter {(objectClass -eq 'computer') -and (LastLogonTimestamp -lt $ChangeDate) -and (SamAccountName -like "*-N*")} -Properties lastLogonTimestamp
if(!$objects)
{
	exit
}

$ChangeDate = (Get-Date).AddDays(-30)

$objects | Sort-Object lastLogonTimestamp | %{ 
if($_.Name -match "\d\d\d\d-N\d\d\d\d")
{
if([datetime]::FromFileTime($_.lastLogonTimestamp) -lt $ChangeDate)
{
	$color = "red"
}
else
{
	$color = "green"
}
$body += @'
<tr class="{2}">
<td>{0}</td>
<td>{1}</td>
</tr>
'@ -f $_.Name, [datetime]::FromFileTime($_.lastLogonTimestamp).ToString("dd.MM.yyyy HH:mm"), $color
}
}

$body += @'
</table>
<small>* данные могут не соответствовать действительности, т.к. синхронизация параметра между контроллерами домена происходит раз в 14 дней</small>
</body>
</html>
'@

Send-MailMessage -from $smtp_from -to $smtp_to -cc $smtp_cc -Encoding UTF8 -subject "Last logon more than 14 and 30 days" -bodyashtml -body $body -smtpServer $smtp_server -Credential $smtp_creds
