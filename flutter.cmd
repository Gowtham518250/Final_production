@echo off
:: Retail Mind - Flutter Helper Script
:: Run this instead of 'flutter' directly
:: Usage: flutter.cmd <any flutter command>
:: Example: flutter.cmd pub get
::          flutter.cmd build apk --debug
::          flutter.cmd clean

if not defined FLUTTER_BIN if defined FLUTTER_ROOT set "FLUTTER_BIN=%FLUTTER_ROOT%\bin"
if not defined FLUTTER_BIN (
    echo Set FLUTTER_ROOT or FLUTTER_BIN to your Flutter installation.
    exit /b 1
)

if not defined JAVA_HOME if exist "%ProgramFiles%\Android\Android Studio\jbr" set "JAVA_HOME=%ProgramFiles%\Android\Android Studio\jbr"
if not defined ANDROID_HOME if defined LOCALAPPDATA set "ANDROID_HOME=%LOCALAPPDATA%\Android\Sdk"

set "PATH=%FLUTTER_BIN%;%PATH%"
if defined JAVA_HOME set "PATH=%JAVA_HOME%\bin;%PATH%"
if defined ANDROID_HOME set "PATH=%ANDROID_HOME%\platform-tools;%PATH%"

"%FLUTTER_BIN%\flutter.bat" %*
