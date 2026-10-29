@echo off
setlocal
if exist "%~dp0.venv\Scripts\python.exe" (
  "%~dp0.venv\Scripts\python.exe" "%~dp0tools\run_game.py" %*
  goto finished
)
set "GAME_PYTHON="
for /d %%D in ("%ProgramFiles%\Blender Foundation\Blender *") do (
  for /d %%V in ("%%~fD\*") do (
    if exist "%%~fV\python\bin\python.exe" set "GAME_PYTHON=%%~fV\python\bin\python.exe"
  )
)
if defined GAME_PYTHON goto bundled
where py >nul 2>nul
if not errorlevel 1 (
  py -3 "%~dp0tools\run_game.py" %*
) else (
  python "%~dp0tools\run_game.py" %*
)
goto finished
:bundled
"%GAME_PYTHON%" "%~dp0tools\run_game.py" %*
:finished
if errorlevel 1 pause
