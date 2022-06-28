<# Send mail

	Ранбук для отправки результирующих почтовых сообщений

	Письмо формируется из входящих параметров subject, body, attachments.
	
	Если параметры who_start_runbook или runbook_name не пустые, то добавляется
	блок с информацией о том, кто запустил ранбук и его название.
	
	Если количество ошибок или предупреждений больше нуля, то добавляется
	блок с информацией о возникших ошибках и предупреждениях.

	На вход ранбук принимает параметры:
		subject           - тема сообщения
		body              - тело сообщения
		attachments       - список файлов разделенный запятыми, которые требуется приложить к письму
		mail_to           - адрес получателя
		mail_to_bcc       - адрес получателя скрытой копии
		who_start_runbook - кто запустил ранбук (из результата запуска ранбука Get-Runbook-Info.ps1)
		who_websco        - кто запустил WebSCO (из параметра переданного ключём /w)
		runbook_name      - название ранбука  (из результата запуска ранбука Get-Runbook-Info.ps1)
		remove_attachments_after_send - если параметр равен 'yes', то файлы перечисленные в attachments
		                    будут удалены после отправки

		errors            - количество возникших ошибок (из результата запуска предыдущего ранбука)
		warnings          - количество возникших предупреждений (из результата запуска предыдущего ранбука)
		message           - текстовое описание ошибок и предупреждений (из результата запуска предыдущего ранбука)
		
	На выходе ранбук возвращает следующие параметры:

		errors   - количество возникших ошибок
		warnings - количество возникших предупреждений
		message  - текстовое описание ошибок и предупреждений

#>

. c:\orchestrator\settings\config.ps1

# Все входящие параметры указываем в $rb_input,
# чтобы в основном блоке не было никаких внешних переменных.
# Тем самым ранбук становится системонезависимым, универсальным и переносимым.

$rb_input = @{
	subject = ''
	body = @'

'@
	attachments = ''
	remove_attachments_after_send = ''
	mail_to = ''
	mail_to_bcc = $global:g_config.admin_email

	who_start_runbook = ''
	who_websco = ''
	runbook_name = ''
	smtp_server = $global:g_config.smtp_server
	smtp_from = $global:g_config.smtp_from
}

# Если ранбуки запускаются цепочкой, то результат выполнения предыдущего
# ранбука указываем здесь

