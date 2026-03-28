@echo off
REM ======================================================================
REM ECG Stream Visualizer - GUI Launcher (Silent Mode)
REM
REM This script launches the GUI without showing a console window.
REM Uses pythonw.exe which runs Python scripts without a console.
REM
REM Author: Claude Code
REM Date: March 2026
REM ======================================================================

REM Get the directory where this batch file is located
set SCRIPT_DIR=%~dp0

REM Launch GUI using pythonw.exe (no console window)
start "" "%SCRIPT_DIR%venv\Scripts\pythonw.exe" "%SCRIPT_DIR%python\ecg_gui_launcher.py"
