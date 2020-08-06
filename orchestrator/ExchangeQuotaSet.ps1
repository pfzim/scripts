# Exchange set quota

$global:login = ''
$global:quota = ''

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

	# Проверка корректности заполнения полей

	if($global:quota -notin $global:g_config.exch_quotas -or $global:login -eq '')
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
			if($global:quota -eq 'unlim')
			{
				Set-Mailbox -Identity $global:login -IssueWarningQuota Unlimited -ProhibitSendQuota Unlimited -ProhibitSendReceiveQuota Unlimited -UseDatabaseQuotaDefaults $false
			}
			else
			{
				Set-Mailbox -Identity $global:login -IssueWarningQuota ([math]::Round(([int] $global:quota)*1024*0.93)*1mb) -ProhibitSendQuota ([math]::Round(([int] $global:quota)*1024*0.96)*1mb) -ProhibitSendReceiveQuota (([int] $global:quota)*1gb) -UseDatabaseQuotaDefaults $false
			}
		}
		catch
		{
			$global:result = 1
			$global:error_msg += ("Ошибка установки квоты (" + $_.Exception.Message + ");`r`n")
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
