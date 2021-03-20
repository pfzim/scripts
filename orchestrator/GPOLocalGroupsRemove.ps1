#  GPO remove entries from Local Groups

$rb_input = @{
	login = ''
	compname = ''
	code = ''
}

$global:result = 0
$global:error_msg = ''

$ErrorActionPreference = 'Stop'

$global:retry_count = 10

. c:\orchestrator\settings\config.ps1

$global:subject = ''
$global:body = ''
$global:smtp_to = @($global:g_config.admin_email, $global:g_config.helpdesk_email, $global:g_config.techsupport_email, $global:g_config.useraccess_email)
$global:smtp_to = $global:smtp_to -join ','

function main($rb_input)
{
	trap
	{
		$global:result = 1
		$global:error_msg += ("Критичная ошибка: {0}`r`n`r`nПроцесс прерван!`r`n" -f $_.Exception.Message);
		return;
	}

	if($rb_input.code -eq 'adm')
	{
		$groupsid = 'S-1-5-32-544'    # Administrators (built-in)
	}
	elseif($rb_input.code -eq 'rdp')
	{
		$groupsid = 'S-1-5-32-555'    # Remote Desktop Users (built-in)
	}
	elseif($rb_input.code -eq 'all' -or $rb_input.code -eq 'rms')
	{
		$groupsid = $null
	}
	else
	{
		$global:result = 1
		$global:error_msg += "Введён некорректный код операции`r`n";
		return;
	}

	try
	{
		$domain = Get-ADDomain
	}
	catch
	{
		$global:result = 1
		$global:error_msg += 'Ошибка: {0}' -f $_.Exception.Message
		return
	}
	
	$xml_file = ('\\{1}\{0}\Machine\Preferences\Groups\Groups.xml' -f $global:g_config.gpo_local_groups_path, $domain.PDCEmulator)
	
	# Create policy backup
	try
	{
		Copy-Item -Path $xml_file -Destination ('c:\_backup\Groups-{0}.xml' -f (Get-Date -format "yyyy-MM-dd-HHmmss"))
	}
	catch
	{
		$global:result = 1
		$global:error_msg += 'Ошибка создания резервной копии: {0}' -f $_.Exception.Message
		return
	}

	if([string]::IsNullOrEmpty($rb_input.login))
	{
		$global:result = 1
		$global:error_msg += 'Ошибка в логине пользователя'
		return
	}

	if([string]::IsNullOrEmpty($rb_input.compname))
	{
		$global:result = 1
		$global:error_msg += 'Ошибка в имени ПК'
		return
	}

	$global:subject = 'Удаление локальных прав на ПК: {0} - {1}' -f $rb_input.login, $rb_input.compname

	$user = $null
	try
	{
		$user = Get-ADUser -Identity $rb_input.login -Properties 'msDS-PrincipalName'
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
	
	<#
	$comp = $null
	try
	{
		$comp = Get-ADComputer -Identity $rb_input.compname
	}
	catch
	{
		$global:result = 1
		$global:error_msg += 'Ошибка в имени ПК: {0}' -f $_.Exception.Message
		return
	}

	if(!$comp)
	{
		$global:result = 1
		$global:error_msg += 'Ошибка в имени ПК'
		return
	}
	#>

	try
	{
		[xml] $xml = Get-Content -Path $xml_file
	}
	catch
	{
		$global:result = 1
		$global:error_msg += 'Ошибка открытия политики: {0}' -f $_.Exception.Message
		return
	}

	$count = 0
	
	try
	{
		# Delete entries

		foreach($group in $xml.Groups.Group)
		{
			if(!$groupsid -or $group.Properties.groupSid -eq $groupsid)
			{
				foreach($member in $group.Properties.Members.Member)
				{
					if($member.Name -eq $user.'msDS-PrincipalName')
					{
						foreach($filter in $group.Filters.FilterComputer)
						{
							if($filter.Name -eq $rb_input.compname)
							{
								$global:error_msg += "Удалена запись: {2} : {0} at {1};`r`n" -f $user.'msDS-PrincipalName', $rb_input.compname, $group.Name
								$xml.Groups.RemoveChild($group) | Out-Null
								$count++
							}
						}
					}
				}
			}
		}
	}
	catch
	{
		$global:result = 1
		$global:error_msg += 'Ошибка удаления из политики: {0}' -f $_.Exception.Message
		return
	}

	if($count -le 0)
	{
		$global:result = 1
		$global:error_msg += 'Для указанного пользователя и ПК записей не найдено!'
		return
	}
	
	$fail = $global:retry_count
	while($fail -gt 0)
	{
		try
		{
			$xml.Save($xml_file)
			$fail = 0
		}
		catch
		{
			$fail--
			if($fail -eq 0)
			{
				$global:result = 1
				$global:error_msg += "Ошибка сохранения политики: {0}`r`n" -f $_.Exception.Message
				return
			}
			Start-Sleep -Seconds 10
		}
	}


	# Формирование информационного сообщения
	
	$global:body += @'
		<h1>Были удалены локальные права на ПК:</h1>
		<p>
			Пользователь: <b>{0}</b><br />
			Компьютер: <b>{1}</b><br />
			Код операции: <b>{2}</b>
		</p>
'@ -f $user.'msDS-PrincipalName', $rb_input.compname, $rb_input.code

}

main -rb_input $rb_input

if($global:result -ne 0)
{
	$global:body += "<br /><br /><pre class=`"error`">Техническая информация:`r`n`r`n{0}</pre>" -f $global:error_msg
}
