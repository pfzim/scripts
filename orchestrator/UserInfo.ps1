# Query user information from AD and Exchange

$global:login = ''
$global:to = ''

$global:exch_creds = New-Object System.Management.Automation.PSCredential ('', (ConvertTo-SecureString '' -AsPlainText -Force))
#$global:smtp_creds = New-Object System.Management.Automation.PSCredential ('', (ConvertTo-SecureString '' -AsPlainText -Force))

$ErrorActionPreference = 'Stop'

. c:\orchestrator\settings\config.ps1

$global:smtp_to = @($global:g_config.admin_email)

if($global:to)
{
	$global:smtp_to += @($global:to)
}

$global:smtp_to = $global:smtp_to -join ','

$global:result = 0
$global:error_msg = ''
$global:body = ''
$global:subject = ''

function main()
{
	trap
	{
		$global:result = 1
		$global:error_msg += ("Критичная ошибка: {0}`r`n`r`nПроцесс прерван!`r`n" -f $_.Exception.Message);
		return;
	}

	# Проверка корректности заполнения полей

	if($global:login -eq '')
	{
		$global:result = 1
		$global:error_msg = 'Ошибка: Не корректно заполнены обязательные поля'
		return
	}

	# Получение информации
	
	$attributes = @('DistinguishedName' ,'msDS-UserPasswordExpiryTimeComputed' ,'PasswordExpired' ,'PasswordNeverExpires' ,'CN' ,'displayName' ,'sn' ,'Surname' ,'Initials' ,'GivenName' ,'Name' ,'Title' ,'mail' ,'AccountExpirationDate' ,'Enabled' ,'LockedOut' ,'telephoneNumber' ,'Company' ,'pwdLastSet' ,'lastLogon' ,'lastLogonTimestamp' ,'msRTCSIP-PrimaryUserAddress' ,'msRTCSIP-UserEnabled' ,'extensionAttribute1' ,'LogonWorkstations' ,'mobile')

	$user_info = $null
	try
	{
		$user_info = Get-ADUser -Identity $global:login -Properties $attributes
	}
	catch
	{
		$user_info = $null
	}

	# Попытка поиска по почтовому адресу
	if(!$user_info -and $global:login -match '.*@.*\..*')
	{
		try
		{
			$user_info = Get-ADUser -LDAPFilter ('(mail={0})' -f $global:login) -Properties $attributes
		}
		catch
		{
			$user_info = $null
		}

		$global:login = $user_info.SamAccountName
	}

	if(!$user_info)
	{
		$global:result = 1
		$global:error_msg = 'Пользователь не найден!'
		return
	}
	
	$lastLogon = 0
	$lastLogonDC = ''
	try
	{
		$controllers = Get-ADDomainController -Filter {Name -like '*'}
	}
	catch
	{
		$global:result = 1
		$global:error_msg += "Ошибка получения списка контроллеров домена: {0}`r`n" -f $_.Exception.Message
	}
	
	foreach($controller in $controllers)
	{
		try
		{
			$u = Get-ADUser -Identity $global:login -Server $controller.HostName -Properties lastLogon
		}
		catch
		{
			$global:result = 1
			$global:error_msg += "Ошибка опроса контроллера домена на предмет получения lastLogon: {1} {0}`r`n" -f $_.Exception.Message, $controller.HostName
		}
		
		if($u.lastLogon -gt $lastLogon)
		{
			$lastLogon = $u.lastLogon
			$lastLogonDC = $controller.Name
		}
	}

	try
	{
		$user_groups = Get-ADGroup -LDAPFilter ("(member:1.2.840.113556.1.4.1941:=" + $user_info.DistinguishedName + ")") | Select-Object -expand Name | Sort-Object Name
	}
	catch
	{
		$global:result = 1
		$global:error_msg += "Ошибка получения списка групп в которых состоит пользователь: {0}`r`n" -f $_.Exception.Message
	}

	try
	{
		$session = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri $global:g_config.exch_conn_uri -Credential $global:exch_creds -Authentication Basic
		Import-PSSession $session

		$mail_box = $null
		try
		{
			$mail_box = Get-Mailbox $global:login
		}
		catch
		{
			$mail_box = $null
			$global:result = 1
			$global:error_msg += "У пользователя нет почтового ящика: {0}`r`n" -f $_.Exception.Message
		}

		if($mail_box)
		{
			try
			{
				$mail_info = Get-CASMailbox $global:login
			}
			catch
			{
				$global:result = 1
				$global:error_msg += "Ошибка Get-CASMailbox: {0}`r`n" -f $_.Exception.Message
			}

			try
			{
				$mail_stats = Get-MailboxStatistics $global:login
			}
			catch
			{
				$global:result = 1
				$global:error_msg += "Ошибка Get-MailboxStatistics: {0}`r`n" -f $_.Exception.Message
			}
			try
			{
				$mail_devices = Get-MobileDeviceStatistics -Mailbox $global:login
			}
			catch
			{
				$global:result = 1
				$global:error_msg += "Ошибка Get-MobileDeviceStatistics: {0}`r`n" -f $_.Exception.Message
			}

			$mail_arch = $null
			if($mail_box.ArchiveState -ne 'None')
			{
				try
				{
					$mail_arch = Get-MailboxStatistics $global:login -Archive
				}
				catch
				{
					$global:result = 1
					$global:error_msg += "Ошибка Get-MailboxStatistics: {0}`r`n" -f $_.Exception.Message
				}
			}

			try
			{
				$mail_perm = $mail_box | Get-MailboxPermission
			}
			catch
			{
				$global:result = 1
				$global:error_msg += "Ошибка Get-MailboxPermission: {0}`r`n" -f $_.Exception.Message
			}
			try
			{
				$mail_sendas = $mail_box | Get-ADPermission | where {$_.ExtendedRights -like 'Send*'}
			}
			catch
			{
				$global:result = 1
				$global:error_msg += "Ошибка Get-ADPermission: {0}`r`n" -f $_.Exception.Message
			}
		}
	}
	catch
	{
		$global:result = 1
		$global:error_msg += "Ошибка подключения к Exchange: {0}`r`n" -f $_.Exception.Message
	}
	
	$global:subject = 'User information: {0} ({1})' -f $user_info.SamAccountName, $user_info.Name

	$global:body = @'
				<h1>User information</h1>
			<table>
			<tr>
			<th>Attribute</th>
			<th>Value</th>
			</tr>
'@

	$global:body += ("<tr><td>SamAccountName:</td><td>" + $user_info.SamAccountName + "</td></tr>")
	$global:body += ("<tr><td>UserPrincipalName:</td><td>" + $user_info.UserPrincipalName + "</td></tr>")
	$global:body += ("<tr><td>DistinguishedName:</td><td>" + $user_info.DistinguishedName+ "</td></tr>")
	$global:body += ("<tr><td>CN:</td><td>" + $user_info.CN + "</td></tr>")
	$global:body += ("<tr><td>DisplayName:</td><td>" + $user_info.DisplayName + "</td></tr>")
	$global:body += ("<tr><td>Name:</td><td>" + $user_info.Name + "</td></tr>")
	$global:body += ("<tr><td>Surname:</td><td>" + $user_info.Surname + "</td></tr>")
	$global:body += ("<tr><td>GivenName:</td><td>" + $user_info.GivenName + "</td></tr>")
	$global:body += ("<tr><td>Initials:</td><td>" + $user_info.Initials + "</td></tr>")
	$global:body += ("<tr><td>sn:</td><td>" + $user_info.sn + "</td></tr>")
	$global:body += ("<tr><td>SID:</td><td>" + $user_info.SID + "</td></tr>")

	if($user_info.AccountExpirationDate)
	{
		if($user_info.AccountExpirationDate -gt (Get-Date))
		{
			$global:body += ("<tr><td>AccountExpirationDate:</td><td class='pass'>"+$user_info.AccountExpirationDate.ToString("dd.MM.yyyy HH:mm")+"</td></tr>")
		}
		else
		{
			$global:body += ("<tr><td>AccountExpirationDate:</td><td class='error'>"+$user_info.AccountExpirationDate.ToString("dd.MM.yyyy HH:mm")+"</td></tr>")
		}
	}
	else
	{
		$global:body += "<tr><td>AccountExpirationDate:</td><td class='pass'>Never</td></tr>"
	}

	if($user_info.Enabled)
	{
		$global:body += "<tr><td>Account enabled:</td><td class='pass'>Yes</td></tr>"
	}
	else
	{
		$global:body += "<tr><td>Account enabled:</td><td class='error'>No</td></tr>"
	}

	if($user_info.LockedOut)
	{
		$global:body += "<tr><td>Account locked:</td><td class='error'>Yes</td></tr>"
	}
	else
	{
		$global:body += "<tr><td>Account locked:</td><td class='pass'>No</td></tr>"
	}

	if($user_info.PasswordNeverExpires)
	{
		$global:body += ("<tr><td>Password expired:</td><td class='pass'>Never</td></tr>")
	}
	elseif($user_info.PasswordExpired)
	{
		$global:body += ("<tr><td>Password expired:</td><td class='error'>" + [datetime]::FromFileTime($user_info.'msDS-UserPasswordExpiryTimeComputed').ToString("dd.MM.yyyy HH:mm") + "</td></tr>")
	}
	else
	{
		$global:body += ("<tr><td>Password expired:</td><td class='pass'>" + [datetime]::FromFileTime($user_info.'msDS-UserPasswordExpiryTimeComputed').ToString("dd.MM.yyyy HH:mm") + "</td></tr>")
	}

	if($lastLogon)
	{
		$global:body += ("<tr><td>lastLogon (" + $lastLogonDC + "):</td><td>" + [datetime]::FromFileTime($lastLogon).ToString("dd.MM.yyyy HH:mm") + "</td></tr>")
	}
	if($user_info.lastLogonTimestamp)
	{
		$global:body += ("<tr><td>lastLogonTimestamp:</td><td>" + [datetime]::FromFileTime($user_info.lastLogonTimestamp).ToString("dd.MM.yyyy HH:mm") + "</td></tr>")
	}
	if($user_info.pwdLastSet)
	{
		$global:body += ("<tr><td>pwdLastSet:</td><td>" + [datetime]::FromFileTime($user_info.pwdLastSet).ToString("dd.MM.yyyy HH:mm") + "</td></tr>")
	}
	$global:body += ("<tr><td>UUID:</td><td>" + $user_info.extensionAttribute1 + "</td></tr>")

	$global:body += @'
		</table>
			<h1>Contact information</h1>
		<table>
		<tr>
		<th>Attribute</th>
		<th>Value</th>
		</tr>
'@

	$global:body += ("<tr><td>Company:</td><td>" + $user_info.Company + "</td></tr>")
	$global:body += ("<tr><td>Title:</td><td>" + $user_info.Title + "</td></tr>")
	$global:body += ("<tr><td>telephoneNumber:</td><td>" + $user_info.telephoneNumber + "</td></tr>")
	$global:body += ("<tr><td>Mobile:</td><td>" + $user_info.mobile + "</td></tr>")
	$global:body += ("<tr><td>mail:</td><td>" + $user_info.mail + "</td></tr>")

	$global:body += @'
		</table>
			<h1>Skype</h1>
		<table>
		<tr>
		<th>Attribute</th>
		<th>Value</th>
		</tr>
'@

	$global:body += ("<tr><td>msRTCSIP-PrimaryUserAddress:</td><td>" + $user_info.'msRTCSIP-PrimaryUserAddress' + "</td></tr>")
	if($user_info.'msRTCSIP-UserEnabled')
	{
		$global:body += "<tr><td>msRTCSIP-UserEnabled:</td><td class='pass'>Yes</td></tr>"
	}
	else
	{
		$global:body += "<tr><td>msRTCSIP-UserEnabled:</td><td class='error'>No</td></tr>"
	}

	$global:body += @'
		</table>
			<h1>Mailbox</h1>
		<table>
		<tr>
		<th>Attribute</th>
		<th>Value</th>
		</tr>
'@

	$global:body += ("<tr><td>PrimarySmtpAddress:</td><td>" + $mail_box.PrimarySmtpAddress + "</td></tr>")
	$global:body += ("<tr><td>ForwardingAddress:</td><td>" + $mail_box.ForwardingAddress + "</td></tr>")
	$global:body += ("<tr><td>ForwardingSmtpAddress:</td><td>" + $mail_box.ForwardingSmtpAddress + "</td></tr>")
	$global:body += ("<tr><td>DB:</td><td>" + $mail_box.Database + "</td></tr>")
	$global:body += ("<tr><td>Mailbox usage size:</td><td>" + $mail_stats.TotalItemSize + "</td></tr>")
	$global:body += ("<tr><td>Send and Receive Quota:</td><td>" + $mail_box.ProhibitSendReceiveQuota + "</td></tr>")
	if($mail_info.ActiveSyncEnabled)
	{
		$global:body += "<tr><td>ActiveSync status:</td><td class='pass'>Enabled</td></tr>"
	}
	else
	{
		$global:body += "<tr><td>ActiveSync status:</td><td class='error'>Disabled</td></tr>"
	}

	if($mail_arch)
	{
		$global:body += ("<tr><td>Archive usage size:</td><td>" + $mail_arch.TotalItemSize + "</td></tr>")
	}
	if($mail_box.HiddenFromAddressListsEnabled)
	{
		$global:body += "<tr><td>Show in address book:</td><td class='error'>No</td></tr>"
	}
	else
	{
		$global:body += "<tr><td>Show in address book:</td><td class='pass'>Yes</td></tr>"
	}

	$global:body += @'
		</table>
'@

	$global:body += @'
		<h1>Users with full access to the mailbox (FullAccess)</h1>
'@

	$global:body += @'
		<table>
		<tr>
		<th>Who</th>
		</tr>
'@

	$i = 0
	foreach($perm in $mail_perm)
	{
		if(!$perm.IsInherited -and !$perm.Deny -and $perm.User -ne 'NT AUTHORITY\SELF' -and $perm.AccessRights -eq 'FullAccess') 
		{
			$global:body += ("<tr><td>" + $perm.User + "</td></tr>")
			$i++
		}
	}

	if($i -eq 0)
	{
		$global:body += @'
			<tr><td colspan="5">No special permissions</td></tr>
'@
	}

	$global:body += @'
		</table>
'@

	$global:body += @'
		<h1>Users with permissions to send email from this mailbox (SendAs)</h1>
'@

	$global:body += @'
		<table>
		<tr>
		<th>Who</th>
		</tr>
'@

	$i = 0
	foreach($perm in $mail_sendas)
	{
		if(!$perm.IsInherited -and !$perm.Deny -and $perm.ExtendedRights -like '*Send-As*' -and $perm.User -ne 'NT AUTHORITY\SELF')
		{
			$global:body += ("<tr><td>" + $perm.User + "</td></tr>")
			$i++
		}
	}

	if($i -eq 0)
	{
		$global:body += @'
			<tr><td colspan="5">No special permissions</td></tr>
'@
	}

	$global:body += @'
		</table>
'@

	$global:body += @'
		<h1>Users with permissions to send email on behalf of this mailbox (Send on Behalf)</h1>
'@

	$global:body += @'
		<table>
		<tr>
		<th>Who</th>
		</tr>
'@

	$i = 0
	foreach($perm in $mail_box.GrantSendOnBehalfTo)
	{
		$global:body += ("<tr><td>" + $perm + "</td></tr>")
		$i++
	}

	if($i -eq 0)
	{
		$global:body += @'
			<tr><td colspan="5">No special permissions</td></tr>
'@
	}

	$global:body += @'
		</table>
'@

	$global:body += @'
		<h1>User devices</h1>
'@

	$global:body += @'
		<table>
		<tr>
		<th>ID</th>
		<th>OS</th>
		<th>Friendly Name</th>
		<th>Last Success Sync</th>
		<th>State</th>
		</tr>
'@

	if($mail_devices)
	{
		foreach($device in $mail_devices)
		{
			if($device.DeviceAccessState -eq "Allowed") 
			{
				$device_state = ("<span class='pass'>" + $device.DeviceAccessState + "</span>")
			}
			elseif($device.DeviceAccessState -eq "Blocked")
			{
				$device_state = ("<span class='red'>" + $device.DeviceAccessState + "</span>")
			}
			else
			{
				$device_state = ("<span class='warn'>" + $device.DeviceAccessState + "</span>")
			}
			$global:body += ("<tr><td>" + $device.DeviceID + "</td><td>" + $device.DeviceOS + "</td><td>" + $device.DeviceFriendlyName + "</td><td>" + $device.LastSuccessSync + "</td><td>" + $device_state + "</td></tr>")
		}
	}
	else
	{
	$global:body += @'
	<tr><td colspan="5">User doesn't have devices</td></tr>
'@
	}

	$global:body += @'
	</table>
'@

	$global:body += @'
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
			$global:body += ("<tr><td class='pass'>" + $group + "</td></tr>")
		}
		else
		{
			$global:body += ("<tr><td>" + $group + "</td></tr>")
		}
	}

	$global:body += @'
	</table>
	<br />
	<table>
	<tr>
	<th>Workstation allowed for logon</th>
	</tr>
'@

	if($user_info.LogonWorkstations)
	{
		$comps += $user_info.LogonWorkstations -split ','
		foreach($comp in $comps)
		{
			$global:body += ("<tr><td>" + $comp + "</td></tr>")
		}
	}
	else
	{
	$global:body += @'
	<tr><td>Workstations for logon is not defined</td></tr>
'@
	}

	$global:body += '</table>'
	try
	{
		Remove-PSSession -Session $session
	}
	catch
	{
	}

	<#
	try
	{
		Send-MailMessage -from $global:g_config.smtp_from -to $global:smtp_to -Encoding UTF8 -subject $global:subject -bodyashtml -body $global:body -smtpServer $global:g_config.smtp_server -Credential $global:smtp_creds
	}
	catch
	{
		$result = 1
		$global:error_msg += "Ошибка отправки письма: {0}`r`n" -f $_.Exception.Message
	}
	#>
}

main

if($global:result -ne 0)
{
	$global:body += "<br /><br /><pre>Детали выполнения ранбука:`r`n`r`n{0}</pre>" -f $global:error_msg
}
