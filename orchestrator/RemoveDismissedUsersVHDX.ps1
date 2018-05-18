$folders = @("1C", "CCTV", "RMS", "VPN-EXT-USERS")
$users = Get-ADUser -Filter * -SearchBase "OU=Disabled Accounts,DC=contoso,DC=com"

foreach($user in $users)
{
    foreach($folder in $folders)
    {
        $file = ("\\contoso.com\UPD\" + $folder + "\UVHD-" + $user.SID.Value + ".vhdx")
        if(Test-Path -Path $file)
        {
            Remove-Item -Path $file -Force
        }
    }
}
