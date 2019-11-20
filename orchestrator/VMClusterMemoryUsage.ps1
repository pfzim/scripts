# Cluster memory and CPU usage

$ps_creds = New-Object System.Management.Automation.PSCredential ("", (ConvertTo-SecureString "" -AsPlainText -Force))

$session = New-PSSession -ComputerName srv-vmm-01 -Credential $ps_creds -Authentication Negotiate

$vms = Invoke-Command -Session $session -ScriptBlock {
	
$smtp_creds = New-Object System.Management.Automation.PSCredential ("", (ConvertTo-SecureString "" -AsPlainText -Force))

$smtp_from = "orchestrator@contoso.com"
$smtp_to = "admin@contoso.com"
$smtp_server = "smtp.contoso.com"

$body = @'
<html>
<head>
	<meta http-equiv="Content-Type" content="text/html; charset=utf-8">
	<style>
		body{font-family: Courier New; font-size: 10pt;}
		h1{font-size: 16px;}
		h2{font-size: 14px;}
		h3{font-size: 12px;}
		table{border: 1px solid black; border-collapse: collapse; font-size: 8pt;}
		th{border: 1px solid black; background: #dddddd; padding: 5px; color: #000000;}
		td{border: 1px solid black; padding: 5px; }
		.pass {background: #7FFF00;}
		.warn {background: #FFE600;}
		.error {background: #FF0000; color: #ffffff;}
		</style>
	</head>
	<body>
'@

$body += @'
<table>
	<tr>
		<th>Host</th>
		<th>Total memory</th>
		<th>Used memory</th>
		<th>Available</th>
		<th>Lost memory</th>
		<th>Total CPU</th>
		<th>Used CPU</th>
	</tr>
'@

$dln_mem = 0
$brc_mem = 0

$dln_vm = 0
$brc_vm = 0
$hi_vm = 0
$stp_vm = 0
$gb = 1024 * 1024 * 1024 

$cluster = Get-SCVMHostCluster -Name SRV-HVCL-02 -VMMServer srv-vmm-01
$nodes = $cluster.Nodes | Sort-Object -Property Name

foreach($node in $nodes)
{
    $brc = 0
    if($node.Name -match "^brc")
    {
        $brc = 1
        $brc_mem += $node.TotalMemory
    }

    if($node.Name -match "^dln")
    {
        $dln_mem += $node.TotalMemory
    }

    $node_vm = 0
    $node_cpu = 0

    foreach($vm in $node.VMs)
    {
        if($vm.Status -eq 'Running')
        {
            if($vm.IsHighlyAvailable)
            {
                $hi_vm += $vm.Memory * 1024 * 1024
            }
            elseif($brc)
            {
                $brc_vm += $vm.Memory * 1024 * 1024
            }
            else
            {
                $dln_vm += $vm.Memory * 1024 * 1024
            }
			
			$node_vm += $vm.Memory * 1024 * 1024
			$node_cpu += $vm.CPUCount
        }
        else
        {
            $stp_vm += $vm.Memory * 1024 * 1024
        }

        #Write-Host ("  {0,-30}  {2,-8} {1:n0} GB" -f $vm.Name, ($vm.Memory/1024), $vm.IsHighlyAvailable)
    }
	
	if($node.AvailableMemory -lt 65536)
	{
		$class = 'error'
	}
	else
	{
		$class = 'pass'
	}

    #Write-Host -ForegroundColor DarkGray ("{0:-30}    Total: {2,8:n0} GB    Used: {3,8:n0} GB    Available: {1,8:n0} GB     Lost: {4,8:n0} GB" -f $node.Name, ($node.AvailableMemory/1024), ($node.TotalMemory/1024/1024/1024), ($node_vm/1024), ((($node.TotalMemory/1024/1024) - $node_vm - $node.AvailableMemory)/1024))
    $body += ('<tr><td>{0}</td><td>{2:n0} GB</td><td>{3:n0} GB</td><td class="{5}">{1:n0} GB</td><td>{4:n0} GB</td><td>{6}</td><td>{7}</td></tr>' -f $node.Name, ($node.AvailableMemory/1024), ($node.TotalMemory/$gb), ($node_vm/$gb), (($node.TotalMemory - $node_vm)/$gb - $node.AvailableMemory/1024), $class, $node.LogicalCPUCount, $node_cpu)
}

$body += "</table>"
$body += ("<p><b>ИФ</b><br />Суммарно доступно памяти: {0:n0} GB<br />Использовано виртуальными машинами: {1:n0} GB<br />Разница (доступная - использованная - 7*64): {2:n0} GB</p>" -f ($brc_mem/$gb), (($brc_vm+$hi_vm)/$gb), (($brc_mem - $brc_vm - $hi_vm)/$gb - 7*64))
$body += ("<p><b>ДЛ</b><br />Суммарно доступно памяти: {0:n0} GB<br />Использовано виртуальными машинами: {1:n0} GB<br />Разница (доступная - использованная - 6*64): {2:n0} GB</p>" -f ($dln_mem/$gb), (($dln_vm+$hi_vm)/$gb), (($dln_mem - $dln_vm - $hi_vm)/$gb - 6*64))
$body += ("<p><b>Всего использовано памяти виртуальными машинами:</b> {0:n0} GB</p>" -f (($brc_vm + $dln_vm + $hi_vm)/$gb))
$body += "</body>"

#Write-Host -ForegroundColor Green ("  BRC  Total: {0:n0} GB  Used: {1:n0} GB  Available: {2:n0} GB" -f ($brc_mem/$gb), (($brc_vm+$hi_vm)/$gb), (($brc_mem - $brc_vm - $hi_vm)/$gb))
#Write-Host -ForegroundColor Green ("  DLN  Total: {0:n0} GB  Used: {1:n0} GB  Available: {2:n0} GB" -f ($dln_mem/$gb), (($dln_vm+$hi_vm)/$gb), (($dln_mem - $dln_vm - $hi_vm)/$gb))

#Write-Host -ForegroundColor Green ("  Total used: {0:n0} GB" -f (($brc_vm + $dln_vm + $hi_vm)/1024))

Send-MailMessage -from $smtp_from -to $smtp_to -Encoding UTF8 -subject "Cluster memory usage" -bodyashtml -body $body -smtpServer $smtp_server -Credential $smtp_creds

}
