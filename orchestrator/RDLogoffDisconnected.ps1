Import-Module -Name RemoteDesktop

Get-RDUserSession -ConnectionBroker srv-rdb-11.contoso.com |
?{ $_.SessionState -eq 'STATE_DISCONNECTED' -and @('srv-RDS-31.contoso.com', 'srv-RDS-32.contoso.com') -eq $_.HostServer } |
Invoke-RDUserLogoff -Force
