# ����� ������ ����������������� �����. ������� ���������� ������ Invoke-Command ��� ����������� � ���������� �������

$global:g_config = @{

	# ��������� �����

	exch_conn_uri = 'https://outlook.contoso.com/powershell/'
	owa_link = 'https://webmail.contoso.com/owa'
	
	# OU ��� ��������� ������ ��������
	ou_mailgroups = 'OU=������� ��������,OU=��������,DC=contoso,DC=com'

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

	# ������ ������������ ����� �� ������� ���� �� (���������� ���������)
	name_pc_tt_and_office_regex = '^(:?\d{2}-\d{4}-[VvMm]?\d+)|(:?\d{4}-[WwNn]\d{4})|(:?\[WwNn]\d{3}-[WwNn]\d{3}-\d{2})|(:?[Rr][Cc]\d-[Uu][Tt][Mm]-\d{2})$'
	
	# ����� VMM �������
	vmm_server = 'srv-vmm-01.contoso.com'

	# ������ FTP ��������
	ftp_servers = @('srv-ftp-01.contoso.com','srv-ftp-02.contoso.com','srv-ftp-01.contoso.com','srv-ftp-02.contoso.com')
	ftp_creds = New-Object System.Management.Automation.PSCredential ('.\scorch', (ConvertTo-SecureString '' -AsPlainText -Force))
	ftp_logs_dir = @('C:\inetpub\logs\LogFiles\')

	# OWA Auth group
	owa_group = "CN=OWACert,OU=������ � OWA,OU=AccessGroups,OU=Groups,OU=MSK,DC=contoso,DC=com"

	# ����� SFB �������
	sfb_conn_uri = 'https://srv-sfb-01.contoso.com/OcsPowershell'

	# ��� ��� ����������� ��������������
	sfb_pool = 'srv-sfb-01.contoso.com'

	# ����� ������� NetBackup. ������������ � ������� ������������ ������ ������ ��� ������
	netbackup_server = 'srv-nb-01.contoso.com'

	# ����� ��������
	helpdesk_url = 'http://helpdesk.contoso.com'

	# ����� ��� ��������
	cdb_url = 'http://web.contoso.com'

	# ����� � ���������� ����������������� �������. ������������ � ������� �������� ������ �������������
	user_folders = @('\\contoso.com\Users\Personal', '\\contoso.com\Common\Users')
	uo_disabled = 'OU=Disabled Accounts,DC=contoso,DC=com'

	# ����� � ������� ����� ����������� ���������������� ������. ������������ � ������� �������� ������ �������������
	export_path = '\\contoso.com\Users\ExportUserData'
	
	# ���������� ��������� ��� �������� UO � ������� ����� ��������� ������������� (������ ���������� �����������)
	ou_can_disable_users_regexp = '((OU=�������,DC=contoso,DC=com$)|(OU=Company,DC=contoso,DC=com))$'
	
	# � ����� OU ��������� ��������� ������� ������ ����������� (���������� ���������)
	ou_can_disable_computer_regexp = 'OU=Company,DC=contoso,DC=com$'
	
	# ������ ����������� ��������� �������
	ad_vba_allow_group = 'gpo_��������� VBA ��� Office'

	# ���� � UPD �������� �������������. ������������ � �������� ������������ �����
	upd_path = '\\contoso.com\UPD\'

	# ���� � ������ �������� �������������� ������������ ��������� ���� �� ��
	gpo_local_groups_path = 'SYSVOL\contoso.com\Policies\{00D81F00-AC85-4F56-A914-BAAAAAAAAAAD}'

	# ���� � ���������� ������������ ����������� . ������������ � ������� "������� _������������ "
	rc1_scanpath = '\\contoso.com\Common\_������������\'

	# ���� � ���������� ������������ ����������� . ������������ � ������� "������� _�����"
	conn_scanpath = '\\contoso.com\Common\M\_�����\'

	# ���� � ��� ���� �����. ������������ � ������� "������� Common ����"
	tof_path = '\\contoso.com\Common\T\'

	# ���� Common Global. ������������ � ������� "������� Common Global"
	common_path = '\\contoso.com\C\'

	# ����������� �������������� �� ������� ������ ����������
	clean_warning = '!��������! ����� ��������� ������������� ��� � �����.txt' 
	
	tmao_03_server = 'srv-ao-03.contoso.com'
	tmao_03_dbname = 'srv-AO-03-ApexOne'

	tmao_01_server = 'srv-ao-01.contoso.com'
	tmao_01_dbname = 'srv-AO-01-ApexOne'
	
	# ��������� SCCM
	sccm_server = 'srv-sccm-01.contoso.com'
	sccm_site = 'M01'
	
	# ����������� ����������� ���������� ������ ������������ ����, ����� ��������������� ����������
	tmao_pattern_version_lag = 6000

	# Exchange ������� ��� ���������� �������� �������
	rules_out = @('��������� � ��������', '��������� � �������� 2', '��������� � �������� 3')
	rules_in = @('��������� �� ���������', '��������� �� ��������� 2', '��������� �� ��������� 3')
	
	# ������ ����������� � ��������� ���� � ����������
	exch_quotas = @('1', '2', '4', '8', 'unlim')

	# ��������� ������������
	scorch_url = 'http://srv-sco-01.contoso.com:81/Orchestrator2012'
	scorch_db_server = 'srv-sco-01'
	scorch_db_name = 'Orchestrator'
	
	# ������ ������� ������������
	ca_servers = @("srv-ca-01.contoso.com\contoso Issuing CA1", "srv-ca-02.contoso.com\contoso Issuing CA2")
	
	# ��������� DNS
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
	
	welcome_subject = '����� ����������'
	
	# list_company ������������ � ������� �������� �� �������������

	list_company = @{
		"sb" = @{
			domain = "domain1.ru";
			path = "OU=Users,OU=��� ��,OU=Company,DC=contoso,DC=com";
			name = "��� ��";
			city = "�";
			subscribe = "CN=�������� - ��� ���������� ��� ��,OU=��� ��,OU=��������,DC=contoso,DC=com";
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
			path = "OU=Users,OU=������,OU=Company,DC=contoso,DC=com";
			name = "��� �";
			city = "�";
			subscribe = "CN=�������� - ��� ���������� ��� �,OU=��� �,OU=��������,DC=contoso,DC=com";
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
			path = "OU=Users,OU=��� �,OU=Company,DC=contoso,DC=com";
			name = "��� �";
			city = $null;
			subscribe = "CN=�������� - ��� ���������� ��� �,OU=��� �,OU=��������,DC=contoso,DC=com";
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
			path = "OU=Users,OU=��� �,OU=Company,DC=contoso,DC=com";
			name = "��� �";
			city = "������-��-����";
			subscribe = "CN=�������� - ��� ���������� '��� �',OU=��� �,OU=��������,DC=contoso,DC=com";
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
			path = "OU=Users,OU=��,OU=Company,DC=contoso,DC=com";
			name = "��� `"�`"";
			city = "������";
			subscribe = "CN=�������� - ��� ���������� ��,OU=������ ��,OU=��������,DC=contoso,DC=com";
			groups = @("������ ������������ - ��� ���������� ��", "G_FS_MSK_Common_RW");
			welcome = "C:\Orchestrator\template\mail\b\index.html";
			attachments = @('C:\Orchestrator\template\mail\b\top.png', 'C:\Orchestrator\template\mail\b\���������� 1.pdf');
			mail = $true;
			lync = $true;
			dfs_link = $null;
			profile_servers = $null;
		};
		"nn" = @{
			domain = "contoso.com";
			path = "OU=Users,OU=��,OU=Company,DC=contoso,DC=com";
			name = "��� `"�`"";
			city = "������ ��������";
			subscribe = "CN=�������� - ��� ���������� ��,OU=��,OU=��������,DC=contoso,DC=com";
			groups = @("G-RODC_Cached_Accounts_Users", "�������������� ����� ��");
			welcome = "C:\Orchestrator\template-mail-a\index.html";
			attachments = @("C:\Orchestrator\template-mail-a\ph.png", "C:\Orchestrator\template-mail-a\top.png", "C:\Orchestrator\template-mail-a\���������� 1.pdf", "C:\Orchestrator\template-mail-a\���������� 2.pdf", "C:\Orchestrator\template-mail-a\����� ���������� ����������.png");
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
			path = "OU=Users,OU=�� �,OU=Company,DC=contoso,DC=com";
			name = "��� `"TT`"";
			city = "������������";
			subscribe = "CN=�������� - ��� ���������� �� �,OU=� ��,OU=��������,DC=contoso,DC=com";
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
			path = "OU=����� ������������,OU=����,OU=Company,DC=contoso,DC=com";
			name = "��� `"�`"";
			city = $null;
			subscribe = "CN=�������� - ��� ���������� �,OU=����,OU=��������,DC=contoso,DC=com";
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
			path = "OU=_����� ���������,OU=������� ������������,DC=contoso,DC=com";
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
			path = "OU=����� �������� ��,OU=Service Accounts,DC=contoso,DC=com";
			#path = "OU=����� �����,DC=contoso,DC=com";
			name = "�";
			city = "������";
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
			path = "OU=���������,OU=Service Accounts,DC=contoso,DC=com";
			name = "�";
			city = "������";
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

	# list_tof ������ OU ����� ��������������� ���� �������

	list_tof = @{
		"10" = "OU=����������_�������,OU=����,OU=Company,DC=contoso,DC=com";
		"11" = "OU=����������_����,OU=����,OU=Company,DC=contoso,DC=com";
		"12" = "OU=����������_�����_��,OU=����,OU=Company,DC=contoso,DC=com";
	}

	# list_shops ������ OU ��������������� ���� �������

	list_shops = @{
		"10" = "OU=����������_�������,OU=Company,DC=contoso,DC=com";
		"11" = "OU=����������_����,OU=Company,DC=contoso,DC=com";
		"12" = "OU=����������_�����_��,OU=Company,DC=contoso,DC=com";
		"99" = "OU=�������� ������,OU=Company,DC=contoso,DC=com";
	}

	# groups_shops ������ ����� ������� ��������������� ���� �������

	groups_shops = @{
		"10" = "CN=� � ����������_�������,OU=Groups,OU=10_����������_�������,OU=Company,DC=contoso,DC=com";
		"11" = "CN=� � ����������_����,OU=Groups,OU=11_����������_����,OU=Company,DC=contoso,DC=com";
		"12" = "CN=� � ����������_�����_��,OU=Groups,OU=12_����������_�����_��,OU=Company,DC=contoso,DC=com";
	}
}
