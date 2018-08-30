$smtp_creds = New-Object System.Management.Automation.PSCredential ("", (ConvertTo-SecureString "" -AsPlainText -Force))

$smtp_from = "orchestrator@contoso.com"
$smtp_to = "admin@contoso.com"
$smtp_server = "smtp.contoso.com"

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
'@


$servers = @("rc1-hv-01.contoso.com", "rc1-hv-02.contoso.com")
foreach($server in $servers)
{
    $sess = New-PSSession -ComputerName $server
    $body += Invoke-Command -Session $sess -ArgumentList $server -ScriptBlock {
		param([string]$server)
	    $body = @'
<h3>{0} - Get-VMReplication</h3>
<table>
<tr>
<th>Name</th>
<th>State</th>
<th>Health</th>
<th>PrimaryServer</th>
<th>ReplicaServer</th>
</tr>
'@ -f $server
        $result = Get-VMReplication

	    foreach($row in $result)
        {
            if($row.Health -eq 'Normal')
            {
		        $color = 'pass'
            }
            elseif($row.Health -eq 'Warning')
            {
		        $color = 'warn'
            }
            else
            {
		        $color = 'error'
            }

		    $body += @'
<td>{0}</td>
<td>{1}</td>
<td class="{5}">{2}</td>
<td>{3}</td>
<td>{4}</td>
</tr>
'@ -f $row.Name, $row.State, $row.Health, $row.PrimaryServer, $row.ReplicaServer, $color
	    }

	    $body += @'
</table>
<h3>{0} - Measure-VMReplication</h3>
<table>
<tr>
<th>Name</th>
<th>State</th>
<th>Health</th>
</tr>
'@ -f $server
        $result = Measure-VMReplication

	    foreach($row in $result)
        {
            if($row.Health -eq 'Normal')
            {
		        $color = 'pass'
            }
            elseif($row.Health -eq 'Warning')
            {
		        $color = 'warn'
            }
            else
            {
		        $color = 'error'
            }

		    $body += @'
<td>{0}</td>
<td>{1}</td>
<td class="{3}">{2}</td>
</tr>
'@ -f $row.Name, $row.State, $row.Health, $color
	    }

	    $body += @'
</table>
<h3>{0} - Free Space</h3>
<table>
<tr>
<th>Root</th>
<th>Used</th>
<th>Free</th>
</tr>
'@ -f $server

        $result = Get-PSDrive -PSProvider FileSystem

	    foreach($row in $result)
        {
		    $body += @'
<tr>
<td>{0}</td>
<td>{1} GB</td>
<td>{2} GB</td>
</tr>
'@ -f $row.Root, ([math]::round($row.Used /1Gb, 2)), ([math]::round($row.Free /1Gb, 2))
	    }

	    $body += @'
</table>
'@

	    return $body
    }
    Remove-PSSession -Session $sess
}


$body += @'
</body>
</html>
'@

Send-MailMessage -from $smtp_from -to $smtp_to -Encoding UTF8 -subject "VM Replication status" -bodyashtml -body $body -smtpServer $smtp_server -Credential $smtp_creds
