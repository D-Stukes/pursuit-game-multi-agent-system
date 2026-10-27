@echo off
setlocal
set "PLAYTEST_PYTHON="
for /d %%D in ("%ProgramFiles%\Blender Foundation\Blender *") do (
  for /d %%V in ("%%~fD\*") do (
    if exist "%%~fV\python\bin\python.exe" set "PLAYTEST_PYTHON=%%~fV\python\bin\python.exe"
  )
)
if defined PLAYTEST_PYTHON goto bundled
where py >nul 2>nul
if not errorlevel 1 (
  py -3 "%~dp0tools\run_playtest.py"
) else (
  python "%~dp0tools\run_playtest.py"
)
goto finished
:bundled
"%PLAYTEST_PYTHON%" "%~dp0tools\run_playtest.py"
:finished
if errorlevel 1 pause
