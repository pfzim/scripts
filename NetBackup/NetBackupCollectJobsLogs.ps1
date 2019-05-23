# Collect jobs log

$ErrorActionPreference = "Stop"

$date = (Get-Date -format "yyyy-MM-dd-HHmm")
$file = ("c:\scripts\logs\jobs-" + $date + ".json")
$data = & 'C:\Program Files\Veritas\NetBackup\bin\admincmd\bpdbjobs.exe' -json
Set-Content -Path $file -Value $data

# merge jobs to one file

$date = Get-Date

if($date.Day -le 2)
{
    $date = (Get-Date).AddMonths(-1).ToString("yyyy-MM")
}
else
{
    $date = (Get-Date -format "yyyy-MM")
}

$file = ("c:\scripts\logs\result-jobs-" + $date + ".json")

try
{
    $result = Get-Content -Path $file -Raw
    $json_result = $result | ConvertFrom-Json
}
catch
{
    $json_result = "[]" | ConvertFrom-Json
}

$json = $data | ConvertFrom-Json
$jobs_list = @()

foreach($j in $json_result)
{
    if($j.Status -eq 0 -and $j.State -eq 0 -and $j.JobId -notin $jobs_list)
    {
        $jobs_list += $j.JobId
    }    
}

foreach($j in $json)
{
    if($j.Status -eq 0 -and $j.State -eq 0 -and $j.JobId -notin $jobs_list)
    {
        $jobs_list += $j.JobId
        $json_result += $j
    }
}

$json_result | ConvertTo-Json -Depth 99 | Set-Content -Path $file

# purge old files

$date = (Get-Date).AddDays(-90)
$files = Get-ChildItem ("c:\scripts\logs\")
foreach($file in $files)
{
    if((!$file.PSIsContainer) -and ($file.Name -match "jobs[-._]\d{4}[-._]\d{2}[-._]\d{2}"))
	{
		$fd = $file.Name.Split("[-._]", 5)

		if((Get-Date ($fd[1]+"-"+$fd[2]+"-"+$fd[3])) -lt $date)
		{
			$file | Remove-Item -Force
		}
	}
}
