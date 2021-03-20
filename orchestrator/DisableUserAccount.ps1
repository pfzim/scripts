# Disable and export user account settings

$global:login = ''
$global:incident = ''

$global:creds = New-Object System.Management.Automation.PSCredential ('', (ConvertTo-SecureString '' -AsPlainText -Force))

$ErrorActionPreference = 'Stop'

. c:\orchestrator\settings\config.ps1

$global:result = 0
$global:error_msg = ''

$global:subject = ''
$global:body = ''
$global:smtp_to = @($global:g_config.helpdesk_email, $global:g_config.techsupport_email, $global:g_config.useraccess_email)
$global:smtp_to = $global:smtp_to -join ','


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
	trap
	{
		$global:result = 1
		$global:error_msg += ("Критичная ошибка: {0}`r`n`r`nПроцесс прерван!`r`n" -f $_.Exception.Message);
		return;
	}

	$user_info = @{
		login = $user.SamAccountName;
		path = (($user.DistinguishedName -split ",",2)[1]);
		groups = @($user.memberof);
		activesync = $false;
		addressbook = $false;
		lync = $false; #$user.'msRTCSIP-UserEnabled'
		activesyncdevices = @();
		mailrules = @();
		edd = (Get-Date -format 'dd-MM-yyyy');
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
		$global:result = 1
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

	# Внесение номера инцидента и Employee Dismissal Date

	try
	{
		Set-ADUser -Identity $user -Description $global:incident -Replace @{'info' = ('EDD:{0}' -f $user_info.edd)}
	}
	catch
	{
		$global:result = 1
		$global:error_msg += ("Ошибка внесения номера инцидента и даты увольнения (" + $_.Exception.Message + ");`r`n")
	}

	# Сохрание списка групп

	try
	{
		Set-Content -Path ("\\brc-admsrv-01\Log_SCORCH$\" + $user.SamAccountName + "_" + $global:incident + ".txt") -Value $user.memberof
	}
	catch
	{
		$global:result = 1
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
			$global:result = 1
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
		$global:result = 1
		$global:error_msg += ("Ошибка добавления в группу Доступ Уволенные сотрудники – Deny All (" + $_.Exception.Message + ");`r`n")
	}


	# Подключение к Exchange

	try
	{
		$session = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri $global:g_config.exch_conn_uri -Credential $global:creds -Authentication Basic
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
				$global:result = 1
				$global:error_msg += ("Ошибка получения статуса показа в адресной книге (" + $_.Exception.Message + ");`r`n")
			}

			# Включение автоответа

			try
			{
				$text = $global:g_config.email_autoanswer_text.Replace('%UserName%', $user.DisplayName).Replace('%CompanyName%', $user.Company)
				Set-MailboxAutoReplyConfiguration -Identity $user.SamAccountName -AutoReplyState Enabled -ExternalAudience All -InternalMessage $text -ExternalMessage $text
			}
			catch
			{
				$global:result = 1
				$global:error_msg += ("Ошибка включения автоответа (" + $_.Exception.Message + ");`r`n")
			}

			# Скрытие из адресной книги

			try
			{
				Set-Mailbox -Identity $user.SamAccountName -HiddenFromAddressListsEnabled $true
			}
			catch
			{
				$global:result = 1
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
				$global:result = 1
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
						$global:result = 1
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
				$global:result = 1
				$global:error_msg += ("Ошибка выключения ActiveSync (" + $_.Exception.Message + ");`r`n")
			}

			# Получить список включенных правил

			try
			{
				$mail_rules = Get-InboxRule -Mailbox $user.SamAccountName
			}
			catch
			{
				$global:result = 1
				$global:error_msg += ("Ошибка получения списка включенных почтовых правил (" + $_.Exception.Message + ");`r`n")
			}

			foreach($rule in $mail_rules)
			{
				if($rule.Enabled -and $rule.SupportedByTask)
				{
					$user_info.mailrules += [string] $rule.RuleIdentity

					# Отключение включенного правила

					try
					{
						Disable-InboxRule -Identity $rule.RuleIdentity -Mailbox $user.SamAccountName -Force
					}
					catch
					{
						$global:result = 1
						$global:error_msg += ("Ошибка отключения почтового правила " + $rule.Name + " (" + $_.Exception.Message + ");`r`n")
					}
				}
			}
		}

		Remove-PSSession -Session $session
	}
	catch
	{
		$global:result = 1
		$global:error_msg += "Ошибка подключения к серверу Exchange: {0}`r`n" -f $_.Exception.Message 
	}

	# Выключение Lync

	try
	{
		$session = New-PSSession -ConnectionUri $global:g_config.sfb_conn_uri -Credential $global:creds
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
				#Disable-CSUser -Identity $user.SamAccountName
				Set-CSUser -Identity $user.DistinguishedName -Enabled:$false -Confirm:$false
			}
			catch
			{
				$global:result = 1
				$global:error_msg += ("Ошибка выключения Lync (" + $_.Exception.Message + ");`r`n")
			}

			try
			{
				Revoke-CsClientCertificate -Identity $user.DistinguishedName
			}
			catch
			{
				#$global:result = 2
				#$global:error_msg += ("Ошибка отзыва сертификата Lync (" + $_.Exception.Message + ");`r`n")
			}
		}

		Remove-PSSession $session
	}
	catch
	{
		$global:result = 1
		$global:error_msg += "Ошибка подключения к серверу Lync: {0}`r`n" -f $_.Exception.Message 
	}

	# Переместить в OU Уволенные сотрудники

	try
	{
		Move-ADObject -Identity $user -TargetPath $global:g_config.uo_disabled
	}
	catch
	{
		$global:result = 1
		$global:error_msg += ("Ошибка перемещения в " + $global:g_config.uo_disabled + " (" + $_.Exception.Message + ");`r`n")
	}

	# Сохрание параметров для восстановления

	try
	{
		#$user_info | ConvertTo-Json | Set-Content -Path ("\\brc-admsrv-01\Log_SCORCH$\" + $user.SamAccountName + "_" + $global:incident + ".json")
		ConvertTo-PSON -Object $user_info -Layers 9 | Set-Content -Path ("\\brc-admsrv-01\Log_SCORCH$\" + $user.SamAccountName + "_" + $global:incident + ".pson")
		
		<#
		$dst = ('{0}\{1}' -f $global:g_config.export_path, $user.SamAccountName)
		if(!(Test-Path -Path $dst))
		{
			New-Item -Path $dst -ItemType Directory -Force
		}
		#>

		ConvertTo-PSON -Object $user_info -Layers 9 | Out-File -FilePath ('{0}\_AccountsDataForRestore\{1}.pson' -f $global:g_config.export_path, $user.SamAccountName)
	}
	catch
	{
		$global:result = 1
		$global:error_msg += ("Ошибка сохранения параметров для восстановления (" + $_.Exception.Message + ");`r`n")
	}

	# Отправка информационного письма

	$global:body += @'
		<br />
		Логин: <b>{0}</b><br />
		ФИО: <b>{1}</b><br />
'@ -f $user.SamAccountName, $user.DisplayName
}

