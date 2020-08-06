# Runbooks usage report

<#
    Небольшое пояснение к таблица БД Orchestrator:
	  POLICIES        - Таблица со всеми ранбуками
	  Jobs            - Таблица с заданиями на запуск ранбуков (время создания задания, кто создал, статус задания)
	  POLICYINSTANCES - Непосредственно экземпляры выполения. В рамках одного задания может быть запущено
	                    несколько экземпляров, если задания с расписанием (ежеденевный запуск). У задания может не
						быть экзепляров запуска, если задание было отменено (из очереди).
#>

$global:result = 0
$global:error_msg = ''

$global:subject = ''
$global:body = ''
$global:smtp_to = ''

$ErrorActionPreference = 'Stop'

. c:\orchestrator\settings\config.ps1

function Invoke-SQL
{
    param(
        [string] $dataSource =  $(throw "Please specify a server."),
        [string] $sqlCommand = $(throw "Please specify a query."),
        [string] $database = $(throw "Please specify a DB.")
      )

    $connectionString = "Data Source=$dataSource; " +
            "Integrated Security=SSPI;"             +
            "Initial Catalog=$database"

    $connection = new-object system.data.SqlClient.SQLConnection($connectionString)
    $command = new-object system.data.sqlclient.sqlcommand($sqlCommand,$connection)
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
		$global:result = 1
		$global:error_msg += ("Критичная ошибка: {0}`r`n`r`nПроцесс прерван!`r`n" -f $_.Exception.Message);
		return;
	}

	# Запрос данных

	try
	{
		$query = @'
			SELECT
				POLICIES.Name
				-- ,POLICIES.UniqueID
				,COUNT(POLICYINSTANCES.UniqueID) AS Runs
			FROM POLICIES
			LEFT JOIN POLICYINSTANCES
				ON POLICYINSTANCES.PolicyID = POLICIES.UniqueID
				AND POLICYINSTANCES.TimeStarted > DATEADD(MONTH, -1, GETDATE())
			GROUP BY
				POLICIES.UniqueID, POLICIES.Name
			ORDER BY
				POLICIES.Name, POLICIES.UniqueID
'@

		$table = '<table><tr><th>Название ранбука</th><th>Количество запусков</th></tr>'

		$res = Invoke-SQL -dataSource $global:g_config.scorch_db_server -sqlCommand $query -database $global:g_config.scorch_db_name
		foreach($row in $res.Rows)
		{
			$table += @'
				<tr>
					<td>{0}</td>
					<td>{1}</td>
				</tr>

'@ -f $row.Name, $row.Runs
			
		}

		$table += '</table>'
	}
	catch
	{
		$global:result = 1
		$global:error_msg += ("Ошибка выполнения SQL запроса: ({0});`r`n" -f $_.Exception.Message)
	}
	
	# Формирование письма

	$global:subject = 'Отчёт по количеству запусков ранбуков за месяц'
	
	$global:body = @'
		<h1>{0}</h1>
		{1}
'@ -f $global:subject, $table
}

main

if($global:result -ne 0)
{
	$global:body += "<br /><br /><pre class=`"error`">Техническая информация:`r`n`r`n{0}</pre>" -f $global:error_msg
}
