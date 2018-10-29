$ErrorActionPreference = "Stop"

$source = "\\srv-sccm-02\deploy$\"

Import-Module "$($ENV:SMS_ADMIN_UI_PATH)\..\ConfigurationManager.psd1"
Set-Location "M01:"

Write-Host ("Getting limiting collection...")
$LimitingCollectionID = (Get-CMDeviceCollection | Where-Object {$_.Name -eq 'All systems'}).CollectionID

$files = Get-ChildItem ("FileSystem::" + $source + "Collection")
foreach($file in $files)
{
	if((!$file.PSIsContainer) -and ($file.Name -match "\.txt$"))
	{
		Write-Host ("Loading: " + $file.Name)
		try
		{
			$CollectionName = $file.Name.Substring(0, $file.Name.Length - 4)
			New-CMDeviceCollection -Name $CollectionName -LimitingCollectionId $LimitingCollectionID
			$comps = Get-Content ("FileSystem::" + $file.FullName)
		}
		catch
		{
			Write-Host -ForegroundColor Red ("  ERROR: " + $_.Exception.Message)
			continue
		}

		foreach($comp in $comps)
		{
			try
			{
				$rid = (Get-CMDevice -Name $comp).ResourceID
				Add-CMDeviceCollectionDirectMembershipRule -CollectionName $CollectionName -ResourceID $rid
			}
			catch
			{
				Write-Host -ForegroundColor Red ("  ERROR: " + $_.Exception.Message)
				continue
			}
		}
	}
}


$folders = Get-ChildItem ("FileSystem::" + $source + "Package")
foreach($folder in $folders)
{
	if($folder.PSIsContainer)
	{
		if(Test-Path -Path ("FileSystem::" + $folder.FullName + "\package.xml"))
	    {
			try
			{
				[xml]$config = Get-Content ("FileSystem::" + $folder.FullName + "\package.xml")
				$pkg_name = ($folder.Name)

				New-CMPackage -Name $pkg_name -Path $folder.FullName
				New-CMProgram -PackageName $pkg_name -StandardProgramName SPM -CommandLine $config.settings.command -WorkingDirectory "C:\temp" -RunType Hidden -ProgramRunType WhetherOrNotUserIsLoggedOn -DiskSpaceRequirement $config.settings.diskspace -DiskSpaceUnit MB -Duration $config.settings.timeout -DriveMode RenameWithUnc
				Get-CMPackage -Name $pkg_name | Start-CMContentDistribution -DistributionPointName "brc-sccm-02.bristolcapital.ru"
			}
			catch
			{
				Write-Host -ForegroundColor Red ("  ERROR: " + $_.Exception.Message)
				continue
			}
		}
	}
}


$files = Get-ChildItem ("FileSystem::" + $source + "Installation")
foreach($file in $files)
{
	if((!$file.PSIsContainer) -and ($file.Name -match "\.txt$"))
	{
		Write-Host ("Loading: " + $file.Name)
		$pkg_name = $file.Name.Substring(0, $file.Name.Length - 4)
		try
		{
			$collections = Get-Content ("FileSystem::" + $file.FullName)
		}
		catch
		{
			Write-Host -ForegroundColor Red ("ERROR: " + $_.Exception.Message)
			continue
		}
		Write-Host ("Package: " + $pkg_name)
		foreach($collection in $collections)
		{
			Write-Host ("  Deploing to: " + $collection)
			try
			{
				New-CMPackageDeployment -StandardProgram -PackageName $pkg_name -ProgramName SPM -CollectionName $collection -DistributionPointName "brc-sccm-02.bristolcapital.ru" -DeployPurpose Required -SendWakeupPacket $false -ScheduleEvent AsSoonAsPossible -RerunBehavior RerunIfFailedPreviousAttempt -FastNetworkOption DownloadContentFromDistributionPointAndRunLocally -SlowNetworkOption DownloadContentFromDistributionPointAndLocally -Confirm:$false
			}
			catch
			{
				Write-Host -ForegroundColor Red ("    ERROR: " + $_.Exception.Message)
				continue
			}
		}
	}
}
