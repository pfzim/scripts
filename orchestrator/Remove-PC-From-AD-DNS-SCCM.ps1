$global:compname = ""

$global:result = 1
$global:error_msg = ""

function main()
{
	if($global:compname -notmatch '^\d\d-\d\d\d\d-\d+$')
	{
		$global:error_msg = "Неправильное имя ПК. Формат: NN-NNNN-N"
		return
	}

	$comp = 0
	try
	{
		$comp = Get-ADComputer -Identity $global:compname
	}
	catch
	{
		$global:error_msg += "ПК не найден в AD;`r`n"
	}

	try
	{
		if($comp)
		{
			Remove-ADComputer -Identity $comp -Confirm:$false
		}
	}
	catch
	{
		$global:result = 2
		$global:error_msg += "Ошибка удаления записи из AD;`r`n"
	}

	$dns = 0

	try
	{
		$dns = Get-DnsServerResourceRecord -ComputerName srv-dc-01 -ZoneName "contoso.com" -Name $global:compname -ErrorAction SilentlyContinue
	}
	catch
	{
		$global:error_msg += "Запись в DNS не найдена;`r`n"
	}

	try
	{
		if($dns)
		{
			$dns | Remove-DnsServerResourceRecord -ComputerName srv-dc-01 -ZoneName "contoso.com" -Force
		}
		else
		{
			$global:error_msg += "Запись в DNS не найдена;`r`n"
		}
	}
	catch
	{
		$global:result = 2
		$global:error_msg += "Ошибка удаления DNS записи;`r`n"
	}

	$sccmServer='srv-sccm-01.contoso.com'
	$sccmSite='M01'

	$comp = 0

	try
	{
		$comp = get-wmiobject -query "select * from SMS_R_SYSTEM WHERE Name='$global:compname'" -computername $sccmServer -namespace "ROOT\SMS\site_$sccmSite"
	}
	catch
	{
		$global:error_msg += "Запись в SCCM не найдена;`r`n"
	}

	try
	{
		if($comp)
		{
			$comp.psbase.delete()
		}
		else
		{
			$global:error_msg += "Запись в SCCM не найдена;`r`n"
		}
	}
	catch
	{
		$global:result = 2
		$global:error_msg += "Ошибка удаления записи из SCCM;`r`n"
	}

	if($global:result -ne 2)
	{
		$global:result = 0
	}
	else
	{
		$global:result = 1
	}
}

main
