@echo off
setlocal
set "CHARACTER_PYTHON="
for /d %%D in ("%ProgramFiles%\Blender Foundation\Blender *") do (
  for /d %%V in ("%%~fD\*") do (
    if exist "%%~fV\python\bin\python.exe" set "CHARACTER_PYTHON=%%~fV\python\bin\python.exe"
  )
)
if defined CHARACTER_PYTHON goto bundled
where py >nul 2>nul
if not errorlevel 1 (
  py -3 "%~dp0tools\run_character_review.py"
) else (
  python "%~dp0tools\run_character_review.py"
)
goto finished
:bundled
"%CHARACTER_PYTHON%" "%~dp0tools\run_character_review.py"
:finished
if errorlevel 1 pause
