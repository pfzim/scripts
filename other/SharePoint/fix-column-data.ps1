cls
$web = Get-SPWeb http://test-portal.contoso.com
$list = $web.Lists["DocLibName"]
$items = $list.Items
foreach($item in $items)
{
    if($item["ColumnName"] -notmatch "^\d*$")
    {
        if($item["ColumnName"] -match ">[^\d<>]*(\d+)[^\d<>]*<")
        {
            $new_bu = $matches[1]
            ("ID: " + $item.id + " BU: " + $item["ColumnName"] + " -> " + $new_bu)
            $item["ColumnName"] = $new_bu
            $item.Update()
            write-host  -ForegroundColor green $item.id " - Updated" 
        }
    }
}
