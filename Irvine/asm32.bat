@echo off
REM -----------------------------
REM asm32.bat - Build MASM + Irvine32
REM Usage: asm32 filename.asm
REM -----------------------------

REM Check for argument
IF "%~1"=="" (
    echo Usage: asm32 filename.asm
    exit /b 1
)

SET FILE=%~1
SET BASENAME=%~n1

REM Path to Irvine32
SET IRVINE=C:\Irvine

REM Assemble
echo Assembling %FILE%...
ml /c /coff %FILE%
IF ERRORLEVEL 1 (
    echo Assembly failed!
    exit /b 1
)

REM Link
echo Linking %BASENAME%.obj...
link %BASENAME%.obj %IRVINE%\Irvine32.lib %IRVINE%\Kernel32.lib %IRVINE%\User32.lib /SUBSYSTEM:CONSOLE
IF ERRORLEVEL 1 (
    echo Linking failed!
    exit /b 1
)

REM Run
echo Build successful! Running %BASENAME%.exe...
%BASENAME%.exe