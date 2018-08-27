$report_date = (Get-Date).AddMonths(+1)
$month = $report_date.Month
$year = $report_date.Year
$dom = [datetime]::DaysInMonth($year,$month)

($report_date).ToString("yyyy-MM")

$day = Get-Date -Year $year -Month $month -Day 1
$dow = [int] $day.DayOfWeek

" Mo Tu We Th Fr Sa Su"

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
        Write-Host -NoNewline " --"
    }
}

for($i = 1; $i -le $dom; $i++)
{
    $day = Get-Date -Year $year -Month $month -Day $i
    if(($day.DayOfWeek -eq 1) -and ($i -ne 1))
    {
        Write-Host ""
    }

    Write-Host -NoNewline (" {0:d2}" -f $i)
}

if($day.DayOfWeek -ne 0)
{
    for($i = $day.DayOfWeek; $i -le 6; $i++)
    {
        Write-Host -NoNewline " --"
    }
}
