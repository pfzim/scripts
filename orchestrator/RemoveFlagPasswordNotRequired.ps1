# Example

# User
$users = Get-ADUser -Properties userAccountControl -LDAPFilter "((userAccountControl:1.2.840.113556.1.4.803:=32))"
foreach($user in $users)
{
    $user.ObjectClass + " " +  [System.Convert]::ToString($user.userAccountControl, 16) + " " + $user.SamAccountName
    if(($user.ObjectClass -eq 'user') -and (($user.userAccountControl -band 0x020) -ne 0))
    {
		Set-ADAccountControl -Identity $user -PasswordNotRequired $false
    }
}


# switch flag

$user.userAccountControl
if(($user.userAccountControl -band 0x020) -ne 0)
{
    $bit = ($user.userAccountControl -band (0xFFFFFFFF -bxor 0x020))
    Set-ADAccountControl zimin_test -PasswordNotRequired $false
}
else
{
    $bit = ($user.userAccountControl -bor 0x020)
    Set-ADAccountControl zimin_test -PasswordNotRequired $true
}
$bit


# Computers

$comps = Get-ADComputer -Properties userAccountControl -LDAPFilter "((userAccountControl:1.2.840.113556.1.4.803:=32))"
foreach($comp in $comps)
{
    $comp.ObjectClass + " " +  [System.Convert]::ToString($comp.userAccountControl, 16) + " " + $comp.SamAccountName
    if(($comp.ObjectClass -eq 'computer') -and (($comp.userAccountControl -band 0x020) -ne 0))
    {
		Set-ADAccountControl -Identity $comp -PasswordNotRequired $false
    }
}
