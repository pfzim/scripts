$result = ""
$error_msg = ""

if($result -ne 0)
{
	throw New-Object System.Exception(("Error: " + $error_msg))
}
