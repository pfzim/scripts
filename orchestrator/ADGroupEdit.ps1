# Add or remove member form multiple AD groups

$global:group_name = ''
$global:login = ''
$global:operation = ''
$global:incident = ''

$global:result = 0
$global:error_msg = ''

$global:subject = ''
$global:body = ''
$global:smtp_to = ''

$ErrorActionPreference = 'Stop'

. c:\orchestrator\settings\config.ps1

$global:retry_count = 1

function main()
{
	trap
	{
		$global:result = 1
		$global:error_msg += ("Критичная ошибка: {0}`r`n`r`nПроцесс прерван!`r`n" -f $_.Exception.Message);
		return;
	}

	# Проверка корректности заполнения полей
	
	$global:group_name = $global:group_name.Trim()
	$global:login = $global:login.Trim()

	if($global:login -eq '')
	{
		$global:result = 1
		$global:error_msg = 'Ошибка: Не заполнено поле Логин пользователя'
		return
	}

	# Проверка существования пользователя

	$user = $null
	try
	{
		$user = Get-ADUser -Identity $global:login -Properties mail
	}
	catch
	{
		$user = $null
	}

	if(!$user)
	{
		$global:result = 1
		$global:error_msg = 'Ошибка: Пользователь не существует: {0}' -f $global:login
		return
	}
	
	# Адрес пользователя
	
	$global:smtp_to = $user.mail

	# Проверка корректности заполнения полей

	if($global:group_name -eq '')
	{
		$global:result = 1
		$global:error_msg = 'Ошибка: Не заполнено поле Название группы'
		return
	}

	if($global:operation -notin ('ADD', 'DEL'))
	{
		$global:result = 1
		$global:error_msg = 'Ошибка: Не заполнено поле Тип операции'
		return
	}

	$op_add = $global:operation -eq 'ADD'
	
	# Добавление в группы
	
	$text = ''

	$groups_list = $global:group_name -Split ','
	
	foreach($group_nm in $groups_list)
	{
		$group_nm = $group_nm.Trim()

		if($group_nm -eq '')
		{
			continue
		}
		
		# Проверка существования группы

		$group = $null
		try
		{
			$group = Get-ADGroup -Identity $group_nm -Properties Description
		}
		catch
		{
			$group = $null
		}

		if(!$group)
		{
			$global:result = 1
			$global:error_msg += "Ошибка: Группа доступа не найдена: {0};`r`n" -f $group_nm
			continue
		}

		if($group.Count -gt 1)
		{
			$global:result = 1
			$global:error_msg += "Ошибка: Найдено несколько групп с названием: {};`r`n" -f $group_nm
			continue
		}

		if($op_add)
		{
			# Добавление в группу

			$fail = $global:retry_count
			$success = 0
			while($fail -gt 0)
			{
				try
				{
					Add-ADGroupMember -Identity $group -Members $user
					$fail = 0
					$success = 1
				}
				catch
				{
					$fail--
					if($fail -eq 0)
					{
						$global:result = 1
						$global:error_msg += ("Ошибка: Изменения группы ({0});`r`n" -f $_.Exception.Message)
					}
					else
					{
						Start-Sleep -Seconds 20
					}
				}
			}

			# Проверка (непонятно зачем) существования в группе

			if($success)
			{

				try
				{
					$fail = 3
					while($fail -gt 0)
					{
						$members = Get-ADGroupMember -Identity $group
						if($user.SamAccountName -in $members.SamAccountName)
						{
							$fail = 0
							$text += @'
<br />
Учётная запись: <b>{0}</b><br />
Была добавлена в группу: <b>{1}</b><br />
Описание группы: {2}<br />
'@ -f $user.SamAccountName, $group.Name, $group.Description
						}
						else
						{
							$fail--
							if($fail -le 0)
							{
								$global:result = 1
								$global:error_msg += ("Ошибка: Проверка не пройдена. Учётная запись не была добавлена в группу: {0};`r`n" -f $group.Name)
							}
							else
							{
								Start-Sleep -Seconds 10
							}
						}
					}
				}
				catch
				{
					$global:result = 1
					$global:error_msg += ("Ошибка: Проверки существования в группе ({0});`r`n" -f $_.Exception.Message)
				}
			}
		}
		else
		{
			# Удаление из группы

			$fail = $global:retry_count
			$success = 0
			while($fail -gt 0)
			{
				try
				{
					Remove-ADGroupMember -Identity $group -Member $user -Confirm:$false
					$fail = 0
					$success = 1
				}
				catch
				{
					$fail--
					if($fail -eq 0)
					{
						$global:result = 1
						$global:error_msg += ("Ошибка: Изменения группы ({0});`r`n" -f $_.Exception.Message)
					}
					else
					{
						Start-Sleep -Seconds 20
					}
				}
			}

			# Проверка (непонятно зачем) существования в группе

			if($success)
			{

				try
				{
					$fail = 3
					while($fail -gt 0)
					{
						$members = Get-ADGroupMember -Identity $group
						if($user.SamAccountName -notin $members.SamAccountName)
						{
							$fail = 0
							$text += @'
<br />
Учётная запись: <b>{0}</b><br />
Была удалена из группы: <b>{1}</b><br />
Описание группы: {2}<br />
'@ -f $user.SamAccountName, $group.Name, $group.Description
						}
						else
						{
							$fail--
							if($fail -le 0)
							{
								$global:result = 1
								$global:error_msg += ("Ошибка: Проверка не пройдена. Учётная запись не была удалена из группы: {0};`r`n" -f $group.Name)
							}
							else
							{
								Start-Sleep -Seconds 10
							}
						}
					}
				}
				catch
				{
					$global:result = 1
					$global:error_msg += ("Ошибка: Проверки существования в группе ({0});`r`n" -f $_.Exception.Message)
				}
			}
		}

	}

	if($op_add)
	{
		$global:op_name = 'Добавление пользователя в группы'
	}
	else
	{
		$global:op_name = 'Удаление пользователя из групп'
	}

	$global:subject = '{0}: {1}' -f $op_name, $user.SamAccountName
	
	$global:body = @'
<h1>{0}</h1>
<p>{1}
<br />
<br />
Номер инцидента: {2}
</p>
'@ -f $op_name, $text, $global:incident
}

main

if($global:result -ne 0)
{
	$global:body += "<br /><br /><pre class=`"error`">Техническая информация:`r`n`r`n{0}</pre>" -f $global:error_msg
}
