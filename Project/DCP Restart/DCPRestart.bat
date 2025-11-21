@echo off
call net start duacorepro
timeout 500
call net stop duacorepro
pause