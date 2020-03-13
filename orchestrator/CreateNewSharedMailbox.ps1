$global:email = ''
$global:name = ''
$global:manager = ''

$global:exch_creds = New-Object System.Management.Automation.PSCredential ('', (ConvertTo-SecureString '' -AsPlainText -Force))
$global:smtp_creds = New-Object System.Management.Automation.PSCredential ('', (ConvertTo-SecureString '' -AsPlainText -Force))

$global:result = 0
$global:error_msg = ''

trap
{
	$global:result = 1
	$global:error_msg += ("Критичная ошибка: {0}`r`n`r`nПроцесс прерван!`r`n" -f $_.Exception.Message);
	return;
}

$ErrorActionPreference = 'Stop'

. c:\orchestrator\settings\settings.ps1

$smtp_to = @($global:helpdesk_email, $global:techsupport_email, $global:useraccess_email)

$global:retry_count = 5

function main()
{
	trap
	{
		$global:result = 1
		$global:error_msg += ("Критичная ошибка: {0}`r`n`r`nПроцесс создания прерван!`r`n" -f $_);
		return;
	}

	# Проверка корректности заполнения полей

	$login = ''
	$domain = ''
	
	if($global:email -match '([^@]+)@([^@]+)')
	{
		$login = $matches[1]
		$domain = $matches[2]
	}

	if($login -eq '' -or $domain -eq '' -or $global:manager -eq '' -or $global:name -eq '')
	{
		$global:result = 1
		$global:error_msg = 'Ошибка: Не заполнены все обязательные поля'
		return
	}
	
	# Проверка существования владельца ПЯ

	$user = $null
	try
	{
		$user = Get-ADUser -Identity $global:manager
	}
	catch
	{
		$user = $null
	}

	if(!$user)
	{
		$global:result = 1
		$global:error_msg = 'Ошибка: Владелец не существует!'
		return
	}

	try
	{
		$session = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri $global:exch_conn_uri -Credential $global:exch_creds -Authentication Basic
		Import-PSSession $session

		$available_domains = Get-AcceptedDomain | %{ $_.DomainName }
		if($domain -notin $available_domains)
		{
			$global:result = 1
			$global:error_msg = ('Ошибка: Указан неверный домен в почтовом адресе - {0}' -f $global:email)
			Remove-PSSession -Session $session
			return
		}

		<# Создание группы доступа

		$fail = $global:retry_count
		while($fail -gt 0)
		{
			try
			{
				New-ADGroup -Name ('{0}_rw' -f $global:email) -SamAccountName ('{0}_rw' -f $global:email) -GroupCategory Security -GroupScope DomainLocal -Path 'OU=Common mailbox permission,OU=Groups,OU=MSK,DC=bristolcapital,DC=ru' -PassThru
				$fail = 0
			}
			catch
			{
				Start-Sleep -Seconds 20
				$fail--
				if($fail -eq 0)
				{
					$global:result = 1
					$global:error_msg += ("Ошибка создания группы доступа {0}_rw ({1});`r`n" -f $global:email, $_.Exception.Message)
				}
			}
		}
		#>

		# Создание общего почтового ящика

		$fail = $global:retry_count
		while($fail -gt 0)
		{
			try
			{
				New-Mailbox -Shared -Alias $login -Name $global:name -PrimarySmtpAddress $global:email -OrganizationalUnit 'OU=Общие ящики,DC=bristolcapital,DC=ru'
				$fail = 0
			}
			catch
			{
				Start-Sleep -Seconds 20
				$fail--
				if($fail -eq 0)
				{
					$global:result = 1
					$global:error_msg += ("Ошибка включения почтового ящика (" + $_.Exception.Message + ");`r`n")
				}
			}
		}

		# Установка квоты и отключение автоматического обновления адреса

		$fail = $global:retry_count
		while($fail -gt 0)
		{
			try
			{
				Set-Mailbox -Identity $login -IssueWarningQuota 960mb -ProhibitSendQuota 990mb -ProhibitSendReceiveQuota 10gb -UseDatabaseQuotaDefaults $false
				$fail = 0
			}
			catch
			{
				Start-Sleep -Seconds 20
				$fail--
				if($fail -eq 0)
				{
					$global:result = 1
					$global:error_msg += ("Ошибка установки квоты на почтовый ящик (" + $_.Exception.Message + ");`r`n")
				}
			}
		}

 		<# Предоставление группе доступа к ПЯ

		$fail = $global:retry_count
		while($fail -gt 0)
		{
			try
			{
				Add-MailboxPermission -Identity $login -User ('{0}_rw' -f $global:email) -AccessRights FullAccess -InheritanceType All
				$fail = 0
			}
			catch
			{
				Start-Sleep -Seconds 20
				$fail--
				if($fail -eq 0)
				{
					$global:result = 1
					$global:error_msg += ("Ошибка предоставления прав доступа группе (" + $_.Exception.Message + ");`r`n")
				}
			}
		}

		# Предоставление группе доступа прав на отправку от имени ПЯ

		$fail = $global:retry_count
		while($fail -gt 0)
		{
			try
			{
				$user = Get-ADUser -Identity $login
				Add-ADPermission -Identity $user.DistinguishedName -User ('{0}_rw' -f $global:email) -AccessRights ExtendedRight -ExtendedRights "Send As"
				$fail = 0
			}
			catch
			{
				Start-Sleep -Seconds 20
				$fail--
				if($fail -eq 0)
				{
					$global:result = 1
					$global:error_msg += ("Ошибка предоставления прав доступа группе на отправку от имени ПЯ " + $login + " (" + $_.Exception.Message + ");`r`n")
				}
			}
		}
		#>

		Remove-PSSession -Session $session
	}
	catch
	{
		$global:result = 1
		$global:error_msg += ("Критичная ошибка подключения к серверу Exchange (" + $_.Exception.Message + ");`r`n")
	}

	# Добавление ссылки на аккаунт менеджера/руководителя
	
	$fail = $global:retry_count
	while($fail -gt 0)
	{
		try
		{
			Set-ADUser -Identity $login -Manager $global:manager
			$fail = 0
		}
		catch
		{
			Start-Sleep -Seconds 20
			$fail--
			if($fail -eq 0)
			{
				$global:result = 1
				$global:error_msg += ("Ошибка установки руководителя " + $manager + " (" + $_.Exception.Message + ");`r`n")
			}
		}
	}

	$body = @'
<html>
<head>
	<meta http-equiv="Content-Type" content="text/html; charset=utf-8">
	<style type="text/css">
		body {font-family: Arial; font-size: 12pt;}
	</style>
</head>
<body>
'@

	$body += @'
Был создан общий почтовый ящик<br />
<br />
E-mail: {0}<br />
<br />
<u>Техническая информация</u>: {1}<br />
'@ -f $global:email, $global:error_msg

	$body += @'
</body>
</html>
'@

	try
	{
		Send-MailMessage -from $global:smtp_from -to $global:smtp_to -Encoding UTF8 -subject ("Shared mailbox created: {0}" -f $global:email) -bodyashtml -body $body -smtpServer $global:smtp_server -Credential $global:smtp_creds
	}
	catch
	{
		$global:result = 1
		$global:error_msg += ("Ошибка отправки информационного письма (" + $_.Exception.Message + ");`r`n")
	}
}

main
