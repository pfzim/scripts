$smtp_creds = New-Object System.Management.Automation.PSCredential ("", (ConvertTo-SecureString "" -AsPlainText -Force))

$smtp_from = "orchestrator@contoso.com"
$smtp_to = "admin@contoso.com"
$smtp_server = "smtp.contoso.com"

function Invoke-SQL
{
    param(
        [string] $dataSource =  $(throw "Please specify a server."),
        [string] $sqlCommand = $(throw "Please specify a query.")
      )

    $connectionString = "Data Source=$dataSource; " +
            "Integrated Security=SSPI"

    $connection = new-object system.data.SqlClient.SQLConnection($connectionString)
    $command = new-object system.data.sqlclient.sqlcommand($sqlCommand,$connection)
    $connection.Open()

    $adapter = New-Object System.Data.sqlclient.sqlDataAdapter $command
    $dataset = New-Object System.Data.DataSet
    $adapter.Fill($dataSet) | Out-Null

    $connection.Close()
    return $dataSet.Tables
}

$query = @'
SELECT  name ,
        recovery_model_desc ,
        state_desc ,
        d AS 'LastFullBackup' ,
        i AS 'LastDifferentialBackup' ,
        l AS 'LastLogBackup'
    FROM    ( SELECT    db.name ,
                        db.state_desc ,
                        db.recovery_model_desc ,
                        type ,
                        backup_finish_date
              FROM      master.sys.databases db
              LEFT OUTER JOIN msdb.dbo.backupset a ON a.database_name = db.name
            ) AS Sourcetable 
        PIVOT 
            ( MAX(backup_finish_date) FOR type IN ( D, I, L ) ) AS MostRecentBackup
		ORDER BY name
'@

$body = @'
<html>
<head>
<meta http-equiv="Content-Type" content="text/html; charset=utf-8"></head>
<style>
	body{font-family: courier; font-size: 9pt;}
	h1{font-size: 16px;}
	h2{font-size: 14px;}
	h3{font-size: 12px;}
	table{border: 1px solid black; border-collapse: collapse; font-size: 8pt;}
	th{border: 1px solid black; background: #dddddd; padding: 5px; color: #000000;}
	td{border: 1px solid black; padding: 5px; }
	.red {background: #FF0000; color: #ffffff;}
	.green {background: #7FFF00;}
	.yellow {background: #FFE600;}
 </style>
<body>
<h1>Databases backup status</h1>
<table>
<tr><th>Server Name</th><th>Database</th><th>Model Type</th><th>Last Full</th><th>Last Differental</th><th>Last Log</th></tr>
'@

$servers = Get-Content -Path "C:\Orchestrator\settings\mssql-servers-list.txt"
foreach($server in $servers)
{
    $result = Invoke-SQL -dataSource $server -sqlCommand $query

    $date7 = (Get-Date).AddDays(-7)
    $date7 = (Get-Date).AddDays(-1)
    foreach($row in $result)
    {
        if(($row.LastFullBackup).Equals([DBNull]::Value))
		{
           $s_full = '<td class="red">Never</td>'
		}
		elseif($row.LastFullBackup -le $date7)
        {
           $s_full = '<td class="red">'+$row.LastFullBackup.ToString("dd.MM.yyyy HH:mm")+'</td>'
        }
        elseif($row.LastFullBackup -le $date1)
        {
           $s_full = '<td class="yellow">'+$row.LastFullBackup.ToString("dd.MM.yyyy HH:mm")+'</td>'
        }
        else
        {
           $s_full = '<td class="green">'+$row.LastFullBackup.ToString("dd.MM.yyyy HH:mm")+'</td>'
        }

        if(($row.LastDifferentialBackup).Equals([DBNull]::Value))
		{
           $s_diff = '<td class="red">Never</td>'
		}
		elseif($row.LastDifferentialBackup -le $date7)
        {
           $s_diff = '<td class="red">'+$row.LastDifferentialBackup.ToString("dd.MM.yyyy HH:mm")+'</td>'
        }
        elseif($row.LastDifferentialBackup -le $date1)
        {
           $s_diff = '<td class="yellow">'+$row.LastDifferentialBackup.ToString("dd.MM.yyyy HH:mm")+'</td>'
        }
        else
        {
           $s_diff = '<td class="green">'+$row.LastDifferentialBackup.ToString("dd.MM.yyyy HH:mm")+'</td>'
        }
        
        if(($row.LastLogBackup).Equals([DBNull]::Value))
		{
           $s_log = '<td class="red">Never</td>'
		}
		elseif($row.LastLogBackup -le $date7)
        {
           $s_log = '<td class="red">'+$row.LastLogBackup.ToString("dd.MM.yyyy HH:mm")+'</td>'
        }
        elseif($row.LastLogBackup -le $date1)
        {
           $s_log = '<td class="yellow">'+$row.LastLogBackup.ToString("dd.MM.yyyy HH:mm")+'</td>'
        }
        else
        {
           $s_log = '<td class="green">'+$row.LastLogBackup.ToString("dd.MM.yyyy HH:mm")+'</td>'
        }

        $body += '<tr><td>'+ $server + '</td><td>'+ $row.name + '</td><td>'+ $row.recovery_model_desc + '</td>' + $s_full + $s_diff + $s_log + '</tr>'
    }
}

$body += @'
</table>
</body>
</html>
'@

Send-MailMessage -from $smtp_from -to $smtp_to -Encoding UTF8 -subject "Databases backup status" -bodyashtml -body $body -smtpServer $smtp_server -Credential $smtp_creds