function main()
{
	trap
	{
		$global:result = 1
		$global:error_msg += ("Критичная ошибка: {0}`r`n`r`nПроцесс прерван!`r`n" -f $_.Exception.Message);
		return;
	}

	# Проверка корректности заполнения полей

	if($global:login -eq '' -or $global:incident -eq '')
	{
		$global:error_msg = "Ошибка: Не заполнены все обязательные поля"
		return
	}

	# Проверка существования пользователя

	$user = $null
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

	# Проверка OU в которой расположена учётная запись

	if($user.DistinguishedName -notmatch $global:g_config.ou_can_disable_users_regexp)
	{
		$global:error_msg = ("Ошибка: Пользователь " + $global:login + " не может быть отключен с помощью ранбука!")
		return
	}

	$global:subject = ("User disabled: " + $user.SamAccountName + " (" + $user.DisplayName + ")")

	$global:body = '<h1>Был заблокирован пользователь</h1>'
	$global:body += '<p>'

	# Отключение учётной записи

	DisableUser -User $user

	# Поиск и отключение административной учётной записи

	$adm_name = ('{0}ADM' -f $user.Name)
	$users = $null
	try
	{
		$users = Get-ADUser -Filter {CN -eq $adm_name} -Properties Company, memberof, displayName, msRTCSIP-UserEnabled
	}
	catch
	{
		# nothing
	}

	foreach($user in $users)
	{
		DisableUser -User $user
	}

	$global:body += '</p>'
}

main

if($global:result -ne 0)
{
	$global:body += "<br /><br /><pre class=`"error`">Техническая информация:`r`n`r`n{0}</pre>" -f $global:error_msg
}
