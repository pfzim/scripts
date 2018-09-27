$ErrorActionPreference = "Stop"

function Invoke-SQL
{
    param(
        [string] $dataSource =  $(throw "Please specify a server."),
        [string] $sqlCommand = $(throw "Please specify a query.")
      )

    $connectionString = "Data Source=$dataSource; " +
            "Integrated Security=SSPI"

     try
    {
   $connection = new-object system.data.SqlClient.SQLConnection($connectionString)
    $command = new-object system.data.sqlclient.sqlcommand($sqlCommand,$connection)
    $connection.Open()

    $adapter = New-Object System.Data.sqlclient.sqlDataAdapter $command
    $dataset = New-Object System.Data.DataSet
    $adapter.Fill($dataSet) | Out-Null

    $connection.Close()
    }
    catch
    {
        Write-Host ("ERROR " + $dataSource + " " + $_.Exception.Message)
    }
    return $dataSet.Tables
}


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


$query = @'
SELECT
	DB_NAME(s.database_id) as dbname,
	type,
	[name]
FROM sys.master_files s
ORDER BY dbname
'@


$servers = Get-Content -Path "C:\Orchestrator\settings\mssql-servers-list.txt"
$exclude = Get-Content -Path "C:\Orchestrator\settings\db-exclude-list.txt"

$list = @{}

foreach($server in $servers)
{
    $result = Invoke-SQL -dataSource $server -sqlCommand $query

    foreach($row in $result)
    {
        if(!$list.ContainsKey($row.dbname))
        {
            $list[$row.dbname] = @{}
            $list[$row.dbname].log = @()
        }

        if($row.type -eq 0)
        {
            $list[$row.dbname].mdf = $row.name
        }
        else
        {
            $list[$row.dbname].log += $row.name
        }
    }
}

ConvertTo-PSON -Object $list -Layers 9 | Set-Content -Path "c:\scripts\logs\NetBackupTestRestore.names.log"
