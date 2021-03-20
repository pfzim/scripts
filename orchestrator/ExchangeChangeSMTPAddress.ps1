# Exchange change SMTP address

$global:login = ''
$global:newmail = ''
$global:incident = ''

$global:smtp_creds = New-Object System.Management.Automation.PSCredential ('', (ConvertTo-SecureString '' -AsPlainText -Force))
$global:exch_creds = New-Object System.Management.Automation.PSCredential ('', (ConvertTo-SecureString '' -AsPlainText -Force))

$ErrorActionPreference = 'Stop'

. c:\orchestrator\settings\config.ps1

$global:smtp_to = @($global:g_config.admin_email, $global:g_config.helpdesk_email)

$global:result = 0
$global:error_msg = ''

function main()
{
	trap
	{
		$global:result = 1
		$global:error_msg += ("Критичная ошибка: {0}`r`n`r`nПроцесс прерван!`r`n" -f $_.Exception.Message);
		return;
	}

	# Проверка корректности заполнения полей

	if($global:newmail -eq '' -or $global:login -eq '')
	{
		$global:result = 1
		$global:error_msg = 'Ошибка: Не корректно заполнены обязательные поля'
		return
	}

	# Проверка существования пользователя

	$user = $null

	try
	{
		$user = Get-ADUser -Identity $global:login
	}
	catch
	{
		$global:result = 1
		$global:error_msg += 'Ошибка в логине пользователя: {0}' -f $_.Exception.Message
		return
	}

	if(!$user)
	{
		$global:result = 1
		$global:error_msg += 'Ошибка в логине пользователя. Пользователь не найден'
		return
	}

	# Смена SMTP адреса
	try
	{
		$session = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri $global:g_config.exch_conn_uri -Credential $global:exch_creds -Authentication Basic
		Import-PSSession $session

		Set-Mailbox -Identity $user.SamAccountName -EmailAddressPolicyEnabled $false -EmailAddresses $global:newmail

		Remove-PSSession -Session $session
	}
	catch
	{
		$global:result = 1
		$global:error_msg += 'Ошибка в изменения адреса: {0}' -f $_.Exception.Message
		return
	}

	# Отправка информационного письма

	$subject = ('Смена SMTP адреса пользователя: {0}' -f $global:login)

	$global:body = @'
<html>
<head>
	<meta http-equiv="Content-Type" content="text/html; charset=utf-8">
	<style type="text/css">
		body {font-family: Arial; font-size: 12pt;}
		h1 {font-size: 16px;}
		h2 {font-size: 14px;}
		h3 {font-size: 12px;}
		table {border: 1px solid black; border-collapse: collapse; font-size: 8pt; font-family: Courier New;}
		th {border: 1px solid black; background: #dddddd; padding: 5px; color: #000000;}
		td {border: 1px solid black; padding: 5px; }
		.pass {background: #7FFF00;}
		.warn {background: #FFE600;}
		.error {background: #FF0000; color: #ffffff;}
	</style>
</head>
<body>
Была произведена смена SMTP адреса пользователя:
<br />
<br />
'@

	$global:body += @'
Пользователь: <b>{1}</b><br />
Новый адрес: <b>{2}</b><br />
Номер инцидента: <b>{3}</b><br />
<br />
<br />
Техническая информация: <br />{0}<br />
'@ -f $global:error_msg.Replace("`r`n", "<br />`r`n"), $global:login, $global:newmail, $global:incident

	$global:body += @'
</body>
</html>
'@

	try
	{
		Send-MailMessage -from $global:g_config.smtp_from -to $global:smtp_to -Encoding UTF8 -subject $subject -bodyashtml -body $global:body -smtpServer $global:g_config.smtp_server -Credential $global:smtp_creds
	}
	catch
	{
		$global:result = 1
		$global:error_msg += ("Ошибка отправки информационного письма ({0});`r`n" -f $_.Exception.Message)
	}
}

main
