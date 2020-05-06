# Reset Remote Desktop sessions

$global:collection = ''
$global:state = ''
$global:login = ''

$global:ps_creds = New-Object System.Management.Automation.PSCredential ('', (ConvertTo-SecureString '' -AsPlainText -Force))
$global:smtp_creds = New-Object System.Management.Automation.PSCredential ('', (ConvertTo-SecureString '' -AsPlainText -Force))

trap
{
	$global:result = 1
	$global:error_msg += ("Критичная ошибка: {0}`r`n`r`nПроцесс прерван!`r`n" -f $_.Exception.Message);
	return;
}

$ErrorActionPreference = 'Stop'

. c:\orchestrator\settings\settings.ps1

$global:smtp_to = @($global:admin_email, $global:helpdesk_email)

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

	if($global:login -eq '' -or $global:collection -eq '' -or $global:state -notin ('ALL', 'DISCONNECTED', 'ACTIVE', 'CONNECTED'))
	{
		$global:result = 1
		$global:error_msg = 'Ошибка: Не корректно заполнены обязательные поля'
		return
	}

	# Проверка существования пользователя

	$samaccount = ''
	if($global:login -ne 'ALL_USERS')
	{
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
			$global:error_msg += 'Ошибка в логине пользователя'
			return
		}
		
		$samaccount = $user.SamAccountName
	}

	$output = Invoke-Command -ComputerName $global:rdsfarm -Credential $global:ps_creds -Authentication CredSSP -ScriptBlock {
		try
		{
			$broker = Get-RDConnectionBrokerHighAvailability
			return @{result = 0; error_msg = ''; broker = $broker.ActiveManagementServer}
		}
		catch
		{
			return @{result = 1; error_msg = ("Ошибка: {0}`r`n" -f $_.Exception.Message)}
		}
	}
	
	if(!$output -or $output.result -ne 0)
	{
		$global:result = 1
		$global:error_msg += $output.error_msg
		return
	}
	else
	{
		$broker = $output.broker
	}
	
	$output = Invoke-Command -ComputerName localhost -Credential $global:ps_creds -Authentication Credssp -ArgumentList @($global:collection, $global:login, $global:state, $samaccount, $broker) -ScriptBlock {
		param(
			[string] $collection,
			[string] $login,
			[string] $state,
			[string] $samaccount,
			[string] $broker
		)

		trap
		{
			return @{result = 1; error_msg = ("Критичная ошибка: {0}`r`n`r`nПроцесс прерван!`r`n" -f $_.Exception.Message)}
		}

		try
		{
			Import-Module -Name RemoteDesktop

			# Проверка существования коллекции

			if($collection -notin ('ALL', 'ALL_COLLECTIONS'))
			{
				$collections = Get-RDSessionCollection -ConnectionBroker $broker
				
				if($collection -notin $collections.CollectionName)
				{
					return @{result = 1; error_msg = 'Ошибка: Указанная коллекция не существует!'}
				}
			}

			# Завершение сессий
			
			$table = '<table><tr><th>Collection</th><th>Host</th><th>User Name</th><th>State</th></tr>'

			$sessions = Get-RDUserSession -ConnectionBroker $broker

			foreach($session in $sessions)
			{
				if(
					($collection -in ('ALL', 'ALL_COLLECTIONS') -or $session.CollectionName -eq $collection) -and
					($login -eq 'ALL_USERS' -or $session.UserName -eq $samaccount) -and
					($state -eq 'ALL' -or $session.SessionState -eq ('STATE_{0}' -f $state))
				)
				{
					$table += '<tr><td>{0}</td><td>{1}</td><td>{2}</td><td>{3}</td></tr>' -f $session.CollectionName, $session.HostServer, $session.UserName, $session.SessionState
					# Завершение сессии пользователя
					$session | Invoke-RDUserLogoff -Force | Out-Null
				}
			}
			
			$table += '</table>'

			return @{result = 0; error_msg = ''; table = $table}
		}
		catch
		{
			return @{result = 1; error_msg = ("Ошибка: {0}`r`n" -f $_.Exception.Message)}
		}
	}

	$table = ''
	if(!$output -or $output.result -ne 0)
	{
		$global:result = 1
		$global:error_msg += $output.error_msg
	}
	else
	{
		$table = $output.table
	}

	# Отправка информационного письма

	$subject = ('Сброс сессий терминальной фермы: {0} - {1}' -f $global:collection, $global:login)

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
Были сброшены сессии терминальной фермы:
<br />
<br />
'@

	$global:body += @'
Коллекция: <b>{1}</b><br />
Статус сессии: <b>{4}</b><br />
Пользователь: <b>{2}</b><br />
<br />
{3}
<br />
Техническая информация: <br />{0}<br />
'@ -f $global:error_msg.Replace("`r`n", "<br />`r`n"), $global:collection, $global:login, $table, $global:state

	$global:body += @'
</body>
</html>
'@

	try
	{
		Send-MailMessage -from $global:smtp_from -to $global:smtp_to -Encoding UTF8 -subject $subject -bodyashtml -body $global:body -smtpServer $global:smtp_server -Credential $global:smtp_creds
	}
	catch
	{
		$global:result = 1
		$global:error_msg += ("Ошибка отправки информационного письма ({0});`r`n" -f $_.Exception.Message)
	}
}

main
