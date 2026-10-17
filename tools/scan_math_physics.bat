@echo off
REM ============================================================================
REM  Scan all math/physics textbooks with Marker on GPU, then rebuild the index
REM  so those books have clean text + LaTeX equations. Resumable (skips books
REM  already scanned in output\marker\). Run AFTER setup_marker_gpu.bat.
REM ============================================================================
set "VENV=%~dp0..\.marker_venv"
cd /d "%~dp0.."
"%VENV%\Scripts\python.exe" tools\marker_batch.py
pause