$result = @{
	errors = [int] 0
	warnings = [int] 0
	messages = @(@'

'@)
}

# Основной блок ранбука

$DebugPreference = 'SilentlyContinue'  # Change to Continue for show debug messages
$ErrorActionPreference = 'Stop'

function main($rb_input, $prev_result)
{
	trap
	{
		return @{ errors = 0; warnings = 0; messages = @("Critical error[{0},{1}]: {2}`r`n`r`nProcess interrupted!`r`n" -f $_.InvocationInfo.ScriptLineNumber, $_.InvocationInfo.OffsetInLine, $_.Exception.Message); }
	}

	try
	{
		$result = @{ errors = 0; warnings = 0; messages = @() }

		# Проверка корректности заполнения полей

		if([string]::IsNullOrWhiteSpace($rb_input.subject))
		{
			$result.errors++; $result.messages += 'Ошибка: Не заполнено поле subject';
		}

		if([string]::IsNullOrWhiteSpace($rb_input.body))
		{
			$result.errors++; $result.messages += 'Ошибка: Не заполнено поле body';
		}

		if([string]::IsNullOrWhiteSpace($rb_input.mail_to) -and [string]::IsNullOrWhiteSpace($rb_input.mail_to_bcc))
		{
			$result.errors++; $result.messages += 'Ошибка: Не заполнено поле mail_to';
		}

		if($result.errors -gt 0)
		{
			return $result
		}

		$body = @'
			<html>
			<head>
				<meta http-equiv="Content-Type" content="text/html; charset=utf-8">
				<style type="text/css">
					body {font-family: Arial; font-size: 11pt;}
					h1 {font-size: 16px;}
					h2 {font-size: 14px;}
					h3 {font-size: 12px;}
					table {border: 1px solid black; border-collapse: collapse; font-size: 8pt; font-family: Courier New;}
					th {border: 1px solid black; background: #dddddd; padding: 5px; color: #000000;}
					td {border: 1px solid black; padding: 5px; }
					.pass {background: #7FFF00;}
					.warn {background: #FFE600;}
					.error {background: #FF0000; color: #ffffff;}
				</style>
			</head>
			<body>
'@

		$body += $rb_input.body

		if($prev_result.errors -gt 0 -or $prev_result.warnings -gt 0 -or -not [string]::IsNullOrWhiteSpace($prev_result.messages))
		{
			$body += '<br /><br /><br />Техническая информация:<br />Ошибок: {0}, Предупреждений: {1}<br />Сообщения:<br /><pre>{2}</pre>' -f $prev_result.errors, $prev_result.warnings, ($prev_result.messages -join "`r`n")
		}

		if(-not ([string]::IsNullOrWhiteSpace($rb_input.runbook_name) -and [string]::IsNullOrWhiteSpace($rb_input.who_start_runbook) -and [string]::IsNullOrWhiteSpace($rb_input.who_websco)))
		{
			$body += "<br /><br /><br /><pre>Ранбук: {0}`r`nИсполнитель: {1}`r`nИсполнитель из WebSCO: {2}</pre>" -f $rb_input.runbook_name, $rb_input.who_start_runbook, $rb_input.who_websco
		}

		$body += '</body></html>'

		$additional_params = @{}

		if(-not [string]::IsNullOrWhiteSpace($rb_input.mail_to))
		{
			$additional_params['To'] = $rb_input.mail_to -split '[,;]' | %{ $_.Trim() }
			if(-not [string]::IsNullOrWhiteSpace($rb_input.mail_to_bcc))
			{
				$additional_params['Bcc'] = $rb_input.mail_to_bcc -split '[,;]' | %{ $_.Trim() }
			}
		}
		else
		{
			$additional_params['To'] = $rb_input.mail_to_bcc -split '[,;]' | %{ $_.Trim() }
		}
		
		if(-not [string]::IsNullOrWhiteSpace($rb_input.attachments))
		{
			$additional_params['Attachments'] = $rb_input.attachments -split '[,;]' | %{ $_.Trim() }
		}

		Send-MailMessage -From $rb_input.smtp_from -Encoding UTF8 -Subject $rb_input.subject -bodyashtml -body $body -smtpServer $rb_input.smtp_server @additional_params

		if(-not [string]::IsNullOrWhiteSpace($rb_input.attachments) -and ($additional_params['Attachments'].Count -gt 0) -and -not [string]::IsNullOrWhiteSpace($rb_input.remove_attachments_after_send) -and ($rb_input.remove_attachments_after_send -eq 'yes'))
		{
			foreach($attachment in $additional_params['Attachments'])
			{
				try
				{
					if(-not (Test-Path -Path $attachment))
					{
						$result.warnings++; $result.messages += ('Send-Mail: Ошибка: Файл не существует {0}' -f $attachment);
						continue
					}

					Remove-Item -Path $attachment -Force -Confirm:$false
				}
				catch
				{
					$result.warnings++; $result.messages += ('Send-Mail: Ошибка удаления файла {3} [{0},{1}]: {2}' -f $_.InvocationInfo.ScriptLineNumber, $_.InvocationInfo.OffsetInLine, $_.Exception.Message, $attachment);
				}
			}
		}

		return $result
	}
	catch
	{
		$result.errors++; $result.messages += ('Send-Mail: ERROR[{0},{1}]: {2}' -f $_.InvocationInfo.ScriptLineNumber, $_.InvocationInfo.OffsetInLine, $_.Exception.Message);
		return $result
	}
}


# Выполняем ранбук

$output = main -rb_input $rb_input -prev_result $result

# Объединяем результат с предыдущим ранбуком

$result.errors += $output.errors
$result.warnings += $output.warnings
$result.messages += $output.messages

# Код выхода для обратной совместимости

$exit_code = 0
if($result.errors -gt 0 -or $result.warnings -gt 0)
{
	$exit_code = 1
}

# Возврат значений

$errors = $result.errors
$warnings = $result.warnings
$message = $result.messages -join "`r`n"

Write-Debug ('Errors: {0}, Warnings: {1}, Messages: {2}' -f $errors, $warnings, $message)