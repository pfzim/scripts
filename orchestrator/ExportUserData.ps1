# Export all user data

$global:login = ''

$global:exch_creds = New-Object System.Management.Automation.PSCredential ('', (ConvertTo-SecureString '' -AsPlainText -Force))
$global:smtp_creds = New-Object System.Management.Automation.PSCredential ('', (ConvertTo-SecureString '' -AsPlainText -Force))

$global:result = 0
$global:error_msg = ''

$ErrorActionPreference = 'Stop'

$global:retry_count = 5

. c:\orchestrator\settings\config.ps1

$global:smtp_to = @($global:g_config.admin_email, $global:g_config.helpdesk_email)

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
		$global:error_msg = "Ошибка: Не заполнены все обязательные поля"
		return
	}

	# Проверка существования пользователя

	$user = $null
	try
	{
		$user = Get-ADUser -Identity $global:login
	}
	catch
	{
		$user= $null
	}

	if(!$user)
	{
		$global:result = 1
		$global:error_msg = "Ошибка: Пользователь не существует!"
		return
	}

	try
	{
        $location = ''
        $i = 1
        foreach($folder in $global:g_config.user_folders)
        {
            $location = ('{0}\{1}' -f $folder, $user.SamAccountName)
            if(Test-Path -Path $location )
            {
                $dst = ('{0}\{1}\data{2:D2}' -f $global:g_config.export_path, $user.SamAccountName, $i)
                if(!(Test-Path -Path $dst))
                {
                    New-Item -Path $dst -ItemType Directory -Force
                }

		        Copy-Item -Path $location -Destination $dst -Force -Recurse

                $i++
            }
        }
	}
	catch
	{
		$global:result = 1
		$global:error_msg += ("Ошибка копирования данных из {0} ({1});`r`n" -f $location, $_.Exception.Message)
	}

	$session = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri $global:g_config.exch_conn_uri -Credential $global:exch_creds -Authentication Basic
	Import-PSSession $session

	$mail_box = $null
	try
	{
		$mail_box = Get-Mailbox -Identity $user.SamAccountName
	}
	catch
	{
		$mail_box = $null
	}
	
	# Выгрузка почтового ящика в PST

	if($mail_box)
	{
		try
		{
            $dst = ('{0}\{1}' -f $global:g_config.export_path, $user.SamAccountName)

            if(!(Test-Path -Path $dst))
            {
                New-Item -Path $dst -ItemType Directory -Force
            }

            $mbex = New-MailboxExportRequest -Name ('RbEx_{0}' -f $user.SamAccountName) -Mailbox $user.SamAccountName -FilePath ('{0}\{1}.pst' -f $dst, $user.SamAccountName) -Priority High
			do
			{
				Start-Sleep -Seconds 60
				$stat = $mbex | Get-MailboxExportRequestStatistics
			}
			while($stat.Status.Value -notin ('Completed', 'Failed'))

			if($stat.Status.Value -eq 'Completed')
			{
				$mbex | Remove-MailboxExportRequest -Force -Confirm:$false
			}
			else
			{
				$global:result = 1
				$global:error_msg += ('Ошибка выгрузки почтового ящика. Статус: {0}, ошибка: {1}' -f $stat.Status, $stat.Message)
			}
		}
		catch
		{
			$global:result = 1
			$global:error_msg += ("Ошибка выгрузки почтового ящика в PST ({0});`r`n" -f $_.Exception.Message)
		}
	}

	Remove-PSSession -Session $session


	$body = @'
<html>
<head>
	<meta http-equiv="Content-Type" content="text/html; charset=utf-8">
	<style type="text/css">
		body {font-family: Arial; font-size: 12pt;}
	</style>
</head>
<body>
'@

	$body += @'
Были выгружены данные пользователя {1}:<br />
<br />
Логин: <b>{1}</b><br />
Путь: <b>{2}\{3}\</b><br />
<br />
<br />
<u>Техническая информация</u>: {0}<br />
'@ -f $global:error_msg, $global:login, $global:g_config.export_path, $user.SamAccountName

	$body += @'
</body>
</html>
'@

	try
	{
		Send-MailMessage -from $global:g_config.smtp_from -to $global:smtp_to -Encoding UTF8 -subject "Выгружены данные пользователя" -bodyashtml -body $body -smtpServer $global:g_config.smtp_server -Credential $global:smtp_creds
	}
	catch
	{
		$global:result = 1
		$global:error_msg += ("Ошибка отправки письма (" + $_.Exception.Message + ");`r`n")
	}
}

main
