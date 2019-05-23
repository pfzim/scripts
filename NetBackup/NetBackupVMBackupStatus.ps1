$smtp_from = "orchestrator@contoso.com"
$smtp_to = "admin@contoso.com"
$smtp_server = "smtp.contoso.com"

$smtp_creds = New-Object System.Management.Automation.PSCredential ("domain\smtp_login", (ConvertTo-SecureString "Passw0rd" -AsPlainText -Force))
$vmm_creds = New-Object System.Management.Automation.PSCredential ("domain\vmm_admin", (ConvertTo-SecureString "Passw0rd" -AsPlainText -Force))

$ErrorActionPreference = "Stop"

$session = New-PSSession -ComputerName srv-vmm-01.contoso.com -Credential $vmm_creds
$clients = Invoke-Command -Session $session -ScriptBlock {

    #Add-PSSnapin *VirtualMachineManager*
    $vms = Get-SCVirtualMachine -VMMServer srv-vmm-01.contoso.com | select Name | Sort-Object -Unique Name

    return $vms.Name
}

Remove-PSSession $session

#$clients = Get-Content -Path "C:\temp\zimin\vms.txt" | Sort-Object -Unique
#$clients = @("srv-scom-01")

$exclude = Get-Content -Path "c:\scripts\vm-exclude-list.txt"

$date7 = (Get-Date).AddDays(-7)
$date1 = (Get-Date).AddDays(-1)

$body = @'
<html>
<head>
	<meta http-equiv="Content-Type" content="text/html; charset=utf-8">
	<style>
		body{font-family: Courier New; font-size: 8pt;}
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
<h1>NetBackup VM backup status</h1>
<table>
<tr><th>Name</th><th>Policy</th><th>Date</th><th>Schedule</th><th>Date</th><th>Schedule</th></tr>
'@

foreach($client in $clients)
{
	if($exclude -eq $client)
	{
		continue
	}

    $json = @()
    $data = ""

    try
    {
        $data = & 'C:\Program Files\Veritas\NetBackup\bin\admincmd\bpimagelist.exe' -client $client -hoursago 500 -json
        $data = $data -join ""
        $data = $data.replace("}{", "},{")

        $json = ("[" + $data + "]") | ConvertFrom-Json
    }
    catch
    {
        $json = @()
    }

    if($json.Count -eq 0)
    {
        Write-Host -ForegroundColor Red ($client + " - NO BACKUPS")
        $body += ("<tr><td>" + $client + "</td><td class=`"error`" colspan=5>NO BACKUPS</td></tr>")
        continue
    }

    $policies = @{}

    foreach($image in $json)
    {
        if($image.policy_name -match "^VM")
        {
            if(!$policies[$image.policy_name])
			{
                $policies[$image.policy_name] = @{}
                $policies[$image.policy_name]['Full'] = @{}
                $policies[$image.policy_name]['Diff'] = @{}
				$policies[$image.policy_name]['Full'].lbd = $null
				$policies[$image.policy_name]['Full'].image = $null
				$policies[$image.policy_name]['Diff'].lbd = $null
				$policies[$image.policy_name]['Diff'].image = $null
			}
			
			if($image.sched_label -match "Full")
			{
				$name = 'Full';
			}
			else
			{
				$name = 'Diff';
			}
			
            $lbd = ((Get-Date "1970-01-01 00:00:00.000Z") + ([TimeSpan]::FromSeconds($image.backup_time)))
			
			if(!$policies[$image.policy_name][$name].image)
			{
				$policies[$image.policy_name][$name].lbd = $lbd
				$policies[$image.policy_name][$name].image = $image
			}
			elseif($lbd -ge $policies[$image.policy_name][$name].lbd)
            {
                $policies[$image.policy_name][$name].lbd = $lbd
                $policies[$image.policy_name][$name].image = $image
            }
        }
    }

    if($policies.Keys.Count -le 0)
    {
        Write-Host -ForegroundColor Red ($client + " - NO BACKUPS")
        $body += ("<tr><td>" + $client + "</td><td class=`"error`" colspan=5>NO BACKUPS</td></tr>")
        continue
    }

    foreach($policy in $policies.Keys)
    {
        $p = $policies[$policy]

		$client_name = $client
		
		$full_sch = ""
		$full_policy = ""
		$lbd_full_s = "NO BACKUPS"
		$class_full = "error"
		
		if($p['Full'].image)
		{
			$full_sch = $p['Full'].image.sched_label
			$client_name = $p['Full'].image.client_name
			$full_policy = $p['Full'].image.policy_name
			$lbd_full = ((Get-Date "1970-01-01 00:00:00.000Z") + ([TimeSpan]::FromSeconds($p['Full'].image.backup_time)))
			$lbd_full_s = $lbd_full.ToString("dd.MM.yyyy HH:mm")
			if($lbd_full -le $date7)
			{
				$color = "Yellow"
				$class_full = "warn"
			}
			else
			{
				$color = "Green"
				$class_full = "pass"

			}
		}

		$diff_sch = ""
		$diff_policy = ""
		$lbd_diff_s = "NO BACKUPS"
		$class_diff = "error"
		
		if($p['Diff'].image)
		{
			$diff_sch = $p['Diff'].image.sched_label
			$full_policy = $p['Diff'].image.policy_name
			$lbd_diff = ((Get-Date "1970-01-01 00:00:00.000Z") + ([TimeSpan]::FromSeconds($p['Diff'].image.backup_time)))
			$lbd_diff_s = $lbd_diff.ToString("dd.MM.yyyy HH:mm")
			if($lbd_diff -le $date7)
			{
				$class_diff = "error"
			}
			elseif($lbd_diff -le $date1)
			{
				$class_diff = "warn"
			}
			else
			{
				$class_diff = "pass"
			}
		}

        Write-Host -ForegroundColor $color ($client_name + "    " + $lbd_full_s + "    " + $full_policy + "    " + $full_sch)      
        $body += ("<tr><td>" + $client_name + "</td><td>" + $full_policy + "</td><td class=`"" + $class_full +"`">" + $lbd_full_s + "</td><td>" + $full_sch + "</td><td class=`"" + $class_diff +"`">" + $lbd_diff_s + "</td><td>" + $diff_sch + "</td></tr>")
    }        
}

$body += @'
</table>
</body>
</html>
'@

Send-MailMessage -from $smtp_from -to $smtp_to -Encoding UTF8 -subject "NetBackup VM backup status" -bodyashtml -body $body -smtpServer $smtp_server -Credential $smtp_creds
