# List certificates and expiration dates

$global:to = ''

$global:result = 0
$global:error_msg = ''

$ErrorActionPreference = 'Stop'

. c:\orchestrator\settings\config.ps1

$global:subject = ''
$global:body = ''
$global:smtp_to = @()

if($global:to)
{
	$global:smtp_to += @($global:to)
}

$global:smtp_to = $global:smtp_to -join ','

function get-ExpiringCerts($duedays=60, $CAlocation="")
{
	trap
	{
		$global:result = 1
		$global:error_msg += ("Критичная ошибка: {0}`r`n`r`nПроцесс прерван!`r`n" -f $_.Exception.Message);
		return;
	}

	$certs = @()
	$now = get-Date;
	$expirationdate = $now.AddDays($duedays)
	$CaView = New-Object -Com CertificateAuthority.View.1
	[void]$CaView.OpenConnection($CAlocation)
	$CaView.SetResultColumnCount(5)
	$index0 = $CaView.GetColumnIndex($false, "Issued Common Name")
	$index1 = $CaView.GetColumnIndex($false, "Certificate Expiration Date")
	$index2 = $CaView.GetColumnIndex($false, "Issued Email Address")
	$index3 = $CaView.GetColumnIndex($false, "Certificate Template")
	$index4 = $CaView.GetColumnIndex($false, "Request Disposition")
	$index0, $index1, $index2, $index3, $index4 | %{$CAView.SetResultColumn($_) }

	# CVR_SORT_NONE 0
	# CVR_SEEK_EQ  1
	# CVR_SEEK_LT  2
	# CVR_SEEK_GT  16

	$index1 = $CaView.GetColumnIndex($false, "Certificate Expiration Date")
	$CAView.SetRestriction($index1,16,0,$now)
	$CAView.SetRestriction($index1,2,0,$expirationdate)

	# brief disposition code explanation:
	# 9 - pending for approval
	# 15 - CA certificate renewal
	# 16 - CA certificate chain
	# 20 - issued certificates
	# 21 - revoked certificates
	# all other - failed requests

	$CAView.SetRestriction($index4,1,0,20)

	$RowObj= $CAView.OpenView() 

	while ($Rowobj.Next() -ne -1)
	{
		$Cert = New-Object PsObject
		$ColObj = $RowObj.EnumCertViewColumn()
		[void]$ColObj.Next()
		do
		{
			$current = $ColObj.GetName()
			$Cert | Add-Member -MemberType NoteProperty $($ColObj.GetDisplayName()) -Value $($ColObj.GetValue(1)) -Force  
		} until ($ColObj.Next() -eq -1)
		Clear-Variable ColObj

		#$cert."Issued Email Address"
		if($cert."Certificate Template" -eq "1.3.6.1.4.1.311.21.8.9193577.1596346.1393818.2862674.14063359.175.9502724.10085239")
		{
			$cl = ''
			$datediff = New-TimeSpan -Start ($now) -End ($cert."Certificate Expiration Date")
			if($datediff.Days -le 30)
			{
				$cl = ' class="error"'
			}
			
			$global:body += '<tr><td>{0}</td><td{3}>{1}</td><td{3}>{2}</td></tr>' -f $cert."Issued Common Name", $dateDiff.Days, $cert."Certificate Expiration Date", $cl;
		}
	}
	$RowObj.Reset()
	$CaView = $null
	[GC]::Collect()
}


function main()
{
	trap
	{
		$global:result = 1
		$global:error_msg += ("Критичная ошибка: {0}`r`n`r`nПроцесс прерван!`r`n" -f $_.Exception.Message);
		return;
	}
	
	$global:subject = 'Список сертификатов OWA и срок их действия'
	
	$global:body = '<h1>Список сертификатов OWA и срок их действия</h1>'
	
	$global:body += '<table><tr><th>Сотрудник</th><th>Осталось дней</th><th>Cрок действия</th></tr>';
	
	foreach($ca_server in $global:g_config.ca_servers)
	{
		get-ExpiringCerts -duedays 365 -CAlocation $ca_server
	}

	$global:body += '</table>';
}

main

if($global:result -ne 0)
{
	$global:body += "<br /><br /><pre class=`"error`">Техническая информация:`r`n`r`n{0}</pre>" -f $global:error_msg
}
