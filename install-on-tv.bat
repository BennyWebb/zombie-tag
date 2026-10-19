@echo off
rem Double-click this file to build Zombie Tag as an Android TV app and put it on the Nvidia Shield.
rem You need Android Studio installed once, and Network debugging turned on on the Shield
rem (see "Playing on the TV" in README.md).
cd /d "%~dp0"

rem the Java and adb that come with Android Studio
if not defined JAVA_HOME if exist "%ProgramFiles%\Android\Android Studio\jbr" set "JAVA_HOME=%ProgramFiles%\Android\Android Studio\jbr"
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
