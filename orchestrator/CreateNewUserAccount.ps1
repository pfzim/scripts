$global:login = ""
$global:full_name = ""
$global:first_name = ""
$global:last_name = ""
$global:title = ""
$global:department = ""
$global:phone = ""
$global:company_code = ""

$creds = New-Object System.Management.Automation.PSCredential ("", (ConvertTo-SecureString "" -AsPlainText -Force))
$smtp_creds = New-Object System.Management.Automation.PSCredential ("", (ConvertTo-SecureString "" -AsPlainText -Force))

$smtp_to = @("techsupport@contoso.com", "UserAccess@bristol.ru")

$global:result = 1
$global:error_msg = ""

function main()
{
	$list_company = @{
		"sb" = @{
			domain = "contoso.com";
			path = "OU=Users,OU=ООО САДЫ БАКСАНА,OU=Company,DC=contoso,DC=com";
			name = "ООО Сады Баксана";
			city = "Нальчик";
			subscribe = "CN=Рассылка - Все сотрудники ООО САДЫ БАКСАНА,OU=ООО САДЫ БАКСАНА,OU=Рассылки,DC=contoso,DC=com";
		};
		"kh" = @{
			domain = "example.org";
			path = "OU=Users,OU=ООО КАЗАЧИЙ ХУТОР,OU=Company,DC=contoso,DC=com";
			name = "ООО Казачий Хутор";
			city = "Владикавказ";
			subscribe = "CN=Рассылка - Все сотрудники ООО КАЗАЧИЙ ХУТОР,OU=ООО КАЗАЧИЙ ХУТОР,OU=Рассылки,DC=contoso,DC=com";
		};
		"ar" = @{
			domain = "example.com";
			path = "OU=Users,OU=Ариана,OU=Company,DC=contoso,DC=com";
			name = "ООО Ариана";
			city = "Владикавказ";
			subscribe = "CN=Рассылка - Все сотрудники ООО АРИАНА,OU=ООО АРИАНА,OU=Рассылки,DC=contoso,DC=com";
		}
	}
	
	$company = $list_company[$global:company_code.ToLower()]
	
	# Проверка корректности заполнения полей
	
	if(!$company)
	{
		$global:error_msg = ("Ошибка: Неправильно указан код компании: " + $global:company_code.ToLower())
		return
	}
	
	if($global:login -eq '' -or $global:full_name -eq '' -or $global:first_name -eq '' -or $global:last_name -eq '' -or $global:title -eq '')
	{
		$global:error_msg = "Ошибка: Не заполнены все обязательные поля"
		return
	}
	
	if($global:phone -eq '')
	{
		$global:phone = $null
	}
	
	if($global:department -eq '')
	{
		$global:department = $null
	}
	
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
		$global:error_msg = "Ошибка: Пользователь уже существует!"
		return
	}

	$password_plain = "Qwe-1234"
	$password = (ConvertTo-SecureString $password_plain -AsPlainText -Force)

	# Создание УЗ пользователя

	try
	{
		$user = New-ADUser -SamAccountName $global:login -UserPrincipalName ($global:login + "@" + $company.domain) -AccountPassword $password -Path $company.path -Name $global:full_name -DisplayName $global:full_name -GivenName $global:first_name -Surname $global:last_name -Title $global:title -Department $global:department -OfficePhone $global:phone -Company $company.name -City $company.city -PasswordNeverExpires:$false -ChangePasswordAtLogon:$true -Enabled:$true -PassThru
	}
	catch
	{
		$global:error_msg = ("Ошибка создания УЗ пользователя (" + $_.Exception.Message + ")")
		return
	}

	# Очистка флага разрешающего установку пустого пароля

	try
	{
		Set-ADAccountControl -Identity $global:login -PasswordNotRequired $false
	}
	catch
	{
		$global:result = 2
		$global:error_msg += ("Ошибка установки флага запрета пустого пароля (" + $_.Exception.Message + ");`r`n")
	}

	# Включение почтового ящика

	$session = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri http://brc-exch-01.contoso.com/powershell/ -Credential $creds -Authentication Kerberos
	Import-PSSession $session

	$fail = 5
	while($fail -gt 0)
	{
		try
		{
			Enable-Mailbox -Identity $global:login -PrimarySmtpAddress ($global:login + "@" + $company.domain)
			$fail = 0
		}
		catch
		{
			Start-Sleep -Seconds 20
			$fail--
			if($fail -eq 0)
			{
				$global:result = 2
				$global:error_msg += ("Ошибка включения почтового ящика (" + $_.Exception.Message + ");`r`n")
			}
		}
	}

	# Установка квоты и отключение автоматического обновления адреса

	$fail = 5
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
				$global:result = 2
				$global:error_msg += ("Ошибка установки квоты на почтовый ящик (" + $_.Exception.Message + ");`r`n")
			}
		}
	}

	# Включение ActiveSync и отключение POP3 и IMAP

	$fail = 5
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
				$global:result = 2
				$global:error_msg += ("Ошибка включения ActiveSync и отключения POP3 и IMAP (" + $_.Exception.Message + ");`r`n")
			}
		}
	}

	$fail = 5
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
				$global:result = 2
				$global:error_msg += ("Ошибка добавления в группу рассылки (" + $_.Exception.Message + ");`r`n")
			}
		}
	}

	Remove-PSSession -Session $session

	# Включение Lync

	$session = New-PSSession -ConnectionUri https://brc-sfb-01.contoso.com/OcsPowershell -Credential $creds
	Import-PSSession $session

	$fail = 5
	while($fail -gt 0)
	{
		try
		{
			Enable-CsUser -Identity $global:login -RegistrarPool "brc-sfb-01.contoso.com" -SipAddressType EmailAddres -SipDomain $company.domain
			$fail = 0
		}
		catch
		{
			Start-Sleep -Seconds 20
			$fail--
			if($fail -eq 0)
			{
				$global:result = 2
				$global:error_msg += ("Ошибка включения Lync (" + $_.Exception.Message + ");`r`n")
			}
		}
	}

	Remove-PSSession $session

	$body = @'
