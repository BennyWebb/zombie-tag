@echo off
rem Double-click this file to build Zombie Tag as an Android TV app and put it on the Nvidia Shield.
rem You need Android Studio installed once, and Network debugging turned on on the Shield
rem (see "Playing on the TV" in README.md).
cd /d "%~dp0"

rem The build needs Java 21 to 24 (Java 25 and newer are too new for it). Use JAVA_HOME if it's one
rem of those, else the Java that comes with Android Studio, else another Java 21 to 24 on this computer.
set "JDK="
call :tryjdk "%JAVA_HOME%"
call :tryjdk "%ProgramFiles%\Android\Android Studio\jbr"
for /d %%d in ("%ProgramFiles%\Microsoft\jdk-*" "%ProgramFiles%\Eclipse Adoptium\jdk-*" "%ProgramFiles%\Java\jdk-*" "%ProgramFiles%\Zulu\zulu-*" "%USERPROFILE%\.jdks\*") do call :tryjdk "%%~d"
if not defined JDK (
  echo The build needs Java 21, and this computer only has a newer or older Java.
  echo Install Java 21 by typing this in a terminal, then run this file again:
  echo.
  echo     winget install Microsoft.OpenJDK.21
  echo.
  pause
  exit /b 1
)
set "JAVA_HOME=%JDK%"
echo Building with the Java in %JAVA_HOME%

rem the adb that comes with Android Studio
if not defined ANDROID_HOME set "ANDROID_HOME=%LOCALAPPDATA%\Android\Sdk"
set "ADB=%ANDROID_HOME%\platform-tools\adb.exe"
if not exist "%ADB%" (
  echo Can't find adb. Install Android Studio and open it once so it downloads the Android SDK.
  pause
  exit /b 1
)

if not exist node_modules (
  echo Installing the game the first time. This takes a minute...
  call npm install || goto failed
)

echo Building the game...
call npm run tv || goto failed
pushd android
call gradlew.bat assembleDebug || (popd & goto failed)
popd

set /p SHIELD=What's the Shield's IP address (Settings, Device Preferences, About, Status)? 
"%ADB%" connect %SHIELD%:5555
echo If the TV asks "Allow network debugging?", choose "Always allow from this computer" and OK.
"%ADB%" wait-for-device
echo Putting Zombie Tag on the Shield...
"%ADB%" install -r android\app\build\outputs\apk\debug\app-debug.apk || goto failed
echo.
echo Done! Zombie Tag is in the Shield's apps.
pause
exit /b 0

:failed
echo.
echo Something went wrong (see above).
pause
exit /b 1

rem Picks the Java in folder %1 if it's version 21 to 24 (and no Java has been picked yet).
:tryjdk
if defined JDK exit /b 0
if "%~1"=="" exit /b 0
if not exist "%~1\release" exit /b 0
findstr /b /r /c:"JAVA_VERSION=.2[1-4]" "%~1\release" >nul && set "JDK=%~1"
exit /b 0
