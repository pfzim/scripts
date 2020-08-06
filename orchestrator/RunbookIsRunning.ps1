# Check is runbook running

$global:id = ''

$ErrorActionPreference = 'Stop'

. c:\orchestrator\settings\config.ps1

$global:result = 0
$global:error_msg = ''
$global:isrunning = ''

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

function main()
{
	trap
	{
		$global:result = 1
		$global:error_msg += ("Критичная ошибка: {0}`r`n`r`nПроцесс прерван!`r`n" -f $_.Exception.Message);
		return;
	}

	# Проверка корректности заполнения полей

	if($global:id -eq '')
	{
		$global:result = 1
		$global:error_msg = 'Ошибка: Не корректно заполнены обязательные поля'
		return
	}

	# Получение информации
	try
	{
		$query = @'
			SELECT 
				COUNT(*) AS [COUNT]
			FROM 
				[Microsoft.SystemCenter.Orchestrator.Runtime.Internal].[Jobs] AS [j]
			WHERE
				[j].[RunbookId] = '{0}'
				AND (
					[j].[StatusId] = 0
					OR 
					[j].[StatusId] = 1
				)
'@ -f $global:id

		$result = Invoke-SQL -dataSource $global:g_config.scorch_db_server -sqlCommand $query -database $global:g_config.scorch_db_name
		
        if($result.Rows.Count -gt 0)
        {
			$global:isrunning = ($result[0].COUNT)
		}
	}
	catch
	{
		$global:result = 1
		$global:error_msg += 'Ошибка: {0}' -f $_.Exception.Message
		return
	}
}

main
