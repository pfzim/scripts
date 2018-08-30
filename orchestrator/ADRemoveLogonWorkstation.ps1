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
			
			$new_comps = @()
			foreach($comp in $comps)
			{
				if($comp -ne $comp_name)
				{
					$new_comps += $comp
				}
			}

			if($new_comps.Count -gt 0)
			{
				Set-ADUser -Identity $user_name -LogonWorkstations ($new_comps -join ',')
			}
			else
			{
				Set-ADUser -Identity $user_name -LogonWorkstations $null
			}

			$result = 0
		}
	}
}
