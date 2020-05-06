# Exchange transport rule - add address to list

$global:address = ''

$global:exch_creds = New-Object System.Management.Automation.PSCredential ('', (ConvertTo-SecureString '' -AsPlainText -Force))
$global:smtp_creds = New-Object System.Management.Automation.PSCredential ('', (ConvertTo-SecureString '' -AsPlainText -Force))

$global:rules_out = @('Запрещено в интернет', 'Запрещено в интернет 2', 'Запрещено в интернет 3')
$global:rules_in = @('Запрещено из интернета', 'Запрещено из интернета 2', 'Запрещено из интернета 3')

$ErrorActionPreference = 'Stop'

. c:\orchestrator\settings\config.ps1

$global:smtp_to = @($global:g_config.admin_email, $global:g_config.uib_email)

$global:result = 0
$global:error_msg = ''

function main()
{
	trap
	{
		$global:result = 1
		$global:error_msg += ("Критичная ошибка: {0}`r`n`r`nПроцесс прерван!`r`n" -f $_.Exception.Message);
		return;
	}

	# Проверка корректности заполнения полей

	if($global:address -eq '' -or $global:address -notmatch '^.+@.+\..+$')
	{
		$global:result = 1
		$global:error_msg = 'Ошибка: Не корректно заполнены обязательные поля'
		return
	}

	try
	{
		$session = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri $global:g_config.exch_conn_uri -Credential $global:exch_creds -Authentication Basic
		Import-PSSession $session

		$address_exist = 0

		foreach($rule in $global:rules_out)
		{
			$list = (Get-TransportRule -Identity $rule).SentTo
			if($list -contains $global:address)
			{
				$address_exist = 1
				$global:error_msg += ("Адрес {0} уже присутствует в правиле {1}`r`n" -f $global:address, $rule)
				break
			}
		}

		if(!$address_exist)
		{
			$address_exist = 0
			foreach($rule in $global:rules_out)
			{
				$list = (Get-TransportRule -Identity $rule).SentTo
				$list += $global:address
				
				try
				{
					Set-TransportRule -Identity $rule -SentTo $list
				}
				catch
				{
					# Проглатываем ошибку (length limit 40960)
					continue
				}

				$list = (Get-TransportRule -Identity $rule).SentTo
				if($list -contains $global:address)
				{
					$address_exist = 1
					$global:error_msg += ("Адрес {0} успешно добавлен в правило {1}`r`n" -f $global:address, $rule)
					break
				}
			}
			
			if(!$address_exist)
			{
				$global:result = 1
				$global:error_msg += ("Неизвестная ошибка: Адрес {0} не был добавлен ни в одно правило`r`n" -f $global:address)
			}
		}
	
		$address_exist = 0
		
		foreach($rule in $global:rules_in)
		{
			$list = (Get-TransportRule -Identity $rule).From
			if($list -contains $global:address)
			{
				$address_exist = 1
				$global:error_msg += ("Адрес {0} уже присутствует в правиле {1}`r`n" -f $global:address, $rule)
				break
			}
		}

		if(!$address_exist)
		{
			foreach($rule in $global:rules_in)
			{
				$list = (Get-TransportRule -Identity $rule).From
				$list += $global:address

				try
				{
					Set-TransportRule -Identity $rule -From $list
				}
				catch
				{
					# Проглатываем ошибку
					continue
				}

				$list = (Get-TransportRule -Identity $rule).From
				if($list -contains $global:address)
				{
					$address_exist = 1
					$global:error_msg += ("Адрес {0} успешно добавлен в правило {1}`r`n" -f $global:address, $rule)
					break
				}
			}

			if(!$address_exist)
			{
				$global:result = 1
				$global:error_msg += ("Неизвестная ошибка: Адрес {0} не был добавлен ни в одно правило`r`n" -f $global:address)
			}
		}
		
		Remove-PSSession -Session $session

	}
	catch
	{
		$global:result = 1
		$global:error_msg += ("Ошибка: {0}`r`n" -f $_.Exception.Message)
		return
	}

	# Отправка информационного письма

	$subject = ('E-Mail address blocked: {0}' -f $global:address)

	$global:body = @'
<html>
<head>
	<meta http-equiv="Content-Type" content="text/html; charset=utf-8">
	<style type="text/css">
		body {font-family: Arial; font-size: 12pt;}
	</style>
</head>
<body>
Был заблокирован адрес:<br />
<br />
'@

	$global:body += @'
E-Mail адрес: <b>{1}</b><br />
<br />
Техническая информация: <br />{0}<br />
'@ -f $global:error_msg.Replace("`r`n", "<br />`r`n"), $global:address

	$global:body += @'
</body>
</html>
'@

	try
	{
		Send-MailMessage -from $global:g_config.smtp_from -to $global:smtp_to -Encoding UTF8 -subject $subject -bodyashtml -body $global:body -smtpServer $global:g_config.smtp_server -Credential $global:smtp_creds
	}
	catch
	{
		$global:result = 1
		$global:error_msg += ("Ошибка отправки информационного письма ({0});`r`n" -f $_.Exception.Message)
	}
}

main
