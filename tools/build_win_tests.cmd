@echo off
setlocal EnableExtensions
cd /d "%~dp0.."

set "VSWHERE=%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe"
if not exist "%VSWHERE%" (
  echo ERROR: vswhere.exe not found. Install Visual Studio with C++ workload.
  exit /b 1
)
for /f "usebackq delims=" %%I in (`"%VSWHERE%" -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath`) do set "VSHOME=%%I"
set "VCVARS=%VSHOME%\VC\Auxiliary\Build\vcvars64.bat"
if not exist "%VCVARS%" (
  echo ERROR: vcvars64.bat not found at "%VCVARS%"
  exit /b 1
)

call "%VCVARS%" || exit /b 1

if not "%~1"=="" (set "NASM=%~1") else (set "NASM=%LOCALAPPDATA%\bin\NASM\nasm.exe")
if not exist "%NASM%" (
  echo ERROR: NASM not found at "%NASM%". Usage: %~nx0 [path\to\nasm.exe]
  exit /b 1
)

if not exist "build\win_x86_64" mkdir "build\win_x86_64"

echo === Assembling ===
"%NASM%" -f win64 -g -F cv8 -o "build\win_x86_64\bootstrap.obj"     "src\hal\win_x86_64\bootstrap.asm"     || goto :fail
"%NASM%" -f win64 -g -F cv8 -o "build\win_x86_64\abi.obj"          "src\hal\win_x86_64\abi.asm"           || goto :fail
"%NASM%" -f win64 -g -F cv8 -o "build\win_x86_64\memory.obj"       "src\hal\win_x86_64\memory.asm"        || goto :fail
"%NASM%" -f win64 -g -F cv8 -o "build\win_x86_64\time.obj"         "src\hal\win_x86_64\time.asm"          || goto :fail
"%NASM%" -f win64 -g -F cv8 -o "build\win_x86_64\threads.obj"      "src\hal\win_x86_64\threads.asm"       || goto :fail
"%NASM%" -f win64 -g -F cv8 -o "build\win_x86_64\syscall.obj"      "src\hal\win_x86_64\syscall.asm"       || goto :fail
"%NASM%" -f win64 -g -F cv8 -o "build\win_x86_64\fileio.obj"       "src\hal\win_x86_64\fileio.asm"        || goto :fail
"%NASM%" -f win64 -g -F cv8 -o "build\win_x86_64\test_win64_abi.obj"      "tests\unit\test_win64_abi.asm"      || goto :fail
"%NASM%" -f win64 -g -F cv8 -o "build\win_x86_64\test_win64_hal_core.obj" "tests\unit\test_win64_hal_core.asm" || goto :fail
"%NASM%" -f win64 -g -F cv8 -o "build\win_x86_64\test_win64_hal_fileio.obj" "tests\unit\test_win64_hal_fileio.asm" || goto :fail

set "LFLAGS=/NOLOGO /MACHINE:X64 /SUBSYSTEM:CONSOLE /NODEFAULTLIB /ENTRY:_start"

echo === Linking test_win64_abi.exe ===
link %LFLAGS% /OUT:"build\win_x86_64\test_win64_abi.exe" "build\win_x86_64\test_win64_abi.obj" "build\win_x86_64\abi.obj" "build\win_x86_64\bootstrap.obj" kernel32.lib || goto :fail

echo === Linking test_win64_hal_core.exe ===
link %LFLAGS% /OUT:"build\win_x86_64\test_win64_hal_core.exe" "build\win_x86_64\test_win64_hal_core.obj" "build\win_x86_64\bootstrap.obj" "build\win_x86_64\abi.obj" "build\win_x86_64\memory.obj" "build\win_x86_64\time.obj" "build\win_x86_64\threads.obj" kernel32.lib || goto :fail

echo === Linking test_win64_hal_fileio.exe ===
link %LFLAGS% /OUT:"build\win_x86_64\test_win64_hal_fileio.exe" "build\win_x86_64\test_win64_hal_fileio.obj" "build\win_x86_64\bootstrap.obj" "build\win_x86_64\abi.obj" "build\win_x86_64\fileio.obj" "build\win_x86_64\syscall.obj" kernel32.lib || goto :fail

echo.
echo OK: build\win_x86_64\test_win64_abi.exe
echo OK: build\win_x86_64\test_win64_hal_core.exe
echo OK: build\win_x86_64\test_win64_hal_fileio.exe
exit /b 0

:fail
echo BUILD FAILED
exit /b 1
