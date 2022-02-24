<# Detemine runbook name and who start it
	
	Ранбук для определения имени пользователя запустившего ранбук и название
	ранбука.
	
	По полученным входящим параметрам делается SQL запрос в базу данных
	Оркестратора для определения пользователя, запустившего ранбук, и названия
	ранбука.
	
	На вход ранбук принимает параметры:
		proc_id           - идентификатор процесса
		sco_server        - имя сервера на котором запущен ранбук
		
		scorch_db_server  - адрес сервера с БД Оркестратора
		scorch_db_name    - имя БД Оркестратора
		
		errors            - количество возникших ошибок (из результата запуска предыдущего ранбука)
		warnings          - количество возникших предупреждений (из результата запуска предыдущего ранбука)
		message           - текстовое описание ошибок и предупреждений (из результата запуска предыдущего ранбука)
		
	На выходе ранбук возвращает следующие параметры:

		errors   - количество возникших ошибок
		warnings - количество возникших предупреждений
		message  - текстовое описание ошибок и предупреждений
#>

. c:\scripts\settings\settings.ps1

# Все входящие параметры указываем в $rb_input,
# чтобы в основном блоке не было никаких внешних переменных.
# Тем самым ранбук становится системонезависимым, универсальным и переносимым.

$rb_input = @{
	proc_id = ''
	sco_server = ''
	scorch_db_server = $global:g_config.scorch_db_server
	scorch_db_name = $global:g_config.scorch_db_name
	
	debug_pref = 'SilentlyContinue'  # Change to Continue for show debug messages
}

# Если ранбуки запускаются цепочкой, то результат выполнения предыдущего
# ранбука указываем здесь

$result = @{
	errors = [int] 0
	warnings = [int] 0
	messages = @()
}

# Основной блок ранбука

$DebugPreference = $rb_input.debug_pref
$ErrorActionPreference = 'Stop'

# Functions for work with SQL queries

