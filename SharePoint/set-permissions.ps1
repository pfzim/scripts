if((Get-PSSnapin -Name Microsoft.SharePoint.PowerShell -ErrorAction SilentlyContinue) -eq $null)
{
	Add-PSSnapin Microsoft.SharePoint.PowerShell
}

Clear-Host
Get-Date -format "dd.MM.yyyy HH:mm:ss"

$portals = @("http://test-portal-02.contoso.com/")
$libs = @("Оприходование товаров")

foreach($portal in $portals)
{
    $web = Get-SPWeb -Identity $portal
    $global_read_user = $web.EnsureUser("G_SP_NN2015_RO")
    $global_write_user = $web.EnsureUser("G_SP_NN2015_RW")

    foreach($lib in $libs)
    {
        $list = $web.Lists[$lib]

		$sQuery = New-Object Microsoft.SharePoint.SPQuery
		$caml = '<Where><Gt><FieldRef Name="ID" /><Value Type="Counter">0</Value></Gt></Where>'
		$sQuery.Query = $caml
		$fItems = $list.GetItems($sQuery)
        $count = $fItems.Count
        Write-Host -ForegroundColor Green ("Count: " + $count)

        foreach($item in $fItems)
        {
            Write-Host -ForegroundColor Green ("Start on item [ " + $i +"/" + $count +" ID: " + $item.Id + "] " + $item.Name)

			$item.BreakRoleInheritance($false)
			while($item.RoleAssignments.Count -gt 0) 
			{
                $item.RoleAssignments.Item(0)
				$item.RoleAssignments.Remove(0)
			}

            $bu = $item["Бизнес юнит"]

            if($bu -notmatch "^\d+$")
            {
                Write-Host -ForegroundColor Red ("BU not defined: " + $bu)
            }
            else
            {
                try
                {
                    $user = $web.EnsureUser("G_SP_BU_" + $bu + "_RW")
                }
                catch
                {
                    $user = $null
                    Write-Host -ForegroundColor Red ("AD group not found: G_SP_BU_" + $bu + "_RW")
                }

                if($user)
                {
                    Write-Host -ForegroundColor Green ("G_SP_BU_" + $bu + "_RW")
			        $roleAssignment = New-Object microsoft.sharepoint.SPRoleAssignment($user)
			        $roleAssignment.RoleDefinitionBindings.Add($web.RoleDefinitions["Full Control"])
			        $item.RoleAssignments.Add($roleAssignment)
                }

                try
                {
                    $user = $web.EnsureUser("G_SP_BU_" + $bu + "_RO")
                }
                catch
                {
                    $user = $null
                    Write-Host -ForegroundColor Red ("AD group not found: G_SP_BU_" + $bu + "_RO")
                }

                if($user)
                {
                    Write-Host -ForegroundColor Green ("G_SP_BU_" + $bu + "_RO")
			        $roleAssignment = New-Object microsoft.sharepoint.SPRoleAssignment($user)
			        $roleAssignment.RoleDefinitionBindings.Add($web.RoleDefinitions["Read"])
			        $item.RoleAssignments.Add($roleAssignment)
                }
            }

		    $roleAssignment = New-Object microsoft.sharepoint.SPRoleAssignment($global_write_user)
		    $roleAssignment.RoleDefinitionBindings.Add($web.RoleDefinitions["Full Control"])
		    $item.RoleAssignments.Add($roleAssignment)

		    $roleAssignment = New-Object microsoft.sharepoint.SPRoleAssignment($global_read_user)
		    $roleAssignment.RoleDefinitionBindings.Add($web.RoleDefinitions["Read"])
		    $item.RoleAssignments.Add($roleAssignment)

			$item.Update()

	        $i++

            break
        }
    }

    $web.Dispose()
}

Get-Date -format "dd.MM.yyyy HH:mm:ss"
