# List group members (dynamic or security group)

$global:group_name = ''
$global:smtp_to = ''

$global:exch_creds = New-Object System.Management.Automation.PSCredential ('', (ConvertTo-SecureString '' -AsPlainText -Force))

$ErrorActionPreference = 'Stop'

. c:\orchestrator\settings\config.ps1

$global:result = 0
$global:recipients_list = ''
$global:error_msg = ''

$global:body = ''
$global:subject = ''

function main()
{
	trap
	{
		$global:result = 1
		$global:error_msg += ("Критичная ошибка: {0}`r`n`r`nПроцесс прерван!`r`n" -f $_);
		return;
	}

	if($global:smtp_to -eq '' -or $global:group_name -eq '')
	{
		$global:result = 1
		$global:error_msg = 'Ошибка: Не корректно заполнены обязательные поля'
		return
	}

	$grp = $null
	try
	{
		$name = $global:group_name
		$grp = Get-ADGroup -Filter {name -eq $name}
	}
	catch
	{
		$grp = $null
	}
	
	if($grp)
	{
		$members = Get-ADGroupMember -Identity $grp
		
		foreach($recipient in $members)
		{
			$global:recipients_list += ("{0}`r`n" -f $recipient.Name)
		}
	}
	else
	{
		try
		{
			$session = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri $global:g_config.exch_conn_uri -Credential $global:exch_creds -Authentication Basic
			Import-PSSession $session

			try
			{
				$ddg = Get-DynamicDistributionGroup -Identity $global:group_name
				$recipients = Get-Recipient -RecipientPreviewFilter $ddg.RecipientFilter -OrganizationalUnit $ddg.RecipientContainer
				foreach($recipient in $recipients)
				{
					$global:recipients_list += ("{0}`r`n" -f $recipient.Name)
				}
			}
			catch
			{
				$global:result = 1
				$global:error_msg += ("Ошибка получения информации о группе (" + $_.Exception.Message + ");`r`n")
			}

			Remove-PSSession -Session $session
		}
		catch
		{
			$global:result = 1
			$global:error_msg += ("Критичная ошибка подключения к серверу Exchange (" + $_.Exception.Message + ");`r`n")
		}
	}
	
	$global:subject = 'List group members: {0}' -f $global:group_name
	
	$global:body += '<h2>Состав группы: {0}</h2>' -f $global:group_name
	$global:body += '<table>'
	$global:body += '<tr><th>Address</th></tr>'
	$global:body += '<tr><td>{0}</td></tr>' -f ($global:recipients_list -replace "`r`n", '</td></tr><tr><td>')
	$global:body += '</table>'
	
	if($global:result -ne 0)
	{
		$global:body += "<br /><br /><pre>Детали выполнения ранбука:`r`n`r`n{0}</pre>" -f $global:error_msg
	}
}

main
