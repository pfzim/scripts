# Runbook execution report

$rb_input = @{
	days = ''
	name = ''
}

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

	# Проверка корректности заполнения полей
	
	$rb_input.days = $rb_input.days.Trim()

	if([string]::IsNullOrEmpty($rb_input.days) -or -not $rb_input.days -match '^[0-9]+$')
	{
		$global:result = 1
		$global:error_msg = 'Ошибка: Не заполнено поле Количество дней'
		return
	}
	
	$rb_input.name = $rb_input.name.Trim()

	<#
	if($rb_input.name -match "[`"'\\]")
	{
		$global:result = 1
		$global:error_msg = 'Ошибка: Поле название содержит запрещеные символы'
		return
	}
	#>
	
	# Запрос данных

	try
	{
		$query = @'
			SELECT
				POLICYINSTANCES.JobID
				,Jobs.CreatedBy
				,POLICIES.Name
				,POLICYINSTANCES.Status
				,POLICYINSTANCES.TimeStarted
			FROM POLICIES
			INNER JOIN [Microsoft.SystemCenter.Orchestrator.Runtime].Jobs AS Jobs
				ON Jobs.RunbookId = POLICIES.UniqueID
			INNER JOIN POLICYINSTANCES
				ON Jobs.Id = POLICYINSTANCES.JobID

			WHERE
				POLICYINSTANCES.TimeStarted > DATEADD(DAY, -{0}, GETDATE())
'@ -f $rb_input.days

		if(-not [string]::IsNullOrEmpty($rb_input.name))
		{
			$query += @'
					AND 
					POLICIES.Name = N'{0}'
'@ -f $rb_input.name
		}

		$query += ' ORDER BY POLICYINSTANCES.TimeStarted'
		
		$table = '<table><tr><th>Название ранбука</th><th>Время запуска</th><th>Статус</th><th>Кто запустил</th><th>Job ID</th></tr>'

		$res = Invoke-SQL -dataSource $global:g_config.scorch_db_server -sqlCommand $query -database $global:g_config.scorch_db_name
		foreach($row in $res.Rows)
		{
			try
			{
				$objSID = New-Object System.Security.Principal.SecurityIdentifier($row.CreatedBy)
				$objUser = $objSID.Translate([System.Security.Principal.NTAccount])
				$username = $objUser.Value
			}
			catch
			{
				$username = $row.CreatedBy
			}
			
			$table += @'
				<tr>
					<td>{0}</td>
					<td>{1}</td>
					<td>{2}</td>
					<td>{3}</td>
					<td>{4}</td>
				</tr>

'@ -f $row.Name, $row.TimeStarted, $row.Status, $username, $row.JobID
			
		}

		$table += '</table>'
	}
	catch
	{
		$global:result = 1
		$global:error_msg += ("Ошибка получения запускателя ранбука ({0});`r`n" -f $_.Exception.Message)
	}
	
	# Формирование письма

	if(-not [string]::IsNullOrEmpty($rb_input.name))
	{
		$global:subject = 'Отчёт по запуску ранбука: {0}' -f $rb_input.name
	}
	else
	{
		$global:subject = 'Отчёт по запуску ранбуков'
	}
	
	$global:subject += ' за последние {0} дней' -f $rb_input.days
	
	$global:body = @'
		<h1>{0}</h1>
		{1}
'@ -f $global:subject, $table
}

main -rb_input $rb_input

if($global:result -ne 0)
{
	$global:body += "<br /><br /><pre class=`"error`">Техническая информация:`r`n`r`n{0}</pre>" -f $global:error_msg
}
