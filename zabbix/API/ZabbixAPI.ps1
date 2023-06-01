
function zabbix_api_request($url, $method, $params, $auth, $id)
{
    $params = @{
        body =  @{
            'jsonrpc'= '2.0'
            'id'= $id
            'auth'= $auth
            'method'= $method
            'params'= $params
        } | ConvertTo-Json -Depth 99
        uri = $url
        ContentType = 'application/json; charset=utf-8'
        method = 'POST'
    }

    Write-Debug $params.body

    $response = Invoke-RestMethod -TimeoutSec 600 @params

	Write-Debug $response

	return $response.result

	<#
    #$response = Invoke-WebRequest -UseBasicParsing @params
    if($response.StatusCode -ne 200)
    {
        throw New-Object System.Exception('Zabbix API return HTTP {0}' -f $response.StatusCode)
    }

    Write-Debug $response.Content

    $result = $response.Content | ConvertFrom-Json

    if($result.error)
    {
        throw New-Object System.Exception('Zabbix API ERROR [{0}]: {1} {2}' -f $result.error.code, $result.error.message, $result.error.data)
    }

    return $result.result
	#>
}
