$smtp_from = "orchestrator@contoso.com"
$smtp_to = "admin@contoso.com"
$smtp_server = "smtp.contoso.com"

$smtp_creds = New-Object System.Management.Automation.PSCredential ("contoso\orchestrator", (ConvertTo-SecureString "Passw0rd" -AsPlainText -Force))


$log_template = @'
MOVE  "{0}"
TO  "F:\Workdata\NB_Test_Restore_log_{1}.ldf"

'@

$bch_template = @'
OPERATION RESTORE
OBJECTTYPE DATABASE
RESTORETYPE MOVE
DATABASE "NB_Test_Restore"
MOVE  "{0}"
TO  "F:\Workdata\NB_Test_Restore.mdf"
{1}
NBIMAGE "{2}"
SQLHOST "srv-NBTEST-01"
SQLINSTANCE "MSSQLSERVER"
NBSERVER "srv-NB-01.CONTOSO.COM"
STRIPES {3:d3}
BROWSECLIENT "{4}"
MAXTRANSFERSIZE 6
BLOCKSIZE 7
RESTOREOPTION REPLACE
RECOVEREDSTATE RECOVERED
NUMBUFS 2
ENDOPER TRUE
'@

$ErrorActionPreference = "Stop"

function Log-Only($severity, $message)
{
	if($severity -eq "error")
	{
		$s = "ERROR:  "
	}
	elseif($severity -eq "warn")
	{
		$s = "WARNING:"
	}
	elseif($severity -eq "pass")
	{
		$s = "OK:     "
	}
	else
	{
		$s = "INFO:     "
	}

	try
	{
		Add-Content "c:\scripts\logs\NetBackupTestRestore.log" -Value ("{1:yyyy-MM-dd HH:mm:ss}    {2} {0}" -f $message, [DateTime]::Now, $s)
	}
	catch
	{
		Write-Host -ForegroundColor Red $_.Exception.Message
	}
}

function Log-Screen($severity, $message)
{
	if($severity -eq "error")
	{
		$s = "ERROR:  "
		$c = "Red"
	}
	elseif($severity -eq "warn")
	{
		$s = "WARNING:"
		$c = "Yellow"
	}
	elseif($severity -eq "pass")
	{
		$s = "OK:     "
		$c = "Green"
	}
	else
	{
		$s = "INFO:     "
		$c = "Gray"
	}

	try
	{
		Add-Content "c:\scripts\logs\NetBackupTestRestore.log" -Value ("{1:yyyy-MM-dd HH:mm:ss}    {2} {0}" -f $message, [DateTime]::Now, $s)
	}
	catch
	{
		Write-Host -ForegroundColor Red $_.Exception.Message
	}
	Write-Host -ForegroundColor $c $message
}

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
    $command.CommandTimeout = 86400
    $connection.Open()

    $adapter = New-Object System.Data.sqlclient.sqlDataAdapter $command
    $dataset = New-Object System.Data.DataSet
    $adapter.Fill($dataSet) | Out-Null

    $connection.Close()
    return $dataSet.Tables
}


Log-Screen "info" ("--- " + (Get-Date).ToString("dd/MM/yyyy HH:mm") + " ---")

try
{
	$clients = Get-Content -Path "C:\scripts\rules\NetBackupRestoreRules.pson" -Raw | Invoke-Expression
}
catch
{
	Log-Screen "error" "Load restore rules"
	$clients = @{}
}


