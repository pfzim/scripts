$count = 10

Clear-Host
$users = Get-ADUser -Filter * -Properties LogonWorkstations -SearchBase "OU=Магазины,OU=Company,DC=contoso,DC=com"
foreach($user in $users)
{
    $user_name = $user.SamAccountName
    if($user_name -match '^\d{6}k?$')
    {
        $update = 0
        $comps = @()
        if($user.LogonWorkstations)
        {
            $comps += $user.LogonWorkstations -split ','
        }

        $filter = ($user_name[0]+$user_name[1]+'-'+$user_name[2]+$user_name[3]+$user_name[4]+$user_name[5]+'-*')
        $exist_comps = @(Get-ADComputer -Filter {Name -like $filter})
        foreach($comp in $exist_comps)
        {
            if($comp.Name -notin $comps)
            {
                $comps += $comp.Name
                $update = 1
            }
        }

        if($update)
        {
            ($user_name + ' : ' + ($comps -join ','))
            #Set-ADUser -Identity $user_name -LogonWorkstations ($comps -join ',')
			
			$count--
			if($count -le 0)
			{
				break
			}
        }
    }
}
