@echo off

set result=0

net share ipc$ | findstr /r "IPC\$"
if %errorlevel% neq 0 (
	set result=1
)

net share admin$ | findstr /r "ADMIN\$"
if %errorlevel% neq 0 (
	set result=1
)

net share c$ | findstr /r "C\$"
if %errorlevel% neq 0 (
	set result=1
)

if %result% neq 0 (
	echo %DATE% - %TIME% %USERNAME% logged into %COMPUTERNAME% using %LOGONSERVER% >>\\admsrv-01.contoso.com\Logs$\Shares\%COMPUTERNAME%.txt
)
