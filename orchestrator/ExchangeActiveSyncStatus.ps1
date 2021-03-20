# Exchange get ActiveSync status

$global:email = ''

$global:exch_creds = New-Object System.Management.Automation.PSCredential ('', (ConvertTo-SecureString '' -AsPlainText -Force))

$ErrorActionPreference = 'Stop'

. c:\orchestrator\settings\config.ps1

$global:result = 0
$global:error_msg = ''
$global:info = ''

function main()
{
	trap
	{
		$global:result = 1
		$global:error_msg += ("Критичная ошибка: {0}`r`n`r`nПроцесс прерван!`r`n" -f $_.Exception.Message);
		return;
	}

	# Проверка корректности заполнения полей

	if($global:email -eq '')
	{
		$global:result = 1
		$global:error_msg = 'Ошибка: Не корректно заполнены обязательные поля'
		return
	}

	# Получение информации
	try
	{
		$session = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri $global:g_config.exch_conn_uri -Credential $global:exch_creds -Authentication Basic
		Import-PSSession $session

		$mbx_cas = Get-CASMailbox -Identity $global:email
		
		$mbx_devs = Get-MobileDevice -Mailbox $global:email
		
		if($mbx_cas.ActiveSyncEnabled)
		{
			$global:info = "ActiveSync: Enabled`r`n"
		}
		else
		{
			$global:info = "ActiveSync: Disabled`r`n"
		}
		
		foreach($dev in $mbx_devs)
		{
			$global:info += "{0} - {1}`r`n" -f $dev.DeviceId, $dev.DeviceAccessState
		}

		Remove-PSSession -Session $session
	}
	catch
	{
		$global:result = 1
		$global:error_msg += 'Ошибка: {0}' -f $_.Exception.Message
		return
	}
}

main
