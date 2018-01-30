$user_sam = ""
$exchange_uri = "http://exchange.contoso.com/powershell/"

$exchange_creds = New-Object System.Management.Automation.PSCredential ("", (ConvertTo-SecureString "" -AsPlainText -Force))
$smtp_creds = New-Object System.Management.Automation.PSCredential ("", (ConvertTo-SecureString "" -AsPlainText -Force))

$smtp_from = "orchestrator@contoso.com"
$smtp_to = "UsersAccess@contoso.com"
$smtp_cc = "admin@contoso.com"

$user_info = Get-ADUser -Identity $user_sam -Properties DistinguishedName, msDS-UserPasswordExpiryTimeComputed, PasswordExpired, PasswordNeverExpires, CN, displayName, sn, Surname, Initials, GivenName, Name, Title, mail, AccountExpirationDate, Enabled, LockedOut, telephoneNumber, Company, pwdLastSet, lastLogon, lastLogonTimestamp, msRTCSIP-PrimaryUserAddress, msRTCSIP-UserEnabled, extensionAttribute1
$user_groups = Get-ADGroup -LDAPFilter ("(member:1.2.840.113556.1.4.1941:=" + $user_info.DistinguishedName + ")") | Select-Object -expand Name | Sort-Object Name

$session = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri $exchange_uri -Credential $exchange_creds -Authentication Kerberos
Import-PSSession $session

$mail_info = Get-CASMailbox $user_sam
$mail_box = Get-Mailbox $user_sam
$mail_stats = Get-MailboxStatistics $user_sam
$mail_devices = Get-MobileDeviceStatistics -Mailbox $user_sam
$mail_arch = $null
if($mail_box.ArchiveState -ne 'None')
{
	$mail_arch = Get-MailboxStatistics $user_sam -Archive
}

