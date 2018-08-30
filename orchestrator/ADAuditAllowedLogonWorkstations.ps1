$smtp_from = "orchestrator@contoso.com"
$smtp_to = @("Pavel.Koveshnikov@contoso.com", "Aleksandr.Panfilov@contoso.com", "Aleksander.Prokin@contoso.com")
$smtp_сс = "admin@contoso.com"
$smtp_creds = New-Object System.Management.Automation.PSCredential ("", (ConvertTo-SecureString "" -AsPlainText -Force))
$smtp_server = "smtp.contoso.com"

$body = @'
<html>
<head>
	<meta http-equiv="Content-Type" content="text/html; charset=utf-8">
	<style type="text/css">
		body{font-family: Courier New; font-size: 9pt;}
		h1{font-size: 16px;}
		h2{font-size: 14px;}
		h3{font-size: 12px;}
		table{border: 1px solid black; border-collapse: collapse; font-size: 8pt;}
		th{border: 1px solid black; background: #dddddd; padding: 5px; color: #000000;}
		td{border: 1px solid black; padding: 5px; }
	</style>
</head>
<body>
<h>Учётные записи с неустновленным либо неправильно установленным параметром входа на рабочие станции</h1>
<table>
<tr>
<th>Name</th>
<th>Workstations</th>
</tr>
'@

$count = 0
$users = Get-ADUser -Filter * -Properties LogonWorkstations -SearchBase "OU=Магазины,OU=Company,DC=contoso,DC=com"
foreach($user in $users)
{
    $user_name = $user.SamAccountName
    if($user_name -match '^\d{6}k?$')
    {
        $update = 0
        $comps = @()
        if(!$user.LogonWorkstations)
        {
			$count++
			$body += @'
<tr>
<td>{0}</td>
<td></td>
</tr>
'@ -f $user_name
		}
		else
		{
			$filter = ('^'+$user_name[0]+$user_name[1]+'-'+$user_name[2]+$user_name[3]+$user_name[4]+$user_name[5]+'-\d+$')
            $comps += $user.LogonWorkstations -split ','
			$failed_comps = @()
			foreach($comp in $comps)
			{
				if($comp -notmatch $filter)
				{
					$failed_comps += $comp
				}
			}

			if($failed_comps.Count -gt 0)
			{
				$count++
				$body += @'
<tr>
<td>{0}</td>
<td>{1}</td>
</tr>
'@ -f $user_name, ($failed_comps -join ', ')
			}
        }
    }
}

$body += @'
</table>
<p>Всего: {0}</p>
</body>
</html>
'@ -f $count

Send-MailMessage -from $smtp_from -to $smtp_to -cc $smtp_cc -Encoding UTF8 -subject "Allowed workstations for logon" -bodyashtml -body $body -smtpServer $smtp_server -Credential $smtp_creds
