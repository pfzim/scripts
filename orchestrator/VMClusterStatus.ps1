# Cluster status

<#
$vms = Invoke-Command -Session $session -ScriptBlock {
	$vms = Get-SCVirtualMachine -VMMServer srv-vmm-01
	
	return $vms
}

#Get-ClusterQuorum -Cluster $cluster.Name
#Get-ClusterResource -Cluster $cluster.Name
#Get-ClusterOwnerNode -ResourceType "Network Name" -Cluster $cluster.Name | fl
#Get-ClusterOwnerNode -ResourceType "IP Address" -Cluster $cluster.Name | fl

#>

$smtp_creds = New-Object System.Management.Automation.PSCredential ('', (ConvertTo-SecureString '' -AsPlainText -Force))
$ssh_creds = New-Object System.Management.Automation.PSCredential ('', (ConvertTo-SecureString '' -AsPlainText -Force))

$smtp_from = 'orchestrator@contoso.com'
$smtp_to = 'dvz@contoso.com'
$smtp_server = 'smtp.contoso.com'

Import-Module -Name FailoverClusters
Import-Module -Name Hyper-V
Import-Module -Name Posh-SSH

$cluster = Get-Cluster -Name srv-hvcl-02
$nodes = Get-ClusterNode -Cluster $cluster.Name
$csvs = Get-ClusterSharedVolume -Cluster $cluster.Name
$clgroup = Get-ClusterGroup -Name 'Cluster Group' -Cluster $cluster.Name
$domain = Get-ADDomain
$forest = Get-ADForest

$table = ''
$table += '<h1>Cluster status - {0}</h1>' -f $cluster.Name
$table += '<h2>Cluster Group</h2>'
$table += '<table>'
$table += '<tr><th>Name</th><th>Owner</th><th>State</th><th>WitnessDynamicWeight</th><th>DynamicQuorum</th></tr>'

if($clgroup.State -eq 'Online') { $bg = 'pass' }
else { $bg = 'error' }
$table += '<tr><td>{0}</td><td>{1}</td><td class="{5}">{2}</td><td>{3}</td><td>{4}</td></tr>' -f $clgroup.Name, $clgroup.OwnerNode, $clgroup.State, $cluster.WitnessDynamicWeight, $cluster.DynamicQuorum, $bg
$table += '</table>'

$table += '<h2>Cluster Nodes</h2>'
$table += '<table>'
$table += '<tr><th>Node</th><th>State</th><th>DynamicWeight</th><th>NodeWeight</th></tr>'

$vms = $null
foreach($node in $nodes)
{
    if($node.State -eq 'Up') { $bg = 'pass' }
    elseif($node.State -eq 'Paused') { $bg  = 'warn' }
    else { $bg = 'error' }
    $table += '<tr><td>{0}</td><td class="{4}">{1}</td><td>{2}</td><td>{3}</td></tr>' -f $node.NodeName, $node.State, $node.DynamicWeight, $node.NodeWeight, $bg
    $vms += Get-VM -ComputerName $node.Name | Select-Object -Property Name, State, @{ Name = 'Node'; Expression = { $node.Name }}
}
$table += '</table>'

$table += '<h2>Cluster Shared Volumes</h2>'
$table += '<table>'
$table += '<tr><th>Path</th><th>Name</th><th>Owner</th><th>State</th></tr>'

foreach($csv in $csvs)
{
    if($csv.State -eq 'Online') { $bg = 'pass' }
    else { $bg = 'error' }
    $table += '<tr><td>{0}</td><td>{1}</td><td>{2}</td><td class="{4}">{3}</td></tr>' -f $csv.SharedVolumeInfo.FriendlyVolumeName, $csv.Name, $csv.OwnerNode, $csv.State, $bg
}
$table += '</table>'

# FSMO

$table += '<h2>FSMO Role Holders</h2>'
$table += '<table>'
$table += '<tr><th>Role</th><th>Holder</th></tr>'

