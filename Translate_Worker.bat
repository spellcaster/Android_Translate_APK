:: Interactive/automated script for help in translating APK's
:: Performs:
::   Decompiling
::   Compiling
::   Replacing of resource.arsc
::   Re-signing (needs ..\Sign_APK\Sign.bat)
:: Requirements:
::   You must have JDK installed and java.exe in PATH
:: Parameters:
::   %1 = full path to apk file (optional)
::   %2 = action number (enable automated mode: specified action will be executed and script will finish)
::   Available actions:
::     1. Decompile to %CD%\%apk_path%\ folder (code is NOT decompiled!)
::     2. Build to %CD%\%apk_path%\build folder
::     3. Make final translated apk (replace resource.arsc, re-sign)

@echo off

:: Not changing calling process' PATH variable
setlocal
set CDir=%~dp0%
set AutoMode=
:: Use aapt from SDK by default
set AAPT=aapt_SDK.exe
:: ! Uncomment this line ONLY if you have troubles building/decompiling apk's !
:: set AAPT=aapt_Custom.exe

:: Check all needed files

copy /y "%CDir%\%AAPT%" "%CDir%\aapt.exe" > nul

:: Java
call java.exe -version 2> nul
if errorlevel 1 (
	echo Java not installed!
	goto :Err
)
:: apktool
if not exist "%CDir%\apktool.jar" (
	echo %CDir%\apktool.jar not found
	set errorlevel=1
	goto :Err
)
:: aapt
if not exist "%CDir%\aapt.exe" (
	echo %CDir%\aapt.exe not found
	set errorlevel=1
	goto :Err
)
:: 7zip
if not exist "%CDir%\7za.exe" (
	echo %CDir%\7za.exe not found
	set errorlevel=1
	goto :Err
)

:: Turn on expandind of the variables on execute rather than on parse
setlocal EnableDelayedExpansion
:: determine APK path
if .%1%.==.. (
    title APK translate helper
    set apk_path=
    set /p apk_path=Input a FULL path to the apk to work with or empty string to exit and hit Enter 
    if .!apk_path!.==.. goto :EOF
    :: remove extension from the path
    set apk_path=!apk_path:~0,-4!
) else (
    set apk_path=%~dpn1%
)

if .%2%. NEQ .. (
    set step=%2%
    set AutoMode="true"
    echo =============== Automated mode ===============
    goto Step!step!
)

set step=1

:Prompt

echo =============== Interactive mode ===============
echo APK to operate on: %apk_path%.apk
echo Select an action to perform
echo 1. Decompile
echo 2. Build
echo 3. Make final translated apk
echo 4. Quit
set input_step=
set /p input_step=Enter action number ^(Enter: action !step!^) 

if "!input_step!" NEQ "" (
	set step=!input_step!
)

goto Step!step!

:: 1. Decompile

:Step1

echo ### Step 1. Decompile %apk_path%.apk
call java.exe -jar "%CDir%\apktool.jar" d -f "%apk_path%.apk" "%apk_path%"
if errorlevel 1 goto :Err

if defined AutoMode goto :Step4
set /a step=!step!+1
goto Prompt

:: 2. Build

:Step2

echo ### Step 2. Build %apk_path%
:: apktool couldn't work if aapt.exe isn't in the %CD% so moving there permanently
pushd "%CDir%"
call java.exe -jar "%CDir%\apktool.jar" b -f "%apk_path%"
if errorlevel 1 (
    popd
    goto :Err
) else (
    popd
)

if defined AutoMode goto :Step4
set /a step=!step!+1
goto Prompt

:: 3. Make final (replace resources, delete old cert, sign with our cert)

:Step3

echo ### Step 3. Make final %apk_path%_transl.apk

:: Copy original apk to %apk_path%_transl.apk
copy /y "%apk_path%.apk" "%apk_path%_transl.apk"
:: Replace resources.arsc in %apk_path%_transl.apk by a new one (no compression!)
call "%CDir%\7za.exe" a -tzip -mx0 "%apk_path%_transl.apk" "%apk_path%\build\apk\resources.arsc"
if errorlevel 1 goto :Err

:: Remove previous certs
call "%CDir%\7za.exe" d -tzip "%apk_path%_transl.apk" META-INF\*
if errorlevel 1 goto :Err

:: Sign with our own cert
call "%CDir%\..\Sign_APK\Sign.bat" "%apk_path%_transl.apk"
if errorlevel 1 (
    echo Error signing the file! Check that you have sign_apk\Sign.bat
    goto Prompt
)

if defined AutoMode goto :Step4
set /a step=!step!+1
goto Prompt

:Step4
goto :EOF

:Err
echo Error occured - process not finished
if not defined AutoMode pause