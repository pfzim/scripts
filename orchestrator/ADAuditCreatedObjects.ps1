$username = "contoso.com\robot"
$password = "password"

$ChangeDate = (Get-Date).AddDays(-1)

$body = @'
<html>
<head>
<meta http-equiv="Content-Type" content="text/html; charset=utf-8"></head>
<style>
	BODY{font-family: Tahoma; font-size: 8pt;}
	H1{font-size: 16px;}
	H2{font-size: 14px;}
	H3{font-size: 12px;}
	TABLE{border: 1px solid black; border-collapse: collapse; font-size: 8pt;}
	TH{border: 1px solid black; background: #dddddd; padding: 5px; color: #000000;}
	TD{border: 1px solid black; padding: 5px; }
	</style>
	<body>
	<h1 align="center">Created objects in AD</h1>
<table>
<tr>
<td>Name</td>
<td>SamAccountName</td>
<td>Type</td>
<td>Date</td>
<td>Owner</td>
</tr>
'@

$objects = Get-ADObject -Filter {whenCreated -gt $ChangeDate} -Properties SamAccountName,Created
if(!$objects)
{
	exit
}

$objects | %{ 
if($_.ObjectClass -ne "printQueue")
{
$body += @'
<tr>
<td>{0}</td>
<td>{1}</td>
<td>{2}</td>
<td>{3}</td>
<td>{4}</td>
</tr>
'@ -f $_.Name, $_.SamAccountName, $_.ObjectClass, $_.Created, (Get-Acl -Path ("AD:"+$_.DistinguishedName)).Owner
}
}

$body += @'
</table>
</body>
</html>
'@

$secstr = New-Object -TypeName System.Security.SecureString
$password.ToCharArray() | ForEach-Object {$secstr.AppendChar($_)}
$cred = new-object -typename System.Management.Automation.PSCredential -argumentlist $username, $secstr

Send-MailMessage -from "scanners@contoso.com" -to "admin@contoso.com" -Encoding UTF8 -subject "AD report created objects" -bodyashtml -body $body -smtpServer smtp.contoso.com -Credential $cred
