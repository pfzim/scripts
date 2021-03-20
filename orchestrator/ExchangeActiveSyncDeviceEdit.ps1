# Exchange ActiveSync add or remove mobile device

$global:device_del = ''
$global:device_add = ''
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

	if([string]::IsNullOrEmpty($global:email) -or ([string]::IsNullOrEmpty($global:device_add) -and [string]::IsNullOrEmpty($global:device_del)))
	{
		$global:result = 1
		$global:error_msg = 'Ошибка: Не корректно заполнены обязательные поля'
		return
	}

	# Добавление/удаление устройства
	try
	{
		$session = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri $global:g_config.exch_conn_uri -Credential $global:exch_creds -Authentication Basic
		Import-PSSession $session

		if(![string]::IsNullOrEmpty($global:device_del))
		{
			Set-CASMailbox -Identity $global:email -ActiveSyncBlockedDeviceIDs @{ add = $global:device_del }
		}

		if(![string]::IsNullOrEmpty($global:device_add))
		{
			Set-CASMailbox –Identity $global:email -ActiveSyncallowedDeviceIDs @{ add = $global:device_add }
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
