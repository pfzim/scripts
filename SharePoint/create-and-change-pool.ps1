Add-PSSnapin Microsoft.SharePoint.PowerShell

$WebAppURL = "http://portal.contoso.com"
$NewAppPoolName = "SP_Pool_Portal"
$NewAppPoolUserName = "contoso\sp_content" # Аккаунт должен быть заранее добавлен в SP Managed Accounts

Start-SPAssignment -Global

$Farm = Get-SPFarm
$Service = $Farm.Services | where {$_.TypeName -eq "Microsoft SharePoint Foundation Web Application"}

# создаем новый пулл
Write-Host ("Creating pool " + $NewAppPoolName)
$NewAppPool = New-Object Microsoft.SharePoint.Administration.SPApplicationPool($NewAppPoolName,$Service)
$NewAppPool.CurrentIdentityType = "SpecificUser"
$NewAppPool.ManagedAccount = Get-SPManagedAccount -Identity $NewAppPoolUserName
$NewAppPool.Provision()
$NewAppPool.Update($true)
$NewAppPool.Deploy()

Stop-SPAssignment -Global

& iisreset

Start-SPAssignment -Global

$Farm = Get-SPFarm
$Service = $Farm.Services | where {$_.TypeName -eq "Microsoft SharePoint Foundation Web Application"}

# меняем пулл приложения на новый
Write-Host ("Changing pool for " + $WebAppURL)
$NewAppPool = $Service.ApplicationPools[$NewAppPoolName]
$WebApp = Get-SPWebApplication $WebAppURL
$WebApp.ApplicationPool = $NewAppPool
$WebApp.Update()
$WebApp.ProvisionGlobally()

Stop-SPAssignment -Global

& iisreset