function mysql_escape
{
	param(
		[string] $value
	)

	#$escapers = @("\", "`"", "`n", "`r", "`t", "`x08", "`x0c", "'", "`x1A", "`0");
	#$replacements = @("\\", "\`"", "\n", "\r", "\t", "\f", "\b", "\'", "\Z", "\0");

	return $value.Replace('\', '\\').Replace('"', '\"').Replace("`n", '\n').Replace("`r", '\r').Replace("'", "\'").Replace("`0", '\0').Replace("`t", '\t').Replace("`f", '\f').Replace("`b", '\b').Replace([string][char]([convert]::toint16('1A', 16)), '\Z')
}

function mssql_escape
{
	param(
		[string] $value
	)

	return $value.Replace("'", "''")
}

<#
 *  \brief Replace placeholders with numbered parameters (zero-based)
 *  
 *  \return Return replaced string
 *  
 *  \details {d0} - safe integer
 *           {s0} - safe trimmed sql string
 *           {f0} - safe float
 *           {r0} - unsafe raw string
 *           @    - DB_PREFIX
 *           {{   - {
 *           {@   - @
 *           {#   - #
 *           {!   - !
 *           #    - safe integer (param by order)
 *           !    - safe trimmed sql string (param by order)
#>

function rpv
{
	param(
		[string] $string,
		[array] $data
	)

	$out_string = ''
	$len = $string.Length
	$n = 0

	$i = 0

	while($i -lt $len)
	{
		if($string[$i] -eq '#')
		{
			$out_string += try { [int] $data[$param] } catch { 0 }
			$n++
		}
		elseif($string[$i] -eq '!')
		{
			$out_string += "N'" + (mssql_escape -value $data[$n]) +"'"
			$n++
		}
		elseif($string[$i] -eq '@')
		{
			$out_string += $global:DB_PREFIX
			$n++
		}
		elseif($string[$i] -eq '{')
		{
			$i++
			if($string[$i] -eq '{')
			{
				$out_string += '{'
			}
			elseif($string[$i] -eq '@')
			{
				$out_string += '@'
			}
			elseif($string[$i] -eq '#')
			{
				$out_string += '#'
			}
			elseif($string[$i] -eq '!')
			{
				$out_string += '!'
			}
			else
			{
				$prefix = $string[$i]
				$param = ''
				$i++
				while($string[$i] -ne '}')
				{
					$param += $string[$i]
					$i++
				}

				$param = try { [int] $param } catch { 0 }

				switch($prefix)
				{
					'd' {
							$out_string += try { [int] $data[$param] } catch { 0 }
						}
					's' {
							$out_string += "N'" + (mssql_escape -value $data[$param]) + "'"
						}
					'f' {
							$out_string += try { [double] $data[$param] } catch { 0 }
						}
					'r' {
							$out_string += $data[$param]
						}
				}
			}
		}
		else
		{
			$out_string += $string[$i]
		}

		$i++
	}

	return $out_string
}

# Функция выполнения SQL запроса

function Invoke-SQL
{
    param(
		[string] $dataSource = $(throw "Please specify a server."),
		[string] $sqlCommand = $(throw "Please specify a query."),
		[string] $database   = $(throw "Please specify a DB.")
    )

    $connection = new-object system.data.SqlClient.SQLConnection('Data Source={0}; Integrated Security=SSPI; Initial Catalog={1}' -f $dataSource, $database)
    $command = new-object system.data.sqlclient.sqlcommand($sqlCommand, $connection)
    $connection.Open()

    $adapter = New-Object System.Data.sqlclient.sqlDataAdapter $command
    $dataset = New-Object System.Data.DataSet
    $adapter.Fill($dataSet) | Out-Null

    $connection.Close()
    return $dataSet.Tables[0]
}

function main($rb_input)
{
	trap
	{
		return @{ errors = 0; warnings = 0; messages = @("Critical error[{0},{1}]: {2}`r`n`r`nProcess interrupted!`r`n" -f $_.InvocationInfo.ScriptLineNumber, $_.InvocationInfo.OffsetInLine, $_.Exception.Message); }
	}

	try
	{
		$result = @{ errors = 0; warnings = 0; messages = @() }

		# Проверка корректности заполнения полей

		if([string]::IsNullOrWhiteSpace($rb_input.proc_id))
		{
			$result.errors++; $result.messages += 'Ошибка: Не заполнено поле proc_id';
		}

		if([string]::IsNullOrWhiteSpace($rb_input.sco_server))
		{
			$result.errors++; $result.messages += 'Ошибка: Не заполнено поле sco_server';
		}

		if($result.errors -gt 0)
		{
			return $result
		}

		$result['runbook_name'] = '';
		$result['who_start_runbook'] = '';

		$query = rpv -string @'
					SELECT TOP 1
						POLICYINSTANCES.JobID
						,Jobs.CreatedBy
						,Jobs.CreationTime
						,POLICYINSTANCES.TimeStarted
						,POLICIES.Name
						,POLICYINSTANCES.Status
					FROM POLICYINSTANCES
					INNER JOIN ACTIONSERVERS ON POLICYINSTANCES.ActionServer = ACTIONSERVERS.UniqueID
					INNER JOIN [Microsoft.SystemCenter.Orchestrator.Runtime.Internal].Jobs AS Jobs ON Jobs.Id = POLICYINSTANCES.JobID
					INNER JOIN POLICIES ON Jobs.RunbookId = POLICIES.UniqueID
					WHERE
						(POLICYINSTANCES.ProcessID = {d0})
						AND (ACTIONSERVERS.Computer = {s1})
						AND (POLICYINSTANCES.Status IS NULL)
					ORDER BY POLICYINSTANCES.TimeStarted DESC
'@ -data @($rb_input.proc_id, $rb_input.sco_server)

		$res = Invoke-SQL -dataSource $rb_input.scorch_db_server -sqlCommand $query -database $rb_input.scorch_db_name
		foreach($row in $res)
		{
			$result.runbook_name = $row.Name

			try
			{
				$objSID = New-Object System.Security.Principal.SecurityIdentifier($row.CreatedBy)
				$objUser = $objSID.Translate([System.Security.Principal.NTAccount])
				$result.who_start_runbook = $objUser.Value
			}
			catch
			{
				$result.who_start_runbook = $row.CreatedBy
			}
			
			break
		}

		return $result
	}
	catch
	{
		$result.errors++; $result.messages += ('ERROR[{0},{1}]: {2}' -f $_.InvocationInfo.ScriptLineNumber, $_.InvocationInfo.OffsetInLine, $_.Exception.Message);
		return $result
	}
}

# Выполняем ранбук, только если предыдущий завершился без ошибок

if($result.errors -eq 0)
{
	$output = main -rb_input $rb_input

	if($output.errors -eq 0)
	{
		# Возврат значений
		
		$runbook_name = $output.runbook_name
		$who_start_runbook = $output.who_start_runbook
	}

	# Объединяем результат с предыдущим ранбуком

	$result.errors += $output.errors
	$result.warnings += $output.warnings
	$result.messages += $output.messages
}

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
Write-Debug ('Name: {0}, Who run: {0}' -f $runbook_name, $who_start_runbook)
