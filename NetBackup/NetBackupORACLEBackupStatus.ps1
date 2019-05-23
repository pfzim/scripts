# ORACLE success report

$smtp_from = "orchestrator@contoso.com"
$smtp_to = "admin@contoso.com"
$smtp_server = "smtp.contoso.com"

$smtp_creds = New-Object System.Management.Automation.PSCredential ("contoso\orchestrator", (ConvertTo-SecureString "Passw0rd" -AsPlainText -Force))

$report_date = Get-Date
$summary = @{}

$log_dates = @($report_date, $report_date.AddDays(-1 - ($report_date.Day)))

$date14 = $report_date.AddDays(-14)
$date7 = $report_date.AddDays(-7)
$date1 = $report_date.AddDays(-1)

# parse policies

$data = & 'C:\Program Files\Veritas\NetBackup\bin\admincmd\bppllist.exe' -allpolicies

$skip_class = $true
$skip_sched = $true
$policies = @{}

for($i = 0; $i -lt $data.Count; $i++)
{
    $row = $data[$i]
    if($row -match '^CLASS ([^\s]+)')
    {
        $class = $matches[1]
        ("" + $class)
        $skip_class = ($class -notmatch "^ORACLE_")
        $skip_schedule = $true
        if(!$skip_class)
        {
            $policies[$class] = @{}
            $policies[$class]['schedules'] = @{}
            $policies[$class]['clients'] = @()
        }
    }
    elseif(!$skip_class)
    {
        if($row -match '^SCHED ([^\s]+)')
        {
            $schedule = $matches[1]
            ("  " + $matches[1])
            $skip_schedule = ($schedule -notmatch "Full")
            if(!$skip_schedule)
            {
                $policies[$class]['schedules'][$schedule] = @{}
            }
        }
        elseif($row -match '^CLIENT ([^\s]+) ([^\s]+) ([^\s]+)\s')
        {
            ("    " + $matches[1] + "\" + $matches[2])
            $policies[$class]['clients'] += @{ name = $matches[1]; instance = $matches[2]; db = $matches[3].Replace("%20", " ") }
        }
        elseif(!$skip_schedule)
        {
            if($row -match '^SCHEDWIN (.+)')
            {
                ("    WINDOWS: " + $matches[1])
                $policies[$class]['schedules'][$schedule]['windows'] = @($matches[1] -split " ")
            }
            elseif($row -match '^SCHEDCALEDAYOWEEK (.+)')
            {
                ("    SCHEDCALEDAYOWEEK: " + $matches[1])
                $policies[$class]['schedules'][$schedule]['exclude'] = $matches[1]
            }
        }
    }
}

#$policies | ConvertTo-Json -Depth 99

# generate empty summary

foreach($p_key in $policies.Keys)
{
    foreach($c_key in $policies[$p_key]['clients'])
    {
        $summary[$p_key] = @{}
        $summary[$p_key][$c_key.name] = @{}
        $summary[$p_key][$c_key.name][$c_key.instance] = @{Full = (Get-Date "1970-01-01 00:00:00.000Z"); FullName = "None"; Diff = (Get-Date "1970-01-01 00:00:00.000Z"); DiffName = "None"}
    }
}

#$summary | ConvertTo-Json -Depth 99

# fill summary from job logs

foreach($log_date in $log_dates)
{
	$file = ("c:\scripts\logs\result-jobs-" + ($log_date).ToString("yyyy-MM") + ".json")
	("Loading: " + $file)

	try
	{
		$data = Get-Content -Path $file -Raw
		$json = $data | ConvertFrom-Json
	}
	catch
	{
		Write-Host -ForegroundColor Red ("Error load: " + $_.Exception.Message)
		$json = "[]" | ConvertFrom-Json
	}

	foreach($j in $json)
	{
		if($j.PolicyName -match "^ORACLE" -and $j.State -eq 3 -and $j.Status -eq 0 -and $j.Restartable -and ($j.ScheduleType -eq 0 -or $j.ScheduleType -eq 1))
		{
			$jst = ((Get-Date "1970-01-01 00:00:00.000Z") + ([TimeSpan]::FromSeconds($j.StartTime)))
			$jet = ((Get-Date "1970-01-01 00:00:00.000Z") + ([TimeSpan]::FromSeconds($j.EndTime)))
					
			Write-Host -ForegroundColor Gray ("{0}`t{9}`t{1}`t{2}`t{3}`t{4}`t{5}`t{6}`t{7}`t{8}`t{10}" -f $j.JobId,$jst.ToString("dd.MM.yyyy HH:mm"),$jet.ToString("dd.MM.yyyy HH:mm"),$j.PolicyName,$j.ScheduleName,$j.ClientName,$j.InstanceDatabaseName,$j.Status,$j.JobSubtypeText, $j.ParentJobId, $j.State)
			
			if(!$summary.ContainsKey($j.PolicyName))
			{
				continue
				$summary[$j.PolicyName] = @{}
			}

			if(!$summary[$j.PolicyName].ContainsKey($j.ClientName))
			{
				continue
				$summary[$j.PolicyName][$j.ClientName] = @{}
			}

			if(!$summary[$j.PolicyName][$j.ClientName].ContainsKey($j.InstanceDatabaseName))
			{
				continue
				$summary[$j.PolicyName][$j.ClientName][$j.InstanceDatabaseName] = @{Full = (Get-Date "1970-01-01 00:00:00.000Z"); FullName = "None"; Diff = (Get-Date "1970-01-01 00:00:00.000Z"); DiffName = "None"}
			}

			if($j.ScheduleType -eq 0)
			{
				if($summary[$j.PolicyName][$j.ClientName][$j.InstanceDatabaseName].Full -le $jst)
				{
				   $summary[$j.PolicyName][$j.ClientName][$j.InstanceDatabaseName].Full = $jst
				   $summary[$j.PolicyName][$j.ClientName][$j.InstanceDatabaseName].FullName = $j.ScheduleName
				}
			}
			elseif($j.ScheduleType -eq 1)
			{
				if($summary[$j.PolicyName][$j.ClientName][$j.InstanceDatabaseName].Diff -le $jst)
				{
				   $summary[$j.PolicyName][$j.ClientName][$j.InstanceDatabaseName].Diff = $jst
				   $summary[$j.PolicyName][$j.ClientName][$j.InstanceDatabaseName].DiffName = $j.ScheduleName
				}
			}

			#$j | ConvertTo-Json
			#break
		}
	}
}

#$summary | ConvertTo-Json -Depth 99

# print report

$title = "NetBackup ORACLE backup status"

$body = @'
<html>
<head>
	<meta http-equiv="Content-Type" content="text/html; charset=utf-8">
	<style>
		body {font-family: Courier New; font-size: 8pt;}
		h1 {font-size: 16px;}
		h2 {font-size: 14px;}
		h3 {font-size: 12px;}
		table {border: 1px solid #A9A9A9; border-collapse: collapse; font-size: 8pt;}
		th {border: 1px solid #A9A9A9; background: #dddddd; padding: 5px; color: #000000;}
		td {border: 1px solid #A9A9A9; padding: 5px; vertical-align: top;}
		div {padding: 5px;}
		.pass {background: #7FFF00;}
		.warn {background: #FFE600;}
		.error {background: #FF0000; color: #ffffff;}
	</style>
</head>
<body>
'@

$body += @'
<h1>{0}</h1>
'@ -f $title

$body += @'
<table>
<tr><th>Policy</th><th>Client</th><th>DB</th><th>Full</th><th>Schedule</th><th>Diff</th><th>Schedule</th></tr>
'@

foreach($p_key in $summary.Keys)
{
    foreach($c_key in $summary[$p_key].Keys)
    {
		foreach($d_key in $summary[$p_key][$c_key].Keys)
		{
			if($summary[$p_key][$c_key][$d_key].Diff -le $date7)
			{
			   $s_diff = '<td class="error">{0}</td>' -f ($summary[$p_key][$c_key][$d_key].Diff).ToString("dd.MM.yyyy HH:mm")
			}
			elseif($summary[$p_key][$c_key][$d_key].Diff -le $date1)
			{
			   $s_diff = '<td class="warn">{0}</td>' -f ($summary[$p_key][$c_key][$d_key].Diff).ToString("dd.MM.yyyy HH:mm")
			}
			else
			{
			   $s_diff = '<td class="pass">{0}</td>' -f ($summary[$p_key][$c_key][$d_key].Diff).ToString("dd.MM.yyyy HH:mm")
			}

			if($summary[$p_key][$c_key][$d_key].Full -le $date14)
			{
			   $s_full = '<td class="error">{0}</td>' -f ($summary[$p_key][$c_key][$d_key].Full).ToString("dd.MM.yyyy HH:mm")
			}
			elseif($summary[$p_key][$c_key][$d_key].Full -le $date7)
			{
			   $s_full = '<td class="warn">{0}</td>' -f ($summary[$p_key][$c_key][$d_key].Full).ToString("dd.MM.yyyy HH:mm")
			}
			else
			{
			   $s_full = '<td class="pass">{0}</td>' -f ($summary[$p_key][$c_key][$d_key].Full).ToString("dd.MM.yyyy HH:mm")
			}
			
			$body += "<tr><td>{0}</td><td>{1}</td><td>{2}</td>{3}<td>{5}</td>{4}<td>{6}</td></tr>`r`n" -f $p_key, $c_key, $d_key, $s_full, $s_diff, $summary[$p_key][$c_key][$d_key].FullName, $summary[$p_key][$c_key][$d_key].DiffName
		}
   }
}

$body += "</table>`r`n"

$body += @'
</body>
</html>
'@

# send report

Send-MailMessage -from $smtp_from -to $smtp_to -Encoding UTF8 -subject $title -bodyashtml -body $body -smtpServer $smtp_server -Credential $smtp_creds -Priority High
