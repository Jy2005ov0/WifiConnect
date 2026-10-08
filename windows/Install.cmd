@echo off
rem Double-click to set up WiFi Connect on this laptop.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Install.ps1"
rem Keep the window open if something went wrong, so the message can be read.
if errorlevel 1 pause
