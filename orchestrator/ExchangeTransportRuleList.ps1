# Exchange transport rule - print list

$global:exch_creds = New-Object System.Management.Automation.PSCredential ('', (ConvertTo-SecureString '' -AsPlainText -Force))
$global:smtp_creds = New-Object System.Management.Automation.PSCredential ('', (ConvertTo-SecureString '' -AsPlainText -Force))

$global:rules_out = @('Запрещено в интернет', 'Запрещено в интернет 2')
$global:rules_in = @('Запрещено из интернета', 'Запрещено из интернета 2')

trap
{
	$global:result = 1
	$global:error_msg += ("Критичная ошибка: {0}`r`n`r`nПроцесс прерван!`r`n" -f $_.Exception.Message);
	return;
}

$ErrorActionPreference = 'Stop'

. c:\orchestrator\settings\settings.ps1

$global:smtp_to = @($global:admin_email, $global:uib_email)

$global:result = 0
$global:error_msg = ''

function main()
{
	trap
	{
		$global:result = 1
		$global:error_msg += ("Критичная ошибка: {0}`r`n`r`nПроцесс прерван!`r`n" -f $_.Exception.Message);
		return;
	}

	try
	{
		$session = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri $global:exch_conn_uri -Credential $global:exch_creds -Authentication Basic
		Import-PSSession $session

		$address_exist = 0

		$list_out = $null
		foreach($rule in $global:rules_out)
		{
			$list_out += (Get-TransportRule -Identity $rule).SentTo
		}

		$list_in = $null
		foreach($rule in $global:rules_in)
		{
			$list_in += (Get-TransportRule -Identity $rule).From
		}
		
		Remove-PSSession -Session $session

	}
	catch
	{
		$global:result = 1
		$global:error_msg += ("Ошибка: {0}`r`n" -f $_.Exception.Message)
		return
	}

	# Отправка информационного письма

	$subject = 'List blocked e-mail addresses'

	$global:body = @'
<html>
<head>
	<meta http-equiv="Content-Type" content="text/html; charset=utf-8">
	<style>
		body {font-family: Courier New; font-size: 8pt;}
		h1 {font-size: 16px;}
		h2 {font-size: 14px;}
		h3 {font-size: 12px;}
		table {border: 1px solid black; border-collapse: collapse; font-size: 8pt;}
		th {border: 1px solid black; background: #dddddd; padding: 5px; color: #000000;}
		td {border: 1px solid black; padding: 5px; }
		.pass {background: #7FFF00;}
		.warn {background: #FFE600;}
		.error {background: #FF0000; color: #ffffff;}
	</style>
</head>
<body>
<h2>Список заблокированных адресов в интернет</h2>
<table>
<tr><th>Адрес</th></tr>
'@

	$list_out = $list_out | Sort-Object
	
	foreach($address in $list_out)
	{
		if($address -ne 'placeholder@example.org')
		{
			$global:body += '<tr><td>{0}</td></tr>' -f $address
		}
	}

	$global:body += @'
</table>
<h2>Список заблокированных адресов из интернет</h2>
<table>
<tr><th>Адрес</th></tr>
'@

	$list_in = $list_in | Sort-Object

	foreach($address in $list_in)
	{
		if($address -ne 'placeholder@example.org')
		{
			$global:body += '<tr><td>{0}</td></tr>' -f $address
		}
	}

	$global:body += @'
</table>
</body>
</html>
'@

	try
	{
		Send-MailMessage -from $global:smtp_from -to $global:smtp_to -Encoding UTF8 -subject $subject -bodyashtml -body $global:body -smtpServer $global:smtp_server -Credential $global:smtp_creds
	}
	catch
	{
		$global:result = 1
		$global:error_msg += ("Ошибка отправки информационного письма ({0});`r`n" -f $_.Exception.Message)
	}
}

main
