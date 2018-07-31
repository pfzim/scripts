if((Get-PSSnapin -Name Microsoft.SharePoint.PowerShell -ErrorAction SilentlyContinue) -eq $null)
{
	Add-PSSnapin Microsoft.SharePoint.PowerShell
}

Clear-Host
Get-Date -format "dd.MM.yyyy HH:mm:ss"

$portals = @("http://nn.contoso.com/", "http://kazan.contoso.com/", "http://central.contoso.com/", "http://moscow.contoso.com/", "http://nord.contoso.com/", "http://omsk.contoso.com/", "http://saratov.contoso.com/", "http://volga.contoso.com/", "http://franch.contoso.com/")
$libs = @("Товарные документы", "Касса", "Инвентаризации", "Выбытие товаров", "Оприходование товаров")

foreach($portal in $portals)
{
    $web = Get-SPWeb -Identity $portal

    foreach($lib in $libs)
    {
        $list = $web.Lists[$lib]
        $fItems = $list.GetItemsWithUniquePermissions()
        $count = $fItems.Count
        Write-Host -ForegroundColor Green ("Count: " + $count)
        $i = 1
        foreach($itemInfo in $fItems)
        {
	        $item = $list.GetItemById($itemInfo.Id) 
	        $item.ResetRoleInheritance() 
            Write-Host -ForegroundColor Green ("Start on item [ " + $i +"/" + $count +" ID: " + $item.Id + "] " + $item.Name)
	        $i++
        }
    }

    $web.Dispose()
}
Get-Date -format "dd.MM.yyyy HH:mm:ss"
