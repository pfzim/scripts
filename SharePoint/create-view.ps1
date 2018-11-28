$portal = "http://my.sharepoint.contoso.com/"
$lib = "Document Library 1"

$views = @(
	@{
		viewTitle = "View Title 1";
		list_bu = @("12048", "12050", "12051", "12053", "12054", "12055", "12056", "12057", "12066")
	},
	@{
		viewTitle = "View Title 2";
		list_bu = @("43047", "43076", "43077", "43078", "43079", "43080", "43081", "43082")
	},
)

$web = Get-SPWeb $portal
#$list = $web.GetList(($web.ServerRelativeUrl.TrimEnd("/") + "/DocLib"))
$list = $web.Lists[$lib]

foreach($view in $views)
{
    #Add the column names from the ViewField property to a string collection
    $viewFields = New-Object System.Collections.Specialized.StringCollection
    $fields = @("DocIcon", "LinkFilename", "_x0420__x0435__x0433__x0438__x043e__x043d__x0430__x043b__x044c__x043d__x043e__x0435__x0020__x0443__x043f__x0440__x0430__x0432__x043b__x0435__x043d__x0438__x0435_0", "_x0420__x0435__x0433__x0438__x043e__x043d__x0430__x043b__x044c__x043d__x043e__x0435__x0020__x043e__x0442__x0434__x0435__x043b__x0435__x043d__x0438__x0435_", "_x041d__x0430__x0438__x043c__x0435__x043d__x043e__x0432__x0430__x043d__x0438__x0435__x0020__x043a__x043e__x043d__x0442__x0440__x0430__x0433__x0435__x043d__x0442__x0430_", "_x041d__x043e__x043c__x0435__x0440__x0020__x043f__x0440__x0438__x0445__x043e__x0434__x043d__x043e__x0433__x043e__x0020__x0028__x0440__x0430__x0441__x0445__x043e__x0434__x043d__x043e__x0433__x043e__x0029__x0020__x043e__x0440__x0434__x0435__x0440__x0430_", "_x0414__x0430_", "_x0422__x043e__x0440_")

    foreach($field in $fields)
    {
        $viewFields.Add($field) > $null
    }

    #Query property

    $prefix = '<OrderBy><FieldRef Name="ID" Ascending="FALSE" /></OrderBy><Where><And>'
    $suffix = ''

    for($i = 0; $i -lt $view.list_bu.Count - 1; $i++)
    {
        $prefix += '<Or>'
        $suffix += ('<Eq><FieldRef Name="_x0411__x0438__x0437__x043d__x0435__x0441__x0020__x044e__x043d__x0438__x0442_" /><Value Type="Text">' + $view.list_bu[$i] + '</Value></Eq></Or>')
    }

    $prefix += ('<Eq><FieldRef Name="_x0411__x0438__x0437__x043d__x0435__x0441__x0020__x044e__x043d__x0438__x0442_" /><Value Type="Text">' + $view.list_bu[$i] + '</Value></Eq>')

    $suffix += '<Eq><FieldRef Name="ContentType" /><Value Type="Computed">Document Type Name</Value></Eq></And></Where>'

    $viewQuery = ($prefix + $suffix)

    #RowLimit property
    $viewRowLimit = 30
    #Paged property
    $viewPaged = $true
    #DefaultView property
    $viewDefaultView = $false

    #Create the view in the destination list
    $newview = $list.Views.Add(("_" + $view.viewTitle), $viewFields, $viewQuery, $viewRowLimit, $viewPaged, $viewDefaultView)
    $newview.Scope = "Recursive"
    $newview.Update()
}
