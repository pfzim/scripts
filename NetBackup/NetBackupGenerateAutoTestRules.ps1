Function ConvertTo-PSON($Object, [Int]$Depth = 9, [Int]$Layers = 1, [Switch]$Strict, [Version]$Version = $PSVersionTable.PSVersion) {
    $Format = $Null
    $Quote = If ($Depth -le 0) {""} Else {""""}
    $Space = If ($Layers -le 0) {""} Else {" "}
    If ($Object -eq $Null) {"`$Null"} Else {
        $Type = "[" + $Object.GetType().Name + "]"
        $PSON = If ($Object -is "Array") {
            $Format = "@(", ",$Space", ")"
            If ($Depth -gt 1) {For ($i = 0; $i -lt $Object.Count; $i++) {ConvertTo-PSON $Object[$i] ($Depth - 1) ($Layers - 1) -Strict:$Strict}}
        } ElseIf ($Object -is "Xml") {
            $Type = "[Xml]"
            $String = New-Object System.IO.StringWriter
            $Object.Save($String)
            $Xml = "'" + ([String]$String).Replace("`'", "&apos;") + "'"
            If ($Layers -le 0) {($Xml -Replace "\r\n\s*", "") -Replace "\s+", " "} ElseIf ($Layers -eq 1) {$Xml} Else {$Xml.Replace("`r`n", "`r`n`t")}
            $String.Dispose()
        } ElseIf ($Object -is "DateTime") {
            "$Quote$($Object.ToString('s'))$Quote"
        } ElseIf ($Object -is "String") {
            0..11 | ForEach {$Object = $Object.Replace([String]"```'""`0`a`b`f`n`r`t`v`$"[$_], ('`' + '`''"0abfnrtv$'[$_]))}; "$Quote$Object$Quote"
        } ElseIf ($Object -is "Boolean") {
            If ($Object) {"`$True"} Else {"`$False"}
        } ElseIf ($Object -is "Char") {
            If ($Strict) {[Int]$Object} Else {"$Quote$Object$Quote"}
        } ElseIf ($Object -is "ValueType") {
            $Object
        } ElseIf ($Object.Keys -ne $Null) {
            If ($Type -eq "[OrderedDictionary]") {$Type = "[Ordered]"}
            $Format = "@{", ";$Space", "}"
            If ($Depth -gt 1) {$Object.GetEnumerator() | ForEach {"`"" + $_.Name + "`"$Space=$Space" + (ConvertTo-PSON $_.Value ($Depth - 1) ($Layers - 1) -Strict:$Strict)}}
        } ElseIf ($Object -is "Object") {
            If ($Version -le [Version]"2.0") {$Type = "New-Object PSObject -Property "}
            $Format = "@{", ";$Space", "}"
            If ($Depth -gt 1) {$Object.PSObject.Properties | ForEach {"`"" + $_.Name + "`"$Space=$Space" + (ConvertTo-PSON $_.Value ($Depth - 1) ($Layers - 1) -Strict:$Strict)}}
        } Else {$Object}
        If ($Format) {
            $PSON = $Format[0] + (&{
                If (($Layers -le 1) -or ($PSON.Count -le 0)) {
                    $PSON -Join $Format[1]
                } Else {
                    ("`r`n" + ($PSON -Join "$($Format[1])`r`n")).Replace("`r`n", "`r`n`t") + "`r`n"
                }
            }) + $Format[2]
        }
        If ($Strict) {"$Type$PSON"} Else {"$PSON"}
    }
}



$data = & 'C:\Program Files\Veritas\NetBackup\bin\admincmd\bppllist.exe' -allpolicies

$skip_class = $true
$skip_sched = $true
$policies = @{}

for($i = 0; $i -lt $data.Count; $i++)
{
    $row = $data[$i]
    if($row -match '^CLASS ([^\s]+)')
    {
        $class = $matches[1]
        ("" + $class)
        $skip_class = ($class -notmatch "^SQL_")
        $skip_schedule = $true
        if(!$skip_class)
        {
            $policies[$class] = @{}
            $policies[$class]['schedules'] = @{}
            $policies[$class]['clients'] = @{}
        }
    }
    elseif(!$skip_class)
    {
        if($row -match '^SCHED ([^\s]+)')
        {
            $schedule = $matches[1]
            ("  " + $matches[1])
            $skip_schedule = ($schedule -notmatch "Full")
            if(!$skip_schedule)
            {
                $policies[$class]['schedules'][$schedule] = @{}
            }
        }
        elseif($row -match '^CLIENT ([^\s]+) ([^\s]+) ([^\s]+)\s')
        {
            ("    " + $matches[1] + "\" + $matches[2])
            $policies[$class]['clients'][$matches[1]] = @{ $matches[3].Replace("%20", " ") = @{ nbimage = $null; media = @(); mdf = $matches[3]; log = $matches[3] + "_log"} }
        }
    }
}

#$policies | ConvertTo-Json -Depth 99

$t = @{}

foreach($p_key in $policies.Keys)
{
    $t[$p_key] = @{}
    foreach($c_key in $policies[$p_key].clients.Keys)
    {
        $t[$p_key][$c_key] = @{}
        foreach($s_key in $policies[$p_key].schedules.Keys)
        {
            $t[$p_key][$c_key][$s_key] = @{interval = if($s_key -match "Month") {90} elseif($s_key -match "Day") {7} else {30}; dblist = @{}}
            foreach($d_key in $policies[$p_key].clients[$c_key].Keys)
            {
                $t[$p_key][$c_key][$s_key].dblist[$d_key] = @{ nbimage = $null; media = @(); mdf = $d_key; log = ($d_key + "_log")}
            }
        }        
    }
}

cls

ConvertTo-PSON -Object $t -Layers 9
