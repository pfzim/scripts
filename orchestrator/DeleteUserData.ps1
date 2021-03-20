# Delete all user data

$global:exch_creds = New-Object System.Management.Automation.PSCredential ('', (ConvertTo-SecureString '' -AsPlainText -Force))
$global:ps_creds = New-Object System.Management.Automation.PSCredential ('', (ConvertTo-SecureString '' -AsPlainText -Force))

$global:result = 0
$global:error_msg = ''

$ErrorActionPreference = 'Stop'

$global:retry_count = 5

. c:\orchestrator\settings\config.ps1

$global:subject = ''
$global:body = ''

$global:smtp_to = @($global:g_config.admin_email, $global:g_config.helpdesk_email)
$global:smtp_to = $global:smtp_to -join ','

function Rename-SubFolders($Path)
{
    $Path
    $folders = Get-ChildItem -Path $Path -Directory
    $i = 0
    foreach($folder in $folders)
    {
        $i++
        Rename-SubFolders -Path $folder.FullName
        #"{0,-60} -> d{1}" -f $folder.Name, $i
        Rename-Item -Path $folder.FullName -NewName ('d{0}' -f $i)
    }
}

function main()
{
	trap
	{
		$global:result = 1
		$global:error_msg += ("Критичная ошибка: {0}`r`n`r`nПроцесс прерван!`r`n" -f $_.Exception.Message);
		return;
	}

	# Формирования списка учётных записей для удаления

	$users = $null
	try
	{
		$users = Get-ADUser -LDAPFilter '(&(useraccountcontrol:1.2.840.113556.1.4.803:=2)(info=*))' -SearchBase $global:g_config.uo_disabled -Properties info
	}
	catch
	{
		$global:result = 1
		$global:error_msg += ("Ошибка: Получения списка пользователей: {0}" -f $_.Exception.Message)
		return
	}

	if(!$users -or $users.Count -eq 0)
	{
		$global:error_msg = "Нечего удалять"
		return
	}

	$session = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri $global:g_config.exch_conn_uri -Credential $global:exch_creds -Authentication Basic
	Import-PSSession $session

	# Удаление данных

	$list_deleted_data = ''
	$table = '<table><tr><th>Login</th><th>Name</th><th>Info</th></tr>'

	$border_date = (Get-Date).AddDays(-90)

	foreach($user in $users)
	{
		$has_errors = $false
		
		if($user.Info -match 'EDD:\d\d-\d\d-\d\d\d\d')
		{
			$date_arr = $user.Info -split '[:-]'
			$edd = Get-Date -Year $date_arr[3] -Month $date_arr[2] -Day $date_arr[1] -Hour 0 -Minute 0 -Second 0 -Millisecond 0

			if(!$user.Enabled -and ($edd -lt $border_date))
			{
				# Удаление DFS ссылок пользователя
				
				foreach($dfs_link in $global:g_config.user_dfs_links)
				{
					$location = ('{0}\{1}' -f $dfs_link, $user.SamAccountName)
					if(Test-Path -Path $location)
					{
						try
						{
							Invoke-Command -ComputerName localhost -ArgumentList @($location) -Credential $global:ps_creds -Authentication Credssp -ScriptBlock {
								param($dfs_link)
								$ErrorActionPreference = 'Stop'
								Remove-DfsnFolder -Path $dfs_link -Confirm:$false -Force 
							}
							$list_deleted_data += "Удалена DFS ссылка: {0}`r`n" -f $location
						}
						catch
						{
							$has_errors = $true
							$global:result = 1
							$global:error_msg += ("Ошибка удаления DFS ссылки {0} ({1});`r`n" -f $location, $_.Exception.Message)
						}
					}
				}

				# Удаление папок пользователя на общих ресурсах
				
				foreach($folder in $global:g_config.user_folders)
				{
					$location = ('{0}\{1}' -f $folder, $user.SamAccountName)
					if(Test-Path -Path $location)
					{
						# Попытка удаления папки
						$done = $false
						try
						{
							Remove-Item -Path $location -Recurse -Force -Confirm:$false
							$list_deleted_data += "Удалена папка: {0}`r`n" -f $location
							$done = $true
						}
						catch
						{
							$done = $false
						}
						
						# Если попытка удаления не удачна
						if(!$done)
						{
							# Переименовываем папки в более короткие имена
							try
							{
								Rename-SubFolders -Path $location
							}
							catch
							{
								$has_errors = $true
								$global:result = 1
								$global:error_msg += ("Ошибка переименования папок в более короткое имя {0} ({1});`r`n" -f $location, $_.Exception.Message)
								continue
							}
							
							# Повторяем попытку удаления
							try
							{
								Remove-Item -Path $location -Recurse -Force -Confirm:$false
								$list_deleted_data += "Удалена папка: {0}`r`n" -f $location
							}
							catch
							{
								$has_errors = $true
								$global:result = 1
								$global:error_msg += ("Ошибка удаления данных из {0} ({1});`r`n" -f $location, $_.Exception.Message)
							}
						}
					}
				}
				
				# Удаление ПЯ и УЗ

				if(!$has_errors)
				{
					$mbx = $null
					try
					{
						$mbx = Get-Mailbox -Identity $user.SamAccountName
					}
					catch
					{
						$mbx = $null
					}
					
					if($mbx)
					{
						try
						{
							Remove-Mailbox -Identity $user.SamAccountName -Permanent $true -Force -Confirm:$false
							$list_deleted_data += "Удалён почтовый ящик и учётная запись: {0}`r`n" -f $user.SamAccountName
						}
						catch
						{
							$global:result = 1
							$has_errors = $true
							$global:error_msg += ("Ошибка удаления ПЯ и УЗ {0} ({1});`r`n" -f $user.SamAccountName, $_.Exception.Message)
						}
					}
					else
					{
						try
						{
							Remove-ADObject -Identity $user -Recursive -Confirm:$false
							$list_deleted_data += "Удалёна учётная запись: {0}`r`n" -f $user.SamAccountName
						}
						catch
						{
							$global:result = 1
							$has_errors = $true
							$global:error_msg += ("Ошибка удаления УЗ из AD {0} ({1});`r`n" -f $user.SamAccountName, $_.Exception.Message)
						}
					}
				}

				$color = ''
				if($has_errors)
				{
					$color = ' class="error"'
				}

				$table += '<tr{3}><td>{0}</td><td>{1}</td><td>{2}</td></tr>' -f $user.SamAccountName, $user.Name, $user.Info, $color
				
				#break # Test break
			}
		}
	}

	Remove-PSSession -Session $session

	$table += '</table>'

	# Отправка информационного письма

	$global:subject = 'Удалены данные уволенных сотрудников'

	$global:body += '<h1>Были удалены данные пользователей</h1><br />'

	$global:body += $table
	$global:body += "<br /></br /><pre>Список удаленных данных:`r`n`r`n{0}</pre>" -f $list_deleted_data
}

main

if($global:result -ne 0)
{
	$global:body += "<br /><br /><pre class=`"error`">Техническая информация:`r`n`r`n{0}</pre>" -f $global:error_msg
}
