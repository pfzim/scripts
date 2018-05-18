@echo off

if not exist "c:\temp" mkdir c:\temp
if not exist "c:\logs" mkdir c:\logs
if not exist "c:\scripts" (
  mkdir c:\scripts
  icacls.exe c:\scripts /inheritance:r /grant:r *S-1-5-32-544:^(oi^)^(ci^)f /grant:r *S-1-5-18:^(oi^)^(ci^)f
)

exit 0
