$portal = "test-portal-02.contoso.com"
$export_file = ("c:\_backup\backup-map-" + $portal + "-" + (Get-Date -format "yyyy-MM-dd-HHmmss") + ".csv")

if((Get-PSSnapin -Name Microsoft.SharePoint.PowerShell -ErrorAction SilentlyContinue) -eq $null)
{
	Add-PSSnapin Microsoft.SharePoint.PowerShell
}

$spWeb = Get-SPWeb -Identity ("http://" + $portal + "/")
$list = $spWeb.Lists["Map"]
$caml=""
 
$query=new-object Microsoft.SharePoint.SPQuery
$query.ViewAttributes = "Scope='Recursive'"
$query.Query=$caml
$items=$list.GetItems($query)

foreach($item in $items)
{
	Add-Content -Path $export_file -Value ($item["Unit"] + "," + $item["WriterUser"].LookupValue + "," + $item["ReaderUser"].LookupValue)
}

$spWeb.Dispose()
