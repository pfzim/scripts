@echo off

rem backups rotate batch script v0.7.0 (cccf947f785166b3fb58a999850a929f)
rem save last 90 days old backups, all 1 and 15 day of month backups
rem other will be deleted

SET BACKUPDST=F:\DIRBACKUP\

goto lb_start

:fn_purge
	FOR %%a IN (%BACKUPDST%backup-*) DO (
		FOR /F "delims=.- tokens=2,3,4" %%b IN ("%%~nxa") DO (
			echo Looking file %%~nxa...
			SET FILENAME=%%a
			IF "%%d" == "08" (
				SET /A FILEDAY=8
			) ELSE IF "%%d" == "09" (
				SET /A FILEDAY=9
			) ELSE (
				SET /A FILEDAY=%%d
			)
			IF "%%c" == "08" (
				SET /A FILEMONTH=8
			) ELSE IF "%%c" == "09" (
				SET /A FILEMONTH=9
			) ELSE (
				SET /A FILEMONTH=%%c
			)
			IF "%%b" == "08" (
				SET /A FILEYEAR=8
			) ELSE IF "%%b" == "09" (
				SET /A FILEYEAR=9
			) ELSE (
				SET /A FILEYEAR=%%b
			)

			IF "%%d" == "01" (
				call :fn_never_expired
			) ELSE IF "%%d" == "15" (
				call :fn_never_expired
			) ELSE (
				call :fn_calc_expire_date
				call :fn_check_and_delete
			)
		)
	)
goto :EOF

:fn_calc_expire_date
	SET /A FILEDAY=FILEDAY+90
	call :fn_fix_date
goto :EOF

:fn_fix_date
	SET /A LEAPYEAR=FILEYEAR%%4
	SET /A LEAPYEAR1=FILEYEAR%%100
	SET /A LEAPYEAR2=FILEYEAR%%400
	SET /A DPM=30
	IF %FILEMONTH% NEQ 2 (
		FOR %%i IN (1,3,5,7,8,10,12) DO (
			IF %FILEMONTH% NEQ %%i (
				rem empty
			) ELSE (
				SET /A DPM=31
			)
		)
	) ELSE (
		rem echo "if(%LEAPYEAR% == 0 && (%LEAPYEAR1% != 0 || %LEAPYEAR2% == 0) LEAPYEAR"
		IF %LEAPYEAR% NEQ 0 (
			SET /A DPM=28
		) ELSE IF %LEAPYEAR2% NEQ 0 (
			IF %LEAPYEAR1% NEQ 0 (
				SET /A DPM=29
			) ELSE (
				SET /A DPM=28
			)
		) ELSE (
			SET /A DPM=29
		)
	)
	IF %FILEDAY% GTR %DPM% (
		SET /A FILEMONTH=FILEMONTH+1
		SET /A FILEDAY=FILEDAY-DPM
	) ELSE (
		goto :EOF
	)
	IF %FILEMONTH% GTR 12 (
		SET /A FILEYEAR=FILEYEAR+1
		SET /A FILEMONTH=1
	)
	goto :fn_fix_date
goto :EOF

:fn_check_and_delete
	SET /A CMPDATE=0
	IF %FILEYEAR% GTR %TODAYYEAR% (
		SET /A CMPDATE=1
	) ELSE IF %FILEYEAR% LSS %TODAYYEAR% (
		SET /A CMPDATE=-1
	) ELSE IF %FILEMONTH% GTR %TODAYMONTH% (
		SET /A CMPDATE=1
	) ELSE IF %FILEMONTH% LSS %TODAYMONTH% (
		SET /A CMPDATE=-1
	) ELSE IF %FILEDAY% GTR %TODAYDAY% (
		SET /A CMPDATE=1
	) ELSE IF %FILEDAY% LSS %TODAYDAY% (
		SET /A CMPDATE=-1
	)

	IF %CMPDATE% LEQ 0 (
		echo File expired %FILENAME% [%FILEDAY%.%FILEMONTH%.%FILEYEAR%]
		call :fn_purge_action
	) ELSE (
		echo File alive %FILENAME% [%FILEDAY%.%FILEMONTH%.%FILEYEAR%]
	)
goto :EOF

:fn_never_expired
	echo File forever %FILENAME% [%FILEDAY%.%FILEMONTH%.%FILEYEAR%]
	rem echo Move to archive file %FILENAME% [%FILEDAY%.%FILEMONTH%.%FILEYEAR%]
	rem move "%FILENAME%" R:\ARCHIVE\
goto :EOF

:fn_purge_action
	del /q /f "%FILENAME%"
goto :EOF

rem FOR /F "tokens=*" %%i IN ('forfiles -pd:\test\ -d-7 -mbackup*') DO del /P d:\test\%%i
rem forfiles -pd:\test\ -mbackup* -d-7 -c"cmd /c del /q @PATH\@FILE"

:lb_start

SET CURDATE=%DATE%.%TIME%
FOR /F "delims=.: tokens=1,2,3,4,5" %%t IN ("%CURDATE%") DO (
	IF "%%t" == "08" (
		SET /A TODAYDAY=8
	) ELSE IF "%%t" == "09" (
		SET /A TODAYDAY=9
	) ELSE (
		SET /A TODAYDAY=%%t
	)
	IF "%%u" == "08" (
		SET /A TODAYMONTH=8
	) ELSE IF "%%u" == "09" (
		SET /A TODAYMONTH=9
	) ELSE (
		SET /A TODAYMONTH=%%u
	)
	IF "%%v" == "08" (
		SET /A TODAYYEAR=8
	) ELSE IF "%%v" == "09" (
		SET /A TODAYYEAR=9
	) ELSE (
		SET /A TODAYYEAR=%%v
	)

	IF %%w LSS 10 (
		SET BACKUPNAME=backup-%%v-%%u-%%t-0%CURDATE:~12,1%%%x
	) ELSE (
		SET BACKUPNAME=backup-%%v-%%u-%%t-%CURDATE:~11,2%%%x
    )
)

echo Today is %TODAYDAY%-%TODAYMONTH%-%TODAYYEAR%.

pushd .

rem backup operation start here or in other script

call :fn_purge

popd

:lb_exit
