param([string] $message)

try
{
	$scriptPath = $PSScriptRoot
	if(!$scriptPath)
	{
		if($MyInvocation.MyCommand.Path)
		{
			$scriptPath = Split-Path -parent $MyInvocation.MyCommand.Path
		}
		else
		{
			$scriptPath = $PSCommandPath
		}
	}

	if([string]::IsNullOrEmpty($message))
	{
		Write-Host ('Usage: ./tlgmsg.ps1 -message "Message text here"')
		return
	}

	. ($scriptPath + '\config.ps1')

	(New-Object System.Net.WebClient).DownloadString('https://api.telegram.org/bot{0}/sendMessage?chat_id={1}&text={2}' -f @($g_config.api_token, $g_config.chat_id, $message))
}
catch
{
	Write-Host -ForegroundColor Red ('ERROR: ' + $_.Exception.Message)
}