<html>
<head>
	<meta http-equiv="Content-Type" content="text/html; charset=utf-8">
	<style type="text/css">
		body{font-family: Courier New; font-size: 8pt;}
		h1{font-size: 16px;}
		h2{font-size: 14px;}
		h3{font-size: 12px;}
		table{border: 1px solid black; border-collapse: collapse; font-size: 8pt;}
		th{border: 1px solid black; background: #dddddd; padding: 5px; color: #000000;}
		td{border: 1px solid black; padding: 5px; }
		.red {color: red;}
		.pass {color: green;}
		.warn {color: #ff6600;}
		.error {background: #FF0000; color: #ffffff;}
	</style>
</head>
<body>
'@

	$body += @'
Был создан пользователь для {4} ({5}):<br />
<br />
Логин: {0}<br />
Пароль: {1}<br />
<br />
E-mail: {0}@{2}<br />
Web адрес почты:  https://webmail.contoso.com/owa<br />
<br />
OU: {7}<br />
Группы рассылки: {6}<br />
<br />
Техническая информация: {3}<br />
'@ -f $global:login, $password_plain, $company.domain, $global:error_msg, $company.name, $company.city, $company.subscribe, $company.path

	$body += @'
</body>
</html>
'@

	try
	{
		Send-MailMessage -from "orchestrator@contoso.com" -to $smtp_to -Encoding UTF8 -subject ("User created: " + $global:login + " (" + $global:full_name + ")") -bodyashtml -body $body -smtpServer smtp.contoso.com -Credential $smtp_creds
	}
	catch
	{
		$global:result = 2
		$global:error_msg += ("Ошибка отправки письма (" + $_.Exception.Message + ");`r`n")
	}

	if($global:result -ne 2)
	{
		$global:result = 0
	}
	else
	{
		$global:result = 1
	}
}

main
