$user = ""
$bu = ""

$global:result = 1
$global:error_msg = ""

function main()
{
	if($bu -notmatch "^\d+$")
	{
		$global:error_msg = "Неправильный формат БЮ"
		return
	}

	$group = 0
		
	try
	{
		$group = Get-ADGroup -Identity ("G_SP_BU_" + $bu + "_RO")
	}
	catch{}

	if(!$group)
	{
		try
		{
			$group = New-ADGroup -Name ("G_SP_BU_" + $bu + "_RO") -SamAccountName ("G_SP_BU_" + $bu + "_RO") -GroupCategory Security -GroupScope DomainLocal -DisplayName ("G_SP_BU_" + $bu + "_RO") -Path "OU=SPBUGroups,OU=SharePoint,OU=Groups,OU=MSK,DC=contoso,DC=com" -PassThru
		}
		catch
		{
			$global:error_msg = ("Группа G_SP_BU_" + $bu + "_RO не создана")
			return
		}
	}

	$group = 0
	try
	{
		$group = Get-ADGroup -Identity ("G_SP_BU_" + $bu + "_RW")
	}
	catch{}

	if(!$group)
	{
		try
		{
			$group = New-ADGroup -Name ("G_SP_BU_" + $bu + "_RW") -SamAccountName ("G_SP_BU_" + $bu + "_RW") -GroupCategory Security -GroupScope DomainLocal -DisplayName ("G_SP_BU_" + $bu + "_RW") -Path "OU=SPBUGroups,OU=SharePoint,OU=Groups,OU=MSK,DC=contoso,DC=com" -PassThru
		}
		catch
		{
			$global:error_msg = ("Группа G_SP_BU_" + $bu + "_RW не создана")
			return
		}
	}

	if($group)
	{
		try
		{
			Get-ADUser -Identity $user
		}
		catch
		{
			$global:error_msg = ("Пользователь " + $user + " не найден")
			return
		}

		Add-ADGroupMember -Identity $group -Members $user
		Add-Content -Path "C:\Orchestrator\output\bu-sam.csv" -Value ($bu + "," + $user)
		$global:result = 0
		$global:error_msg = "No errors"
	}
}

main
