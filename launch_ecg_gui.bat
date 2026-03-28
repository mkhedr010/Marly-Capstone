@echo off
REM ======================================================================
REM ECG Stream Visualizer - GUI Launcher
REM
REM This script activates the Python virtual environment and launches
REM the ECG visualizer GUI. Double-click this file to start the GUI.
REM
REM Author: Claude Code
REM Date: March 2026
REM ======================================================================

echo.
echo ====================================================
echo   ECG Stream Visualizer - GUI Launcher
echo ====================================================
echo.
echo Starting GUI...
echo.

REM Get the directory where this batch file is located
set SCRIPT_DIR=%~dp0

REM Change to project directory
cd /d "%SCRIPT_DIR%"

REM Activate virtual environment
echo Activating virtual environment...
call "%SCRIPT_DIR%venv\Scripts\activate.bat"

if errorlevel 1 (
    echo.
    echo ERROR: Failed to activate virtual environment!
    echo Please ensure venv exists at: %SCRIPT_DIR%venv
    echo.
    pause
    exit /b 1
)

echo Virtual environment activated.
echo.

REM Launch the GUI
echo Launching ECG Visualizer GUI...
python "%SCRIPT_DIR%python\ecg_gui_launcher.py"

REM Deactivate virtual environment on exit
call deactivate

echo.
echo GUI closed.
echo.
pause
