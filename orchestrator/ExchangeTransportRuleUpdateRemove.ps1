# Exchange transport rule - remove address from list

$global:address = ''

$global:exch_creds = New-Object System.Management.Automation.PSCredential ('', (ConvertTo-SecureString '' -AsPlainText -Force))
$global:smtp_creds = New-Object System.Management.Automation.PSCredential ('', (ConvertTo-SecureString '' -AsPlainText -Force))

trap
{
	$global:result = 1
	$global:error_msg += ("Критичная ошибка: {0}`r`n`r`nПроцесс прерван!`r`n" -f $_.Exception.Message);
	return;
}

$ErrorActionPreference = 'Stop'

. c:\orchestrator\settings\settings.ps1

$global:smtp_to = @($global:admin_email, $global:uib_email)

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

	if($global:address -eq 'placeholder@example.org' -or $global:address -notmatch '^.+@.+\..+$')
	{
		$global:result = 1
		$global:error_msg = 'Ошибка: Не корректно заполнены обязательные поля'
		return
	}

	$rules_out = @('Запрещено в интернет', 'Запрещено в интернет 2')
	$rules_in = @('Запрещено из интернета', 'Запрещено из интернета 2')

	try
	{
		$session = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri $global:exch_conn_uri -Credential $global:exch_creds -Authentication Basic
		Import-PSSession $session

		$address_exist = 0

		foreach($rule in $rules_out)
		{
			$list = (Get-TransportRule -Identity $rule).SentTo
			if($list -contains $global:address)
			{
				$list = @($list | Where-Object { $_ -ne $global:address })
				if($list.Count -gt 0)
				{
					Set-TransportRule -Identity $rule -SentTo $list

					$list = (Get-TransportRule -Identity $rule).From
					if($list -notcontains $global:address)
					{
						$global:error_msg += ("Адрес {0} успешно удален из правила {1}`r`n" -f $global:address, $rule)
					}
					else
					{
						$global:result = 1
						$global:error_msg += ("Неизвестная ошибка: Адрес {0} не был удален из правила {1}`r`n" -f $global:address, $rule)
					}				
				}
				else
				{
					$global:result = 1
					$global:error_msg += ("Ошибка: Вы пытаетесь удалить последний адрес из правила {0}. Список адресов не может оставаться пустым`r`n" -f $rule)
				}
			}
			else
			{
				$global:error_msg += ("Адрес {0} не найден в правиле {1}`r`n" -f $global:address, $rule)
			}
		}

		foreach($rule in $rules_in)
		{
			$list = (Get-TransportRule -Identity $rule).From
			if($list -contains $global:address)
			{
				$list = @($list | Where-Object { $_ -ne $global:address })
				if($list.Count -gt 0)
				{
					Set-TransportRule -Identity $rule -From $list

					$list = (Get-TransportRule -Identity $rule).From
					if($list -notcontains $global:address)
					{
						$global:error_msg += ("Адрес {0} успешно удален из правила {1}`r`n" -f $global:address, $rule)
					}
					else
					{
						$global:result = 1
						$global:error_msg += ("Неизвестная ошибка: Адрес {0} не был удален из правила {1}`r`n" -f $global:address, $rule)
					}				
				}
				else
				{
					$global:result = 1
					$global:error_msg += ("Ошибка: Вы пытаетесь удалить последний адрес из правила {0}. Список адресов не может оставаться пустым`r`n" -f $rule)
				}
			}
			else
			{
				$global:error_msg += ("Адрес {0} не найден в правиле {1}`r`n" -f $global:address, $rule)
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

	$subject = ('E-Mail address unblocked: {0}' -f $global:address)

	# Отправка информационного письма

	$global:body = @'
<html>
<head>
	<meta http-equiv="Content-Type" content="text/html; charset=utf-8">
	<style type="text/css">
		body {font-family: Arial; font-size: 12pt;}
	</style>
</head>
<body>
Был разблокирован адрес:<br />
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
		Send-MailMessage -from $global:smtp_from -to $global:smtp_to -Encoding UTF8 -subject $subject -bodyashtml -body $global:body -smtpServer $global:smtp_server -Credential $global:smtp_creds
	}
	catch
	{
		$global:result = 1
		$global:error_msg += ("Ошибка отправки информационного письма ({0});`r`n" -f $_.Exception.Message)
	}
}

main
