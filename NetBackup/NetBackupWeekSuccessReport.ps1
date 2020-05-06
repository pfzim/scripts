# Week success jobs report

. c:\scripts\inc.config.ps1

$global:smtp_creds = New-Object System.Management.Automation.PSCredential ($global:g_config.smtp_login, (ConvertTo-SecureString $global:g_config.smtp_passwd -AsPlainText -Force))

$report_date = Get-Date                 # previous week
#$report_date = (Get-Date).AddDays(7)    # current week

$ErrorActionPreference = 'Stop'

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
        $skip_class = ($class -notmatch "^SQL_")
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
            $skip_schedule = ($schedule -notmatch 'Full')
            if(!$skip_schedule)
            {
                $policies[$class]['schedules'][$schedule] = @{calendar = $false}
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
            elseif($row -match '^SCHEDCALDAYOWEEK (.+)')
            {
                ("    SCHEDCALEDAYOWEEK: " + $matches[1])
                $policies[$class]['schedules'][$schedule]['include'] = $matches[1]
            }
            elseif($row -match '^SCHEDCALENDAR')
            {
                ("    SCHEDCALEDAYOWEEK: " + $matches[1])
                $policies[$class]['schedules'][$schedule]['calendar'] = $true
            }
        }
    }
}

#$policies | ConvertTo-Json -Depth 99

# create launches calendar

$month = $report_date.Month
$year = $report_date.Year
$dom = [datetime]::DaysInMonth($year,$month)

if($report_date.DayOfWeek -eq 0)
{
    $twd = 7
}
else
{
    $twd = $report_date.DayOfWeek
}

$report_date = $report_date.AddDays(-6 - $twd)

$calendar = @{}

foreach($p_key in $policies.Keys)
{
    $policy = $policies[$p_key]

    if($policy.Keys.Count -le 0)
    {
        continue
    }

    $calendar[$p_key] = @()

    #("POLICY : " + $p_key)

    foreach($c_key in $policy['clients'])
    {
        $client = @{ name = $c_key['name']; instance = $c_key['instance']; db = $c_key['db']; days = @{} }

        for($i = 0; $i -lt 7; $i++)
        {
			$date = $report_date.AddDays($i)
            $date = Get-Date -Year $date.Year -Month $date.Month -Day $date.Day -Hour 0 -Minute 0 -Second 0

            #("  DAY : " + $day['date'])
            $dow = [int] $date.DayOfWeek
            $wom = [math]::floor(($date.day - (6+$dow)%7 + 5)/7)+1
			# NetBackup specific week number of month
			$nb_wom = [math]::floor(($date.day-1)/7)+1
            #$day['schedules'] = @()
			$client['days'][[string] $date.Day] = @{}

            foreach($s_key in $policy['schedules'].Keys)
            {
                #("    SCHED : " + $s_key)
                #$schedule = $policies[$p_key][$s_key]
                if($policies[$p_key]['schedules'][$s_key].windows[$dow*2])
                {
					if($policies[$p_key]['schedules'][$s_key].exclude -notmatch ("" + ($dow+1) + ',' + $nb_wom) -and (
							!$policies[$p_key]['schedules'][$s_key].calendar -or
							$policies[$p_key]['schedules'][$s_key].include -match ("" + ($dow+1) + ',' + $nb_wom) -or
							(($date.day + 7) -gt $dom -and $policies[$p_key]['schedules'][$s_key].include -match ("" + ($dow+1) + ',5'))
						)
					)
                    {
			            $client['days'][[string] $date.Day][$s_key] = 'error'
                    }
                }
            }

            #$calendar[$p_key] += $day
            #$client['days'][[string] $date.Day] += $schedules
        }

        $calendar[$p_key] += $client
    }
}

#$calendar | ConvertTo-Json -Depth 99
#$policies | ConvertTo-Json -Depth 99

# check finished launches

#$data = & 'C:\Program Files\Veritas\NetBackup\bin\admincmd\bpdbjobs.exe' -ignore_parent_jobs -json

if($report_date.Month -ne $report_date.AddDays(6).Month)
{
	$log_dates = @($report_date, $report_date.AddDays(6))
}
else
{
	$log_dates = @($report_date)
}

