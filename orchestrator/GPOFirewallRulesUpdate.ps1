<# Cut the ip range from GPO firewall rules

	Ранбук выполяет следующие действия:
	1. Создаёт резервню копию правил файервола из групповой политики.
	2. Создаёт резевную копию POL файла
	3. Если в качестве Rule name указано LoadJSON, то правила подгрузятся из файла file_with_rules.
	   В противном случае удалит указанный при запуске ранбука диапазон из RemoteAddresses во всех
	   правилах, если в качесте Rule name указано ALL, либо если имя правила равно Rule name
	4. Создаёт информационный файл с актуальными правилами
	5. Удаляет из политики все настройки файервола.
	6. Записывает обновлённые правила

	На вход ранбук принимает параметры:

		gpo_policy        - путь к политике
		rule_name         - название правила конкретного правилв или ALL, чтобы изменить
		                    все правила. Либо LoadJSON, чтобы загрузить правила из
							файла file_with_rules
		backup_path       - путь к папке с резервными копиями
		pol_file          - путь к POL файлу для создания резервной копии
		file_with_rules   - путь к файлу из которого загружать правила (при LoadJSON)
		file_with_info    - путь к файлу для сохранения человеко-читаемой копии

		cut_start_ip      - IP адрес - начало вырезаемого диапазона
		cut_end_ip        - IP адрес - конец вырезаемого диапазона

		errors            - количество возникших ошибок (из результата запуска предыдущего ранбука)
		warnings          - количество возникших предупреждений (из результата запуска предыдущего ранбука)
		message           - текстовое описание ошибок и предупреждений (из результата запуска предыдущего ранбука)

	На выходе ранбук возвращает следующие параметры:

		errors   - количество возникших ошибок
		warnings - количество возникших предупреждений
		message  - текстовое описание ошибок и предупреждений
#>

#. c:\orchestrator\settings\config.ps1

# Все входящие параметры указываем в $rb_input,
# чтобы в основном блоке не было никаких внешних переменных.
# Тем самым ранбук становится системонезависимым, универсальным и переносимым.

$rb_input = @{
	gpo_policy = 'contoso.co\TEST'
	rule_name = ''
	backup_path = 'C:\Orchestrator\backups\gpo_firewall_test'
	pol_file = '\\contoso.com\SYSVOL\contoso.com\Policies\{00000000-7B60-4B23-8DF8-000000000000}\Machine\Registry.pol'
	file_with_rules = 'C:\Orchestrator\backups\gpo_firewall_test\latest.json'
	file_with_info = 'C:\Orchestrator\backups\gpo_firewall_test.txt'

	cut_start_ip = ''
	cut_end_ip = ''

	ps_server = 'localhost'
	ps_user = ''
	ps_passwd = ''

	debug_pref = 'SilentlyContinue'  # Change to Continue for show debug messages
}

# Если ранбуки запускаются цепочкой, то результат выполнения предыдущего
# ранбука указываем здесь

