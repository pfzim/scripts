@echo off

set ipaddr=0.0.0.0

for /f "usebackq tokens=2 delims=:" %%f in (`ipconfig ^| findstr /c:IPv4`) do (
  set ipaddr=%%f
  goto lb_break
)

:lb_break

echo %DATE% - %TIME% %USERNAME% logged into %COMPUTERNAME% ip%ipaddr% using %LOGONSERVER% >>\\contoso.com\Logs$\%username%.txt
echo %DATE% - %TIME% %USERNAME% logged into %COMPUTERNAME% ip%ipaddr% using %LOGONSERVER% >>\\contoso.com\Logs$\%computername%.txt
