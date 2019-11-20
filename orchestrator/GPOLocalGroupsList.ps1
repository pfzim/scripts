#  GPO list entries from Local Groups

$global:mail = ''

$smtp_creds = New-Object System.Management.Automation.PSCredential ('', (ConvertTo-SecureString '' -AsPlainText -Force))

$smtp_to = @("admin@contoso.com")
$smtp_server = "smtp.contoso.com"

if($global:mail)
{
	$smtp_to += @($global:mail)
}

$global:gpo_path = '\\contoso.com\SYSVOL\contoso.com\Policies\{74D81F96-AC85-4F56-A914-B63BE6C4E6AD}'

$ErrorActionPreference = 'Stop'

$global:result = 0
$global:error_msg = ''
$global:table = ''

function main()
{
	try
	{
		[xml] $xml = Get-Content -Path ('{0}\Machine\Preferences\Groups\Groups.xml' -f $global:gpo_path)
	}
	catch
	{
		$global:result = 1
		$global:error_msg = 'Ошибка открытия политики: {0}' -f $_.Exception.Message
		return
	}

	$count = 0
	
	try
	{
		# List entries
		
		$global:table = '<table>'
		$global:table +=  '<tr><th>Login</th><th>Computer</th></tr>'
		
		foreach($group in $xml.Groups.Group)
		{
			$global:table +=  '<tr><td>{0}</td><td>{1}</td></tr>' -f ($group.Properties.Members.Member.name -join '; '), ($group.Filters.FilterComputer.name -join '; ')
		}
		
		$global:table += '</table>'
	}
	catch
	{
		$global:result = 1
		$global:error_msg = 'Ошибка чтения из политики: {0}' -f $_.Exception.Message
		return
	}
}

main

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

$body += '<h2>Список предоставленных прав локального администратора на ПК</h2>'
$body += $global:table
$body += $global:error_msg

$body += @'
</body>
</html>
'@

try
{
	Send-MailMessage -from "orchestrator@contoso.com" -to $smtp_to -Encoding UTF8 -subject "Список предоставленных прав локального администратора на ПК" -bodyashtml -body $body -smtpServer $smtp_server -Credential $smtp_creds
}
catch
{
	$global:result = 1
	$global:error_msg += ("Ошибка отправки письма (" + $_.Exception.Message + ");`r`n")
}
