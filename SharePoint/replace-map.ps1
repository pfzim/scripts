if((Get-PSSnapin -Name Microsoft.SharePoint.PowerShell -ErrorAction SilentlyContinue) -eq $null)
{
	Add-PSSnapin Microsoft.SharePoint.PowerShell
}

$spWeb = Get-SPWeb -Identity "http://test-portal-02.contoso.com/"
$list = $spWeb.Lists["Map"]
$csv = Import-Csv "C:\_backup\backup-map.csv" -Encoding Default -Header "Unit", "RW", "RO"
$caml=""
 
$query=new-object Microsoft.SharePoint.SPQuery
$query.ViewAttributes = "Scope='Recursive'"
$query.Query=$caml
$items=$list.GetItems($query)

$items | % { $list.GetItemById($_.Id).Delete() }

foreach($row in $csv)
{
	try
	{
		$item = $list.Items.Add();
		$item["Unit"] = $row.Unit;
		$item["WriterUser"] = $spWeb.EnsureUser($row.RW);
		$item["ReaderUser"] = $spWeb.EnsureUser($row.RO);
		$item.Update();
	}
	catch
	{
		Write-Host -ForegroundColor Red ("FAILED - " + $row.Unit)
	}
}

$spWeb.Dispose()
