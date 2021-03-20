# Check timezone setting

$rb_input = @{
	reg_code = ''
}

$global:ps_creds = New-Object System.Management.Automation.PSCredential ('', (ConvertTo-SecureString '' -AsPlainText -Force))

$global:result = 0
$global:error_msg = ''

$ErrorActionPreference = 'Stop'

. c:\orchestrator\settings\config.ps1

$global:subject = ''
$global:body = ''
$global:smtp_to = @($global:g_config.admin_email)

$global:smtp_to = $global:smtp_to -join ','

function main($rb_input)
{
	trap
	{
		$global:result = 1
		$global:error_msg += ("Критичная ошибка: {0}`r`n`r`nПроцесс прерван!`r`n" -f $_.Exception.Message);
		return;
	}

	if($rb_input.reg_code -notmatch '\d\d')
	{
		$global:result = 1
		$global:error_msg += 'Указан неправильный код региона'
		return
	}

	$name = ('{0}-*' -f $rb_input.reg_code)
	$computers = Get-ADComputer -SearchBase $global:g_config.ou_shops -Filter {Name -like $name }

	foreach($computer in $computers)
	{
		try
		{
			<# 1. Method WinRM
			$time_zone = Invoke-Command -ComputerName $computer.Name -Credential $global:ps_creds -ScriptBlock {
				$key = Get-ItemProperty -Path "Registry::HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\TimeZoneInformation" -Name TimeZoneKeyName
				return $key.TimeZoneKeyName
			}
			#>
			
			# 2. Method WMI (by Anton V. Efremov)
			$time_zone = (Get-WmiObject -Class Win32_TimeZone -ComputerName $computer.Name).Caption

			$table += '<tr><td>{0}</td><td>{1}</td></tr>' -f $computer.Name, $time_zone
		}
		catch
		{
			$table += '<tr><td>{0}</td><td class="error">ОШИБКА: {1}</td></tr>' -f $computer.Name, $_.Exception.Message
		}
	}

	$global:subject = 'Отчёт по установленному часовому поясу на компьютерах {0} региона' -f $rb_input.reg_code

	$global:body = '<h2>{0}</h2>' -f $global:subject

	$global:body += '<table>'
	$global:body +=  '<tr><th>Имя ПК</th><th>Часовой пояс</th></tr>'
	$global:body +=  $table
	$global:body += '</table>'
}

main -rb_input $rb_input

if($global:result -ne 0)
{
	$global:body += "<br /><br /><pre class=`"error`">Техническая информация:`r`n`r`n{0}</pre>" -f $global:error_msg
}
