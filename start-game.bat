@echo off
rem Double-click this file to start Zombie Tag.
cd /d "%~dp0"
if not exist node_modules (
  echo Installing the game the first time. This takes a minute...
  call npm install
)
call npm run dev
