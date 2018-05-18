@echo off

findstr /c:%COMPUTERNAME% \\contoso.com\Common\MSK\_Common\test\list_destination.txt
if %errorlevel%==0 (
  for /F "tokens=*" %%s in (\\contoso.com\Common\MSK\_Common\test\list_folders.txt) do (
    for %%f in ("%%s") do robocopy "%%s" "c:\software\%%~nxf" /e /purge /copy:dat /dcopy:t /mt:3 /r:60
	echo %DATE% %TIME% %COMPUTERNAME% %%s >>\\contoso.com\Common\MSK\_Common\test\get.log
  )
)
