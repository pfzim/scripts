Function ConvertTo-PSON($Object, [Int]$Depth = 9, [Int]$Layers = 1, [Switch]$Strict, [Version]$Version = $PSVersionTable.PSVersion) {
    $Format = $Null
    $Quote = If ($Depth -le 0) {""} Else {""""}
    $Space = If ($Layers -le 0) {""} Else {" "}
    If ($Object -eq $Null) {"`$Null"} Else {
        $Type = "[" + $Object.GetType().Name + "]"
        $PSON = If ($Object -is "Array") {
            $Format = "@(", ",$Space", ")"
            If ($Depth -gt 1) {For ($i = 0; $i -lt $Object.Count; $i++) {ConvertTo-PSON $Object[$i] ($Depth - 1) ($Layers - 1) -Strict:$Strict}}
        } ElseIf ($Object -is "Xml") {
            $Type = "[Xml]"
            $String = New-Object System.IO.StringWriter
            $Object.Save($String)
            $Xml = "'" + ([String]$String).Replace("`'", "&apos;") + "'"
            If ($Layers -le 0) {($Xml -Replace "\r\n\s*", "") -Replace "\s+", " "} ElseIf ($Layers -eq 1) {$Xml} Else {$Xml.Replace("`r`n", "`r`n`t")}
            $String.Dispose()
        } ElseIf ($Object -is "DateTime") {
            "$Quote$($Object.ToString('s'))$Quote"
        } ElseIf ($Object -is "String") {
            0..11 | ForEach {$Object = $Object.Replace([String]"```'""`0`a`b`f`n`r`t`v`$"[$_], ('`' + '`''"0abfnrtv$'[$_]))}; "$Quote$Object$Quote"
        } ElseIf ($Object -is "Boolean") {
            If ($Object) {"`$True"} Else {"`$False"}
        } ElseIf ($Object -is "Char") {
            If ($Strict) {[Int]$Object} Else {"$Quote$Object$Quote"}
        } ElseIf ($Object -is "ValueType") {
            $Object
        } ElseIf ($Object.Keys -ne $Null) {
            If ($Type -eq "[OrderedDictionary]") {$Type = "[Ordered]"}
            $Format = "@{", ";$Space", "}"
            If ($Depth -gt 1) {$Object.GetEnumerator() | ForEach {"`"" + $_.Name + "`"$Space=$Space" + (ConvertTo-PSON $_.Value ($Depth - 1) ($Layers - 1) -Strict:$Strict)}}
        } ElseIf ($Object -is "Object") {
            If ($Version -le [Version]"2.0") {$Type = "New-Object PSObject -Property "}
            $Format = "@{", ";$Space", "}"
            If ($Depth -gt 1) {$Object.PSObject.Properties | ForEach {"`"" + $_.Name + "`"$Space=$Space" + (ConvertTo-PSON $_.Value ($Depth - 1) ($Layers - 1) -Strict:$Strict)}}
        } Else {$Object}
        If ($Format) {
            $PSON = $Format[0] + (&{
                If (($Layers -le 1) -or ($PSON.Count -le 0)) {
                    $PSON -Join $Format[1]
                } Else {
                    ("`r`n" + ($PSON -Join "$($Format[1])`r`n")).Replace("`r`n", "`r`n`t") + "`r`n"
                }
            }) + $Format[2]
        }
        If ($Strict) {"$Type$PSON"} Else {"$PSON"}
    }
}

$media = @{
	"0432L6" = "LQ0432L6"; 
	"1402L6" = "JY1402L6"; 
	"0932L6" = "LQ0932L6"; 
	"0411L6" = "LQ0411L6"; 
	"0408L6" = "LQ0408L6"; 
	"0406L6" = "LQ0406L6"; 
	"5184L6" = "LQ5184L6"; 
	"1600L6" = "JY1600L6"
}

@{
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

(Get-Date).ToString("dd/MM/yyyy HH:mm")

$media_required = @()

foreach($p_key in $clients.Keys)
{
    foreach($c_key in $clients[$p_key].Keys)
    {
        foreach($s_key in $clients[$p_key][$c_key].Keys)
        {
            $sd = (Get-Date).AddDays(-$clients[$p_key][$c_key][$s_key].interval).ToString("MM/dd/yyyy HH:mm")
            $ed = (Get-Date).ToString("MM/dd/yyyy HH:mm")

            try
            {
                $data = & 'C:\Program Files\Veritas\NetBackup\bin\admincmd\bpimagelist.exe' -client $c_key -policy $p_key -sl $s_key -d $sd -e $ed -json -json_array
            }
            catch
            {
                Write-Host -ForegroundColor Red ("ERROR: Not found images for " + $c_key + " " + $p_key + " " + $s_key)
                continue
            }

            $json = $data | ConvertFrom-Json

            foreach($j in $json)
            {
                $date = (((Get-Date "1970-01-01 00:00:00.000Z") + ([TimeSpan]::FromSeconds($j.backup_time)))).ToString("MM/dd/yyyy HH:mm")
                $date

                try
                {
                    $images = (& 'C:\Program Files\Veritas\NetBackup\bin\bplist.exe' -s $date -e $date -C $c_key -k $p_key -t 15 -R \) | Sort-Object -Unique
                }
                catch
                {
                    continue
                }

	            foreach($image in $images)
	            {
		            $data = $image -split '\.'

		            if($data[3] -eq 'db' -and ($data[7].Substring(0, 5) -eq '001of') -and $clients[$p_key][$c_key][$s_key].dblist.ContainsKey($data[4]))
		            {
                        if(!$clients[$p_key][$c_key][$s_key].dblist[$data[4]].nbimage)
                        {
			                $clients[$p_key][$c_key][$s_key].dblist[$data[4]].stripes = [int] $data[7].Substring(5, 3)
			                $clients[$p_key][$c_key][$s_key].dblist[$data[4]].nbimage = $image.Substring(0, $image.Length - 2)
                            foreach($f in $j.frags)
                            {
                                if($f.media_type -eq 2)
                                {
			                        $clients[$p_key][$c_key][$s_key].dblist[$data[4]].media += $media[$f.id]
                                    if($media[$f.id] -notin $media_required)
                                    {
                                        $media_required += $media[$f.id]
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

#$clients | ConvertTo-Json -Depth 99
#cls
ConvertTo-PSON -Object $clients -Layers 9

"Media required:"
$media_required

(Get-Date).ToString("dd/MM/yyyy HH:mm")

foreach($p_key in $clients.Keys)
{
    foreach($c_key in $clients[$p_key].Keys)
    {
        foreach($s_key in $clients[$p_key][$c_key].Keys)
        {
			foreach($d_key in $clients[$p_key][$c_key][$s_key].dblist.Keys)
			{
				if($clients[$p_key][$c_key][$s_key].dblist[$d_key].nbimage)
				{
					Write-Host -ForegroundColor Green ("DB: " + $d_key +" Image: " + $clients[$p_key][$c_key][$s_key].dblist[$d_key].nbimage)
					Write-Host -ForegroundColor Green ("Media required: " + ($clients[$p_key][$c_key][$s_key].dblist[$d_key].media -join ", "))
					Write-Host -ForegroundColor Green ("MDF: " + $clients[$p_key][$c_key][$s_key].dblist[$d_key].log + " LOG: " + $clients[$p_key][$c_key][$s_key].dblist[$d_key].log + " Stripes: " + $clients[$p_key][$c_key][$s_key].dblist[$d_key].stripes)

					# create move script

					$bch = $bch_template -f $clients[$p_key][$c_key][$s_key].dblist[$d_key].mdf, $clients[$p_key][$c_key][$s_key].dblist[$d_key].log, $clients[$p_key][$c_key][$s_key].dblist[$d_key].nbimage, $clients[$p_key][$c_key][$s_key].dblist[$d_key].stripes, $c_key
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
			break
		}
		break
	}
	break
}

(Get-Date).ToString("dd/MM/yyyy HH:mm")
