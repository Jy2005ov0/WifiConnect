@echo off
rem Double-click to remove WiFi Connect from this laptop.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Uninstall.ps1"
rem Keep the window open if something went wrong, so the message can be read.
if errorlevel 1 pause
