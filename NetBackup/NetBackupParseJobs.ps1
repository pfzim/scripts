$smtp_from = "orchestrator@contoso.com"
$smtp_to = "admin@contoso.com"
$smtp_server = "smtp.contoso.com"

$smtp_creds = New-Object System.Management.Automation.PSCredential ("domain\smtp_login", (ConvertTo-SecureString "Passw0rd" -AsPlainText -Force))

$ErrorActionPreference = "Stop"

$exclude = Get-Content -Path "c:\scripts\error-exclude-list.txt"

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
<h1>NetBackup jobs finished with <span class="error">errors</span></h1>
<table>
<tr><th>Date</th><th>Job ID</th><th>Client</th><th>Policy</th><th>Schedule</th><th>Exit code</th><th>Message</th></tr>
'@

try
{
    $data = & 'C:\Program Files\Veritas\NetBackup\bin\admincmd\bperror.exe' -backstat -hoursago 25
}
catch
{
    $data = @()
}

$clients = @()

foreach($row in $data)
{
    if($row -match "\s(\d+)$")
    {
        if($matches[1] -gt 0)
        {
            if($row -match "^(\d+) (?:[^\s]+\s){4}(\d+) (-?\d+) .* CLIENT ([^\s]+)\s+POLICY ([^\s]+)\s+SCHED ([^\s]+)\s+EXIT STATUS (\d+) (.+) VBRF")
            {
	            if($exclude -eq $matches[1])
	            {
		            continue
	            }

                $body += ("<tr><td>" + ((Get-Date "1970-01-01 00:00:00.000Z") + ([TimeSpan]::FromSeconds($matches[1]))).ToString("dd.MM.yyyy HH:mm") + "</td><td>" + $matches[3] + "/" + $matches[2] + "</td><td>" + $matches[4] + "</td><td>" + $matches[5] + "</td><td>" + $matches[6] + "</td><td>" + $matches[7] + "</td><td>" + $matches[8] + "</td></tr>")
            }
            else
            {
                $body += ("<tr><td colspan=7>" + $row + "</td></tr>")
            }
        }
    }
}

$body += @'
</table>
</body>
</html>
'@

Send-MailMessage -from $smtp_from -to $smtp_to -Encoding UTF8 -subject "NetBackup jobs finished with errors" -bodyashtml -body $body -smtpServer $smtp_server -Credential $smtp_creds