$result = @{
	errors = [int] ''
	warnings = [int] ''
	messages = @(@'

'@)
}

$DebugPreference = $rb_input.debug_pref
$ErrorActionPreference = 'Stop'

# Основной блок ранбука

function main($rb_input)
{
	trap
	{
		return @{ errors = 0; warnings = 0; messages = @("Critical error[{0},{1}]: {2}`r`n`r`nProcess interrupted!`r`n" -f $_.InvocationInfo.ScriptLineNumber, $_.InvocationInfo.OffsetInLine, $_.Exception.Message); }
	}

	try
	{
		$result = @{ errors = 0; warnings = 0; messages = @() }

		$ps_creds = (New-Object System.Management.Automation.PSCredential ($rb_input.ps_user, (ConvertTo-SecureString $rb_input.ps_passwd -AsPlainText -Force)))

		$session = New-PSSession -ComputerName $rb_input.ps_server -Credential $ps_creds -Authentication Credssp
		$result = Invoke-Command -Session $session -ArgumentList @($rb_input) -ScriptBlock {
			param(
				$rb_input
			)
			$DebugPreference = $rb_input.debug_pref
			$ErrorActionPreference = 'Stop'
			try
			{
				$result = @{ errors = 0; warnings = 0; messages = @() }

				# Convert IP from string to integer

				function Convert-IPToInt($ip)
				{
					if($ip -match '^(\d+)\.(\d+)\.(\d+)\.(\d+)$')
					{
						$ipa = 1..4 | %{ [int] $Matches[$_] }
						$ipa | %{ if($_ -lt 0 -or $_ -gt 255) { throw New-Object System.Exception(('Invalid IP address: {0}' -f $ip)) } }
						return ($ipa[3]) + ($ipa[2] * 256) + ($ipa[1] * 65536) + ($ipa[0] * 16777216)
					}
					else
					{
						throw New-Object System.Exception(('Invalid IP address: {0}' -f $ip))
					}
				}

				# Convert array of IP string ranges to integer ranges

				function Convert-IPRangesFromStrToInt($ranges, [ref] $out_ranges)
				{
					[array] $out_ranges.Value = foreach($range in $ranges)
					{
						if($range -match '^(\d+\.\d+\.\d+\.\d+)-(\d+\.\d+\.\d+\.\d+)$')
						{
							$ip_s = Convert-IPToInt -ip $Matches[1]
							$ip_e = Convert-IPToInt -ip $Matches[2]

							if($ip_s -gt $ip_e)
							{
								throw New-Object System.Exception(('Invalid IP range (first address greater last): {0}' -f $range))
							}

							[PSCustomObject] @{
								s = $ip_s
								e = $ip_e
							}
						}
						elseif($range -match '^(\d+)\.(\d+)\.(\d+)\.(\d+)$')
						{
							$ip_s = Convert-IPToInt -ip $range
							[PSCustomObject] @{
								s = $ip_s
								e = $ip_s
							}
						}
						elseif($range -ieq 'Any')
						{
							[PSCustomObject] @{
								s = 0
								e = 4294967295
							}
						}
						else
						{
							throw New-Object System.Exception(('Unsupported IP range format: {0}' -f $range))
						}
					}
				}

				# Cut the range from IP ranges

				function Cut-IPRange([ref] $ref_ranges, $range)
				{
					$ranges = $ref_ranges.Value

					[array] $new_ranges = for($i = 0; $i -lt $ranges.Count; $i++)
					{
						# [ s ]
						if($range.s -ge $ranges[$i].s -and $range.s -le $ranges[$i].e)
						{
							# s = [
							if($range.s -eq $ranges[$i].s)
							{
								# s = [  e = ]
								if($range.e -ge $ranges[$i].e)
								{
									# remove this range
									continue
								}
								# s = [ e ]
								else
								{
									$ranges[$i].s = $range.e + 1
									$ranges[$i]
								}
							}
							# e >= ]
							elseif($range.e -ge $ranges[$i].e)
							{
								$ranges[$i].e = $range.s - 1
								$ranges[$i]
							}
							# [ s e ]
							else
							{
								[PSCustomObject] @{ s = $range.e + 1; e = $ranges[$i].e }
								$ranges[$i].e = $range.s - 1
								$ranges[$i]
							}
						}
						# s [ e < ]
						elseif($range.e -ge $ranges[$i].s -and $range.e -lt $ranges[$i].e)
						{
							$ranges[$i].s = $range.e + 1
							$ranges[$i]
						}
						# s [ ] <= e
						elseif($range.s -le $ranges[$i].s -and $range.e -ge $ranges[$i].e)
						{
							# remove this range
							continue
						}
						# other
						else
						{
							# no changes
							$ranges[$i]
						}
					}

					$ref_ranges.Value = $new_ranges
				}

				# Convert array of IP ranges to string array

				function Convert-IPRangesFromIntToStr($ranges, [ref] $out_ranges)
				{
					[array] $out_ranges.Value = foreach($range in $ranges)
					{
						$s = ('{0}.{1}.{2}.{3}' -f ([math]::truncate($range.s/16777216)), ([math]::truncate(($range.s % 16777216)/65536)), ([math]::truncate(($range.s % 65536)/256)), ([math]::truncate($range.s % 256)))
						$e = ('{0}.{1}.{2}.{3}' -f ([math]::truncate($range.e/16777216)), ([math]::truncate(($range.e % 16777216)/65536)), ([math]::truncate(($range.e % 65536)/256)), ([math]::truncate($range.e % 256)))

						if($range.s -eq $range.e)
						{
							$s
						}
						else
						{
							('{0}-{1}' -f $s, $e)
						}
					}
				}

				# Проверка корректности заполнения полей

				if([string]::IsNullOrWhiteSpace($rb_input.rule_name))
				{
					$result.errors++; $result.messages += 'Ошибка: Некорректно заполнено поле Rule name';
				}

				if(($rb_input.rule_name -ine 'LoadJSON'))
				{
					if(-not ($rb_input.cut_start_ip -match '^\d+\.\d+\.\d+\.\d+$'))
					{
						$result.errors++; $result.messages += 'Ошибка: Некорректно заполнено поле IP';
					}

					if(-not ($rb_input.cut_end_ip -match '^\d+\.\d+\.\d+\.\d+$'))
					{
						$result.errors++; $result.messages += 'Ошибка: Некорректно заполнено поле IP';
					}
				}

				if($result.errors -gt 0)
				{
					return $result
				}

				# Validate IP addresses

				Convert-IPToInt -ip $rb_input.cut_start_ip | Out-Null
				Convert-IPToInt -ip $rb_input.cut_end_ip | Out-Null

				# Read GPO firewall rules and prepare JSON structure

				$rules = Get-NetFirewallRule -PolicyStore $rb_input.gpo_policy

				$json_rules = foreach($rule in $rules)
				{
					$addr_filter = Get-NetFirewallAddressFilter -AssociatedNetFirewallRule $rule
					$app_filter = Get-NetFirewallApplicationFilter -AssociatedNetFirewallRule $rule
					$port_filter = Get-NetFirewallPortFilter -AssociatedNetFirewallRule $rule
					$if_filter = Get-NetFirewallInterfaceTypeFilter -AssociatedNetFirewallRule $rule
					#$type_filter = Get-NetFirewallInterfaceTypeFilter -AssociatedNetFirewallRule $rule

					$ranges = $null
					$ForDebugPurposesRemoteAddressesInverted = $null

					$ranges_inverted = @(
						[PSCustomObject] @{ s = 0; e = 4294967295 } # 0.0.0.0 - 255.255.255.255
					)

					Convert-IPRangesFromStrToInt -ranges $addr_filter.RemoteAddress -out_ranges ([ref] $ranges)

					foreach($range in $ranges)
					{
						Cut-IPRange -ref_ranges ([ref] $ranges_inverted) -range $range
					}

					Convert-IPRangesFromIntToStr -ranges $ranges_inverted -out_ranges ([ref] $ForDebugPurposesRemoteAddressesInverted)

					[PSCustomObject] @{
						Name = $rule.Name
						Enabled = $rule.Enabled
						DisplayName = $rule.DisplayName
						Description = $rule.Description
						Profile = $rule.Profile
						Direction = $rule.Direction
						Action = $rule.Action
						AppProgram = $app_filter.Program
						AppPackage = $app_filter.Package
						InterfaceType = $if_filter.InterfaceType
						Protocol = $port_filter.Protocol
						ICMPType = $port_filter.IcmpType
						LocalPorts = @($port_filter.LocalPort)
						RemotePorts = @($port_filter.RemotePort)
						DynamicTarget = @($port_filter.DynamicTarget)
						LocalAddresses = @($addr_filter.LocalAddress)
						RemoteAddresses = @($addr_filter.RemoteAddress)
						_RemoteAddressesInverted = $ForDebugPurposesRemoteAddressesInverted
					}
				}


				# Creating backup in JSON format

				$date_now = (Get-Date).toString('yyyy-MM-dd-HHmm')

				$backup_file = '{0}\backup-{1}-gpo.json' -f $rb_input.backup_path, $date_now
				$json_rules | ConvertTo-Json -Depth 99 | Out-File -FilePath $backup_file

				$result.messages += 'INFO: Резервная копия сохранена в {0}' -f $backup_file

				# Creating backup in POL format

				$backup_file = '{0}\backup-{1}-gpo.pol' -f $rb_input.backup_path, $date_now
				Copy-Item -Path $rb_input.pol_file -Destination $backup_file

				$result.messages += 'INFO: Резервная копия сохранена в {0}' -f $backup_file
				
				$changed = $false

				if(($rb_input.rule_name -ieq 'LoadJSON'))
				{
					# Read rules from JSON file

					$json_rules = Get-Content -Path $rb_input.file_with_rules -Raw | ConvertFrom-Json
					
					$result.messages += 'INFO: Прочитаны правила из файла {0}' -f $rb_input.file_with_rules
					$changed = $true
				}
				else
				{
					# Modify rules

					foreach($rule in $json_rules)
					{
						if(($rb_input.rule_name -ieq 'ALL') -or ($rule.DisplayName -ieq $rb_input.rule_name))
						{
							# Cut the IP range form RemoteAddresses

							$ranges = $null

							Convert-IPRangesFromStrToInt -ranges $rule.RemoteAddresses -out_ranges ([ref] $ranges)

							$range_for_cut = [PSCustomObject] @{
								s = (Convert-IPToInt -ip $rb_input.cut_start_ip)
								e = (Convert-IPToInt -ip $rb_input.cut_end_ip)
							}

							Cut-IPRange -ref_ranges ([ref] $ranges) -range $range_for_cut

							$temp_ranges = $null

							Convert-IPRangesFromIntToStr -ranges $ranges -out_ranges ([ref] $temp_ranges)

							$rule.RemoteAddresses = $temp_ranges

							# Invert ranges

							$ranges_inverted = @(
								[PSCustomObject] @{ s = 0; e = 4294967295 } # 0.0.0.0 - 255.255.255.255
							)

							foreach($range in $ranges)
							{
								Cut-IPRange -ref_ranges ([ref] $ranges_inverted) -range $range
							}

							$temp_ranges = $null

							Convert-IPRangesFromIntToStr -ranges $ranges_inverted -out_ranges ([ref] $temp_ranges)

							$rule._RemoteAddressesInverted = $temp_ranges

							$result.messages += 'INFO: Изменено правило {0}' -f $rule.DisplayName
							$changed = $true
						}
					}

					# Creating JSON file with latest rules

					$backup_file = '{0}\latest.json' -f $rb_input.backup_path
					$json_rules | ConvertTo-Json -Depth 99 | Out-File -FilePath $backup_file
				}

				# Create file with info

				'Список правил файлервола и разрешённых адресов' |  Out-File -FilePath $rb_input.file_with_info
				$json_rules | %{
					''
					'{0} ({1} {2} {3} {4})' -f $_.DisplayName, $_.Protocol, ($_.LocalPorts -join ', '), (&{if($_.Direction -eq 1) { '<-' } else { '->' }}), ($_.RemotePorts -join ', ')
					$_._RemoteAddressesInverted | Sort-Object | %{ '    {0}' -f $_ }
				} | Out-File -Append -FilePath $rb_input.file_with_info

				# Create GPO firewall rules from JSON data
				
				if($changed)
				{
					Remove-NetFirewallRule -PolicyStore $rb_input.gpo_policy -All | Out-Null

					foreach($rule in $json_rules)
					{
						New-NetFirewallRule -PolicyStore $rb_input.gpo_policy -Enabled $rule.Enabled -Name $rule.Name -DisplayName $rule.DisplayName -Description $rule.Description -Profile $rule.Profile -Direction $rule.Direction -Action $rule.Action -Program $rule.AppProgram -Package $rule.AppPackage -LocalAddress $rule.LocalAddresses -RemoteAddress $rule.RemoteAddresses -InterfaceType $rule.InterfaceType -Protocol $rule.Protocol -IcmpType $rule.ICMPType -LocalPort $rule.LocalPorts -RemotePort $rule.RemotePorts -DynamicTarget $rule.DynamicTarget | Out-Null
					}
					
					$result.messages += 'INFO: Изменения применены'
				}
				else
				{
					$result.warnings++; $result.messages += ('WARNING: Правило с названием "{0}" не найдено. Изменения не произведены' -f $rb_input.rule_name);
				}

				return $result
			}
			catch
			{
				$result.errors++; $result.messages += ('ERROR[{0},{1}]: {2}' -f $_.InvocationInfo.ScriptLineNumber, $_.InvocationInfo.OffsetInLine, $_.Exception.Message);
				return $result
			}
		}

		Remove-PSSession -Session $session

		return $result
	}
	catch
	{
		$result.errors++; $result.messages += ('ERROR[{0},{1}]: {2}' -f $_.InvocationInfo.ScriptLineNumber, $_.InvocationInfo.OffsetInLine, $_.Exception.Message);
		return $result
	}
}

# Выполняем ранбук, только если предыдущий завершился без ошибок

if($result.errors -eq 0)
{
	$output = main -rb_input $rb_input

	# Объединяем результат с предыдущим ранбуком

	$result.errors += $output.errors
	$result.warnings += $output.warnings
	$result.messages += $output.messages

	<# Return custom results
	if($output.errors -eq 0)
	{
		$data = $output.data
	}
	#>
}

# Код выхода для обратной совместимости

$exit_code = 0
if($result.errors -gt 0 -or $result.warnings -gt 0)
{
	$exit_code = 1
}

# Возврат значений

$errors = $result.errors
$warnings = $result.warnings
$message = $result.messages -join "`r`n"

Write-Debug ('Errors: {0}, Warnings: {1}, Messages: {2}' -f $errors, $warnings, $message)
