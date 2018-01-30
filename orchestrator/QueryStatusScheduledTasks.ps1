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
	<h1 align="center">Статус заданий на клонирование дисков</h1>
<table>
<tr>
<th>TaskName</th>
<th>Status</th>
<th>Last run</th>
</tr>
'@

$sess = New-PSSession -ComputerName "brc-ssmc-01"
$body += Invoke-Command -Session $sess -ScriptBlock {
	$body = ""
    $tasks = Get-ScheduledTask -TaskName "ALB_UT_Clone", "ALB_UT to ALB_UT_Test_01", "ALB_UT to ALB_UT_Test_02", "ALB_BP_KORP_Clone", "ALB_ZUP_Clone", "ALB_UPRHOLD"
	if(!$tasks)
	{
			$body = @'
<tr>
<td>List empty</td>
<td>!</td>
</tr>
'@
	}
	else
	{
		$tasks | %{ 
			$body += @'
<tr>
<td>{0}</td>
<td>{1}</td>
<td>{2}</td>
</tr>
'@ -f $_.TaskName, $_.State, (Get-ScheduledTaskInfo -TaskName $_.TaskName).LastRunTime
		}
	}
	return $body
}
Remove-PSSession -Session $sess

$body += @'
</table>
</body>
</html>
'@

$username = ""
$password = ""
$secstr = New-Object -TypeName System.Security.SecureString
$password.ToCharArray() | ForEach-Object {$secstr.AppendChar($_)}
$cred = new-object -typename System.Management.Automation.PSCredential -argumentlist $username, $secstr

Send-MailMessage -from "orchestrator@contoso.com" -to "systems@contoso.com" -Cc "admin@contoso.com" -Encoding UTF8 -subject "Статус заданий на клонирование дисков" -bodyashtml -body $body -smtpServer smtp.contoso.com -Credential $cred
