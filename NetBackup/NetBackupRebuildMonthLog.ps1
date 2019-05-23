# rebuild result jobs log file for current month

$ErrorActionPreference = "Stop"

$date = Get-Date
$file_name = ("c:\scripts\logs\result-jobs-" + (Get-Date -format "yyyy-MM") + ".json")

$jobs_list = @()
$json_result = "[]" | ConvertFrom-Json
$mask = ("jobs[-._]{0:d4}[-._]{1:d2}[-._]\d\d[-._]" -f $date.Year, $date.Month)
("Mask: " + $mask)

$files = Get-ChildItem ("c:\scripts\logs\")
foreach($file in $files)
{
    if((!$file.PSIsContainer) -and ($file.Name -match $mask))
	{
        ("Loading: " + $file.Name)
        try
        {
            $data = $file | Get-Content -Raw
        }
        catch
        {
            continue
        }

        $json = $data | ConvertFrom-Json

        foreach($j in $json)
        {
            if($j.Status -eq 0 -and $j.State -eq 0 -and $j.JobId -notin $jobs_list)
            {
                $jobs_list += $j.JobId
                $json_result += $j
            }
        }
	}
}

("Save: " + $file_name)
$json_result | ConvertTo-Json -Depth 99 | Set-Content -Path $file_name
