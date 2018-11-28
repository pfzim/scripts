# Update folders permissions

if((Get-PSSnapin -Name Microsoft.SharePoint.PowerShell -ErrorAction SilentlyContinue) -eq $null)
{
	Add-PSSnapin Microsoft.SharePoint.PowerShell
}

Clear-Host
Get-Date -format "dd.MM.yyyy HH:mm:ss"

$portals = @("http://sharepoint.contoso.com/")
$libs = @("Document Library 1")

foreach($portal in $portals)
{
    $web = Get-SPWeb -Identity $portal
    
    $global_read_user = $web.SiteGroups["G_Portal_RO"]
    $global_write_user = $web.SiteGroups["G_Portal_RW"]

    foreach($lib in $libs)
    {
        $list = $web.Lists[$lib]

		$sQuery = New-Object Microsoft.SharePoint.SPQuery
		$caml = "<Where><Eq><FieldRef Name='ContentType' /><Value Type='Computed'>Папка</Value></Eq></Where>"
		$sQuery.Query = $caml
		$fItems = $list.GetItems($sQuery)
        $count = $fItems.Count
        Write-Host -ForegroundColor Green ("Count: " + $count)

        foreach($item in $fItems)
        {
            $found_bu_ro = $false
            $found_bu_rw = $false
            $found_portal_ro = $false
            $found_portal_rw = $false
            $found_others = $false

            $bu = $item.Name

            if($bu -notmatch "^\d+$")
            {
                Write-Host -ForegroundColor Red ("  Invalid folder name: " + $bu)
				continue
            }
            
			if($bu -ne "640052")
            {
                #continue
            }

            Write-Host -ForegroundColor Green ("Folder: " + $bu)
            
            if(-not $item.HasUniqueRoleAssignments)
            {
                Write-Host -ForegroundColor DarkYellow ("  Not unique permissions")

			    $item.BreakRoleInheritance($true)
			    while($item.RoleAssignments.Count -gt 0) 
			    {
				    $item.RoleAssignments.Remove(0)
			    }
            }
            else
            {
                foreach($role in $item.RoleAssignments)
                {
                    if($role.Member.Name -match ("g_sp_bu_" + $bu + "_ro$"))
                    {
                        $found_bu_ro = $true
                    }
                    elseif($role.Member.Name -match ("g_sp_bu_" + $bu + "_rw$"))
                    {
                        $found_bu_rw = $true
                    }
                    elseif($role.Member.Name -match "g_portal_ro$")
                    {
                        $found_portal_ro = $true
                    }
                    elseif($role.Member.Name -match "g_portal_rw$")
                    {
                        $found_portal_rw = $true
                    }
                    else
                    {
                        $found_others = $true
                        Write-Host -ForegroundColor Red ("  Other permissions set: " + $role.Member.Name)
                    }
                }
            }

            if(-not $found_others)
            {
                #Write-Host -ForegroundColor Red ("  Other permissions set")
            }
			
			if(-not $found_bu_rw -or -not $found_bu_ro -or -not $found_portal_rw -or -not $found_portal_ro)
            {
				if(-not $found_bu_rw)
				{
					Write-Host -ForegroundColor DarkYellow ("  G_SP_BU_RW not set")
					try
					{
						$x = Get-ADGroup -Identity ("G_SP_BU_" + $bu + "_RW") -ErrorAction Stop
						$user = $web.EnsureUser("G_SP_BU_" + $bu + "_RW")
					}
					catch
					{
						$user = $null
						Write-Host -ForegroundColor Red ("  AD group not found: G_SP_BU_" + $bu + "_RW")
					}

					if($user)
					{
						Write-Host -ForegroundColor Green ("  G_SP_BU_" + $bu + "_RW")
						$roleAssignment = New-Object microsoft.sharepoint.SPRoleAssignment($user)
						$roleAssignment.RoleDefinitionBindings.Add($web.RoleDefinitions["Edit"])
						$item.RoleAssignments.Add($roleAssignment)
					}
				}

				if(-not $found_bu_ro)
				{
					Write-Host -ForegroundColor DarkYellow ("  G_SP_BU_RO not set")
					try
					{
						$x = Get-ADGroup -Identity ("G_SP_BU_" + $bu + "_RO") -ErrorAction Stop
						$user = $web.EnsureUser("G_SP_BU_" + $bu + "_RO")
					}
					catch
					{
						$user = $null
						Write-Host -ForegroundColor Red ("  AD group not found: G_SP_BU_" + $bu + "_RO")
					}

					if($user)
					{
						Write-Host -ForegroundColor Green ("  G_SP_BU_" + $bu + "_RO")
						$roleAssignment = New-Object microsoft.sharepoint.SPRoleAssignment($user)
						$roleAssignment.RoleDefinitionBindings.Add($web.RoleDefinitions["Read"])
						$item.RoleAssignments.Add($roleAssignment)
					}
				}

				if(-not $found_portal_rw)
				{
					Write-Host -ForegroundColor DarkYellow ("  G_Portal_RW not set")

					$roleAssignment = New-Object microsoft.sharepoint.SPRoleAssignment($global_write_user)
					$roleAssignment.RoleDefinitionBindings.Add($web.RoleDefinitions["Edit"])
					$item.RoleAssignments.Add($roleAssignment)
				}

				if(-not $found_portal_ro)
				{
					Write-Host -ForegroundColor DarkYellow ("  G_Portal_RO not set")

					$roleAssignment = New-Object microsoft.sharepoint.SPRoleAssignment($global_read_user)
					$roleAssignment.RoleDefinitionBindings.Add($web.RoleDefinitions["Read"])
					$item.RoleAssignments.Add($roleAssignment)
				}

				$item.Update()
			}
        }
    }

    $web.Dispose()
}

Get-Date -format "dd.MM.yyyy HH:mm:ss"
