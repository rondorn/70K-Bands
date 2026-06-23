@echo off
setlocal
cd /d "%~dp0"

if not exist .venv (
  echo First-time setup required.
  call setup.bat
  if errorlevel 1 exit /b 1
)

call .venv\Scripts\activate.bat
python run_data_entry.py %*
