$user_name = ""
$comp_name = ""

$result = 1

if($user_name -match '^\d{6}k?$')
{
	$user = 0
	$user = Get-ADUser -Identity $user_name -Properties LogonWorkstations
	if($user)
	{
		$user_name = $user.SamAccountName
		if($user_name -match '^\d{6}k?$')
		{
			$comps = @()
			if($user.LogonWorkstations)
			{
				$comps += $user.LogonWorkstations -split ','
			}
			
			$comps += $comp_name

			Set-ADUser -Identity $user_name -LogonWorkstations ($comps -join ',')

			$result = 0
		}
	}
}
