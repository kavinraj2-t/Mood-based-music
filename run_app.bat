@echo off
title Emotion Music Player Launcher
echo ===================================================
echo   Starting Emotion-Based Music Player in MATLAB...
echo ===================================================
echo.
start "" "C:\Program Files\MATLAB\R2026b\bin\matlab.exe" -sd "%~dp0." -r "setupProject; EmotionMusicPlayer;"
