# [My useful scripts](https://github.com/pfzim/scripts)

`rotate.cmd`,
`rotate.sh`   - remove files olders than XX days and stay it if 1 or 15 day of month `backup-YYYY-MM-DD-any-name-here.ext`

`purge_exchanger.sh` - move files unmodified more that XX days to subfolder and remove permanently after XX days

`etc/fonts` - fontconfig settings for MS fonts with disabled antialiasing

`windows-resistry` - different Windows registry settings

`settings` - other linux configuration files

`orchestrator/` - Runbooks for System Center Orchestrator

`NetBackup/` - scripts for generate different reports


https://github.com/Disassembler0/Win10-Initial-Setup-Script/issues/250
Receive updates for other Microsoft products (Windows 7)
(New-Object -ComObject Microsoft.Update.ServiceManager).AddService2("7971f918-a847-4430-9279-4a52d1efe18d", 7, "")
