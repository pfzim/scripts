$web = Get-SPWeb http://test-portal.contoso.com
$list = $web.Lists["DocLibName"]
$assoc = $list.WorkFlowAssociations | Where { $_.Name -eq "WorkflowName"}
$data = $assoc.AssociationData
$assoc.AllowAsyncManualStart = $true
$manager = $web.Site.WorkflowManager
$sQuery = New-Object Microsoft.SharePoint.SPQuery
$caml = '<Where><Gt><FieldRef Name="ID" /><Value Type="Counter">0</Value></Gt></Where>'
$sQuery.Query = $caml
$fItems = $list.GetItems($sQuery)
Foreach($item in $fItems)
{
	$res = $manager.StartWorkflow($item,$assoc,$data,$true)
    Write-Host -ForegroundColor Green ("Start on item " + $item.Name)
}

$manager.Dispose()
$web.Dispose()
