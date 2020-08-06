# Edit AD acoount attributes

$rb_input = @{
	login = ''
	GivenName = ''
	Surname = ''
	DisplayName = ''
	Company = ''
	Department = ''
	Title = ''
	OfficePhone = ''
	MobilePhone = ''
	extensionAttribute1 = ''
}

$global:result = 0
$global:error_msg = ''

$global:subject = ''
$global:body = ''
$global:smtp_to = ''

$ErrorActionPreference = 'Stop'

. c:\orchestrator\settings\config.ps1

$global:retry_count = 1

function main($rb_input)
{
	trap
	{
		$global:result = 1
		$global:error_msg += ("Критичная ошибка: {0}`r`n`r`nПроцесс прерван!`r`n" -f $_.Exception.Message);
		return;
	}

	# Проверка корректности заполнения полей
	
	$rb_input.login = $rb_input.login.Trim()

	if([string]::IsNullOrEmpty($rb_input.login))
	{
		$global:result = 1
		$global:error_msg = 'Ошибка: Не заполнено поле Логин пользователя'
		return
	}
	
	try
	{
		$domain = Get-ADDomain
	}
	catch
	{
		$global:result = 1
		$global:error_msg = 'Ошибка: Подключения к контроллеру домена: {0}' -f $rb_input.login
		return
	}


	# Проверка существования пользователя

	$user = $null
	try
	{
		$user = Get-ADUser -Server $domain.PDCEmulator -Identity $rb_input.login -Properties CN, displayName, sn, Surname, Initials, GivenName, Name, Title, telephoneNumber, mobile, Company, extensionAttribute1
	}
	catch
	{
		$user = $null
	}

	if(!$user)
	{
		$global:result = 1
		$global:error_msg = 'Ошибка: Пользователь не существует: {0}' -f $rb_input.login
		return
	}
	
	$text = ''

	# Изменение GivenName
	
	if(-not [string]::IsNullOrEmpty($rb_input.GivenName))
	{
		try
		{
			if($rb_input.GivenName -eq 'DEL')
			{
				Set-ADUser -Server $domain.PDCEmulator -Identity $user -GivenName $null -PassThru
			}
			else
			{
				Set-ADUser -Server $domain.PDCEmulator -Identity $user -GivenName $rb_input.GivenName -PassThru
			}
		}
		catch
		{
			$global:result = 1
			$global:error_msg += ("Ошибка: Изменения GivenName ({0});`r`n" -f $_.Exception.Message)
		}
	}
	
	# Изменение Surname
	
	if(-not [string]::IsNullOrEmpty($rb_input.Surname))
	{
		try
		{
			if($rb_input.Surname -eq 'DEL')
			{
				Set-ADUser -Server $domain.PDCEmulator -Identity $user -Surname $null -PassThru
			}
			else
			{
				Set-ADUser -Server $domain.PDCEmulator -Identity $user -Surname $rb_input.Surname -PassThru
			}
		}
		catch
		{
			$global:result = 1
			$global:error_msg += ("Ошибка: Изменения Surname ({0});`r`n" -f $_.Exception.Message)
		}
	}
	
	# Изменение DisplayName
	
	if(-not [string]::IsNullOrEmpty($rb_input.DisplayName))
	{
		try
		{
			if($rb_input.DisplayName -eq 'DEL')
			{
				$global:result = 1
				$global:error_msg += ("Ошибка: Параметр DisplayName нельзя очищать")
			}
			else
			{
				Set-ADUser -Server $domain.PDCEmulator -Identity $user -DisplayName $rb_input.DisplayName -PassThru
			}
		}
		catch
		{
			$global:result = 1
			$global:error_msg += ("Ошибка: Изменения DisplayName ({0});`r`n" -f $_.Exception.Message)
		}
	}
	
	# Изменение Company
	
	if(-not [string]::IsNullOrEmpty($rb_input.Company))
	{
		try
		{
			if($rb_input.Company -eq 'DEL')
			{
				Set-ADUser -Server $domain.PDCEmulator -Identity $user -Company $null -PassThru
			}
			else
			{
				Set-ADUser -Server $domain.PDCEmulator -Identity $user -Company $rb_input.Company -PassThru
			}
		}
		catch
		{
			$global:result = 1
			$global:error_msg += ("Ошибка: Изменения Company ({0});`r`n" -f $_.Exception.Message)
		}
	}
	
	# Изменение Department
	
	if(-not [string]::IsNullOrEmpty($rb_input.Department))
	{
		try
		{
			if($rb_input.Department -eq 'DEL')
			{
				Set-ADUser -Server $domain.PDCEmulator -Identity $user -Department $null -PassThru
			}
			else
			{
				Set-ADUser -Server $domain.PDCEmulator -Identity $user -Department $rb_input.Department -PassThru
			}
		}
		catch
		{
			$global:result = 1
			$global:error_msg += ("Ошибка: Изменения Department ({0});`r`n" -f $_.Exception.Message)
		}
	}
	
	# Изменение Title
	
	if(-not [string]::IsNullOrEmpty($rb_input.Title))
	{
		try
		{
			if($rb_input.Title -eq 'DEL')
			{
				Set-ADUser -Server $domain.PDCEmulator -Identity $user -Title $null -PassThru
			}
			else
			{
				Set-ADUser -Server $domain.PDCEmulator -Identity $user -Title $rb_input.Title -PassThru
			}
		}
		catch
		{
			$global:result = 1
			$global:error_msg += ("Ошибка: Изменения Title ({0});`r`n" -f $_.Exception.Message)
		}
	}
	
	# Изменение MobilePhone
	
	if(-not [string]::IsNullOrEmpty($rb_input.MobilePhone))
	{
		try
		{
			if($rb_input.MobilePhone -eq 'DEL')
			{
				Set-ADUser -Server $domain.PDCEmulator -Identity $user -MobilePhone $null -PassThru
			}
			else
			{
				Set-ADUser -Server $domain.PDCEmulator -Identity $user -MobilePhone $rb_input.MobilePhone -PassThru
			}
		}
		catch
		{
			$global:result = 1
			$global:error_msg += ("Ошибка: Изменения MobilePhone ({0});`r`n" -f $_.Exception.Message)
		}
	}
	
	# Изменение OfficePhone
	
	if(-not [string]::IsNullOrEmpty($rb_input.OfficePhone))
	{
		try
		{
			if($rb_input.OfficePhone -eq 'DEL')
			{
				Set-ADUser -Server $domain.PDCEmulator -Identity $user -OfficePhone $null -PassThru
			}
			else
			{
				Set-ADUser -Server $domain.PDCEmulator -Identity $user -OfficePhone $rb_input.OfficePhone -PassThru
			}
		}
		catch
		{
			$global:result = 1
			$global:error_msg += ("Ошибка: Изменения OfficePhone ({0});`r`n" -f $_.Exception.Message)
		}
	}
	
	# Изменение extensionAttribute1
	
	if(-not [string]::IsNullOrEmpty($rb_input.extensionAttribute1))
	{
		try
		{
			if($rb_input.extensionAttribute1 -eq 'DEL')
			{
				Set-ADUser -Server $domain.PDCEmulator -Identity $user -Clear extensionAttribute1 -PassThru
			}
			else
			{
				Set-ADUser -Server $domain.PDCEmulator -Identity $user -Replace @{'extensionAttribute1' = $rb_input.extensionAttribute1} -PassThru
			}
		}
		catch
		{
			$global:result = 1
			$global:error_msg += ("Ошибка: Изменения extensionAttribute1 ({0});`r`n" -f $_.Exception.Message)
		}
	}

	# Проверка (непонятно зачем)

	Start-Sleep -Seconds 15

	try
	{
		$user_updated = Get-ADUser -Server $domain.PDCEmulator -Identity $rb_input.login -Properties CN, displayName, sn, Surname, Initials, GivenName, Name, Title, telephoneNumber, mobile, Company, extensionAttribute1
	}
	catch
	{
		$global:result = 1
		$global:error_msg += ("Ошибка: Получения данных для сравнения ({0});`r`n" -f $_.Exception.Message)
	}
	
	$text += '<table><tr><th>Параметр</th><th>Старое значение</th><th>Устанавливаемое значение</th><th>Фактическое значение</th></tr>'
	
	if(-not [string]::IsNullOrEmpty($rb_input.GivenName))
	{
		$class = 'pass'
		if(($rb_input.GivenName -eq 'DEL' -and -not [string]::IsNullOrEmpty($user_updated.GivenName)) -or ($rb_input.GivenName -ne 'DEL' -and $user_updated.GivenName -ne $rb_input.GivenName))
		{
			$class = 'error'
		}

		$text += '<tr><td>GivenName</td><td>{0}</td><td>{1}</td><td class="{3}">{2}</td></tr>'-f $user.GivenName, $rb_input.GivenName, $user_updated.GivenName, $class
	}

	if(-not [string]::IsNullOrEmpty($rb_input.Surname))
	{
		$class = 'pass'
		if(($rb_input.Surname -eq 'DEL' -and -not [string]::IsNullOrEmpty($user_updated.sn)) -or ($rb_input.Surname -ne 'DEL' -and $user_updated.sn -ne $rb_input.Surname))
		{
			$class = 'error'
		}

		$text += '<tr><td>Surname</td><td>{0}</td><td>{1}</td><td class="{3}">{2}</td></tr>'-f $user.sn, $rb_input.Surname, $user_updated.sn, $class
	}

	if(-not [string]::IsNullOrEmpty($rb_input.DisplayName))
	{
		$class = 'pass'
		if(($rb_input.DisplayName -eq 'DEL' -and -not [string]::IsNullOrEmpty($user_updated.DisplayName)) -or ($rb_input.DisplayName -ne 'DEL' -and $user_updated.DisplayName -ne $rb_input.DisplayName))
		{
			$class = 'error'
		}

		$text += '<tr><td>DisplayName</td><td>{0}</td><td>{1}</td><td class="{3}">{2}</td></tr>'-f $user.DisplayName, $rb_input.DisplayName, $user_updated.DisplayName, $class
	}

	if(-not [string]::IsNullOrEmpty($rb_input.Company))
	{
		$class = 'pass'
		if(($rb_input.Company -eq 'DEL' -and -not [string]::IsNullOrEmpty($user_updated.Company)) -or ($rb_input.Company -ne 'DEL' -and $user_updated.Company -ne $rb_input.Company))
		{
			$class = 'error'
		}

		$text += '<tr><td>Company</td><td>{0}</td><td>{1}</td><td class="{3}">{2}</td></tr>'-f $user.Company, $rb_input.Company, $user_updated.Company, $class
	}

	if(-not [string]::IsNullOrEmpty($rb_input.Department))
	{
		$class = 'pass'
		if(($rb_input.Department -eq 'DEL' -and -not [string]::IsNullOrEmpty($user_updated.Department)) -or ($rb_input.Department -ne 'DEL' -and $user_updated.Department -ne $rb_input.Department))
		{
			$class = 'error'
		}

		$text += '<tr><td>Department</td><td>{0}</td><td>{1}</td><td class="{3}">{2}</td></tr>'-f $user.Department, $rb_input.Department, $user_updated.Department, $class
	}

	if(-not [string]::IsNullOrEmpty($rb_input.Title))
	{
		$class = 'pass'
		if(($rb_input.Title -eq 'DEL' -and -not [string]::IsNullOrEmpty($user_updated.Title)) -or ($rb_input.Title -ne 'DEL' -and $user_updated.Title -ne $rb_input.Title))
		{
			$class = 'error'
		}

		$text += '<tr><td>Title</td><td>{0}</td><td>{1}</td><td class="{3}">{2}</td></tr>'-f $user.Title, $rb_input.Title, $user_updated.Title, $class
	}

	if(-not [string]::IsNullOrEmpty($rb_input.OfficePhone))
	{
		$class = 'pass'
		if(($rb_input.OfficePhone -eq 'DEL' -and -not [string]::IsNullOrEmpty($user_updated.telephoneNumber)) -or ($rb_input.OfficePhone -ne 'DEL' -and $user_updated.telephoneNumber -ne $rb_input.OfficePhone))
		{
			$class = 'error'
		}

		$text += '<tr><td>OfficePhone</td><td>{0}</td><td>{1}</td><td class="{3}">{2}</td></tr>'-f $user.telephoneNumber, $rb_input.OfficePhone, $user_updated.telephoneNumber, $class
	}

	if(-not [string]::IsNullOrEmpty($rb_input.MobilePhone))
	{
		$class = 'pass'
		if(($rb_input.MobilePhone -eq 'DEL' -and -not [string]::IsNullOrEmpty($user_updated.mobile)) -or ($rb_input.MobilePhone -ne 'DEL' -and $user_updated.mobile -ne $rb_input.MobilePhone))
		{
			$class = 'error'
		}

		$text += '<tr><td>MobilePhone</td><td>{0}</td><td>{1}</td><td class="{3}">{2}</td></tr>'-f $user.mobile, $rb_input.MobilePhone, $user_updated.mobile, $class
	}

	if(-not [string]::IsNullOrEmpty($rb_input.extensionAttribute1))
	{
		$class = 'pass'
		if(($rb_input.extensionAttribute1 -eq 'DEL' -and -not [string]::IsNullOrEmpty($user_updated.extensionAttribute1)) -or ($rb_input.extensionAttribute1 -ne 'DEL' -and $user_updated.extensionAttribute1 -ne $rb_input.extensionAttribute1))
		{
			$class = 'error'
		}

		$text += '<tr><td>UUID</td><td>{0}</td><td>{1}</td><td class="{3}">{2}</td></tr>'-f $user.extensionAttribute1, $rb_input.extensionAttribute1, $user_updated.extensionAttribute1, $class
	}
	
	$text += '</table>'

	$global:subject = 'Внесены изменения в учётную запись: {0}' -f $user.SamAccountName
	
	$global:body = @'
<h1>Внесены изменения в учётную запись: {0}</h1>
{1}
'@ -f $user.SamAccountName, $text
}

main -rb_input $rb_input

if($global:result -ne 0)
{
	$global:body += "<br /><br /><pre class=`"error`">Техническая информация:`r`n`r`n{0}</pre>" -f $global:error_msg
}
