$smtp_creds = New-Object System.Management.Automation.PSCredential ("", (ConvertTo-SecureString "" -AsPlainText -Force))

$smtp_from = "orchestrator@bristolcapital.ru"
$smtp_to = "admin@contoso.com"
$smtp_server = "smtp.contoso.com"

$comps = Get-ADComputer -LDAPFilter "((userAccountControl:1.2.840.113556.1.4.803:=32))"
$users = Get-ADUser -LDAPFilter "((userAccountControl:1.2.840.113556.1.4.803:=32))"
$comps_count = $comps.Count
$users_count = $users.Count

if(($comps_count -le 0) -and ($users_count -le 0)) 
{
	Exit 0
}

$body = @'
<html>
<head>
<meta http-equiv="Content-Type" content="text/html; charset=utf-8"></head>
<style>
	body {font-family: Tahoma; font-size: 9pt;}
	h1 {font-size: 16px;}
	h2 {font-size: 14px;}
	h3 {font-size: 12px;}
	table {border: 1px solid black; border-collapse: collapse; font-size: 9pt;}
	th {border: 1px solid black; background: #dddddd; padding: 5px; color: #000000;}
	td {border: 1px solid black; padding: 5px;}
</style>
<body>
'@

$body += @'
<p>В Active Directory найдено {0} УЗ пользователей и {1} УЗ компьютеров с возможностью установки пустого пароля</p>
'@ -f $users_count, $comps_count

$body += @'
</table>
</body>
</html>
'@

Send-MailMessage -from $smtp_from -to $smtp_to -Encoding UTF8 -subject "AD objects with an empty password are allowed" -bodyashtml -body $body -smtpServer $smtp_server -Credential $smtp_creds
