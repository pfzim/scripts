@echo off

if not "%COMPUTERNAME:~7,2%"=="-2" goto :EOF

set admincomp=%COMPUTERNAME:~0,7%-1
set adminuser=%COMPUTERNAME:~0,2%%COMPUTERNAME:~3,4%

if not exist "c:\backup" mkdir c:\backup

icacls.exe c:\backup | findstr /r "^.*%admincomp%\$:(OI)(CI)(M)"
if %errorlevel% neq 0 (
  icacls.exe c:\backup /inheritance:r /grant:r *S-1-5-32-544:^(oi^)^(ci^)f /grant:r *S-1-5-18:^(oi^)^(ci^)f /grant:r contoso.com\%admincomp%$:^(oi^)^(ci^)m /grant:r contoso.com\%adminuser%:^(oi^)^(ci^)rx /grant:r contoso.com\%adminuser%k:^(oi^)^(ci^)rx
)

icacls.exe c:\backup | findstr /r "^.*%adminuser%:(OI)(CI)(RX)"
if %errorlevel% neq 0 (
  icacls.exe c:\backup /inheritance:r /grant:r *S-1-5-32-544:^(oi^)^(ci^)f /grant:r *S-1-5-18:^(oi^)^(ci^)f /grant:r contoso.com\%admincomp%$:^(oi^)^(ci^)m /grant:r contoso.com\%adminuser%:^(oi^)^(ci^)rx /grant:r contoso.com\%adminuser%k:^(oi^)^(ci^)rx
)

icacls.exe c:\backup | findstr /r "^.*%adminuser%k:(OI)(CI)(RX)"
if %errorlevel% neq 0 (
  icacls.exe c:\backup /inheritance:r /grant:r *S-1-5-32-544:^(oi^)^(ci^)f /grant:r *S-1-5-18:^(oi^)^(ci^)f /grant:r contoso.com\%admincomp%$:^(oi^)^(ci^)m /grant:r contoso.com\%adminuser%:^(oi^)^(ci^)rx /grant:r contoso.com\%adminuser%k:^(oi^)^(ci^)rx
)

net share backup-kassir | findstr /r "^.*Все,.*CHANGE$"
if %errorlevel% neq 0 (
  net share backup-kassir /delete
  net share backup-kassir=c:\backup /grant:Все,change
)
