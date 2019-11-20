# 3PAR VV UsrCPG SnpCPG compare

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
	<h1>Отчёт по сравнению VV на 3PAR</h1>
'@

Import-Module -Name Posh-SSH

foreach($ip in $ips)
{
	$body += "<h2>{0}</h2>" -f $ip

    $body += @'
<table>
<tr>
<th>Name</th>
<th>UsrCPG</th>
<th>SnpCPG</th>
</tr>
'@

    $sess = New-SSHSession -ComputerName $ip -Credential $ssh_creds -AcceptKey

    $res = Invoke-SSHCommand -SSHSession $sess -Command "showvv -showcols Name,UsrCPG,SnpCPG -p -prov tpvv -type base"
    if($res.ExitStatus -eq 0)
    {
        foreach ($line in  $res.Output[1..($res.Output.Count-3)])
        {
            $line = $line -replace "^\s+", ""
            $line = $line -replace "\s+$", ""
            $line = $line -replace "\s+", ","
            $data = $line.Split(",")

            if($data[1] -ne $data[2])
            {
                $body += "<tr><td>{0}</td><td>{1}</td><td>{2}</td></tr>" -f $data[0], $data[1], $data[2]
            }
        }
    }

    Remove-SSHSession -SSHSession $sess | Out-Null

    $body += '</table>'
}

$body += @'
</body>
</html>
'@

Send-MailMessage -from $smtp_from -to $smtp_to -Encoding UTF8 -subject "3PAR VV UsrCPG SnpCPG compare" -bodyashtml -body $body -smtpServer $smtp_server -Credential $smtp_creds
}

Remove-PSSession $session
