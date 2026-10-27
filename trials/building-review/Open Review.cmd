@echo off
setlocal
where py >nul 2>nul
if not errorlevel 1 (
  py -3 "%~dp0serve.py" --open
) else (
  python "%~dp0serve.py" --open
)
if errorlevel 1 (
  echo Install Python 3.10 or newer, or run serve.py with your existing Python.
  pause
)
