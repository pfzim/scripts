$region = ""
$user = ""

$list = @{
	"11" = "CN=Магазины – 11_Республика_Коми,OU=Groups,OU=11_Республика_Коми,OU=Магазины,OU=Company,DC=contoso,DC=com";
	"12" = "CN=Магазины – 12_Республика_Марий_Эл,OU=Groups,OU=12_Республика_Марий_Эл,OU=Магазины,OU=Company,DC=contoso,DC=com";
	"13" = "CN=Магазины – 13_Республика_Мордовия,OU=Groups,OU=13_Республика_Мордовия,OU=Магазины,OU=Company,DC=contoso,DC=com";
	"16" = "CN=Магазины – 16_Республика_Татарстан,OU=Groups,OU=16_Республика_Татарстан,OU=Магазины,OU=Company,DC=contoso,DC=com";
	"18" = "CN=Магазины – 18_Республика_Удмуртия,OU=Groups,OU=18_Республика_Удмуртия,OU=Магазины,OU=Company,DC=contoso,DC=com";
	"21" = "CN=Магазины – 21_Республика_Чувашия,OU=Groups,OU=21_Республика_Чувашия,OU=Магазины,OU=Company,DC=contoso,DC=com";
	"24" = "CN=Магазины – 24_Красноярский_край,OU=Groups,OU=24_Красноярский_край,OU=Магазины,OU=Company,DC=contoso,DC=com";
	"29" = "CN=Магазины – 29_Архангельская_область,OU=Groups,OU=29_Архангельская_область,OU=Магазины,OU=Company,DC=contoso,DC=com";
	"32" = "CN=Магазины – 32_Брянская_область,OU=Groups,OU=32_Брянская_область,OU=Магазины,OU=Company,DC=contoso,DC=com";
	"33" = "CN=Магазины – 33_Владимирская_область,OU=Groups,OU=33_Владимирская_область,OU=Магазины,OU=Company,DC=contoso,DC=com";
	"34" = "CN=Магазины – 34_Волгоградская_область,OU=Groups,OU=34_Волгоградская_область,OU=Магазины,OU=Company,DC=contoso,DC=com";
	"35" = "CN=Магазины – 35_Вологодская_область,OU=Groups,OU=35_Вологодская_область,OU=Магазины,OU=Company,DC=contoso,DC=com";
	"36" = "CN=Магазины – 36_Воронежская_область,OU=Groups,OU=36_Воронежская_область,OU=Магазины,OU=Company,DC=contoso,DC=com";
	"37" = "CN=Магазины – 37_Ивановская_область,OU=Groups,OU=37_Ивановская_область,OU=Магазины,OU=Company,DC=contoso,DC=com";
	"40" = "CN=Магазины – 40_Калужская_область,OU=Groups,OU=40_Калужская_область,OU=Магазины,OU=Company,DC=contoso,DC=com";
	"43" = "CN=Магазины – 43_Кировская_область,OU=Groups,OU=43_Кировская_область,OU=Магазины,OU=Company,DC=contoso,DC=com";
	"44" = "CN=Магазины – 44_Костромская_область,OU=Groups,OU=44_Костромская_область,OU=Магазины,OU=Company,DC=contoso,DC=com";
	"51" = "CN=Магазины – 51_Мурманская_область,OU=Groups,OU=51_Мурманская_область,OU=Магазины,OU=Company,DC=contoso,DC=com";
	"52" = "CN=Магазины – 52_Нижегородская_область,OU=Groups,OU=52_Нижегородская_область,OU=Магазины,OU=Company,DC=contoso,DC=com";
	"55" = "CN=Магазины – 55_Омская_область,OU=Groups,OU=55_Омская_область,OU=Магазины,OU=Company,DC=contoso,DC=com";
	"57" = "CN=Магазины – 57_Орловская_область,OU=Groups,OU=57_Орловская_область,OU=Магазины,OU=Company,DC=contoso,DC=com";
	"58" = "CN=Магазины – 58_Пензенская_область,OU=Groups,OU=58_Пензенская_область,OU=Магазины,OU=Company,DC=contoso,DC=com";
	"59" = "CN=Магазины – 59_Пермский_край,OU=Groups,OU=59_Пермский_край,OU=Магазины,OU=Company,DC=contoso,DC=com";
	"60" = "CN=Магазины – 60_Псковская_область,OU=Groups,OU=60_Псковская_область,OU=Магазины,OU=Company,DC=contoso,DC=com";
	"61" = "CN=Магазины – 61_Ростовская_область,OU=Groups,OU=61_Ростовская_область,OU=Магазины,OU=Company,DC=contoso,DC=com";
	"62" = "CN=Магазины – 62_Рязанская_область,OU=Groups,OU=62_Рязанская_область,OU=Магазины,OU=Company,DC=contoso,DC=com";
	"63" = "CN=Магазины – 63_Самарская_область,OU=Groups,OU=63_Самарская_область,OU=Магазины,OU=Company,DC=contoso,DC=com";
	"64" = "CN=Магазины – 64_Саратовская_область,OU=Groups,OU=64_Саратовская_область,OU=Магазины,OU=Company,DC=contoso,DC=com";
	"66" = "CN=Магазины – 66_Свердловская_область,OU=Groups,OU=66_Свердловская_область,OU=Магазины,OU=Company,DC=contoso,DC=com";
	"67" = "CN=Магазины – 67_Смоленская_область,OU=Groups,OU=67_Смоленская_область,OU=Магазины,OU=Company,DC=contoso,DC=com";
	"68" = "CN=Магазины – 68_Тамбовская_область,OU=Groups,OU=68_Тамбовская_область,OU=Магазины,OU=Company,DC=contoso,DC=com";
	"69" = "CN=Магазины – 69_Тверская_область,OU=Groups,OU=69_Тверская_область,OU=Магазины,OU=Company,DC=contoso,DC=com";
	"71" = "CN=Магазины – 71_Тульская_область,OU=Groups,OU=71_Тульская_область,OU=Магазины,OU=Company,DC=contoso,DC=com";
	"72" = "CN=Магазины – 72_Тюменская_область,OU=Groups,OU=72_Тюменская_область,OU=Магазины,OU=Company,DC=contoso,DC=com";
	"73" = "CN=Магазины – 73_Ульяновская_область,OU=Groups,OU=73_Ульяновская_область,OU=Магазины,OU=Company,DC=contoso,DC=com";
	"74" = "CN=Магазины – 74_Челябинская_область,OU=Groups,OU=74_Челябинская_область,OU=Магазины,OU=Company,DC=contoso,DC=com";
	"76" = "CN=Магазины – 76_Ярославская_область,OU=Groups,OU=76_Ярославская_область,OU=Магазины,OU=Company,DC=contoso,DC=com";
	"77" = "CN=Магазины – 77_Московская_область,OU=Groups,OU=77_Москва_и_Московская_область,OU=Магазины,OU=Company,DC=contoso,DC=com";
	"83" = "CN=Магазины – 83_Ненецкий_автономный_округ,OU=Groups,OU=83_Ненецкий_автономный_округ,OU=Магазины,OU=Company,DC=contoso,DC=com";
	"86" = "CN=Магазины – 86_Ханты-Мансиийский_автономный_округ,OU=Groups,OU=86_Ханты-Мансийский_автономный_округ,OU=Магазины,OU=Company,DC=contoso,DC=com";
}

if($list[$region])
{
	Add-ADGroupMember -Identity $list[$region] -Members $user
}
