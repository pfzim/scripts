$global:login = ""
$global:incident = ""
$global:incident_restore = ""

$creds = New-Object System.Management.Automation.PSCredential ("", (ConvertTo-SecureString "" -AsPlainText -Force))
$smtp_creds = New-Object System.Management.Automation.PSCredential ("", (ConvertTo-SecureString "" -AsPlainText -Force))

$smtp_to = @("helpdesk@contoso.com", "techsupport@contoso.com", "UserAccess@contoso.com")
$smtp_server = "smtp.contoso.com"

$ErrorActionPreference = "Stop"

$global:result = 1
$global:error_msg = ""

$global:body = @'
<html>
<head>
	<meta http-equiv="Content-Type" content="text/html; charset=utf-8">
	<style type="text/css">
		body {font-family: Arial; font-size: 12pt;}
	</style>
</head>
<body>
Был разблокирован пользователь:<br />
'@

function EnableUser($user)
{
	if(!(Test-Path -Path ("\\srv-admsrv-01\Log_SCORCH$\" + $user.samaccountname + "_" + $global:incident + ".pson")))
	{
		$global:result = 2
		$global:error_msg += ("Данные для восстановления не найдены;`r`n")
		return
	}
	
	try
	{
		$data = Get-Content -Path ("\\srv-admsrv-01\Log_SCORCH$\" + $user.samaccountname + "_" + $global:incident + ".pson")
	}
	catch
	{
		$global:result = 2
		$global:error_msg += ("Ошибка загрузки данные для восстановления (" + $_.Exception.Message + ");`r`n")
		return
	}
	
	try
	{
		$user_info = Invoke-Expression $data
	}
	catch
	{
		$global:result = 2
		$global:error_msg += ("Ошибка загрузки данные для восстановления (" + $_.Exception.Message + ");`r`n")
		return
	}
	
	if($user_info.login -ne $user.samaccountname)
	{
		$global:result = 2
		$global:error_msg += ("Ошибка в данных для восстановления (" + $_.Exception.Message + ");`r`n")
		return
	}


	$password_plain = ("Tmp-" + (([char[]]"abcdefghikmnprstuvwxyzABCEFGHJKLMNPQRSTUVWXYZ23456789" | Get-Random -Count 4) -join ''))
	$password = (ConvertTo-SecureString $password_plain -AsPlainText -Force)

	# Включение УЗ пользователя

	try
	{
		Enable-ADAccount -Identity $user
	}
	catch
	{
		$global:result = 2
		$global:error_msg += ("Ошибка включения УЗ пользователя (" + $_.Exception.Message + ");`r`n")
	}

	# Смена пароля пользователя

	try
	{
		Set-ADAccountPassword -Identity $user -Reset -NewPassword $password -Confirm:$false
	}
	catch
	{
		$global:error_msg += ("Ошибка смены пароля (" + $_.Exception.Message + ");`r`n")
	}

	# Внесение номера инцидента и запроса смены пароля при первом входе

	try
	{
		Set-ADUser -Identity $user -Description $global:incident_restore -ChangePasswordAtLogon:$true
	}
	catch
	{
		$global:result = 2
		$global:error_msg += ("Ошибка внесения номера инцидента и запроса смены пароля при первом входе (" + $_.Exception.Message + ");`r`n")
	}

	# Переместить в OU

	try
	{
		Move-ADObject -Identity $user -TargetPath $user_info.path
	}
	catch
	{
		$global:result = 2
		$global:error_msg += ("Ошибка перемещения в " + $user_info.path + " (" + $_.Exception.Message + ");`r`n")
	}

	# Удаление пользователя из групп

	foreach($group in $user.memberof)
	{
		try
		{
			Remove-ADGroupMember -Identity $group -Members $user -Confirm:$false
		}
		catch
		{
			$global:result = 2
			$global:error_msg += ("Ошибка удаления из группы " + $group + " (" + $_.Exception.Message + ");`r`n")
		}
	}

	# Добавление в группы
	
	foreach($group in $user_info.groups)
	{
		try
		{
			Add-ADGroupMember -Identity $group -Members $user
		}
		catch
		{
			$global:result = 2
			$global:error_msg += ("Ошибка добавления в группу " + $group + " (" + $_.Exception.Message + ");`r`n")
		}
	}

	$session = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri https://outlook.contoso.com/powershell/ -Credential $creds -Authentication Basic
	Import-PSSession $session

	$mail_box = $null
	try
	{
		$mail_box = Get-Mailbox -Identity $user.SamAccountName
	}
	catch
	{
	}
	
	if($mail_box)
	{
		# Показать в адресной книге

		if($user_info.addressbook)
		{
			try
			{
				Set-Mailbox -Identity $user.SamAccountName -HiddenFromAddressListsEnabled $false
			}
			catch
			{
				$global:result = 2
				$global:error_msg += ("Ошибка скрытия из адресной книги (" + $_.Exception.Message + ");`r`n")
			}
		}

		# Удаление разрешенных устройств

		if($user_info.activesyncdevices.Count -gt 0)
		{
			try
			{
				Set-CASMailbox -Identity $user.SamAccountName -ActiveSyncAllowedDeviceIDs $user_info.activesyncdevices
			}
			catch
			{
				$global:result = 2
				$global:error_msg += ("Ошибка добавления разрешенных устройств (" + $_.Exception.Message + ");`r`n")
			}
		}
		
		# Включение ActiveSync

		if($user_info.activesync)
		{
			try
			{
				Set-CASMailbox -Identity $user.SamAccountName -ActivesyncEnabled $true
			}
			catch
			{
				$global:result = 2
				$global:error_msg += ("Ошибка включения ActiveSync (" + $_.Exception.Message + ");`r`n")
			}
		}

		foreach($rule in $user_info.mailrules)
		{
			# Включение почтового правила

			try
			{
				Enable-InboxRule -Identity $rule -Mailbox $user.SamAccountName
			}
			catch
			{
				$global:result = 2
				$global:error_msg += ("Ошибка включения почтового правила " + $rule.Name + " (" + $_.Exception.Message + ");`r`n")
			}
		}
	}

	Remove-PSSession -Session $session

	# Включение Lync

	$session = New-PSSession -ConnectionUri https://srv-sfb-01.contoso.com/OcsPowershell -Credential $creds
	Import-PSSession $session

	if($user_info.lync)
	{
		try
		{
			Enable-CsUser -Identity $global:login -RegistrarPool "srv-sfb-01.contoso.com" -SipAddressType EmailAddress
		}
		catch
		{
			$global:result = 2
			$global:error_msg += ("Ошибка включения Lync (" + $_.Exception.Message + ");`r`n")
		}
	}

	Remove-PSSession $session

	# Отправка информационного письма

	$global:body += @'
<br />
ФИО: {1}<br />
<br />
Логин: {0}<br />
Пароль: {2}<br />
'@ -f $user.SamAccountName, $user.DisplayName, $password_plain
}

function main()
{
	# Проверка корректности заполнения полей

	if($global:login -eq '' -or $global:incident -eq '' -or $global:incident_restore -eq '')
	{
		$global:error_msg = "Ошибка: Не заполнены все обязательные поля"
		return
	}

	# Проверка существования пользователя

	$user = 0
	try
	{
		$user = Get-ADUser -Identity $global:login -Properties Company, memberof, displayName, msRTCSIP-UserEnabled
	}
	catch
	{
		# nothing
	}

	if(!$user)
	{
		$global:error_msg = ("Ошибка: Пользователь " + $global:login + " не найден!")
		return
	}
	
	if($user.DistinguishedName -notmatch "OU=Disabled Accounts,DC=contoso,DC=com$")
	{
		$global:error_msg = ("Ошибка: Пользователь " + $global:login + " не может быть включен с помощью ранбука!")
		return
	}
	
	$subject = ("User enabled: " + $user.SamAccountName + " (" + $user.DisplayName + ")")

	EnableUser -User $user

	# Отправка информационного письма

	$global:body += @'
<br />
Техническая информация: <br />{0}<br />
'@ -f $global:error_msg.Replace("`r`n", "<br />`r`n")

	$global:body += @'
</body>
</html>
'@

	try
	{
		Send-MailMessage -from "orchestrator@contoso.com" -to $smtp_to -Encoding UTF8 -subject $subject -bodyashtml -body $global:body -smtpServer $smtp_server -Credential $smtp_creds
	}
	catch
	{
		$global:result = 2
		$global:error_msg += ("Ошибка отправки информационного письма (" + $_.Exception.Message + ");`r`n")
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
