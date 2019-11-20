# 3PAR VV snapshots used space

$ps_creds = New-Object System.Management.Automation.PSCredential ("", (ConvertTo-SecureString "" -AsPlainText -Force))

$session = New-PSSession -ComputerName localhost -Credential $ps_creds -Authentication Credssp

$snapshots = Invoke-Command -Session $session -ScriptBlock {

$ssh_creds = New-Object System.Management.Automation.PSCredential ("", (ConvertTo-SecureString "" -AsPlainText -Force))
$smtp_creds = New-Object System.Management.Automation.PSCredential ("", (ConvertTo-SecureString "" -AsPlainText -Force))

$smtp_from = "orchestrator@contoso.com"
$smtp_to = "admin@contoso.com"
$smtp_server = "smtp.contoso.com"

$ips = @("172.18.1.1", "172.18.1.2")

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
	<h1>Отчёт по занятому VV-снапшотами месту на 3PAR</h1>
'@

Import-Module -Name Posh-SSH

foreach($ip in $ips)
{
	$body += "<h2>{0}</h2>" -f $ip

	$table = "<table>`r`n<tr><th>Server</th><th>Name</th><th>Usr_RawRsvd, GB</th><th>Snp_RawRsvd, GB</th><th>Usage Percent</th></tr>`r`n"

	$sum_total = 0
	$sum_snap = 0
	
    $sess = New-SSHSession -ComputerName $ip -Credential $ssh_creds -AcceptKey

    $res = Invoke-SSHCommand -SSHSession $sess -Command "showvv -showcols Name,Usr_RawRsvd_MB,Snp_RawRsvd_MB -p -type base"
    if($res.ExitStatus -eq 0)
    {
        foreach ($line in  $res.Output[1..($res.Output.Count-3)])
        {
            $line = $line -replace "^\s+", ""
            $line = $line -replace "\s+$", ""
            $line = $line -replace "\s+", ","
            $data = $line.Split(",")
			
			$sum_total += [int] $data[1]
			$sum_snap += [int] $data[2]
			
			if([int] $data[1] -gt 0 -and [int] $data[2] -gt 0)
			{
				$percent = ([int] $data[2] * 100 / [int] $data[1])
				
				$class = ""
				if($percent -gt 30)
				{
					$class = "error"
				}
				elseif($percent -gt 20)
				{
					$class = "warn"
				}
				$table += '<tr class="{5}"><td>{0}</td><td>{1}</td><td>{2:N0}</td><td>{3:N0}</td><td>{4:N0}%</td></tr>' -f $ip, $data[0], ([int] $data[1] / 1024), ([int] $data[2] / 1024), $percent, $class
			}
        }
    }

    Remove-SSHSession -SSHSession $sess | Out-Null

	if($sum_total -gt 0)
	{
		$percent = ($sum_snap * 100 / $sum_total)
		
		$class = ""
		if($percent -gt 30)
		{
			$class = "error"
		}
		elseif($percent -gt 20)
		{
			$class = "warn"
		}
		$table += '<tr class="{5}"><th>{0}</th><th>{1}</th><th>{2:N0}</th><th>{3:N0}</th><th>{4:N0}%</th></tr>' -f $ip, "Total", ($sum_total / 1024), ($sum_snap / 1024), $percent, $class
	}
	
	$table += "</table>"
	$body += $table
}


$body += @'
</body>
</html>
'@

Send-MailMessage -from $smtp_from -to $smtp_to -Encoding UTF8 -subject "3PAR VV snapshots used space" -bodyashtml -body $body -smtpServer $smtp_server -Credential $smtp_creds
}

Remove-PSSession $session