$success_jobs = [System.Collections.ArrayList]@()

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

	$report_start = Get-Date -Year $report_date.Year -Month $report_date.Month -Day $report_date.Day -Hour 0 -Minute 0 -Second 0
	$week_end = $report_date.AddDays(6)
	$report_end = Get-Date -Year $week_end.Year -Month $week_end.Month -Day $week_end.Day -Hour 23 -Minute 59 -Second 59

	"Finding all success jobs..."

	foreach($j in $json)
	{
		if($j.Status -eq 0)
		{
			[void] $success_jobs.Add($j.JobId)
		}
	}

	"Generating calendar..."

	foreach($j in $json)
	{
		if($j.ScheduleName -match 'Full')
		{
			if($calendar.ContainsKey($j.PolicyName))
			{
				foreach($client in $calendar[$j.PolicyName])
				{
					# fix names
					$c_name = ($client['name'].split('.'))[0]
					if($c_name -match "^srv-vsql-0[12]")
					{
						$c_name += "|srv-sql-01|srv-sql-02"
					}
					if($c_name -match "^srv-vsql-03")
					{
						$c_name += "|srv-sql-05|srv-sql-06"
					}

					if($j.Status -eq 0 -and $j.ClientName -match $c_name -and ($client['instance'] + "\" + $client['db']) -eq $j.InstanceDatabaseName)
					{
						$jst = ((Get-Date "1970-01-01 00:00:00.000Z") + ([TimeSpan]::FromSeconds($j.StartTime)))
						if($jst -ge $report_start -and $jst -le $report_end -and $j.ParentJobID -in $success_jobs)
						{
							if($client['Days'][[string] $jst.Day].ContainsKey($j.ScheduleName))
							{
								if($client['Days'][[string] $jst.Day][$j.ScheduleName] -eq 'error')
								{
									$client['Days'][[string] $jst.Day][$j.ScheduleName] = 'pass'
								}
							}
							else
							{
								$client['Days'][[string] $jst.Day][$j.ScheduleName] = 'warn'
							}
							#(""+ $j.JobId + "   " + $j.Status + "   " + $day['start'] + " < " + $jst +  " <  " + $day['end'] + "   " + $j.PolicyName + "   " + $j.ScheduleName + "   " + $j.InstanceDatabaseName)
						}
					}
				}
			}
		}
	}
}

#$calendar | ConvertTo-Json

# print report

"Generating report..."

$title = "NetBackup week report ({0})" -f ($report_date).ToString("yyyy-MM-dd")

$body = @'
<html>
<head>
	<meta http-equiv="Content-Type" content="text/html; charset=utf-8">
	<style>
		body {font-family: Tahoma; font-size: 10pt;}
		h1 {font-size: 16px;}
		h2 {font-size: 14px;}
		h3 {font-size: 12px;}
		table {border: 1px solid #A9A9A9; border-collapse: collapse; font-size: 10pt;}
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
<p>
<span class="pass">Успешно</span> выполнено по расписанию</br>
<span class="warn">Успешно</span> выполнено не по расписанию</br>
<span class="error">Не выполнено</span> по запланированному расписанию
</p>
'@ -f $title

$body += @'
<table>
<tr><th>DB</th><th>Mo</th><th>Tu</th><th>We</th><th>Th</th><th>Fr</th><th>Sa</th><th>Su</th></tr>
'@

foreach($p_key in $calendar.Keys)
{
    #$day = Get-Date -Year $year -Month $month -Day 1
    #$dow = [int] $day.DayOfWeek

    $body += @'
<tr><th colspan=8>{0}</th></tr>
'@ -f $p_key

    foreach($c_key in $calendar[$p_key])
    {
        $body += @'
<tr>
<td>{0}: {1}\{2}</td>
'@ -f $c_key['name'], $c_key['instance'], $c_key['db']

        for($i = 0; $i -lt 7; $i++)
        {
            $day = $report_date.AddDays($i)
            $body += ("<td>")
            foreach($schedule in $c_key['days'][[string] $day.Day].Keys) #['schedules']
            {
                $body += ("<div class=`"{0}`">{1}</div>" -f $c_key['days'][[string] $day.Day][$schedule], $schedule)
            }
            $body += "</td>"
        }

        $body += "</tr>`r`n"
   }
}
$body += "</table>`r`n"

$body += @'
<small>Данные для отчёта сформированы из политик с названием SQL* и накопленных логов. Для переформирования отчёта требуется запустить NetBackupCollectLogs.ps1 и затем NetBackupWeekReport.ps1</small>
</body>
</html>
'@

Send-MailMessage -from $global:g_config.smtp_from -to $global:g_config.smtp_to -Encoding UTF8 -subject $title -bodyashtml -body $body -smtpServer $global:g_config.smtp_server -Credential $global:smtp_creds -Priority High
