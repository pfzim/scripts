#  GPO remove entries from Local Groups

$global:login = ''
$global:compname = ''

$smtp_creds = New-Object System.Management.Automation.PSCredential ('', (ConvertTo-SecureString '' -AsPlainText -Force))

$smtp_to = @("admin@contoso.com", "helpdesk@contoso.com")
$smtp_server = "smtp.contoso.com"

$global:gpo_path = '\\contoso.com\SYSVOL\contoso.com\Policies\{74D81F96-AC85-4F56-A914-B63BE6C4E6AD}'

$ErrorActionPreference = 'Stop'

$global:result = 0
$global:error_msg = ''

function main()
{
	try
	{
		Copy-Item -Path ('{0}\Machine\Preferences\Groups\Groups.xml' -f $global:gpo_path) -Destination ('c:\_backup\Groups-{0}.xml' -f (Get-Date -format "yyyy-MM-dd-HHmmss"))
	}
	catch
	{
		$global:result = 1
		$global:error_msg = 'Ошибка создания резервной копии: {0}' -f $_.Exception.Message
		return
	}

	try
	{
		$user = Get-ADUser -Identity $global:login -Properties 'msDS-PrincipalName'
	}
	catch
	{
		$global:result = 1
		$global:error_msg = 'Ошибка в логине пользователя: {0}' -f $_.Exception.Message
		return
	}

	try
	{
		$comp = Get-ADComputer -Identity $global:compname
	}
	catch
	{
		$global:result = 1
		$global:error_msg = 'Ошибка в имени ПК: {0}' -f $_.Exception.Message
		return
	}

	try
	{
		[xml] $xml = Get-Content -Path ('{0}\Machine\Preferences\Groups\Groups.xml' -f $global:gpo_path)
	}
	catch
	{
		$global:result = 1
		$global:error_msg = 'Ошибка открытия политики: {0}' -f $_.Exception.Message
		return
	}

	$count = 0
	
	try
	{
		# Delete entries
		
		foreach($group in $xml.Groups.Group)
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
	catch
	{
		$global:result = 1
		$global:error_msg = 'Ошибка удаления из политики: {0}' -f $_.Exception.Message
		return
	}

	if($count -le 0)
	{
		$global:result = 1
		$global:error_msg = 'Для указанного пользователя и ПК записей не найдено!'
		return
	}
	
	try
	{
		$xml.Save(('{0}\Machine\Preferences\Groups\Groups.xml' -f $global:gpo_path))
	}
	catch
	{
		$global:result = 1
		$global:error_msg = 'Ошибка сохранения политики: {0}' -f $_.Exception.Message
		return
	}
}

main

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
Были удалены административные права на ПК:<br />
<br />
Пользователь: <b>{0}</b><br />
Компьютер: <b>{1}</b><br />
<br />
<br />
<u>Техническая информация</u>: {2}<br />
'@ -f $global:login, $compname, $global:error_msg.Replace("`r`n", "<br />`r`n")

$body += @'
</body>
</html>
'@

try
{
	Send-MailMessage -from "orchestrator@contoso.com" -to $smtp_to -Encoding UTF8 -subject "Удаление административных прав на ПК" -bodyashtml -body $body -smtpServer $smtp_server -Credential $smtp_creds
}
catch
{
	$global:result = 1
	$global:error_msg += ("Ошибка отправки письма (" + $_.Exception.Message + ");`r`n")
}
