# Detemine runbook name and who start it

. c:\scripts\settings\settings.ps1

# Все входящие параметры указываем в $rb_input,
# чтобы в основном блоке не было никаких внешних переменных.
# Тем самым ранбук становится системонезависимым, универсальным и переносимым.

$rb_input = @{
	proc_id = ''
	sco_server = ''
	scorch_db_server = $global:g_config.scorch_db_server
	scorch_db_name = $global:g_config.scorch_db_name
}

# Если ранбуки запускаются цепочкой, то результат выполнения предыдущего
# ранбука указываем здесь

$result = @{
	errors = [int] 0
	warnings = [int] 0
	messages = @()
}

# Основной блок ранбука

$DebugPreference = 'SilentlyContinue'  # Change to Continue for show debug messages
$ErrorActionPreference = 'Stop'

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
    return $dataSet.Tables
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

		$query = @'
					SELECT
						POLICYINSTANCES.JobID
						,Jobs.CreatedBy
						,POLICIES.Name
						,POLICYINSTANCES.Status
					FROM POLICYINSTANCES
					INNER JOIN ACTIONSERVERS ON POLICYINSTANCES.ActionServer = ACTIONSERVERS.UniqueID
					INNER JOIN [Microsoft.SystemCenter.Orchestrator.Runtime].Jobs AS Jobs ON Jobs.Id = POLICYINSTANCES.JobID
					INNER JOIN POLICIES ON Jobs.RunbookId = POLICIES.UniqueID
					WHERE
						(POLICYINSTANCES.ProcessID = '{0}')
						AND (ACTIONSERVERS.Computer = '{1}')
						AND (POLICYINSTANCES.Status IS NULL)
'@ -f $rb_input.proc_id, $rb_input.sco_server

		$res = Invoke-SQL -dataSource $rb_input.scorch_db_server -sqlCommand $query -database $rb_input.scorch_db_name
		foreach($row in $res.Rows)
		{
			try
			{
				$objSID = New-Object System.Security.Principal.SecurityIdentifier($row.CreatedBy)
				$objUser = $objSID.Translate([System.Security.Principal.NTAccount])
				$result.who_start_runbook = $objUser.Value

				$result.runbook_name = $row.Name
				break
			}
			catch
			{
				$result.who_start_runbook = $row.CreatedBy
			}
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
