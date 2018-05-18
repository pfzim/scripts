$smtp_creds = New-Object System.Management.Automation.PSCredential ("", (ConvertTo-SecureString "" -AsPlainText -Force))

$smtp_from = "orchestrator@contoso.com"
$smtp_to = "admin@contoso.com"
$smtp_server = "smtp.contoso.com"

$ChangeDate = (Get-Date).AddDays(-1)

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
	<h1>Created objects in AD</h1>
<table>
<tr>
<td>Name</td>
<td>SamAccountName</td>
<td>Type</td>
<td>Date</td>
<td>Owner</td>
</tr>
'@

$objects = @(Get-ADObject -Filter {whenCreated -gt $ChangeDate} -Properties SamAccountName, Created, userAccountControl)
$comps = @(Get-ADComputer -LDAPFilter "((userAccountControl:1.2.840.113556.1.4.803:=32))")
$users = @(Get-ADUser -LDAPFilter "((userAccountControl:1.2.840.113556.1.4.803:=32))")
$comps_count = $comps.Count
$users_count = $users.Count

if(($objects.Count -le 0) -and ($comps_count -le 0) -and ($users_count -le 0)) 
{
	Exit 0
}

foreach($object in $objects)
{
	if($object.ObjectClass -ne "printQueue")
	{
		$owner = (Get-Acl -Path ("AD:"+$object.DistinguishedName)).Owner
		
		if(($object.userAccountControl -band 0x020) -ne 0)
		{
			$body += '<tr class="error">'
		}
		elseif($owner -match "_adm$")
		{
			$body += '<tr class="warn">'
		}
		else
		{
			$body += '<tr>'
		}

		$body += @'
<td>{0}</td>
<td>{1}</td>
<td>{2}</td>
<td>{3}</td>
<td>{4}</td>
</tr>
'@ -f $object.Name, $object.SamAccountName, $object.ObjectClass, $object.Created, $owner
	}
}

$body += '</table>'

#if(($comps_count -gt 0) -or ($users_count -gt 0)) 
#{
	$body += @'
<p>Найдено <b>{0}</b> УЗ пользователей и <b>{1}</b> УЗ компьютеров с возможностью установки пустого пароля</p>
'@ -f $users_count, $comps_count
#}

$users = Get-ADUser -Filter * -Properties LogonWorkstations

$body += @'
<h1>Invalid logon workstations</h1>
<table>
<tr>
<td>Name</td>
<td>LogonWorkstations</td>
</tr>
'@

foreach($user in $users)
{
    $user_name = $user.SamAccountName
    if($user_name -match '\d{6}k?')
    {
        if($user.LogonWorkstations)
        {
            $comps = $user.LogonWorkstations -split ','
            foreach($comp in $comps)
            {
                if($comp -notmatch ($user_name[0]+$user_name[1]+'-'+$user_name[2]+$user_name[3]+$user_name[4]+$user_name[5]+'-\d'))
                {
					$body += @'
<tr>
<td>{0}</td>
<td>{1}</td>
</tr>
'@ -f $user_name, $user.LogonWorkstations
                }
            }
        }
    }
}

$body += '</table>'

$body += @'
</body>
</html>
'@

Send-MailMessage -from $smtp_from -to $smtp_to -Encoding UTF8 -subject "AD report created objects" -bodyashtml -body $body -smtpServer $smtp_server -Credential $smtp_creds
