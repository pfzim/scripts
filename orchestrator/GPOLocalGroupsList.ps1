#  GPO list entries from Local Groups

$rb_input = @{
	mail = ''
}

$global:result = 0
$global:error_msg = ''

$ErrorActionPreference = 'Stop'

$global:retry_count = 8

. c:\orchestrator\settings\config.ps1

$global:subject = ''
$global:body = ''
$global:smtp_to = @($global:g_config.admin_email, $global:g_config.useraccess_email)

if($rb_input.mail)
{
	$global:smtp_to += @($rb_input.mail)
}

$global:smtp_to = $global:smtp_to -join ','

function main($rb_input)
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

	$xml_file = ('\\{1}\{0}\Machine\Preferences\Groups\Groups.xml' -f $global:g_config.gpo_local_groups_path, $domain.PDCEmulator)

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

	$global:subject = 'Список предоставленных локальных прав на ПК'

	$global:body = '<h2>Список предоставленных локальных прав на ПК</h2>'

	$global:body += '<table>'
	$global:body +=  '<tr><th>Local group</th><th>Login</th><th>Computer</th></tr>'
	
	$table = $table | Sort-Object GroupName, Members, Computers
	
	foreach($row in $table)
	{
		$global:body +=  '<tr><td>{0}</td><td>{1}</td><td>{2}</td></tr>' -f $row.GroupName, $row.Members, $row.Computers
	}
	
	$global:body += '</table>'

	$global:body += '<br /><small><a href="{0}/orchestrator/start-runbook.php?id=3db0cebd-3339-4aec-959c-0138a5ba7e0d&param[fe287297-b00d-4ece-94e4-eb9a56297cd2]={1}">Сформировать отчёт заново</a></small>' -f $global:g_config.cdb_url, $rb_input.mail
}

main -rb_input $rb_input

if($global:result -ne 0)
{
	$global:body += "<br /><br /><pre class=`"error`">Техническая информация:`r`n`r`n{0}</pre>" -f $global:error_msg
}