$table += '<tr><td>InfrastructureMaster</td><td>{0}</td></tr>' -f $domain.InfrastructureMaster
$table += '<tr><td>RIDMaster</td><td>{0}</td></tr>' -f $domain.RIDMaster
$table += '<tr><td>PDCEmulator</td><td>{0}</td></tr>' -f $domain.PDCEmulator
$table += '<tr><td>DomainNamingMaster</td><td>{0}</td></tr>' -f $forest.DomainNamingMaster
$table += '<tr><td>SchemaMaster</td><td>{0}</td></tr>' -f $forest.SchemaMaster
$table += '</table>'

# Get 3PAR info

$ip = @{
	'STR-03' = '172.18.1.1';
	'STR-01' = '172.18.1.2';
}

foreach($k in $ip.Keys)
{
	$table += '<h2>3PAR Remote Copy Groups - {0} ({1})</h2>' -f $k, $ip[$k]
	$table += '<table>'
	$table += '<tr><th>Name</th><th>Target</th><th>State</th><th>Role</th></tr>'

	$sess = New-SSHSession -ComputerName $ip[$k] -Credential $ssh_creds -AcceptKey
	$res = Invoke-SSHCommand -SSHSession $sess -Command 'showrcopy groups'
	if($res.ExitStatus -eq 0)
	{
		$section_found = $false
		$seek_empty = $false
		$skip_header = $false
		$rcgs = 0

		foreach($line in  $res.Output)
		{
			if($section_found)
			{
				if($seek_empty)
				{
					if($line -eq '')
					{
						$seek_empty = $false
						$skip_header = $true
					}
				}
				elseif($skip_header)
				{
					$skip_header = $false
				}
				else
				{
					$seek_empty = $true
					
					$line = $line -replace "^\s+", ""
					$line = $line -replace "\s+$", ""
					$line = $line -replace "\s+", ";"
					$row = $line.Split(";")

					#$line
					#'{0} {1} {2}' -f $row[0], $row[2], $row[3]
					
					if($row[2] -eq 'Started') { $bg_state = 'pass' }
					else { $bg_state = 'error' }
					
					if($row[3] -eq 'Primary') { $bg_role = 'pass' }
					else { $bg_role = 'warn' }
					
					$table += '<tr><td>{0}</td><td>{5}</td><td class="{3}">{1}</td><td class="{4}">{2}</td></tr>' -f $row[0], $row[2], $row[3], $bg_state, $bg_role, $row[1]
					$rcgs++
				}
			}
			elseif($line -match '^Group Information')
			{
				$section_found = $true
				$seek_empty = $true
				$skip_header = $false
			}
		}
	}

	Remove-SSHSession -SSHSession $sess | Out-Null

	$table += '</table>'
}

# Virtual Machines

$table += '<h2>Virtual Machines</h2>'
$table += '<table>'
$table += '<tr><th>Name</th><th>Node</th><th>State</th></tr>'

$vms = $vms | Sort-Object Node, Name

foreach($vm in $vms)
{
    if($vm.State -eq 'Running') { $bg = 'pass' }
    elseif($vm.State -eq 'Off') { $bg  = 'warn' }
    else { $bg = 'error' }
    $table += '<tr><td>{1}</td><td>{0}</td><td class="{3}">{2}</td></tr>' -f $vm.Name, $vm.Node, $vm.State, $bg
}
$table += '</table>'

$body = @'
<html>
<head>
	<meta http-equiv="Content-Type" content="text/html; charset=utf-8">
	<style>
		body{font-family: Courier New; font-size: 8pt;}
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


$body += $table

$body += @'
</body>
</html>
'@

Send-MailMessage -from $smtp_from -to $smtp_to -Encoding UTF8 -subject 'Cluster status' -bodyashtml -body $body -smtpServer $smtp_server -Credential $smtp_creds
