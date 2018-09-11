$smtp_from = "orchestrator@contoso.com"
$smtp_to = "admin@contoso.com"
$smtp_server = "smtp.contoso.com"

$smtp_creds = New-Object System.Management.Automation.PSCredential ("contoso\smtp_login", (ConvertTo-SecureString "Passw0rd" -AsPlainText -Force))

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

# create launches calendar

$report_date = (Get-Date).AddMonths(-1)
$month = $report_date.Month
$year = $report_date.Year
$dom = [datetime]::DaysInMonth($year,$month)

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

        for($i = 1; $i -le $dom; $i++)
        {
            $date = Get-Date -Year $year -Month $month -Day $i -Hour 0 -Minute 0 -Second 0

            #("  DAY : " + $day['date'])
            $dow = [int] $date.DayOfWeek
            $wom = [math]::floor(($date.day - (6+$dow)%7 + 5)/7)+1
            #$day['schedules'] = @()
			$client['days'][[string] $i] = @{}

            foreach($s_key in $policy['schedules'].Keys)
            {
                #("    SCHED : " + $s_key)
                #$schedule = $policies[$p_key][$s_key]
                if($policies[$p_key]['schedules'][$s_key].windows[$dow*2])
                {
                    if($policies[$p_key]['schedules'][$s_key].exclude -notmatch ("" + ($dow+1) + ',' + $wom))
                    {
			            $client['days'][[string] $i][$s_key] = 'error'
                    }
                }
            }

            #$calendar[$p_key] += $day
            #$client['days'][[string] $i] += $schedules
        }

        $calendar[$p_key] += $client
    }
}

#$calendar | ConvertTo-Json -Depth 99
#$policies | ConvertTo-Json -Depth 99

# check finished launches

#$data = & 'C:\Program Files\Veritas\NetBackup\bin\admincmd\bpdbjobs.exe' -ignore_parent_jobs -json

$date = ($report_date).ToString("yyyy-MM")
$file = ("c:\scripts\logs\result-jobs-" + $date + ".json")

try
{
    $data = Get-Content -Path $file -Raw
    $json = $data | ConvertFrom-Json
}
catch
{
    $json = "[]" | ConvertFrom-Json
}

$report_start = Get-Date -Year $report_date.Year -Month $report_date.Month -Day 1 -Hour 0 -Minute 0 -Second 0
$report_end = Get-Date -Year $report_date.Year -Month $report_date.Month -Day $dom -Hour 23 -Minute 59 -Second 59

foreach($j in $json)
{
	if($j.ScheduleName -match '^Full')
	{
		if($calendar.ContainsKey($j.PolicyName))
		{
			foreach($client in $calendar[$j.PolicyName])
			{
				# fix names
				$c_name = ($client['name'].split('.'))[0]
				if($c_name -match "^srv-vsql")
				{
					$c_name += "|srv-sql-01|srv-sql-02"
				}

				if($j.Status -eq 0 -and $j.ClientName -match $c_name -and ($client['instance'] + "\" + $client['db']) -eq $j.InstanceDatabaseName)
				{
					$jst = ((Get-Date "1970-01-01 00:00:00.000Z") + ([TimeSpan]::FromSeconds($j.StartTime)))
					if($jst -ge $report_start -and $jst -le $report_end)
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


#$calendar | ConvertTo-Json -Depth 99

# print report

$title = "NetBackup month report ({0})" -f $date

$body = @'
<html>
<head>
	<meta http-equiv="Content-Type" content="text/html; charset=utf-8">
	<style>
		body {font-family: Tahoma; font-size: 10pt;}
		h1 {font-size: 16px;}
		h2 {font-size: 14px; margin-left: 10px}
		h3 {font-size: 12px; margin-left: 20px}
		table {border: 1px solid #A9A9A9; border-collapse: collapse; font-size: 10pt; margin-left: 30px}
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

foreach($p_key in $calendar.Keys)
{
    $day = Get-Date -Year $year -Month $month -Day 1
    $dow = [int] $day.DayOfWeek

    $body += @'
<h2>{0}</h2>
'@ -f $p_key

    foreach($c_key in $calendar[$p_key])
    {
        $body += @'
<h3>{0}: {1}\{2}</h3>
<table>
<tr><th>Mo</th><th>Tu</th><th>We</th><th>Th</th><th>Fr</th><th>Sa</th><th>Su</th></tr>
<tr>
'@ -f $c_key['name'], $c_key['instance'], $c_key['db']

        if($dow -ne 1)
        {
            if($dow -eq 0)
            {
                $fill = 6
            }
            else
            {
                $fill = $dow - 1
            }
            for($i = 0; $i -lt $fill; $i++)
            {
                $body += ("<td></td>")
            }
        }

        for($i = 1; $i -le $dom; $i++)
        {
            $day = Get-Date -Year $year -Month $month -Day $i
            if(($day.DayOfWeek -eq 1) -and ($i -ne 1))
            {
                $body += "</tr>`r`n<tr>"
            }
            #$body += ("<td>{1}</td>" -f $i, ($calendar[$p_key][($i-1)]['schedules'] -join ', '))
            $body += ("<td>" + $i)
            foreach($schedule in $c_key['days'][[string] $i].Keys) #['schedules']
            {
                $body += ("<div class=`"{0}`">{1}</div>" -f $c_key['days'][[string] $i][$schedule], $schedule)
            }
            $body += "</td>"
        }

        if($day.DayOfWeek -ne 0)
        {
            for($i = $day.DayOfWeek; $i -le 6; $i++)
            {
                $body += ("<td></td>")
            }
        }
    
        $body += "</tr></table>`r`n"
   }
}

$body += @'
</body>
</html>
'@

Send-MailMessage -from $smtp_from -to $smtp_to -Encoding UTF8 -subject $title -bodyashtml -body $body -smtpServer $smtp_server -Credential $smtp_creds
