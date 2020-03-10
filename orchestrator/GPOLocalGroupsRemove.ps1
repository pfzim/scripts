#  GPO remove entries from Local Groups

$global:login = ''
$global:compname = ''
$global:code = ''

$global:smtp_creds = New-Object System.Management.Automation.PSCredential ('', (ConvertTo-SecureString '' -AsPlainText -Force))

$ErrorActionPreference = 'Stop'

$global:result = 0
$global:error_msg = ''

trap
{
	$global:result = 1
	$global:error_msg += ("Критичная ошибка: {0}`r`n`r`nПроцесс прерван!`r`n" -f $_.Exception.Message);
	return;
}

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

	if($global:code -eq 'adm')
	{
		$groupsid = 'S-1-5-32-544'    # Administrators (built-in)
	}
	elseif($global:code -eq 'rdp')
	{
		$groupsid = 'S-1-5-32-555'    # Remote Desktop Users (built-in)
	}
	elseif($global:code -eq 'all')
	{
		$groupsid = $null
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
							if($filter.Name -eq $comp.Name)
							{
								$global:error_msg += "Удалена запись: {2} : {0} at {1};`r`n" -f $user.'msDS-PrincipalName', $comp.Name, $group.Name
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
Были удалены локальных права на ПК:<br />
<br />
Пользователь: <b>{0}</b><br />
Компьютер: <b>{1}</b><br />
Код операции: <b>{3}</b><br />
<br />
<br />
<u>Техническая информация</u>:<br />{2}<br />
'@ -f $global:login, $compname, $global:error_msg.Replace("`r`n", "<br />`r`n"), $global:code

	$body += @'
</body>
</html>
'@

	try
	{
		Send-MailMessage -from $global:smtp_from -to $global:smtp_to -Encoding UTF8 -subject "Удаление локальных прав на ПК" -bodyashtml -body $body -smtpServer $global:smtp_server -Credential $global:smtp_creds
	}
	catch
	{
		$global:result = 1
		$global:error_msg += ("Ошибка отправки письма (" + $_.Exception.Message + ");`r`n")
	}
}

main
