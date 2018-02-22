$smtp_creds = New-Object System.Management.Automation.PSCredential ("", (ConvertTo-SecureString "" -AsPlainText -Force))

$data = Import-CSV -Path "\\fileserver\Common\Orchestrator\UpdateUserInfo.csv" -Encoding Default
Remove-Item -Path "\\fileserver\Common\Orchestrator\UpdateUserInfo.csv" -Force

$out = ""

foreach($row in $data)
{
	try
	{
		$user = Get-ADUser $row.SamAccountName -Properties CN, displayName, sn, Surname, Initials, GivenName, Name, Title, Company, extensionAttribute1
	}
	catch
	{
		$out += ("<p class=`"red`"><b>{0}</b> - User not found</p>" -f $row.SamAccountName, $_.Exception.Message)
		continue
	}

	if($user)
	{
		$out += ("<p><b>{0}</b></p>" -f $user.SamAccountName)
		$out += "<p>"
		$out += ("{0} -> <span class=`"green`">{1}</span><br>" -f $user.CN, $row.DisplayName)
		$out += ("{0} -> <span class=`"green`">{1}</span><br>" -f $user.displayName, $row.DisplayName)
		$out += ("{0} -> <span class=`"green`">{1}</span><br>" -f $user.Surname, $row.Sn)
		$out += ("{0} -> <span class=`"green`">{1}</span><br>" -f $user.GivenName, $row.GivenName)
		$out += ("{0} -> <span class=`"green`">{1}</span><br>" -f $user.Title, $row.Title)
		$out += ("{0} -> <span class=`"green`">{1}</span><br>" -f $user.Company, $row.Company)
		$out += ("{0} -> <span class=`"green`">{1}</span><br>" -f $user.extensionAttribute1, $row.extensionAttribute1)
		$out += "</p>"

		try
		{
			Set-ADUser -Identity $user -GivenName $row.GivenName -Surname $row.Sn -DisplayName $row.DisplayName -Company $row.Company -Department $row.Department -Title $row.Title -Replace @{"extensionAttribute1" = $row.extensionAttribute1} -Clear Initials
		}
		catch
		{
			$out += ("<p class=`"red`"><b>{0}</b> - Error Set-ADUser: {1}</p>" -f $row.SamAccountName, $_.Exception.Message)
			continue
		}

		try
		{
			Rename-ADObject -Identity $user -NewName $row.DisplayName
		}
		catch
		{
			$out += ("<p class=`"red`"><b>{0}</b> - Error Rename-ADObject: {1}</p>" -f $row.SamAccountName, $_.Exception.Message)
			continue
		}
	}
	else
	{
		$out += ("<p class=`"red`"><b>{0}</b> - User not found</p>" -f $row.SamAccountName)
	}
}

$body = @'
<html>
<head>
<meta http-equiv="Content-Type" content="text/html; charset=utf-8"></head>
<style>
	body{font-family: courier; font-size: 9pt;}
	h1{font-size: 16px;}
	h2{font-size: 14px;}
	h3{font-size: 12px;}
	table{border: 1px solid black; border-collapse: collapse; font-size: 8pt;}
	th{border: 1px solid black; background: #dddddd; padding: 5px; color: #000000;}
	td{border: 1px solid black; padding: 5px; }
	.red {color: red;}
	.green {color: green;}
	.yellow {color: yellow;}
</style>
<body>
<h1>Updated users info</h1>
'@

$body += $out

$body += @'
</body>
</html>
'@

Send-MailMessage -from "orchestrator@constoso.com" -to "admin@contoso.com" -Encoding UTF8 -subject "Batch users info update" -bodyashtml -body $body -smtpServer smtp.contoso.com -Credential $smtp_creds
