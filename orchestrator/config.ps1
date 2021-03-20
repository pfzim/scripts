# Новая версия конфигурационного файла. Удобнее передавать внутрь Invoke-Command при подключенни к удаленному серверу

$global:g_config = @{

	# Настройки почты

	exch_conn_uri = 'https://outlook.contoso.com/powershell/'
	owa_link = 'https://webmail.contoso.com/owa'
	
	# OU где создаются группы рассылки
	ou_mailgroups = 'OU=Созданы ранбуком,OU=Рассылки,DC=contoso,DC=com'

	smtp_server = 'smtp.contoso.com'
	smtp_from = 'orchestrator@contoso.com'

	admin_email = 'admin@contoso.com'
	helpdesk_email = 'hd@contoso.com'
	techsupport_email = 'ts@contoso.com'
	useraccess_email = 'ua@contoso.com'
	uib_email = 'seb@contoso.com'
	ritm_email = 'itman@contoso.com'
	gup_boss_email = 'Aleksander.Testov@contoso.com'
	wt_email = 'wt@contoso.com'

	g_domain = 'contoso'
	rdsfarm = 'srv-rdsfarm-01.contoso.com'

	# Формат соответствия имени ПК Офисный либо ТТ (регулярное выражение)
	name_pc_tt_and_office_regex = '^(:?\d{2}-\d{4}-[VvMm]?\d+)|(:?\d{4}-[WwNn]\d{4})|(:?\[WwNn]\d{3}-[WwNn]\d{3}-\d{2})|(:?[Rr][Cc]\d-[Uu][Tt][Mm]-\d{2})$'
	
	# Адрес VMM сервера
	vmm_server = 'srv-vmm-01.contoso.com'

	# Адреса FTP серверов
	ftp_servers = @('srv-ftp-01.contoso.com','srv-ftp-02.contoso.com','srv-ftp-01.contoso.com','srv-ftp-02.contoso.com')
	ftp_creds = New-Object System.Management.Automation.PSCredential ('.\scorch', (ConvertTo-SecureString '' -AsPlainText -Force))
	ftp_logs_dir = @('C:\inetpub\logs\LogFiles\')

	# OWA Auth group
	owa_group = "CN=OWACert,OU=Доступ к OWA,OU=AccessGroups,OU=Groups,OU=MSK,DC=contoso,DC=com"

	# Адрес SFB сервера
	sfb_conn_uri = 'https://srv-sfb-01.contoso.com/OcsPowershell'

	# Пул для регистрации прользователей
	sfb_pool = 'srv-sfb-01.contoso.com'

	# Адрес сервера NetBackup. Используется в ранбуке формирования списка кассет для замены
	netbackup_server = 'srv-nb-01.contoso.com'

	# Адрес ХелпДеск
	helpdesk_url = 'http://helpdesk.contoso.com'

	# Адрес веб сервисов
	cdb_url = 'http://web.contoso.com'

	# Папки с различными пользовательскими данными. Используется в ранбуке экспорта данных пользователей
	user_folders = @('\\contoso.com\Users\Personal', '\\contoso.com\Common\Users')
	uo_disabled = 'OU=Disabled Accounts,DC=contoso,DC=com'

	# Папка в которую будут выгружаться пользовательские данные. Используется в ранбуке экспорта данных пользователей
	export_path = '\\contoso.com\Users\ExportUserData'
	
	# Регулярное выражение для проверки UO в которых можно отключать пользователей (ранбук Увольнение сотрудников)
	ou_can_disable_users_regexp = '((OU=Внешние,DC=contoso,DC=com$)|(OU=Company,DC=contoso,DC=com))$'
	
	# В какой OU разрешено отключать учётные записи компьютеров (регулярное выражение)
	ou_can_disable_computer_regexp = 'OU=Company,DC=contoso,DC=com$'
	
	# Группа разрешающая выполнять макросы
	ad_vba_allow_group = 'gpo_Разрешить VBA для Office'

	# Путь к UPD профилям пользователей. Используется в ранбуках терминальной фермы
	upd_path = '\\contoso.com\UPD\'

	# Путь к файлам политики Предоставление персональных локальных прав на ПК
	gpo_local_groups_path = 'SYSVOL\contoso.com\Policies\{00D81F00-AC85-4F56-A914-BAAAAAAAAAAD}'

	# Путь к директории сканирования сотрудников . Используется в ранбуке "Очистка _Сканирование "
	rc1_scanpath = '\\contoso.com\Common\_Сканирование\'

	# Путь к директории сканирования сотрудников . Используется в ранбуке "Очистка _Сканы"
	conn_scanpath = '\\contoso.com\Common\M\_Сканы\'

	# Путь к СФР всех ТОФов. Используется в ранбуке "Очистка Common ТОФы"
	tof_path = '\\contoso.com\Common\T\'

	# Путь Common Global. Используется в ранбуке "Очистка Common Global"
	common_path = '\\contoso.com\C\'

	# Стандартное предупреждение об очистке данной директории
	clean_warning = '!ВНИМАНИЕ! Папка очищается автоматически раз в сутки.txt' 
	
	tmao_03_server = 'srv-ao-03.contoso.com'
	tmao_03_dbname = 'srv-AO-03-ApexOne'

	tmao_01_server = 'srv-ao-01.contoso.com'
	tmao_01_dbname = 'srv-AO-01-ApexOne'
	
	# Настройки SCCM
	sccm_server = 'srv-sccm-01.contoso.com'
	sccm_site = 'M01'
	
	# Максимально разрешенное отставание версии антивирусной базы, чтобы соответствовать требования
	tmao_pattern_version_lag = 6000

	# Exchange правила для блокировки почтовых адресов
	rules_out = @('Запрещено в интернет', 'Запрещено в интернет 2', 'Запрещено в интернет 3')
	rules_in = @('Запрещено из интернета', 'Запрещено из интернета 2', 'Запрещено из интернета 3')
	
	# Список разрешенных к установке квот в гигабайтах
	exch_quotas = @('1', '2', '4', '8', 'unlim')

	# Настройки Оркестратора
	scorch_url = 'http://srv-sco-01.contoso.com:81/Orchestrator2012'
	scorch_db_server = 'srv-sco-01'
	scorch_db_name = 'Orchestrator'
	
	# Список Центров сертификации
	ca_servers = @("srv-ca-01.contoso.com\contoso Issuing CA1", "srv-ca-02.contoso.com\contoso Issuing CA2")
	
	# Настройки DNS
	dns_server = 'srv-dc-01.contoso.com'
	dns_zone = 'contoso.com'
	
	hosts_3par = @(
		@{
			name = 'srv-STR-02'
			host = '172.18.0.1'
		}
		,
		@{
			name = 'srv-STR-01'
			host = '172.18.0.2'
		}
	)
	
	welcome_subject = 'Добро пожаловать'
	
	# list_company используется в ранбуке Создание УЗ универсальный

	list_company = @{
		"sb" = @{
			domain = "domain1.ru";
			path = "OU=Users,OU=ООО СБ,OU=Company,DC=contoso,DC=com";
			name = "ООО СБ";
			city = "Н";
			subscribe = "CN=Рассылка - Все сотрудники ООО СБ,OU=ООО СБ,OU=Рассылки,DC=contoso,DC=com";
			groups = $null;
			welcome = $null;
			attachments = $null;
			mail = $true;
			lync = $true;
			dfs_link = $null;
			profile_servers = $null;
		};
		"ar" = @{
			domain = "a.ru";
			path = "OU=Users,OU=Ариана,OU=Company,DC=contoso,DC=com";
			name = "ООО А";
			city = "В";
			subscribe = "CN=Рассылка - Все сотрудники ООО А,OU=ООО А,OU=Рассылки,DC=contoso,DC=com";
			groups = $null;
			welcome = $null;
			attachments = $null;
			mail = $true;
			lync = $true;
			dfs_link = $null;
			profile_servers = $null;
		};
		"sr" = @{
			domain = "s.ru";
			path = "OU=Users,OU=ООО С,OU=Company,DC=contoso,DC=com";
			name = "ООО С";
			city = $null;
			subscribe = "CN=Рассылка - Все сотрудники ООО С,OU=ООО С,OU=Рассылки,DC=contoso,DC=com";
			groups = $null;
			welcome = $null;
			attachments = $null;
			mail = $true;
			lync = $true;
			dfs_link = $null;
			profile_servers = $null;
		};
		"tm" = @{
			domain = "s.ru";
			path = "OU=Users,OU=ООО Т,OU=Company,DC=contoso,DC=com";
			name = "ООО Т";
			city = "Ростов-на-Дону";
			subscribe = "CN=Рассылка - Все сотрудники 'ООО Т',OU=ООО Т,OU=Рассылки,DC=contoso,DC=com";
			groups = $null;
			welcome = $null;
			attachments = $null;
			mail = $true;
			lync = $true;
			dfs_link = $null;
			profile_servers = $null;
		};
		"bl" = @{
			domain = "contoso.com";
			path = "OU=Users,OU=БМ,OU=Company,DC=contoso,DC=com";
			name = "ООО `"Б`"";
			city = "Москва";
			subscribe = "CN=Рассылка - Все сотрудники ГМ,OU=Москва ГО,OU=Рассылки,DC=contoso,DC=com";
			groups = @("Доступ пользователи - Все сотрудники ГМ", "G_FS_MSK_Common_RW");
			welcome = "C:\Orchestrator\template\mail\b\index.html";
			attachments = @('C:\Orchestrator\template\mail\b\top.png', 'C:\Orchestrator\template\mail\b\Приложение 1.pdf');
			mail = $true;
			lync = $true;
			dfs_link = $null;
			profile_servers = $null;
		};
		"nn" = @{
			domain = "contoso.com";
			path = "OU=Users,OU=ЦО,OU=Company,DC=contoso,DC=com";
			name = "ООО `"А`"";
			city = "Нижний Новгород";
			subscribe = "CN=Рассылка - Все сотрудники ЦО,OU=ЦО,OU=Рассылки,DC=contoso,DC=com";
			groups = @("G-RODC_Cached_Accounts_Users", "Перенапавление папок ЦО");
			welcome = "C:\Orchestrator\template-mail-a\index.html";
			attachments = @("C:\Orchestrator\template-mail-a\ph.png", "C:\Orchestrator\template-mail-a\top.png", "C:\Orchestrator\template-mail-a\Приложение 1.pdf", "C:\Orchestrator\template-mail-a\Приложение 2.pdf", "C:\Orchestrator\template-mail-a\Схема внутренней территории.png");
			mail = $true;
			lync = $true;
			dfs_link = '\\contoso.com\Users\NN';
			profile_servers = @(
				@{
					server = 'SRV-FILE-01'
					path = 'D:\Common\Users-01'
					share = '\\srv-file-04\Users-01$'
				},
				@{
					server = 'SRV-FILE-02'
					path = 'D:\Common-03\Users-02'
					share = '\\srv-file-05\Users-02$'
				},
				@{
					server = 'SRV-FILE-03'
					path = 'D:\Common-02\Users-03'
					share = '\\srv-file-06\Users-03$'
				}
			);
		};
		"ek" = @{
			domain = "contoso.com";
			path = "OU=Users,OU=РЦ Е,OU=Company,DC=contoso,DC=com";
			name = "ООО `"TT`"";
			city = "Екатеринбург";
			subscribe = "CN=Рассылка - Все сотрудники РЦ Е,OU=Е РЦ,OU=Рассылки,DC=contoso,DC=com";
			groups = $null;
			welcome = $null;
			attachments = $null;
			mail = $true;
			lync = $true;
			dfs_link = $null;
			profile_servers = $null;
		};
		"tof" = @{
			domain = "contoso.com";
			path = "OU=Новые пользователи,OU=ТОФы,OU=Company,DC=contoso,DC=com";
			name = "ООО `"А`"";
			city = $null;
			subscribe = "CN=Рассылка - Все сотрудники Т,OU=ТОФы,OU=Рассылки,DC=contoso,DC=com";
			groups = $null;
			welcome = $null;
			attachments = $null;
			mail = $true;
			lync = $true;
			dfs_link = $null;
			profile_servers = $null;
		};
		"ext" = @{
			domain = "contoso.com";
			path = "OU=_новый сотрудник,OU=Внешние пользователи,DC=contoso,DC=com";
			name = "Contracted";
			city = $null;
			subscribe = $null;
			groups = $null;
			welcome = $null;
			attachments = $null;
			mail = $true;
			lync = $true;
			dfs_link = $null;
			profile_servers = $null;
		};
		"shared" = @{
			domain = "contoso.com";
			path = "OU=Общие почтовые УЗ,OU=Service Accounts,DC=contoso,DC=com";
			#path = "OU=Общие ящики,DC=contoso,DC=com";
			name = "Б";
			city = "Москва";
			subscribe = $null;
			groups = $null;
			welcome = $null;
			attachments = $null;
			mail = $true;
			lync = $true;
			dfs_link = $null;
			profile_servers = $null;
		};
		"svc" = @{
			domain = "contoso.com";
			path = "OU=Служебные,OU=Service Accounts,DC=contoso,DC=com";
			name = "Б";
			city = "Москва";
			subscribe = $null;
			groups = $null;
			welcome = $null;
			attachments = $null;
			mail = $false;
			lync = $false;
			dfs_link = $null;
			profile_servers = $null;
		}
	}

	# list_tof список OU ТОФов соответствующих коду региона

	list_tof = @{
		"10" = "OU=Республика_Карелия,OU=ТОФы,OU=Company,DC=contoso,DC=com";
		"11" = "OU=Республика_Коми,OU=ТОФы,OU=Company,DC=contoso,DC=com";
		"12" = "OU=Республика_Марий_Эл,OU=ТОФы,OU=Company,DC=contoso,DC=com";
	}

	# list_shops список OU соответствующих коду региона

	list_shops = @{
		"10" = "OU=Республика_Карелия,OU=Company,DC=contoso,DC=com";
		"11" = "OU=Республика_Коми,OU=Company,DC=contoso,DC=com";
		"12" = "OU=Республика_Марий_Эл,OU=Company,DC=contoso,DC=com";
		"99" = "OU=Тестовый регион,OU=Company,DC=contoso,DC=com";
	}

	# groups_shops список групп доступа соответствующих коду региона

	groups_shops = @{
		"10" = "CN=М – Республика_Карелия,OU=Groups,OU=10_Республика_Карелия,OU=Company,DC=contoso,DC=com";
		"11" = "CN=М – Республика_Коми,OU=Groups,OU=11_Республика_Коми,OU=Company,DC=contoso,DC=com";
		"12" = "CN=М – Республика_Марий_Эл,OU=Groups,OU=12_Республика_Марий_Эл,OU=Company,DC=contoso,DC=com";
	}
}
