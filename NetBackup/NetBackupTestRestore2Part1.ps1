$smtp_from = "orchestrator@contoso.com"
$smtp_to = "admin@contoso.com"
$smtp_server = "smtp.contoso.com"

$smtp_creds = New-Object System.Management.Automation.PSCredential ("contoso\orchestrator", (ConvertTo-SecureString "Passw0rd" -AsPlainText -Force))

$media = @{
	"0432L6" = "LQ0432L6"; 
	"1402L6" = "JY1402L6"; 
	"0932L6" = "LQ0932L6"; 
	"0411L6" = "LQ0411L6"; 
	"0408L6" = "LQ0408L6"; 
	"5181L6" = "LQ5181L6"; 
	"5471L6" = "MR5471L6"; 
	"0407L6" = "LQ0407L6"; 
	"5185L6" = "LQ5185L6"; 
	"0936L6" = "LQ0936L6"; 
	"0433L6" = "LQ0433L6"; 
	"5470L6" = "MR5470L6"; 
	"0417L6" = "LQ0417L6"; 
	"0414L6" = "LQ0414L6"; 
	"0434L6" = "LQ0434L6"; 
	"5229L6" = "MO5229L6"; 
	"5749L6" = "MR5749L6"; 
	"1407L6" = "JY1407L6"; 
	"5226L6" = "MO5226L6"; 
	"5461L6" = "MR5461L6"; 
	"1409L6" = "JY1409L6"; 
	"1601L6" = "JY1601L6"; 
	"1618L6" = "JY1618L6"; 
	"0418L6" = "LQ0418L6"; 
	"0435L6" = "LQ0435L6"; 
	"0929L6" = "LQ0929L6"; 
	"1600L6" = "JY1600L6"
}

$clients = @{
	"SQL_SystemDB" = @{
		"srv-vsql-02.contoso.com" = @{
			"Full-Day" = @{
				"interval" = 7; 
				"dblist" = @{
					"model" = @{
						"media" = @(); 
						"nbimage" = $Null; 
						"mdf" = "modeldev"; 
						"log" = @("modellog")
					}; 
					"master" = @{
						"media" = @(); 
						"nbimage" = $Null; 
						"mdf" = "master"; 
						"log" = @("mastlog")
					}; 
					"msdb" = @{
						"media" = @(); 
						"nbimage" = $Null; 
						"mdf" = "MSDBData"; 
						"log" = @("MSDBLog")
					}
				}
			}
		}; 
		"srv-1c-01.contoso.com" = @{
			"Full-Day" = @{
				"interval" = 7; 
				"dblist" = @{
					"ALB_RT_CleanCopy_dev" = @{
						"media" = @(); 
						"nbimage" = $Null; 
						"mdf" = "ALB_RT_CleanCopy_dev"; 
						"log" = @("ALB_RT_CleanCopy_dev_log", "ALB_RT_CleanCopy_dev_log2")
					}; 
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
SQLHOST "BRC-NBTEST-01"
SQLINSTANCE "MSSQLSERVER"
NBSERVER "BRC-NB-01.BRISTOLCAPITAL.RU"
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

Log-Screen "info" ("--- " + (Get-Date).ToString("dd/MM/yyyy HH:mm") + " ---")

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
                Log-Screen "error" ("Not found images for " + $c_key + " " + $p_key + " " + $s_key)
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

							Log-Screen "pass" ($p_key + " : " + $c_key + " : " + $s_key + " : " + $clients[$p_key][$c_key][$s_key].dblist[$data[4]].stripes + " : " + $clients[$p_key][$c_key][$s_key].dblist[$data[4]].nbimage)

                            foreach($f in $j.frags)
                            {
                                if($f.media_type -eq 2)
                                {
                                    if($media[$f.id] -notin $clients[$p_key][$c_key][$s_key].dblist[$data[4]].media)
                                    {
										$clients[$p_key][$c_key][$s_key].dblist[$data[4]].media += $media[$f.id]
                                    }
									
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
try
{
	ConvertTo-PSON -Object $clients -Layers 9 | Set-Content -Path "\\srv-nbtest-01.contoso.com\rules$\NetBackupRestoreRules.pson"
}
catch
{
	Log-Screen "error" ("Save restore rules")
}

try
{
	ConvertTo-PSON -Object $clients -Layers 9 | Set-Content -Path "c:\scripts\logs\NetBackupTestRestore.debug.log"
}
catch
{
	Log-Screen "error" ("Save debug log")
}

$media_required = $media_required | Sort-Object

Log-Screen "info" ("Media required for load: " + ($media_required -join ", "))

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

$body = $header
$body += @'
<h1>Запущено тестовое восстановление резервных копий баз данных</h1>
<p>Предположительный список кассет, требуемых для загрузки в библиотеку:<br /><br />{0}</p>
'@ -f ($media_required -join "<br />")

$list_count = 0
$list = @'
<h3>Список не найденных образов резервных копий</h1>
<table>
<tr><th>Policy</th><th>Client</th><th>Schedule</th><th>DB</th></tr>
'@
foreach($p_key in $clients.Keys)
{
    foreach($c_key in $clients[$p_key].Keys)
    {
        foreach($s_key in $clients[$p_key][$c_key].Keys)
        {
			foreach($d_key in $clients[$p_key][$c_key][$s_key].dblist.Keys)
			{
				if(!$clients[$p_key][$c_key][$s_key].dblist[$d_key].nbimage)
				{
					$list += '<tr><td>{0}</td><td>{1}</td><td>{2}</td><td>{3}</td></tr>' -f $p_key, $c_key, $s_key, $d_key
					$list_count++
				}
			}
		}
	}
}

if($list_count -gt 0)
{
	$body += $list
}

$body += @'
</table>
</body>
</html>
'@

Send-MailMessage -from $smtp_from -to $smtp_to -Encoding UTF8 -subject "Running DB backup tests" -bodyashtml -body $body -smtpServer $smtp_server -Credential $smtp_creds
