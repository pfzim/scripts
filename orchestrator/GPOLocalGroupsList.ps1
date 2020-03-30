#  GPO list entries from Local Groups

$global:mail = ''

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

$global:smtp_to = @($global:admin_email)

if($global:mail)
{
	$global:smtp_to += @($global:mail)
}

function main()
{
	trap
	{
		$global:result = 1
		$global:error_msg += ("Критичная ошибка: {0}`r`n`r`nПроцесс прерван!`r`n" -f $_.Exception.Message);
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

	$xml_file = ('\\{1}\{0}\Machine\Preferences\Groups\Groups.xml' -f $global:gpo_local_groups_path, $domain.PDCEmulator)

	try
	{
		[xml] $xml = Get-Content -Path $xml_file
	}
	catch
	{
		$global:result = 1
		$global:error_msg = 'Ошибка открытия политики: {0}' -f $_.Exception.Message
		return
	}

	$count = 0
	$table = @()
	
	try
	{
		# List entries
		
		foreach($group in $xml.Groups.Group)
		{
			$output = new-object psobject
			$output | add-member noteproperty "GroupName" $group.Properties.groupName
			$output | add-member noteproperty "Members" ($group.Properties.Members.Member.name -join '; ')
			$output | add-member noteproperty "Computers" ($group.Filters.FilterComputer.name -join '; ')

			$table += $output
		}
	}
	catch
	{
		$global:result = 1
		$global:error_msg = 'Ошибка чтения из политики: {0}' -f $_.Exception.Message
		return
	}

	$body = @'
<html>
<head>
	<meta http-equiv="Content-Type" content="text/html; charset=utf-8">
	<style>
		body{font-family: Courier New; font-size: 8pt;}
		h1{font-size: 16px;}
		h2{font-size: 14px;}
		h3{font-size: 12px;}
		table{border: 1px solid black; border-collapse: collapse; font-size: 8pt;}
		th{border: 1px solid black; background: #dddddd; padding: 5px; color: #000000;}
		td{border: 1px solid black; padding: 5px; }
		.pass {background: #7FFF00;}
		.warn {background: #FFE600;}
		.error {background: #FF0000; color: #ffffff;}
	</style>
</head>
<body>
'@

	$body += '<h2>Список предоставленных локальных прав на ПК</h2>'

	$body += '<table>'
	$body +=  '<tr><th>Local group</th><th>Login</th><th>Computer</th></tr>'
	
	$table = $table | Sort-Object GroupName, Members, Computers
	
	foreach($row in $table)
	{
		$body +=  '<tr><td>{0}</td><td>{1}</td><td>{2}</td></tr>' -f $row.GroupName, $row.Members, $row.Computers
	}
	
	$body += '</table>'

	$body += $global:error_msg

	$body += @'
<br /><small><a href="http://web.bristolcapital.ru/orchestrator/start-runbook.php?id=3db0cebd-3339-4aec-959c-0138a5ba7e0d&param[fe287297-b00d-4ece-94e4-eb9a56297cd2]={0}">Сформировать отчёт заново</a></small>
</body>
</html>
'@ -f $global:mail

	try
	{
		Send-MailMessage -from $global:smtp_from -to $global:smtp_to -Encoding UTF8 -subject "Список предоставленных локальных прав на ПК" -bodyashtml -body $body -smtpServer $global:smtp_server -Credential $global:smtp_creds
	}
	catch
	{
		$global:result = 1
		$global:error_msg += ("Ошибка отправки письма (" + $_.Exception.Message + ");`r`n")
	}
}

main