$body = @'
<html>
<head>
<meta http-equiv="Content-Type" content="text/html; charset=utf-8"></head>
<style>
	BODY{font-family: Courier; font-size: 9pt;}
	H1{font-size: 16px;}
	H2{font-size: 14px;}
	H3{font-size: 12px;}
	TABLE{border: 1px solid black; border-collapse: collapse; font-size: 8pt;}
	TH{border: 1px solid black; background: #dddddd; padding: 5px; color: #000000;}
	TD{border: 1px solid black; padding: 5px; }
	.red {color: red;}
	.green {color: green;}
	.yellow {color: yellow;}
	</style>
	<body>
	<h1>User information</h1>
<table>
<tr>
<th>Attribute</th>
<th>Value</th>
</tr>
'@

$body += ("<tr><td>SamAccountName:</td><td>" + $user_info.SamAccountName + "</td></tr>")
$body += ("<tr><td>UserPrincipalName:</td><td>" + $user_info.UserPrincipalName + "</td></tr>")
$body += ("<tr><td>DistinguishedName:</td><td>" + $user_info.DistinguishedName+ "</td></tr>")
$body += ("<tr><td>CN:</td><td>" + $user_info.CN + "</td></tr>")
$body += ("<tr><td>DisplayName:</td><td>" + $user_info.DisplayName + "</td></tr>")
$body += ("<tr><td>Name:</td><td>" + $user_info.Name + "</td></tr>")
$body += ("<tr><td>Surname:</td><td>" + $user_info.Surname + "</td></tr>")
$body += ("<tr><td>GivenName:</td><td>" + $user_info.GivenName + "</td></tr>")
$body += ("<tr><td>Initials:</td><td>" + $user_info.Initials + "</td></tr>")
$body += ("<tr><td>sn:</td><td>" + $user_info.sn + "</td></tr>")
$body += ("<tr><td>SID:</td><td>" + $user_info.SID + "</td></tr>")

if($user_info.AccountExpirationDate)
{
	if($user_info.AccountExpirationDate -gt (Get-Date))
	{
		$body += ("<tr><td>AccountExpirationDate:</td><td><span class='green'>"+$user_info.AccountExpirationDate.ToString("dd.MM.yyyy HH:mm")+"</span></td></tr>")
	}
	else
	{
		$body += ("<tr><td>AccountExpirationDate:</td><td><span class='red'>"+$user_info.AccountExpirationDate.ToString("dd.MM.yyyy HH:mm")+"</span></td></tr>")
	}
}
else
{
	$body += "<tr><td>AccountExpirationDate:</td><td><span class='green'>Never</span></td></tr>"
}

if($user_info.Enabled)
{
	$body += "<tr><td>Account enabled:</td><td><span class='green'>Yes</span></td></tr>"
}
else
{
	$body += "<tr><td>Account enabled:</td><td><span class='red'>No</span></td></tr>"
}

if($user_info.LockedOut)
{
	$body += "<tr><td>Account locked:</td><td><span class='red'>Yes</span></td></tr>"
}
else
{
	$body += "<tr><td>Account locked:</td><td><span class='green'>No</span></td></tr>"
}

if($user_info.PasswordNeverExpires)
{
	$body += ("<tr><td>Password expired:</td><td><span class='green'>Never</span></td></tr>")
}
elseif($user_info.PasswordExpired)
{
	$body += ("<tr><td>Password expired:</td><td><span class='red'>" + [datetime]::FromFileTime($user_info.'msDS-UserPasswordExpiryTimeComputed').ToString("dd.MM.yyyy HH:mm") + "</span></td></tr>")
}
else
{
	$body += ("<tr><td>Password expired:</td><td><span class='green'>" + [datetime]::FromFileTime($user_info.'msDS-UserPasswordExpiryTimeComputed').ToString("dd.MM.yyyy HH:mm") + "</span></td></tr>")
}

if($user_info.lastLogon)
{
	$body += ("<tr><td>lastLogon:</td><td>" + [datetime]::FromFileTime($user_info.lastLogon).ToString("dd.MM.yyyy HH:mm") + "</td></tr>")
}
if($user_info.lastLogonTimestamp)
{
	$body += ("<tr><td>lastLogonTimestamp:</td><td>" + [datetime]::FromFileTime($user_info.lastLogonTimestamp).ToString("dd.MM.yyyy HH:mm") + "</td></tr>")
}
if($user_info.pwdLastSet)
{
	$body += ("<tr><td>pwdLastSet:</td><td>" + [datetime]::FromFileTime($user_info.pwdLastSet).ToString("dd.MM.yyyy HH:mm") + "</td></tr>")
}
$body += ("<tr><td>UUID:</td><td>" + $user_info.extensionAttribute1 + "</td></tr>")

$body += @'
</table>
	<h1>Contact information</h1>
<table>
<tr>
<th>Attribute</th>
<th>Value</th>
</tr>
'@

$body += ("<tr><td>Company:</td><td>" + $user_info.Company + "</td></tr>")
$body += ("<tr><td>Title:</td><td>" + $user_info.Title + "</td></tr>")
$body += ("<tr><td>telephoneNumber:</td><td>" + $user_info.telephoneNumber + "</td></tr>")
$body += ("<tr><td>mail:</td><td>" + $user_info.mail + "</td></tr>")

$body += @'
</table>
	<h1>Skype</h1>
<table>
<tr>
<th>Attribute</th>
<th>Value</th>
</tr>
'@

$body += ("<tr><td>msRTCSIP-PrimaryUserAddress:</td><td>" + $user_info.'msRTCSIP-PrimaryUserAddress' + "</td></tr>")
if($user_info.'msRTCSIP-UserEnabled')
{
	$body += "<tr><td>msRTCSIP-UserEnabled:</td><td><span class='green'>Yes</span></td></tr>"
}
else
{
	$body += "<tr><td>msRTCSIP-UserEnabled:</td><td><span class='red'>No</span></td></tr>"
}

$body += @'
</table>
	<h1>Mailbox</h1>
<table>
<tr>
<th>Attribute</th>
<th>Value</th>
</tr>
'@

$body += ("<tr><td>PrimarySmtpAddress:</td><td>" + $mail_box.PrimarySmtpAddress + "</td></tr>")
$body += ("<tr><td>ForwardingAddress:</td><td>" + $mail_box.ForwardingAddress + "</td></tr>")
$body += ("<tr><td>ForwardingSmtpAddress:</td><td>" + $mail_box.ForwardingSmtpAddress + "</td></tr>")
$body += ("<tr><td>DB:</td><td>" + $mail_box.Database + "</td></tr>")
$body += ("<tr><td>Mailbox usage size:</td><td>" + $mail_stats.TotalItemSize + "</td></tr>")
$body += ("<tr><td>Send and Receive Quota:</td><td>" + $mail_box.ProhibitSendReceiveQuota + "</td></tr>")
if($mail_info.ActiveSyncEnabled)
{
	$body += "<tr><td>ActiveSync status:</td><td><span class='green'>Enabled</span></td></tr>"
}
else
{
	$body += "<tr><td>ActiveSync status:</td><td><span class='red'>Disabled</span></td></tr>"
}

if($mail_arch)
{
	$body += ("<tr><td>Archive usage size:</td><td>" + $mail_arch.TotalItemSize + "</td></tr>")
}

$body += @'
</table>
'@

$body += @'
	<h1>User devices</h1>
'@

if($mail_devices)
{
$body += @'
<table>
<tr>
<th>ID</th>
<th>OS</th>
<th>Friendly Name</th>
<th>Last Success Sync</th>
<th>State</th>
</tr>
'@

foreach($device in $mail_devices)
{
	if($device.DeviceAccessState -eq "Allowed") 
	{
		$device_state = ("<span class='green'>" + $device.DeviceAccessState + "</span>")
	}
	elseif($device.DeviceAccessState -eq "Blocked")
	{
		$device_state = ("<span class='red'>" + $device.DeviceAccessState + "</span>")
	}
	else
	{
		$device_state = ("<span class='yellow'>" + $device.DeviceAccessState + "</span>")
	}
	$body += ("<tr><td>" + $device.DeviceID + "</td><td>" + $device.DeviceOS + "</td><td>" + $device.DeviceFriendlyName + "</td><td>" + $device.LastSuccessSync + "</td><td>" + $device_state + "</td></tr>")
}
}
else
{
$body += @'
<p>User doesn't have devices</p>
'@
}

$body += @'
</table>
'@

$body += @'
<br />
<table>
<tr>
<th>User groups</th>
</tr>
'@

foreach($group in $user_groups)
{
	if($group -eq "VPN Users") 
	{
		$body += ("<tr><td><span class='green'>" + $group + "</span></td></tr>")
	}
	else
	{
		$body += ("<tr><td>" + $group + "</td></tr>")
	}
}

$body += @'
</table>
</body>
</html>
'@

Remove-PSSession -Session $session

Send-MailMessage -from $smtp_from -to $smtp_to -cc $smtp_cc -Encoding UTF8 -subject ("User information: " + $user_info.SamAccountName + " (" + $user_info.Name + ")") -bodyashtml -body $body -smtpServer smtp.contoso.com -Credential $smtp_creds
