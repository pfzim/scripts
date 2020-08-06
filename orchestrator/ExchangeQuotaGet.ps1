# Exchange get quota

$global:login = ''

$global:exch_creds = New-Object System.Management.Automation.PSCredential ("", (ConvertTo-SecureString "" -AsPlainText -Force))

$ErrorActionPreference = 'Stop'

. c:\orchestrator\settings\config.ps1

$global:result = 0
$global:error_msg = ''
$global:message = ''

function main()
{
	trap
	{
		$global:result = 1
		$global:error_msg += ("Критичная ошибка: {0}`r`n`r`nПроцесс прерван!`r`n" -f $_);
		return;
	}

	# Проверка корректности заполнения полей

	if($global:login -eq '')
	{
		$global:result = 1
		$global:error_msg = 'Ошибка: Не корректно заполнены обязательные поля'
		return
	}

	try
	{
		$session = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri $global:g_config.exch_conn_uri -Credential $global:exch_creds -Authentication Basic
		Import-PSSession $session

		try
		{
			$mbx = Get-Mailbox -Identity $global:login
			$global:message = 'Квота: {0}' -f $mbx.ProhibitSendReceiveQuota
		}
		catch
		{
			$global:result = 1
			$global:error_msg += ("Ошибка получения информации о почтовом ящике (" + $_.Exception.Message + ");`r`n")
		}

		Remove-PSSession -Session $session
	}
	catch
	{
		$global:result = 1
		$global:error_msg += ("Критичная ошибка подключения к серверу Exchange (" + $_.Exception.Message + ");`r`n")
	}
}

main
