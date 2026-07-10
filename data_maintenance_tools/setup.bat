@echo off
setlocal
cd /d "%~dp0"

where python >nul 2>&1
if errorlevel 1 (
  echo Python is required. Install from https://www.python.org/downloads/
  echo Check "Add python.exe to PATH" during installation.
  exit /b 1
)

echo Creating virtual environment in .venv ...
python -m venv .venv
if errorlevel 1 exit /b 1

call .venv\Scripts\activate.bat
python -m pip install --upgrade pip
pip install -r requirements.txt
if errorlevel 1 exit /b 1

if not exist festival_data_entry.json (
  copy festival_data_entry.example.json festival_data_entry.json
  echo Created festival_data_entry.json from example.
)

if not exist data mkdir data

echo Setup complete.
echo.
echo Note: folder/file pickers need Python's tkinter (included with python.org installs).
echo Start the app:  run.bat
echo Or:             run.bat --open-browser
