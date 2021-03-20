# Send mail runbook

$global:smtp_to = ''
$global:subject = ''
$global:body = @'

'@
$global:proc_id = ''
$global:sco_server = ''

$global:smtp_creds = New-Object System.Management.Automation.PSCredential ('', (ConvertTo-SecureString '' -AsPlainText -Force))

$ErrorActionPreference = 'Stop'

. c:\orchestrator\settings\config.ps1

$global:result = 0
$global:error_msg = ''

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

	if($global:smtp_to -eq '')
	{
		$global:smtp_to = @()
	}
	else
	{
		$global:smtp_to = $global:smtp_to -Split ','
	}
	
	$global:smtp_to += @($global:g_config.useraccess_email, $global:g_config.admin_email)

	$header = @'
		<html>
		<head>
			<meta http-equiv="Content-Type" content="text/html; charset=utf-8">
			<style type="text/css">
				body {font-family: Courier New; font-size: 8pt;}
				p {font-family: Arial; font-size: 12pt;}
				h1 {font-family: Arial; font-size: 16px;}
				h2 {font-family: Arial; font-size: 14px;}
				h3 {font-family: Arial; font-size: 12px;}
				table {border: 1px solid black; border-collapse: collapse; font-size: 8pt;}
				th {border: 1px solid black; background: #dddddd; padding: 5px; color: #000000;}
				td {border: 1px solid black; padding: 5px; }
				.red {color: red;}
				.pass {color: green;}
				.warn {color: #ff6600;}
				.error {background: #FF0000; color: #ffffff;}
                .small {font-size: 8pt;}
			</style>
		</head>
		<body>
'@
	$footer = '</body></html>';

	# Определение названия ранбука и запустившего ранбук

	$info = ''

	if($global:proc_id -ne '' -and $global:sco_server -ne '')
	{
		try
		{
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
'@ -f $global:proc_id, $global:sco_server

			$info = '<br />'
			$res = Invoke-SQL -dataSource $global:g_config.scorch_db_server -sqlCommand $query -database $global:g_config.scorch_db_name
			foreach($row in $res.Rows)
			{
				try
				{
					$objSID = New-Object System.Security.Principal.SecurityIdentifier($row.CreatedBy)
					$objUser = $objSID.Translate([System.Security.Principal.NTAccount])
					$username = $objUser.Value

					if($global:subject -eq '')
					{
						$global:subject = $row.Name
					}
				}
				catch
				{
					$username = $row.CreatedBy
				}
				
				$info += @'
					<br />
					<pre class="small">
Название ранбука: {3}
Кто запустил: {0}
Process ID: {1}
Job ID: {4}
Running server: {2}
</pre>
'@ -f $username, $global:proc_id, $global:sco_server, $row.Name, $row.JobID
				
		
			}
		}
		catch
		{
			$global:result = 1
			$global:error_msg += ("Ошибка получения запускателя ранбука ({0});`r`n" -f $_.Exception.Message)
		}
	}

	# Отправка информационного письма

	if($global:subject -eq '')
	{
		$global:subject = 'Undefined subject value'
	}

	$global:body = ($header + $global:body + $info + $footer)

	try
	{
		Send-MailMessage -from $global:g_config.smtp_from -to $global:smtp_to -Encoding UTF8 -subject $global:subject -bodyashtml -body $global:body -smtpServer $global:g_config.smtp_server -Credential $global:smtp_creds
	}
	catch
	{
		$global:result = 1
		$global:error_msg += ("Ошибка отправки информационного письма ({0});`r`n" -f $_.Exception.Message)
	}
}

main
