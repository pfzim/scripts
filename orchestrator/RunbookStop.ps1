# Stop all runbook jobs

$global:id = ''

$ErrorActionPreference = 'Stop'

. c:\orchestrator\settings\config.ps1

$global:result = 0
$global:error_msg = ''

function Invoke-SQL
{
    param(
        [string] $dataSource =  $(throw "Please specify a server."),
        [string] $sqlCommand = $(throw "Please specify a query."),
        [string] $database = $(throw "Please specify a DB.")
      )

    $connectionString = "Data Source=$dataSource; " +
            "Integrated Security=SSPI;"             +
            "Initial Catalog=$database"

    $connection = new-object system.data.SqlClient.SQLConnection($connectionString)
    $command = new-object system.data.sqlclient.sqlcommand($sqlCommand,$connection)
    $connection.Open()

    $adapter = New-Object System.Data.sqlclient.sqlDataAdapter $command
    $dataset = New-Object System.Data.DataSet
    $adapter.Fill($dataSet) | Out-Null

    $connection.Close()
    return $dataSet.Tables
}

function Runbook-Stop()
{
    param(
        [string] $jobid =  $(throw "Please specify a job id.")
    )

	$joburl = "{0}/Orchestrator.svc/Jobs(guid'{1}')" -f $global:g_config.scorch_url, $jobid

	# Get the current job
	$jobrequest = [System.Net.HttpWebRequest]::Create($joburl)
	$jobrequest.Method = "GET"
	$jobrequest.UserAgent = "Microsoft ADO.NET Data Services"

	# Set the credentials to default or prompt for credentials
	$jobrequest.UseDefaultCredentials = $true
	# $jobrequest.Credentials = Get-Credentia


	# Get the response from the request
	[System.Net.HttpWebResponse] $jobresponse = [System.Net.HttpWebResponse] $jobrequest.GetResponse()


	# Build the XML for the job that we will use in the POST request
	$reader = [IO.StreamReader] $jobresponse.GetResponseStream()
	$jobxml = $reader.ReadToEnd()
	[xml]$jobxml = $jobxml
	$reader.Close()

	# Modify date/time properties for the job and specify that it should be stopped 
	$lastmodifiedtime = $jobxml.DocumentElement.Item("content").Item("m:properties").Item("d:LastModifiedTime").InnerText
	$creationtime = $jobxml.DocumentElement.Item("content").Item("m:properties").Item("d:CreationTime").InnerText
	$jobxml.DocumentElement.Item("published").InnerText = $creationtime + "Z"
	$jobxml.DocumentElement.Item("updated").InnerText = $lastmodifiedtime + "Z"
	$jobxml.DocumentElement.Item("content").Item("m:properties").Item("d:Status").InnerText = "Canceled"

	# Remove the <link> nodes from the job XML
	$linknode = $jobxml.DocumentElement.Item("link")
	while ($linknode -ne $null)
	{
		[void]$jobxml.DocumentElement.RemoveChild($linknode)
		$linknode = $jobxml.DocumentElement.Item("link")
	}

	# Use the new job XML for the request body of the post request
	$postrequestbody = $jobxml.get_outerxml()


	# Setup the post request
	$postrequest = [System.Net.HttpWebRequest]::Create($joburl)

	# Set the credentials to default or prompt for credentials
	$postrequest.UseDefaultCredentials = $true
	# $postrequest.Credentials = Get-Credentia

	# Build the request header
	$postrequest.Method = "POST"
	$postrequest.UserAgent = "Microsoft ADO.NET Data Services"
	$postrequest.Accept = "application/atom+xml,application/xml"
	$postrequest.ContentType = "application/atom+xml"
	$postrequest.KeepAlive = $true
	$postrequest.Headers.Add("Accept-Encoding","identity")
	$postrequest.Headers.Add("Accept-Language","en-US")
	$postrequest.Headers.Add("DataServiceVersion","1.0;NetFx")
	$postrequest.Headers.Add("MaxDataServiceVersion","2.0;NetFx")
	$postrequest.Headers.Add("Pragma","no-cache")

	# Add header properties specific for Cancel Job
	$postrequest.Headers.Add("X-HTTP-Method","MERGE")
	$lmtime = $lastmodifiedtime.Replace(":","%3A")
	$tempstring = -join ("W/" , '"' , "datetime'" , $lmtime , "'" , '"')
	$postrequest.Headers.Add("If-Match",$tempstring)

	# Create a request stream from the request
	$requestStream = new-object System.IO.StreamWriter $postrequest.GetRequestStream()
	 
	# Sends the request to the service
	$requestStream.Write($postrequestbody)
	$requestStream.Flush()
	$requestStream.Close()
	[System.Net.HttpWebResponse] $response = [System.Net.HttpWebResponse] $postrequest.GetResponse()
}

function main()
{
	trap
	{
		$global:result = 1
		$global:error_msg += ("Критичная ошибка: {0}`r`n`r`nПроцесс прерван!`r`n" -f $_.Exception.Message);
		return;
	}

	# Проверка корректности заполнения полей

	if($global:id -eq '')
	{
		$global:result = 1
		$global:error_msg = 'Ошибка: Не корректно заполнены обязательные поля'
		return
	}

	# Получение списка запущенных задач и остановка
	try
	{
		$query = @'
			SELECT 
				[j].[Id] AS [Id], 
				[j].[RunbookId] AS [RunbookId], 
				[j].[StatusId] AS [StatusId], 
				[j].[CreationTime] AS [CreationTime]
			FROM 
				[Microsoft.SystemCenter.Orchestrator.Runtime.Internal].[Jobs] AS [j]
			WHERE
				[j].[RunbookId] = '{0}'
				AND (
					[j].[StatusId] = 0
					OR 
					[j].[StatusId] = 1
				)
			ORDER BY
				[j].[StatusId]
'@ -f $global:id

		$result = Invoke-SQL -dataSource $global:g_config.scorch_db_server -sqlCommand $query -database $global:g_config.scorch_db_name
		
        foreach($row in $result)
        {
			$global:error_msg += "Stop job ID: {0}`r`n" -f $row.Id
			Runbook-Stop -jobid $row.Id
		}
	}
	catch
	{
		$global:result = 1
		$global:error_msg += 'Ошибка: {0}' -f $_.Exception.Message
		return
	}
}

main
