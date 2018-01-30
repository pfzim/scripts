$address = ""

if($address -notmatch ".+@.+\..+")
{
	throw New-Object System.Exception("Invalid e-mail address format")
}

$passwd = ConvertTo-SecureString "" -AsPlainText -Force
$creds = New-Object System.Management.Automation.PSCredential ("", $passwd)

$session = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri http://mail.contoso.com/powershell/ -Credential $creds -Authentication Kerberos

Import-PSSession $session

$result_in = 0
$result_out = 0

$list = (Get-TransportRule -Identity "Запрещено в интернет").SentTo

if($list -contains $address)
{
	$list = @($list | Where-Object { $_ -ne $address })
	Set-TransportRule -Identity "Запрещено в интернет" -SentTo $list
	$result_out = 1
}

$list = (Get-TransportRule -Identity "Запрещено из интернета").From

if($list -contains $address)
{
	$list = @($list | Where-Object { $_ -ne $address })
	Set-TransportRule -Identity "Запрещено из интернета" -From $list
	$result_in = 1
}

Remove-PSSession -Session $session