# Create new user account

$global:login = ''
$global:full_name = ''
$global:first_name = ''
$global:last_name = ''
$global:title = ''
$global:department = ''
$global:phone = ''
$global:company_code = ''
$global:region = ''
$global:employeeid = ''
$global:city = ''
$global:exp_date = ''
$global:curator = ''
$global:manager = ''
$global:email = ''

$global:exch_creds = New-Object System.Management.Automation.PSCredential ('', (ConvertTo-SecureString '' -AsPlainText -Force))
$global:ps_creds = New-Object System.Management.Automation.PSCredential ('', (ConvertTo-SecureString '' -AsPlainText -Force))

$ErrorActionPreference = 'Stop'

. c:\orchestrator\settings\config.ps1

$global:result = 0
$global:error_msg = ''

$global:subject = ''
$global:body = ''
$global:smtp_to = @($global:g_config.helpdesk_email, $global:g_config.techsupport_email, $global:g_config.useraccess_email)
$global:smtp_to = $global:smtp_to -join ','

$global:retry_count = 15

$global:company_code = $global:company_code.ToLower()

function main()
{
	trap
	{
		$global:result = 1
		$global:error_msg += ("Критичная ошибка: {0}`r`n`r`nПроцесс создания УЗ прерван!`r`n" -f $_.Exception.Message);
		return;
	}

	$company = $global:g_config.list_company[$global:company_code]

	# Проверка корректности заполнения полей

	if(!$company)
	{
		$global:error_msg = ('Ошибка: Неправильно указан код компании: {0}' -f $global:company_code)
		return
	}

	if([string]::IsNullOrEmpty($global:login) -or [string]::IsNullOrEmpty($global:full_name) -or [string]::IsNullOrEmpty($global:first_name) -or [string]::IsNullOrEmpty($global:last_name) -or [string]::IsNullOrEmpty($global:title))
	{
		$global:error_msg = "Ошибка: Не заполнены все обязательные поля"
		return
	}

	if([string]::IsNullOrEmpty($global:email))
	{
		$global:email = ($global:login + "@" + $company.domain)
	}

	if([string]::IsNullOrEmpty($global:phone))
	{
		$global:phone = $null
	}

	if([string]::IsNullOrEmpty($global:department))
	{
		$global:department = $null
	}

	if([string]::IsNullOrEmpty($global:employeeid))
	{
		$global:employeeid = $null
	}

	if([string]::IsNullOrEmpty($global:manager))
	{
		$global:manager = $null
	}

	if([string]::IsNullOrEmpty($global:curator))
	{
		$global:curator = $null
	}
	else
	{
		$global:curator = ("Курирующий менеджер: " + $global:curator)
	}

	if([string]::IsNullOrEmpty($global:exp_date))
	{
		$global:exp_date = $null
	}
	elseif($global:exp_date -notmatch '^\d\d\.\d\d\.\d\d\d\d$')
	{
		$global:error_msg = "Ошибка: Не верная дата (DD.MM.YYYY)"
		return
	}

	# Fix OU path for TOF

	if($global:company_code -eq "tof")
	{
		if($global:g_config.list_tof[$global:region])
		{
			$company.path = ('OU=Users,' + $global:g_config.list_tof[$global:region])
		}
		else
		{
			$global:error_msg = 'Ошибка: Не указан код региона для ТОФа'
			return
		}

		if($global:city -ne '')
		{
			$company.city = $global:city
		}
	}

	if($global:company_code -eq 'svc')
	{
		$global:login = ('svc_{0}' -f $global:login)
	}

	<#
	if($global:company_code -eq 'mbx')
	{
		$global:login = ('mbx_' -f $global:login)
	}
	#>

	# Проверка существования пользователя

	$user = 0
	try
	{
		$user = Get-ADUser -Identity $global:login
	}
	catch
	{
		# nothing
	}

	if($user)
	{
		$global:error_msg = 'Ошибка: Пользователь уже существует!'
		return
	}

	$password_plain = ('Tmp-{0}' -f (([char[]]"abcdefghikmnprstuvwxyzABCEFGHJKLMNPQRSTUVWXYZ23456789" | Get-Random -Count 4) -join ''))
	$password = (ConvertTo-SecureString $password_plain -AsPlainText -Force)

	# Создание УЗ пользователя

	try
	{
		$user = New-ADUser -SamAccountName $global:login -UserPrincipalName ('{0}@{1}' -f $global:login, $company.domain) -AccountPassword $password -Path $company.path -Name $global:full_name -DisplayName $global:full_name -GivenName $global:first_name -Surname $global:last_name -Title $global:title -Department $global:department -OfficePhone $global:phone -Company $company.name -City $company.city -Description $global:curator -EmployeeID $global:employeeid -PasswordNeverExpires:$false -ChangePasswordAtLogon:$true -Enabled:$true -PassThru
	}
	catch
	{
		$global:error_msg = ("Ошибка создания УЗ пользователя ({0});`r`n" -f $_.Exception.Message)
		return
	}

	# Добавление ссылки на аккаунт менеджера/руководителя
	
	if($global:manager)
	{
		$fail = $global:retry_count
		while($fail -gt 0)
		{
			try
			{
				Set-ADUser -Identity $user -Manager $global:manager
				$fail = 0
			}
			catch
			{
				Start-Sleep -Seconds 20
				$fail--
				if($fail -eq 0)
				{
					$global:result = 1
					$global:error_msg += ("Ошибка установки руководителя {1} ({0});`r`n" -f $_.Exception.Message, $manager)
				}
			}
		}
	}

	# Добавление в группы

	foreach($group in $company.groups)
	{
		$fail = $global:retry_count
		while($fail -gt 0)
		{
			try
			{
				Add-ADGroupMember -Identity $group -Members $global:login
				$fail = 0
			}
			catch
			{
				Start-Sleep -Seconds 20
				$fail--
				if($fail -eq 0)
				{
					$global:result = 1
					$global:error_msg += ("Ошибка добавления в группу {1} ({0});`r`n" -f $_.Exception.Message, $group)
				}
			}
		}
	}

	# Очистка флага разрешающего установку пустого пароля

	$fail = $global:retry_count
	while($fail -gt 0)
	{
		try
		{
			Set-ADAccountControl -Identity $global:login -PasswordNotRequired $false
			$fail = 0
		}
		catch
		{
			Start-Sleep -Seconds 20
			$fail--
			if($fail -eq 0)
			{
				$global:result = 1
				$global:error_msg += ("Ошибка установки флага запрета пустого пароля ({0});`r`n" -f $_.Exception.Message)
			}
		}
	}

	# Установка срока жизни УЗ

	if($global:exp_date)
	{
		$fail = $global:retry_count
		while($fail -gt 0)
		{
			try
			{
				Set-ADAccountExpiration -Identity $global:login -DateTime $global:exp_date
				$fail = 0
			}
			catch
			{
				Start-Sleep -Seconds 20
				$fail--
				if($fail -eq 0)
				{
					$global:result = 1
					$global:error_msg += ("Ошибка установки срока жизни УЗ ({0});`r`n" -f $_.Exception.Message)
				}
			}
		}
	}
	
	# Настройка почтового ящика

	if($company.mail)
	{
		try
		{
			$session = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri $global:g_config.exch_conn_uri -Credential $global:exch_creds -Authentication Basic
			Import-PSSession $session

			# Включение почтового ящика

			$fail = $global:retry_count
			while($fail -gt 0)
			{
				try
				{
					Enable-Mailbox -Identity $global:login -PrimarySmtpAddress $global:email
					$fail = 0
				}
				catch
				{
					Start-Sleep -Seconds 20
					$fail--
					if($fail -eq 0)
					{
						$global:result = 1
						$global:error_msg += ("Ошибка включения почтового ящика ({0});`r`n" -f $_.Exception.Message)
					}
				}
			}

			# Установка квоты и отключение автоматического обновления адреса

			$fail = $global:retry_count
			while($fail -gt 0)
			{
				try
				{
					Set-Mailbox -Identity $global:login -IssueWarningQuota 960mb -ProhibitSendQuota 990mb -ProhibitSendReceiveQuota 1gb -UseDatabaseQuotaDefaults $false -EmailAddressPolicyEnabled $false
					$fail = 0
				}
				catch
				{
					Start-Sleep -Seconds 20
					$fail--
					if($fail -eq 0)
					{
						$global:result = 1
						$global:error_msg += ("Ошибка установки квоты на почтовый ящик ({0});`r`n" -f $_.Exception.Message)
					}
				}
			}

			# Включение ActiveSync и отключение POP3 и IMAP

			$fail = $global:retry_count
			while($fail -gt 0)
			{
				try
				{
					Set-CASMailbox -Identity $global:login -ActivesyncEnabled $true -PopEnabled $false -ImapEnabled $false
					$fail = 0
				}
				catch
				{
					Start-Sleep -Seconds 20
					$fail--
					if($fail -eq 0)
					{
						$global:result = 1
						$global:error_msg += ("Ошибка включения ActiveSync и отключения POP3 и IMAP ({0});`r`n" -f $_.Exception.Message)
					}
				}
			}

			if($company.subscribe)
			{
				$fail = $global:retry_count
				while($fail -gt 0)
				{
					try
					{
						Add-DistributionGroupMember -Identity $company.subscribe -Member $global:login
						$fail = 0
					}
					catch
					{
						Start-Sleep -Seconds 20
						$fail--
						if($fail -eq 0)
						{
							$global:result = 1
							$global:error_msg += ("Ошибка добавления в группу рассылки ({0});`r`n" -f $_.Exception.Message)
						}
					}
				}
			}

			Remove-PSSession -Session $session
		}
		catch
		{
			$global:result = 1
			$global:error_msg += ("Критичная ошибка подключения к серверу Exchange ({0});`r`n" -f $_.Exception.Message)
		}
	}
	
	# Создание DFS ссылки на профиль
	
	if($company.profile_servers -and $company.dfs_link)
	{
		try
		{
			# Определяем самый свободный диск
		
			$max = -1
			$profile_path = $null
			$server = $null

			foreach($fs in $company.profile_servers)
			{
				try
				{
					$sess = New-CimSession -ComputerName $fs.server
					$quota = Get-FsrmQuota -CimSession $sess -Path $fs.path
					$current = $quota.Size - $quota.Usage
					Remove-CimSession -CimSession $sess
				}
				catch
				{
					$global:error_msg += ("Информация: Не был доступен сервер {1} ({0});`r`n" -f $_.Exception.Message, $fs.server)
					continue
				}

				if($current -gt $max)
				{
					$max = $current
					$profile_path = $fs.share
				}
			}

			if($profile_path)
			{
				$profile_path = '{0}\{1}' -f $profile_path, $user.SamAccountName

				New-Item -ItemType 'directory' -Path $profile_path

				# Назначаем необходимые права

				$acl = Get-Acl -Path $profile_path
				$fileSystemAccessRule = New-Object -TypeName System.Security.AccessControl.FileSystemAccessRule -ArgumentList @($user.SamAccountName, 'FullControl', 'ContainerInherit, ObjectInherit', 'InheritOnly', 'Allow')
				#$fileSystemAccessRule = New-Object -TypeName System.Security.AccessControl.FileSystemAccessRule -ArgumentList @($user.SamAccountName, 'FullControl', 'Allow')
				$acl.SetAccessRule($fileSystemAccessRule)
				Set-Acl -Path $profile_path -AclObject $acl

				# Создаем DFS-ссылку на профиль пользователя
				Invoke-Command -ComputerName localhost -ArgumentList @($company.dfs_link, $user.SamAccountName, $profile_path) -Credential $global:ps_creds -Authentication Credssp -ScriptBlock {
					param($dfs_link, $SamAccountName, $profile_path)
					$ErrorActionPreference = 'Stop'
					New-DfsnFolder -Path ("{0}\{1}" -f $dfs_link, $SamAccountName) -TargetPath $profile_path
				}
			}
			else
			{
				$global:result = 1
				$global:error_msg += ("Критичная ошибка создания папки профиля. Не обнаружен свободный ресурс для профиля;`r`n")
			}
		}
		catch
		{
			$global:result = 1
			$global:error_msg += ("Критичная ошибка создания DFS ссылки на профиль ({0});`r`n" -f $_.Exception.Message)
		}
	}

	# Включение Lync

	if($company.lync)
	{
		try
		{
			$session = New-PSSession -ConnectionUri $global:g_config.sfb_conn_uri -Credential $global:exch_creds
			Import-PSSession $session

			$fail = $global:retry_count
			while($fail -gt 0)
			{
				try
				{
					Enable-CsUser -Identity $global:login -RegistrarPool $global:g_config.sfb_pool -SipAddressType EmailAddress
					$fail = 0
				}
				catch
				{
					Start-Sleep -Seconds 20
					$fail--
					if($fail -eq 0)
					{
						$global:result = 1
						$global:error_msg += ("Ошибка включения Lync ({0});`r`n" -f $_.Exception.Message)
					}
				}
			}

			Remove-PSSession $session
		}
		catch
		{
			$global:result = 1
			$global:error_msg += ("Критичная ошибка подключения к серверу Lync ({0});`r`n" -f $_.Exception.Message)
		}
	}

	# Отправка приветственного письма созданному пользователю

	if($company.welcome -and $company.mail)
	{
		try
		{
			$body = Get-Content -Path $company.welcome -Encoding UTF8 | Out-String
			Send-MailMessage -from $global:g_config.wt_email -to $global:email -bcc $global:g_config.wt_email -Encoding UTF8 -subject $global:g_config.welcome_subject -bodyashtml -body $body -Attachments $company.attachments -smtpServer $global:g_config.smtp_server
		}
		catch
		{
			$global:result = 1
			$global:error_msg += ("Ошибка отправки приветственного письма ({0});`r`n" -f $_.Exception.Message)
		}
	}

	# Формирование информационного сообщения

	$global:subject = ("User created: {0} ({1})" -f $global:login, $global:full_name)

	$global:body = @'
		<h1>Был создан пользователь для {3} ({4})</h1>
		<p>
			Логин: <b>{0}</b><br />
			Пароль: <b>{1}</b><br />
			<br />
			E-mail: {7}<br />
			Web адрес почты:  {8}<br />
			<br />
			<u>OU</u>: {6}<br />
			<u>Группы рассылки</u>: {5}<br />
			<u>Группы AD</u>: {9}
		</p>
'@ -f $global:login, $password_plain, $company.domain, $company.name, $company.city, $company.subscribe, $company.path, $global:email, $global:g_config.owa_link, ($company.groups -join ', ')
}

main

if($global:result -ne 0)
{
	$global:body += "<br /><br /><pre class=`"error`">Техническая информация:`r`n`r`n{0}</pre>" -f $global:error_msg
}