$header = @'
<html>
<head>
	<meta http-equiv="Content-Type" content="text/html; charset=utf-8">
	<style>
		body{font-family: Arial; font-size: 8pt;}
		h1{font-size: 16px;}
		h2{font-size: 14px;}
		h3{font-size: 12px;}
		table{border: 1px solid black; border-collapse: collapse; font-size: 8pt;}
		th{border: 1px solid black; background: #dddddd; padding: 5px; color: #000000;}
		td{border: 1px solid black; padding: 5px; }
		.pass {background: #7FFF00;}
		.warn {background: #FFE600;}
		.error {background: #FF0000; color: #ffffff;}
	</style>
</head>
<body>
'@

Log-Screen "info" "--- Start testing procedure ---"

$body = $header

$body += @'
<h1>Результат тестового восстановления резервных копий баз данных</h1>
<table>
<tr><th>Client</th><th>Schedule</th><th>DB</th><th>Backup Date</th><th>Restore Time</th><th>Result</th></tr>
'@

foreach($p_key in $clients.Keys)
{
	$body += '<tr><th colspan="6">{0}</th></tr>' -f $p_key

    foreach($c_key in $clients[$p_key].Keys)
    {
        foreach($s_key in $clients[$p_key][$c_key].Keys)
        {
			foreach($d_key in $clients[$p_key][$c_key][$s_key].dblist.Keys)
			{
				$body += '<tr><td>{0}</td><td>{1}</td><td>{2}</td>' -f $c_key, $s_key, $d_key
				if($clients[$p_key][$c_key][$s_key].dblist[$d_key].nbimage)
				{
					$cols = $clients[$p_key][$c_key][$s_key].dblist[$d_key].nbimage -split '\.'
					$body += '<td>' + $cols[8][6] + $cols[8][7] + "." + $cols[8][4] + $cols[8][5] + "." + $cols[8][0] + $cols[8][1] + $cols[8][2] + $cols[8][3] + '</td>'
					Log-Screen "pass" ("DB: " + $d_key +", Image: " + $clients[$p_key][$c_key][$s_key].dblist[$d_key].nbimage)
					Log-Screen "info" ("  Media required: " + ($clients[$p_key][$c_key][$s_key].dblist[$d_key].media -join ", "))
					Log-Screen "info" ("  MDF: " + $clients[$p_key][$c_key][$s_key].dblist[$d_key].mdf + ", LOG: " + $clients[$p_key][$c_key][$s_key].dblist[$d_key].log + ", Stripes: " + $clients[$p_key][$c_key][$s_key].dblist[$d_key].stripes)

					# create move script
					
					$log = ''
					$i = 0
					foreach($l_name in $clients[$p_key][$c_key][$s_key].dblist[$d_key].log)
					{
						$log += $log_template -f $l_name, $i
						$i++
					}

					$bch = $bch_template -f $clients[$p_key][$c_key][$s_key].dblist[$d_key].mdf, $log, $clients[$p_key][$c_key][$s_key].dblist[$d_key].nbimage, $clients[$p_key][$c_key][$s_key].dblist[$d_key].stripes, $c_key
					Set-Content -Path "c:\_temp\restore.bch" -Value $bch
					
					Log-Only "info" "  Restoring DB..."
					Write-Host -NoNewline "  Restoring DB..."
					
					$start = Get-Date

					#& 'start /wait C:\Program Files\Veritas\NetBackup\bin\dbbackex.exe' -f c:\_temp\restore.bch -u sa -pw B2FSQkvYrPuVeZdj -np
					$proc = Start-Process -FilePath 'C:\Program Files\Veritas\NetBackup\bin\dbbackex.exe' -ArgumentList '-f c:\_temp\restore.bch -u sa -pw B2FSQkvYrPuVeZdj -np' -PassThru
					Wait-Process -InputObject $proc #-Timeout 99999
					$stop = Get-Date
					$duration = (New-TimeSpan –Start $start –End $stop)
					$body += '<td>{0:d2}:{1:d2}</td>' -f [int] ($duration.TotalMinutes / 60), [int] ($duration.TotalMinutes % 60)
					Log-Only "info" ("  Exit code = " + $proc.ExitCode)
					Write-Host -ForegroundColor Green (" result: " + $proc.ExitCode)
					if($proc.HasExited -and $proc.ExitCode -eq 0)
					{
						Log-Only "info" "  Checking DB..."
						Write-Host -NoNewline "  Checking DB..."

						$status = 0
						try
						{
							$result = Invoke-SQL -dataSource "srv-nbtest-01" -sqlCommand "DBCC CHECKDB ([NB_Test_Restore]) WITH TABLERESULTS"
							foreach($r in $result)
							{
								if($r.Status -ne 0)
								{
									$status = 1
								}
							}
						}
						catch
						{
							$status = 1
							Log-Only "error" ("  Exception: " + $_.Exception.Message)
							Write-Host -NoNewline -ForegroundColor Red (" (" + $_.Exception.Message + ")")
						}

						if($status -eq 0)
						{
							$body += '<td class="pass">PASSED</td></tr>'
							Write-Host -ForegroundColor Green (" OK")
						}
						else
						{
							$body += '<td class="error">CHECKDB FAILED</td></tr>'
							Write-Host -ForegroundColor Red (" FAILED")
						}
					}
					else
					{
						$body += '<td class="error">RESTORE FAILED</td></tr>'
					}

					Log-Screen "info" "  Deleting DB..."

					try
					{
						$result = Invoke-SQL -dataSource "srv-nbtest-01" -sqlCommand "USE master`r`nIF EXISTS(select * from sys.databases where name='NB_Test_Restore')`r`nDROP DATABASE NB_Test_Restore"
					}
					catch
					{
						Log-Screen "error" "Error drop test DB"
						$body += '<tr><td class="error">Error drop test DB</td></tr>'
					}
				}
				else
				{
					$body += '<td></td><td class="error">NO IMAGE</td></tr>'
				}
			}
		}
	}
}

Log-Screen "info" ("--- Done --- " + (Get-Date).ToString("dd/MM/yyyy HH:mm") + " ---")

$body += @'
</table>
</body>
</html>
'@

Send-MailMessage -from $smtp_from -to $smtp_to -Encoding UTF8 -subject "Result DB backup tests" -bodyashtml -body $body -smtpServer $smtp_server -Credential $smtp_creds
