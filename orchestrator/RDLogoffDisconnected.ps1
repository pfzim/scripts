Import-Module -Name RemoteDesktop

Get-RDUserSession -ConnectionBroker brc-rdb-11.contoso.com |
?{ $_.SessionState -eq 'STATE_DISCONNECTED' -and @('BRC-RDS-31.contoso.com', 'BRC-RDS-32.contoso.com') -eq $_.HostServer } |
Invoke-RDUserLogoff -Force
