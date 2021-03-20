#  GPO add entries to Local Groups

$rb_input = @{
	login = ''
	compname = ''
	code = ''
	comment = ''
}

$global:result = 0
$global:error_msg = ''

$ErrorActionPreference = 'Stop'

$global:retry_count = 8

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

	$add_to_admin = 0
	$add_to_rdp = 0

	if($rb_input.code -eq 'adm')
	{
		$groupsid = 'S-1-5-32-544'    # Administrators (built-in)
		$add_to_admin = 1
	}
	elseif($rb_input.code -eq 'rdp')
	{
		$groupsid = 'S-1-5-32-555'    # Remote Desktop Users (built-in)
		$add_to_rdp = 1
	}
	elseif($rb_input.code -eq 'all' -or $rb_input.code -eq 'rms')
	{
		$groupsid = $null
		$add_to_admin = 1
		$add_to_rdp = 1
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

	$global:subject = 'Предоставление локальные права на ПК: {0} - {1}' -f $rb_input.login, $rb_input.compname

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

	try
	{
		# Duplicate entry find
		
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
							if($filter.Name -eq $comp.Name)
							{
								$global:result = 0
								$global:error_msg += 'Duplicate entry found: {2} : {0} at {1}' -f $user.'msDS-PrincipalName', $comp.Name, $group.Name
								if($group.Properties.groupSid -eq 'S-1-5-32-544')
								{
									$add_to_admin = 0
								}
								elseif($group.Properties.groupSid -eq 'S-1-5-32-555')
								{
									$add_to_rdp = 0
								}
								#return
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
		$global:error_msg += 'Ошибка поиска дубликата: {0}' -f $_.Exception.Message
		return
	}

	try
	{
		# Add user to Administrators group
		if($add_to_admin)
		{
			$group = $xml.CreateElement('Group')

			$group.SetAttribute('clsid', '{6D4A79E4-529C-4481-ABD0-F5BD7EA93BA7}')
			$group.SetAttribute('name', ('{0} to {1} - Administrators (built-in)' -f $user.SamAccountName, $comp.Name))
			$group.SetAttribute('image', '2')
			$group.SetAttribute('changed', (Get-Date -format "yyyy-MM-dd HH:mm:ss"))
			$group.SetAttribute('uid', ("{{{0}}}" -f [guid]::NewGuid().Guid.ToUpper()))
			$group.SetAttribute('userContext', '0')
			$group.SetAttribute('removePolicy', '0')

			$properties = $xml.CreateElement('Properties')

			$properties.SetAttribute('action', 'U')
			$properties.SetAttribute('newName', '')
			$properties.SetAttribute('description', '')
			$properties.SetAttribute('deleteAllUsers', '0')
			$properties.SetAttribute('deleteAllGroups', '0')
			$properties.SetAttribute('removeAccounts', '0')
			$properties.SetAttribute('groupSid', 'S-1-5-32-544')
			$properties.SetAttribute('groupName', 'Administrators (built-in)')

			$members = $xml.CreateElement('Members')
			$member = $xml.CreateElement('Member')

			$member.SetAttribute('name', $user.'msDS-PrincipalName')
			$member.SetAttribute('action', 'ADD')
			$member.SetAttribute('sid', $user.SID.Value)

			$filters = $xml.CreateElement('Filters')
			$filter = $xml.CreateElement('FilterComputer')

			$filter.SetAttribute('bool', 'AND')
			$filter.SetAttribute('not', '0')
			$filter.SetAttribute('type', 'NETBIOS')
			$filter.SetAttribute('name', $comp.Name)

			$filters.AppendChild($filter) | Out-Null

			$members.AppendChild($member) | Out-Null
			$properties.AppendChild($members) | Out-Null

			$group.AppendChild($properties) | Out-Null
			$group.AppendChild($filters) | Out-Null

			$xml.Groups.AppendChild($group) | Out-Null
		}
		
		# Add user to Remote Desktop Users group
		if($add_to_rdp)
		{
			$group = $xml.CreateElement('Group')

			$group.SetAttribute('clsid', '{6D4A79E4-529C-4481-ABD0-F5BD7EA93BA7}')
			$group.SetAttribute('name', ('{0} to {1} - Remote Desktop Users (built-in)' -f $user.SamAccountName, $comp.Name))
			$group.SetAttribute('image', '2')
			$group.SetAttribute('changed', (Get-Date -format "yyyy-MM-dd HH:mm:ss"))
			$group.SetAttribute('uid', ("{"+([guid]::NewGuid()).Guid.ToUpper()+"}"))
			$group.SetAttribute('userContext', '0')
			$group.SetAttribute('removePolicy', '0')

			$properties = $xml.CreateElement('Properties')

			$properties.SetAttribute('action', 'U')
			$properties.SetAttribute('newName', '')
			$properties.SetAttribute('description', '')
			$properties.SetAttribute('deleteAllUsers', '0')
			$properties.SetAttribute('deleteAllGroups', '0')
			$properties.SetAttribute('removeAccounts', '0')
			$properties.SetAttribute('groupSid', 'S-1-5-32-555')
			$properties.SetAttribute('groupName', 'Remote Desktop Users (built-in)')

			$members = $xml.CreateElement('Members')
			$member = $xml.CreateElement('Member')

			$member.SetAttribute('name', $user.'msDS-PrincipalName')
			$member.SetAttribute('action', 'ADD')
			$member.SetAttribute('sid', $user.SID.Value)

			$filters = $xml.CreateElement('Filters')
			$filter = $xml.CreateElement('FilterComputer')

			$filter.SetAttribute('bool', 'AND')
			$filter.SetAttribute('not', '0')
			$filter.SetAttribute('type', 'NETBIOS')
			$filter.SetAttribute('name', $comp.Name)

			$filters.AppendChild($filter) | Out-Null

			$members.AppendChild($member) | Out-Null
			$properties.AppendChild($members) | Out-Null

			$group.AppendChild($properties) | Out-Null
			$group.AppendChild($filters) | Out-Null

			$xml.Groups.AppendChild($group) | Out-Null
		}
	}
	catch
	{
		$global:result = 1
		$global:error_msg += 'Ошибка добавления параметров: {0}' -f $_.Exception.Message
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
				$global:error_msg += 'Ошибка сохранения политики: {0}' -f $_.Exception.Message
				return
			}
			Start-Sleep -Seconds 10
		}
	}


	# Формирование информационного сообщения
	
	$global:body += @'
		<h1>Предоставлены локальные права на ПК:</h1>
		<p>
			Пользователь: <b>{0}</b><br />
			Компьютер: <b>{1}</b><br />
			Код операции: <b>{2}</b><br />
			Номер заявки: <b>{3}</b>
		</p>
'@ -f $user.'msDS-PrincipalName', $rb_input.compname, $rb_input.code, $rb_input.comment
}

main -rb_input $rb_input

if($global:result -ne 0)
{
	$global:body += "<br /><br /><pre class=`"error`">Техническая информация:`r`n`r`n{0}</pre>" -f $global:error_msg
}
