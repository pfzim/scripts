# list_company

$global:list_company = @{
	"co" = @{
		domain = "contoso.com";
		path = "OU=Users,OU=Contoso,OU=Company,DC=contoso,DC=com";
		name = "JSC Contoso";
		city = "NY";
		subscribe = $null;
		groups = $null;
		welcome = $null;
		attachments = $null;
		mail = $true;
		lync = $true;
	};
	"ex" = @{
		domain = "example.org";
		path = "OU=Users,OU=Example,OU=Company,DC=contoso,DC=com";
		name = "JSC Example";
		city = "Moscow";
		subscribe = $null;
		groups = $null;
		welcome = $null;
		attachments = $null;
		mail = $true;
		lync = $true;
	};
}

# list_tof

$global:list_tof = @{
	"10" = "OU=10_Республика_Карелия,OU=Office,OU=Company,DC=contoso,DC=com";
	"11" = "OU=11_Республика_Коми,OU=Ofiice,OU=Company,DC=contoso,DC=com";
	"12" = "OU=12_Республика_Марий_Эл,OU=Office,OU=Company,DC=contoso,DC=com";
}

# list_shops

$global:list_shops = @{
	"10" = "OU=10_Республика_Карелия,OU=Shops,OU=Company,DC=contoso,DC=com";
	"11" = "OU=11_Республика_Коми,OU=Shops,OU=Company,DC=contoso,DC=com";
	"12" = "OU=12_Республика_Марий_Эл,OU=Shops,OU=Company,DC=contoso,DC=com";
}

# groups_shops

$global:groups_shops = @{
	"10" = "CN=10_Республика_Карелия,OU=Groups,OU=10_Республика_Карелия,OU=Shops,OU=Company,DC=contoso,DC=com";
	"11" = "CN=11_Республика_Коми,OU=Groups,OU=11_Республика_Коми,OU=Shops,OU=Company,DC=contoso,DC=com";
	"12" = "CN=12_Республика_Марий_Эл,OU=Groups,OU=12_Республика_Марий_Эл,OU=Shops,OU=Company,DC=contoso,DC=com";
}

# gpo_local_groups_path

$global:gpo_local_groups_path = '\\contoso.com\SYSVOL\contoso.com\Policies\{70001006-A080-4006-A010-B030E6040600}'

# Настройки почты

$global:smtp_server = 'smtp.contoso.com'
$global:smtp_from = 'orchestrator@contoso.com'
$global:admin_email = 'admin@contoso.com'
$global:helpdesk_email = 'helpdesk@contoso.com'
$global:techsupport_email = 'techsupport@contoso.com'
$global:useraccess_email = 'UserAccess@contoso.com'
