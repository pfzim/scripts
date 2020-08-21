# Export all user data

$global:login = ''

$global:exch_creds = New-Object System.Management.Automation.PSCredential ('', (ConvertTo-SecureString '' -AsPlainText -Force))

$global:subject = ''
$global:body = ''

$ErrorActionPreference = 'Stop'

$global:result = 0
$global:error_msg = ''

$global:retry_count = 5

. c:\orchestrator\settings\config.ps1

$global:smtp_to = @($global:g_config.admin_email, $global:g_config.helpdesk_email)
$global:smtp_to = $global:smtp_to -join ','

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

	# Выгрузка данных
	
	$text = ''

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
				
				$text += 'Данные из папки {0} скопированы в {1}<br />' -f $location, $dst

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
			
			$text += 'Почтовый ящик {2} выгружен в файл {0}\{1}.pst<br />' -f $dst, $user.SamAccountName, $mail_box.PrimarySmtpAddress

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

	$global:subject = 'Выгружены данные пользователя: {0}' -f $global:login
	
	$global:body = @'
<h1>Были выгружены данные пользователя</h1>
<br />
<p>
Логин: <b>{0}</b><br />
Путь: <b>{1}\{2}\</b><br />
</p>
<br />
Выгружены следующие данные:<br />
{3}
<br />
'@ -f $global:login, $global:g_config.export_path, $user.SamAccountName, $text

}

main

if($global:result -ne 0)
{
	$global:body += "<br /><br /><pre class=`"error`">Техническая информация:`r`n`r`n{0}</pre>" -f $global:error_msg
}
