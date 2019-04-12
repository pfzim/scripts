function Walk($path, $reg_code, $ou)
{
	$files = Get-ChildItem $path -Attributes Directory
	foreach($file in $files)
	{
		Write-Output ("### {0}{1}" -f $path, $file.Name)
        Write-Output ("New-ADOrganizationalUnit `"{0}`" -Path `"{1}`"" -f $file.Name, $ou)
		Write-Output ("New-ADGroup -name `"G_FS_TOF_Reg{0}_{1}_Full`" -GroupCategory Security -GroupScope DomainLocal -path `"OU={1},{2}`"" -f $reg_code, $file.Name, $ou)
		Write-Output ("New-ADGroup -name `"G_FS_TOF_Reg{0}_{1}_RO`" -GroupCategory Security -GroupScope DomainLocal -path `"OU={1},{2}`"" -f $reg_code, $file.Name, $ou)
		Write-Output ("New-ADGroup -name `"G_FS_TOF_Reg{0}_{1}_RW`" -GroupCategory Security -GroupScope DomainLocal -path `"OU={1},{2}`"" -f $reg_code, $file.Name, $ou)

		Write-Output ("`$acl = Get-Acl `"{0}{1}`"" -f $path, $file.Name)
	
		Write-Output ("`$acl.SetAccessRule((New-Object System.Security.AccessControl.FileSystemAccessRule -ArgumentList (`"G_FS_TOF_Reg{0}_{1}_Full`",`"FullControl`",`"ContainerInherit, ObjectInherit`",`"None`",`"Allow`")))" -f $reg_code, $file.Name)
		Write-Output ("`$acl.SetAccessRule((New-Object System.Security.AccessControl.FileSystemAccessRule -ArgumentList (`"G_FS_TOF_Reg{0}_{1}_RO`",`"ReadAndExecute`",`"ContainerInherit, ObjectInherit`",`"None`",`"Allow`")))" -f $reg_code, $file.Name)
		Write-Output ("`$acl.SetAccessRule((New-Object System.Security.AccessControl.FileSystemAccessRule -ArgumentList (`"G_FS_TOF_Reg{0}_{1}_RW`",`"Modify`",`"ContainerInherit, ObjectInherit`",`"None`",`"Allow`")))" -f $reg_code, $file.Name)

		Write-Output ("`$acl | Set-Acl `"{0}{1}`"" -f $path, $file.Name)
		Write-Output ""

		Walk -path ("{0}{1}\" -f $path, $file.Name) -ou ("OU={0},{1}" -f $file.Name, $ou)
	}
}

$reg_code = '42'
$reg_name = 'Кемеровская_область'
$path = "F:\SFR-42\Common-01\"
$out_file = "c:\tmp\_gen_acl_script_reg_42.ps1"

Remove-Item -Path $out_file -Confirm:$true

Write-Output ("New-ADOrganizationalUnit `"" + $reg_code + "_" + $reg_name + "`" -Path `"OU=TOF,OU=contoso.com\\common,OU=СФР,OU=Company,DC=contoso,DC=com`"") | Out-File -FilePath $out_file -Append
Walk -path $path -reg_code $reg_code -ou ("OU={0}_{1},OU=TOF,OU=contoso.com\\common,OU=СФР,OU=Company,DC=contoso,DC=com" -f $reg_code, $reg_name) | Out-File -FilePath $out_file -Append
