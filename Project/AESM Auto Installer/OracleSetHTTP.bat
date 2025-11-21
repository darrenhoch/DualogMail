@echo off
@setlocal
set sqlplusexec="C:\Dualog\oraclexe\app\oracle\product\11.2.0\server\bin\sqlplus.exe"
set sqlfile=%temp%\oraclesetport.sql
set oraclehttpport=4444
set oraclesyspassword=oracle
echo WHENEVER SQLERROR EXIT SQL.SQLCODE>%sqlfile%
echo CONNECT sys/%oraclesyspassword%@127.0.0.1/xe as sysdba>>%sqlfile%
echo EXEC DBMS_XDB.SETHTTPPORT(%oraclehttpport%);>>%sqlfile%
echo EXIT;>>%sqlfile%
echo Changing Oracle http port to %oraclehttpport%
%sqlplusexec% /nolog @%sqlfile% > nul 2>&1
if %errorlevel% equ 0 (
	echo Oracle http port changed successfully
) else (
	echo failed to change Oracle http port. ORA error: %errorlevel%
)
del /f /q %sqlfile%
endlocal
exit /b %errorlevel%