@echo off
cls
echo ==============================================================================================
echo Dualog IMAP Mail Store Backup / Change Folder and Message Ownership / Version 1.0.0 2021-11-15
echo ==============================================================================================
set var_backupfolder=C:\DualogBackup\
set var_backupfilemask=imapmailstore.dualogbackup*
set var_thisfolder=%~dp0
echo.
echo This Folder (Script) : %var_thisfolder%
echo Dualog Backup Folder : %var_backupfolder%
echo User's 'Temp' Folder : %temp%
if not exist "%var_thisfolder%7z.exe" goto 7ZipEXEMissing
if not exist "%var_thisfolder%7z.dll" goto 7ZipDLLMissing
if not exist "%var_thisfolder%DualogUserMap.exe" goto DualogUserMapEXEMissing
if not exist "%var_thisfolder%DualogUserMap.ini" goto DualogUserMapINIMissing
if not exist "%var_backupfolder%%var_backupfilemask%" goto NoBackupFilesDetected
echo.
echo List of Detected Dualog IMAP Mail Store Backup Files...
echo.
for %%a IN ("%var_backupfolder%%var_backupfilemask%") DO echo %%~nxa
rem echo.
rem echo User ID Mapping File...
rem echo.
rem type "%var_thisfolder%DualogUserMap.ini"
echo.
echo Starting Main Process...
for %%a IN ("%var_backupfolder%%var_backupfilemask%") DO if /i not "%%a" == "%var_backupfolder%imapmailstore.dualogbackup.archive" call :ProcessBackupFile %%a
echo.
echo =================
echo Process Completed
echo =================
echo.
goto End

:ProcessBackupFile
echo.
echo Processing File : %~nx1
if /i exist %temp%\folders del %temp%\folders
call 7z e -aoa -bb0 -bd -pG4VESSEL -o%temp% %1 FOLDERS > nul
if not exist %temp%\folders (
  echo Failed to Extract File Named 'FOLDERS' From Archive!
  exit /b)
if /i exist %temp%\folders copy %temp%\folders %var_backupfolder%Original-Folders-File-From-%~nx1 > nul
if /i exist %temp%\folders copy %temp%\folders %temp%\Original-Folders-File-From-%~nx1 > nul
echo.
call %var_thisfolder%DualogUserMap.exe
if /i exist %temp%\dualogusermap.log type %temp%\dualogusermap.log
if /i exist %temp%\dualogusermap.log del %temp%\dualogusermap.log
echo.
echo Replacing Modified File in Archive (This Will Take Some Time - Please Wait)...
7z d -pG4VESSEL %1 FOLDERS > nul
7z a -pG4VESSEL %1 %temp%\FOLDERS > nul
if /i exist %temp%\folders del %temp%\folders
echo.
echo Processing of File Completed (%~nx1)
exit /b

:NoBackupFilesDetected
echo.
echo =====
echo ERROR
echo =====
echo.
echo No Dualog IMAP mail store backup files were detected using this mask:
echo.
echo %var_backupfolder%%var_backupfilemask%
echo.
goto End

:DualogUserMapEXEMissing
echo.
echo =====
echo ERROR
echo =====
echo.
echo File DualogUserMap.exe not detected
echo.
echo Please ensure that file DualogUserMap.exe is in the same folder as this script
echo.
goto End

:DualogUserMapINIMissing
echo.
echo =====
echo ERROR
echo =====
echo.
echo File DualogUserMap.ini not detected
echo.
echo Please ensure that file DualogUserMap.ini is in the same folder as this script
echo.
goto End

:7ZipDLLMissing
echo.
echo =====
echo ERROR
echo =====
echo.
echo File 7z.dll not detected
echo.
echo Please ensure that file 7z.dll is in the same folder as this script
echo.
goto End

:7ZipEXEMissing
echo.
echo =====
echo ERROR
echo =====
echo.
echo File 7z.exe not detected
echo.
echo Please ensure that file 7z.exe is in the same folder as this script
echo.
goto End

:End
pause
