$global:email = ''
$global:name = ''
$global:company = ''

$global:exch_creds = New-Object System.Management.Automation.PSCredential ('', (ConvertTo-SecureString '' -AsPlainText -Force))

$ErrorActionPreference = 'Stop'

. c:\orchestrator\settings\config.ps1

$global:result = 0
$global:error_msg = ''

function main()
{
	trap
	{
		$global:result = 1
		$global:error_msg += ("Критичная ошибка: {0}`r`n`r`nПроцесс прерван!`r`n" -f $_);
		return;
	}

	if($global:company -eq '' -or $global:name -eq '' -or $global:email -eq '')
	{
		$global:result = 1
		$global:error_msg = 'Ошибка: Не заполнены все обязательные поля'
		return
	}

	try
	{
		$session = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri $global:g_config.exch_conn_uri -Credential $global:exch_creds -Authentication Basic
		Import-PSSession $session

		# Редактировние почтового контакта

		try
		{
			$new_contact = Get-MailContact -Identity $global:email
			$new_contact | Set-Contact -DisplayName $global:name -Company $global:company
		}
		catch
		{
			$global:result = 1
			$global:error_msg += ("Ошибка редактирования почтового ящика (" + $_.Exception.Message + ");`r`n")
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
