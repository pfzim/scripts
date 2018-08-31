$global:login = ""
$global:incident = ""

$creds = New-Object System.Management.Automation.PSCredential ("", (ConvertTo-SecureString "" -AsPlainText -Force))
$smtp_creds = New-Object System.Management.Automation.PSCredential ("", (ConvertTo-SecureString "" -AsPlainText -Force))

$smtp_to = @("helpdesk@contoso.com", "techsupport@contoso.com", "UserAccess@contoso.com")
$smtp_server = "smtp.contoso.com"

$ErrorActionPreference = "Stop"

$global:result = 1
$global:error_msg = ""

$global:body = @'
<html>
<head>
	<meta http-equiv="Content-Type" content="text/html; charset=utf-8">
	<style type="text/css">
		body {font-family: Arial; font-size: 12pt;}
	</style>
</head>
<body>
Был заблокирован пользователь:<br />
'@

Function ConvertTo-PSON($Object, [Int]$Depth = 9, [Int]$Layers = 1, [Switch]$Strict, [Version]$Version = $PSVersionTable.PSVersion) {
    $Format = $Null
    $Quote = If ($Depth -le 0) {""} Else {""""}
    $Space = If ($Layers -le 0) {""} Else {" "}
    If ($Object -eq $Null) {"`$Null"} Else {
        $Type = "[" + $Object.GetType().Name + "]"
        $PSON = If ($Object -is "Array") {
            $Format = "@(", ",$Space", ")"
            If ($Depth -gt 1) {For ($i = 0; $i -lt $Object.Count; $i++) {ConvertTo-PSON $Object[$i] ($Depth - 1) ($Layers - 1) -Strict:$Strict}}
        } ElseIf ($Object -is "Xml") {
            $Type = "[Xml]"
            $String = New-Object System.IO.StringWriter
            $Object.Save($String)
            $Xml = "'" + ([String]$String).Replace("`'", "&apos;") + "'"
            If ($Layers -le 0) {($Xml -Replace "\r\n\s*", "") -Replace "\s+", " "} ElseIf ($Layers -eq 1) {$Xml} Else {$Xml.Replace("`r`n", "`r`n`t")}
            $String.Dispose()
        } ElseIf ($Object -is "DateTime") {
            "$Quote$($Object.ToString('s'))$Quote"
        } ElseIf ($Object -is "String") {
            0..11 | ForEach {$Object = $Object.Replace([String]"```'""`0`a`b`f`n`r`t`v`$"[$_], ('`' + '`''"0abfnrtv$'[$_]))}; "$Quote$Object$Quote"
        } ElseIf ($Object -is "Boolean") {
            If ($Object) {"`$True"} Else {"`$False"}
        } ElseIf ($Object -is "Char") {
            If ($Strict) {[Int]$Object} Else {"$Quote$Object$Quote"}
        } ElseIf ($Object -is "ValueType") {
            $Object
        } ElseIf ($Object.Keys -ne $Null) {
            If ($Type -eq "[OrderedDictionary]") {$Type = "[Ordered]"}
            $Format = "@{", ";$Space", "}"
            If ($Depth -gt 1) {$Object.GetEnumerator() | ForEach {$_.Name + "$Space=$Space" + (ConvertTo-PSON $_.Value ($Depth - 1) ($Layers - 1) -Strict:$Strict)}}
        } ElseIf ($Object -is "Object") {
            If ($Version -le [Version]"2.0") {$Type = "New-Object PSObject -Property "}
            $Format = "@{", ";$Space", "}"
            If ($Depth -gt 1) {$Object.PSObject.Properties | ForEach {$_.Name + "$Space=$Space" + (ConvertTo-PSON $_.Value ($Depth - 1) ($Layers - 1) -Strict:$Strict)}}
        } Else {$Object}
        If ($Format) {
            $PSON = $Format[0] + (&{
                If (($Layers -le 1) -or ($PSON.Count -le 0)) {
                    $PSON -Join $Format[1]
                } Else {
                    ("`r`n" + ($PSON -Join "$($Format[1])`r`n")).Replace("`r`n", "`r`n`t") + "`r`n"
                }
            }) + $Format[2]
        }
        If ($Strict) {"$Type$PSON"} Else {"$PSON"}
    }
}

function DisableUser($user)
{
	$user_info = @{
		login = $user.SamAccountName;
		path = (($user.DistinguishedName -split ",",2)[1]);
		groups = @($user.memberof);
		activesync = $false;
		addressbook = $false;
		lync = $false; #$user.'msRTCSIP-UserEnabled'
		activesyncdevices = @();
		mailrules = @();
	}

	$password_plain = ("Tmp-" + (([char[]]"abcdefghikmnprstuvwxyzABCEFGHJKLMNPQRSTUVWXYZ23456789" | Get-Random -Count 8) -join ''))
	$password = (ConvertTo-SecureString $password_plain -AsPlainText -Force)

	# Отключение УЗ пользователя

	try
	{
		Disable-ADAccount -Identity $user
	}
	catch
	{
		$global:result = 2
		$global:error_msg += ("Ошибка отключения УЗ пользователя (" + $_.Exception.Message + ");`r`n")
	}

	# Смена пароля пользователя

	try
	{
		Set-ADAccountPassword -Identity $user -Reset -NewPassword $password -Confirm:$false
	}
	catch
	{
		$global:error_msg += ("Ошибка смены пароля (" + $_.Exception.Message + ");`r`n")
	}

	# Внесение номера инцидента

	try
	{
		Set-ADUser -Identity $user -Description $global:incident
	}
	catch
	{
		$global:result = 2
		$global:error_msg += ("Ошибка внесения номера инцидента (" + $_.Exception.Message + ");`r`n")
	}

	# Переместить в OU Уволенные сотрудники

	if($user.Company -eq 'ООО "БРЛ"')
	{
		$path = "OU=Уволенные сотрудники БРЛ,OU=Disabled Accounts,DC=contoso,DC=com"
	}
	elseif($user.Company -eq 'ООО "Альбион-2002"')
	{
		$path = "OU=Уволенные сотрудники Альбион-2002,OU=Disabled Accounts,DC=contoso,DC=com"
	}
	else
	{
		$path = "OU=Disabled Accounts,DC=contoso,DC=com"
	}

	try
	{
		Move-ADObject -Identity $user -TargetPath $path
	}
	catch
	{
		$global:result = 2
		$global:error_msg += ("Ошибка перемещения в " + $path + " (" + $_.Exception.Message + ");`r`n")
	}

	# Сохрание списка групп

	try
	{
		Set-Content -Path ("\\srv-admsrv-01\Log_SCORCH$\" + $user.SamAccountName + "_" + $global:incident + ".txt") -Value $user.memberof
	}
	catch
	{
		$global:result = 2
		$global:error_msg += ("Ошибка сохранения списка групп (" + $_.Exception.Message + ");`r`n")
	}

	# Удаление пользователя из групп

	foreach($group in $user.memberof)
	{
		try
		{
			Remove-ADGroupMember -Identity $group -Members $user -Confirm:$false
		}
		catch
		{
			$global:result = 2
			$global:error_msg += ("Ошибка удаления из группы " + $group + " (" + $_.Exception.Message + ");`r`n")
		}
	}

	# Добавление в группу

	try
	{
		Add-ADGroupMember -Identity "Доступ Уволенные сотрудники – Deny All" -Members $user
	}
	catch
	{
		$global:result = 2
		$global:error_msg += ("Ошибка добавления в группу Доступ Уволенные сотрудники – Deny All (" + $_.Exception.Message + ");`r`n")
	}


	$session = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri http://srv-exch-01.contoso.com/powershell/ -Credential $creds -Authentication Kerberos
	Import-PSSession $session

	$mail_box = $null
	try
	{
		$mail_box = Get-Mailbox -Identity $user.SamAccountName
	}
	catch
	{
	}
	
	if($mail_box)
	{
		# Получить статус показа в адресной книге
		
		try
		{
			$mail_info = Get-CASMailbox $user.SamAccountName
			$user_info.addressbook = (!($mail_info.HiddenFromAddressListsEnabled))
			$user_info.activesync = $mail_info.ActiveSyncEnabled
		}
		catch
		{
			$global:result = 2
			$global:error_msg += ("Ошибка получения статуса показа в адресной книге (" + $_.Exception.Message + ");`r`n")
		}

		# Скрытие из адресной книги

		try
		{
			Set-Mailbox -Identity $user.SamAccountName -HiddenFromAddressListsEnabled $true
		}
		catch
		{
			$global:result = 2
			$global:error_msg += ("Ошибка скрытия из адресной книги (" + $_.Exception.Message + ");`r`n")
		}

		# Получить список разрешенных устройств

		$mail_devices = @()
		try
		{
			$mail_devices = Get-MobileDeviceStatistics -Mailbox $user.SamAccountName
		}
		catch
		{
			$global:result = 2
			$global:error_msg += ("Ошибка получения списка разрешенных устройств (" + $_.Exception.Message + ");`r`n")
		}

		# Удаление разрешенных устройств

		foreach($device in $mail_devices)
		{
			if($device.DeviceAccessState -eq "Allowed")
			{
				$user_info.activesyncdevices += $device.DeviceID
				try
				{
					Set-CASMailbox -Identity $user.SamAccountName -ActiveSyncBlockedDeviceIDs @{ Add = $device.DeviceID }
				}
				catch
				{
					$global:result = 2
					$global:error_msg += ("Ошибка блокировки устройства " + $divice.DeviceID + " (" + $_.Exception.Message + ");`r`n")
				}
			}
		}

		# Выключение ActiveSync

		try
		{
			Set-CASMailbox -Identity $user.SamAccountName -ActivesyncEnabled $false
		}
		catch
		{
			$global:result = 2
			$global:error_msg += ("Ошибка выключения ActiveSync (" + $_.Exception.Message + ");`r`n")
		}

		# Получить список включенных правил

		try
		{
			$mail_rules = Get-InboxRule -Mailbox $user.SamAccountName
		}
		catch
		{
			$global:result = 2
			$global:error_msg += ("Ошибка получения списка включенных правил (" + $_.Exception.Message + ");`r`n")
		}

		foreach($rule in $mail_rules)
		{
			if($rule.Enabled)
			{
				$user_info.mailrules += [string] $rule.RuleIdentity

				# Отключение включенного правила

				try
				{
					Disable-InboxRule -Identity $rule.RuleIdentity -Mailbox $user.SamAccountName
				}
				catch
				{
					$global:result = 2
					$global:error_msg += ("Ошибка отключения включенного правила " + $rule.Name + " (" + $_.Exception.Message + ");`r`n")
				}
			}
		}
	}

	Remove-PSSession -Session $session

	# Выключение Lync

	$session = New-PSSession -ConnectionUri https://srv-sfb-01.contoso.com/OcsPowershell -Credential $creds
	Import-PSSession $session

	$lync_user = $null
	try
	{
		$lync_user = Get-CSUser -Identity $user.SamAccountName
	}
	catch
	{
	}
	
	if($lync_user)
	{
		$user_info.lync = $true
		
		try
		{
			Disable-CSUser -Identity $user.SamAccountName
		}
		catch
		{
			$global:result = 2
			$global:error_msg += ("Ошибка выключения Lync (" + $_.Exception.Message + ");`r`n")
		}

		try
		{
			Revoke-CsClientCertificate -Identity $user.SamAccountName
		}
		catch
		{
			$global:result = 2
			$global:error_msg += ("Ошибка отзыва сертификата Lync (" + $_.Exception.Message + ");`r`n")
		}
	}

	Remove-PSSession $session

	# Сохрание параметров для восстановления

	try
	{
		#$user_info | ConvertTo-Json | Set-Content -Path ("\\srv-admsrv-01\Log_SCORCH$\" + $user.SamAccountName + "_" + $global:incident + ".json")
		ConvertTo-PSON $user_info | Set-Content -Path ("\\srv-admsrv-01\Log_SCORCH$\" + $user.SamAccountName + "_" + $global:incident + ".pson")
	}
	catch
	{
		$global:result = 2
		$global:error_msg += ("Ошибка сохранения параметров для восстановления (" + $_.Exception.Message + ");`r`n")
	}

	# Отправка информационного письма

	$global:body += @'
<br />
Логин: {0}<br />
ФИО: {1}<br />
'@ -f $user.SamAccountName, $user.DisplayName
}

function main()
{
	# Проверка корректности заполнения полей

	if($global:login -eq '' -or $global:incident -eq '')
	{
		$global:error_msg = "Ошибка: Не заполнены все обязательные поля"
		return
	}

	# Проверка существования пользователя

	$user = 0
	try
	{
		$user = Get-ADUser -Identity $global:login -Properties Company, memberof, displayName, msRTCSIP-UserEnabled
	}
	catch
	{
		# nothing
	}

	if(!$user)
	{
		$global:error_msg = ("Ошибка: Пользователь " + $global:login + " не найден!")
		return
	}
	
	if($user.DistinguishedName -notmatch "OU=Company,DC=contoso,DC=com$")
	{
		$global:error_msg = ("Ошибка: Пользователь " + $global:login + " не может быть отключен с помощью ранбука!")
		return
	}
	
	$subject = ("User disabled: " + $user.SamAccountName + " (" + $user.DisplayName + ")")

	DisableUser -User $user

	$adm_name = ($user.Name + "ADM")
	$user = 0
	try
	{
		$user = Get-ADUser -Filter {CN -eq $adm_name} -Properties Company, memberof, displayName, msRTCSIP-UserEnabled
	}
	catch
	{
		# nothing
	}

	if($user)
	{
		DisableUser -User $user
	}

	# Отправка информационного письма

	$global:body += @'
<br />
Техническая информация: <br />{0}<br />
'@ -f $global:error_msg.Replace("`r`n", "<br />`r`n")

	$global:body += @'
</body>
</html>
'@

	try
	{
		Send-MailMessage -from "orchestrator@contoso.com" -to $smtp_to -Encoding UTF8 -subject $subject -bodyashtml -body $global:body -smtpServer $smtp_server -Credential $smtp_creds
	}
	catch
	{
		$global:result = 2
		$global:error_msg += ("Ошибка отправки информационного письма (" + $_.Exception.Message + ");`r`n")
	}

	if($global:result -ne 2)
	{
		$global:result = 0
	}
	else
	{
		$global:result = 1
	}
}

main
