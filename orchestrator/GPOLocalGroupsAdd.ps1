#  GPO add entries to Local Groups

$global:login = ''
$global:compname = ''
$global:code = ''

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

$global:smtp_to = @($global:admin_email, $global:helpdesk_email, $global:techsupport_email, $global:useraccess_email)

function main()
{
	trap
	{
		$global:result = 1
		$global:error_msg += ("Критичная ошибка: {0}`r`n`r`nПроцесс прерван!`r`n" -f $_.Exception.Message);
		return;
	}

	$add_to_admin = 0
	$add_to_rdp = 0

	if($global:code -eq 'adm')
	{
		$groupsid = 'S-1-5-32-544'    # Administrators (built-in)
		$add_to_admin = 1
	}
	elseif($global:code -eq 'rdp')
	{
		$groupsid = 'S-1-5-32-555'    # Remote Desktop Users (built-in)
		$add_to_rdp = 1
	}
	elseif($global:code -eq 'all' -or $global:code -eq 'rms')
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

	# Create policy backup
	try
	{
		Copy-Item -Path ('{0}\Machine\Preferences\Groups\Groups.xml' -f $global:gpo_local_groups_path) -Destination ('c:\_backup\Groups-{0}.xml' -f (Get-Date -format "yyyy-MM-dd-HHmmss"))
	}
	catch
	{
		$global:result = 1
		$global:error_msg += 'Ошибка создания резервной копии: {0}' -f $_.Exception.Message
		return
	}

	$user = $null
	try
	{
		$user = Get-ADUser -Identity $global:login -Properties 'msDS-PrincipalName'
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
		$comp = Get-ADComputer -Identity $global:compname
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
		[xml] $xml = Get-Content -Path ('{0}\Machine\Preferences\Groups\Groups.xml' -f $global:gpo_local_groups_path)
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
								$global:result = 1
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

	try
	{
		$xml.Save(('{0}\Machine\Preferences\Groups\Groups.xml' -f $global:gpo_local_groups_path))
	}
	catch
	{
		$global:result = 1
		$global:error_msg += 'Ошибка сохранения политики: {0}' -f $_.Exception.Message
		return
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
Предоставлены локальные права на ПК:<br />
<br />
Пользователь: <b>{0}</b><br />
Компьютер: <b>{1}</b><br />
Код операции: <b>{3}</b><br />
<br />
<br />
<u>Техническая информация</u>:<br />{2}<br />
'@ -f $global:login, $compname, $global:error_msg, $global:code

	$body += @'
</body>
</html>
'@

	try
	{
		Send-MailMessage -from $global:smtp_from -to $global:smtp_to -Encoding UTF8 -subject "Предоставление локальные права на ПК" -bodyashtml -body $body -smtpServer $global:smtp_server -Credential $global:smtp_creds
	}
	catch
	{
		$global:result = 1
		$global:error_msg += ("Ошибка отправки письма (" + $_.Exception.Message + ");`r`n")
	}
}

main
