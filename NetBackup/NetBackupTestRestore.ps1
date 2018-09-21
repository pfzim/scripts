#srv-nbtest-01.MSSQL7.BRC-NBTEST-01.db.TestDB.~.7.001of001.20180913153524..C:\

$media = @{
	"0432L6" = "LQ0432L6"; 
	"1402L6" = "JY1402L6"; 
	"0932L6" = "LQ0932L6"; 
	"0411L6" = "LQ0411L6"; 
	"0408L6" = "LQ0408L6"; 
	"5181L6" = "LQ5181L6"; 
	"5470L6" = "MR5470L6"; 
	"0417L6" = "LQ0417L6"; 
	"0930L6" = "LQ0930L6"; 
	"5746L6" = "MR5746L6"; 
	"1613L6" = "JY1613L6"; 
	"5228L6" = "MO5228L6"; 
	"5472L6" = "MR5472L6"; 
	"5186L6" = "LQ5186L6"; 
	"1600L6" = "JY1600L6"
}

$clients = @{
	"SQL_SystemDB" = @{
		"srv-1c-03.contoso.com" = @{
			"Full-Day" = @{
				"interval" = 7; 
				"dblist" = @{
					"model" = @{
						"media" = @(); 
						"nbimage" = $Null; 
						"mdf" = "model"; 
						"log" = "model_log"
					}; 
					"master" = @{
						"media" = @(); 
						"nbimage" = $Null; 
						"mdf" = "master"; 
						"log" = "master_log"
					}; 
					"msdb" = @{
						"media" = @(); 
						"nbimage" = $Null; 
						"mdf" = "msdb"; 
						"log" = "msdb_log"
					}
				}
			}
		}; 
		"srv-sco-01.contoso.com" = @{
			"Full-Day" = @{
				"interval" = 7; 
				"dblist" = @{
					"model" = @{
						"media" = @(); 
						"nbimage" = $Null; 
						"mdf" = "model"; 
						"log" = "model_log"
					}; 
					"master" = @{
						"media" = @(); 
						"nbimage" = $Null; 
						"mdf" = "master"; 
						"log" = "master_log"
					}; 
					"msdb" = @{
						"media" = @(); 
						"nbimage" = $Null; 
						"mdf" = "msdb"; 
						"log" = "msdb_log"
					}
				}
			}
			"Full-Month" = @{
				"interval" = 90; 
				"dblist" = @{
					"model" = @{
						"media" = @(); 
						"nbimage" = $Null; 
						"mdf" = "model"; 
						"log" = "model_log"
					}; 
					"master" = @{
						"media" = @(); 
						"nbimage" = $Null; 
						"mdf" = "master"; 
						"log" = "master_log"
					}; 
					"msdb" = @{
						"media" = @(); 
						"nbimage" = $Null; 
						"mdf" = "msdb"; 
						"log" = "msdb_log"
					}
				}
			}
		}
	}
}










$bch_template = @'
OPERATION RESTORE
OBJECTTYPE DATABASE
RESTORETYPE MOVE
DATABASE "NB_Test_Restore"
MOVE  "{0}"
TO  "E:\Workdata\NB_Test_Restore.mdf"
MOVE  "{1}"
TO  "E:\Workdata\NB_Test_Restore_log.ldf"
NBIMAGE "{2}"
SQLHOST "SRV-NBTEST-01"
SQLINSTANCE "MSSQLSERVER"
NBSERVER "SRV-NB-01.CONTOSO.COM"
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

# list images

foreach($client in $clients.Keys)
{
	$images = (& 'C:\Program Files\Veritas\NetBackup\bin\bplist.exe' -C $client -t 15 -R \) | Sort-Object -Unique

	foreach($image in $images)
	{
		$data = $image -split '\.'

		if($data[3] -eq 'db' -and ($data[7].Substring(0, 3) -eq '001') -and $data[8] -eq '20180909203211')
		{
			$stripes = [int] $data[7].Substring(5, 3)
			$nbimage = $image.Substring(0, $image.Length - 2)
			$dbname = $data[4]
			if($clients[$client].ContainsKey($dbname))
			{
				Write-Host -ForegroundColor Green ($data[7] + " " + $data[2] + " " + $data[4] + " " + $data[8][6] + $data[8][7] + "." + $data[8][4] + $data[8][5] + "." + $data[8][0] + $data[8][1] + $data[8][2] + $data[8][3] + " " + $data[8][8] + $data[8][9] + ":" + $data[8][10] + $data[8][11])
				
				Write-Host -ForegroundColor Green -NoNewline "Finding media..."
				$backups = & 'C:\Program Files\Veritas\NetBackup\bin\bpimagelist.exe' -C $client -json
				
				foreach($backup in $backups)
				{
					$date = (((Get-Date "1970-01-01 00:00:00.000Z") + ([TimeSpan]::FromSeconds($j.backup_time)))).ToString("MM/dd/yyyy HH:mm")
					$i = & 'C:\Program Files\Veritas\NetBackup\bin\bplist.exe' -s $date -e $date -C $client -t 15 -R $image
					$frags = & 'C:\Program Files\Veritas\NetBackup\bin\bpimagelist.exe' -backupid $backup
					foreach($frag in $frags)
					{
						if($frag -match '^FRAG ')
						{
							$ = & 'C:\Program Files\Veritas\VolMgr\bin\vmquery.exe' -m $media
						}
					}
				}

				# create move script

				$bch = $bch_template -f $clients[$client][$dbname].mdf, $clients[$client][$dbname].log, $nbimage, $stripes, $client
				Set-Content -Path "c:\_temp\restore.bch" -Value $bch
				
				Write-Host -ForegroundColor Green -NoNewline "Restoring DB..."

				#& 'start /wait C:\Program Files\Veritas\NetBackup\bin\dbbackex.exe' -f c:\_temp\restore.bch -u sa -pw B2FSQkvYrPuVeZdj -np
				$proc = Start-Process -FilePath 'C:\Program Files\Veritas\NetBackup\bin\dbbackex.exe' -ArgumentList '-f c:\_temp\restore.bch -u sa -pw B2FSQkvYrPuVeZdj -np' -PassThru
				Wait-Process -InputObject $proc #-Timeout 99999
				Write-Host -ForegroundColor Green (" result: " + $proc.ExitCode)
				if($proc.HasExited -and $proc.ExitCode -eq 0)
				{
					Write-Host -ForegroundColor Green "Checking DB..."

					$result = Invoke-SQL -dataSource "srv-nbtest-01" -sqlCommand "DBCC CHECKDB ([NB_Test_Restore]) WITH TABLERESULTS"
				}

				Write-Host -ForegroundColor Green "Deleting DB..."

				$result = Invoke-SQL -dataSource "srv-nbtest-01" -sqlCommand "USE master`r`nIF EXISTS(select * from sys.databases where name='NB_Test_Restore')`r`nDROP DATABASE NB_Test_Restore"

				break
			}
		}
	}
}

# how about insert tape
# send report
