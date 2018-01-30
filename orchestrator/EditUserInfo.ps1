$user_sam = ""
$givenName = ""
$sn = ""
$displayName = ""
$company = ""
$department = ""
$title = ""
$extensionAttribute1 = ""

$res_gn = 0
$res_sn = 0
$res_dn = 0
$res_cm = 0
$res_dp = 0
$res_tl = 0
$res_ea = 0

$user = Get-ADUser $user_sam

if($user)
{
	if($givenName)
	{
		$result = Set-ADUser -Identity $user -GivenName $givenName -PassThru
		if($result)
		{
			$res_gn = 1
		}
	}

	if($sn)
	{
		$result = Set-ADUser -Identity $user -Surname $sn -PassThru
		if($result)
		{
			$res_sn = 1
		}
	}

	if($displayName)
	{
		$result = Set-ADUser -Identity $user -DisplayName $displayName -PassThru
		if($result)
		{
			$res_dn = 1
		}
	}

	if($company)
	{
		$result = Set-ADUser -Identity $user -Company $company -PassThru
		if($result)
		{
			$res_cm = 1
		}
	}

	if($department)
	{
		$result = Set-ADUser -Identity $user -Department $department -PassThru
		if($result)
		{
			$res_dp = 1
		}
	}

	if($title)
	{
		$result = Set-ADUser -Identity $user -Title $title -PassThru
		if($result)
		{
			$res_tl = 1
		}
	}

	if($extensionAttribute1)
	{
		$result = Set-ADUser -Identity $user -Replace @{"extensionAttribute1" = $extensionAttribute1} -PassThru
		if($result)
		{
			$res_ea = 1
		}
	}
}
