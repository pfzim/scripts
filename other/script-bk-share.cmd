@echo off

set account=env@contoso.com

echo **********************************************************************
echo ������ ��஫� �� %account% ��� ������祭�� �⥢��� ��᪠
echo **********************************************************************

:lb_start
net use y: \\srv-file-01\dev * /user:%account%
if errorlevel 1 goto lb_start
