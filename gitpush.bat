@echo off
setlocal

REM ===========================================================
REM  gitpush.bat
REM  Stages everything, commits, and pushes the repository this
REM  file lives in. Double-click to run, or call from a command
REM  prompt with a commit message:  gitpush.bat fixed the thing
REM ===========================================================

REM Work in the folder containing this script, not wherever the
REM shell happened to be. %~dp0 is that folder.
cd /d "%~dp0"

REM --- Sanity checks -----------------------------------------

where git >nul 2>&1
if errorlevel 1 goto nogit

git rev-parse --is-inside-work-tree >nul 2>&1
if errorlevel 1 goto norepo

for /f "delims=" %%b in ('git rev-parse --abbrev-ref HEAD') do set "BRANCH=%%b"
if "%BRANCH%"=="HEAD" goto detached

echo.
echo   Repository : %CD%
echo   Branch     : %BRANCH%
echo.

REM --- Stage ------------------------------------------------

git add -A
if errorlevel 1 goto stagefail

REM "diff --cached --quiet" exits 0 when nothing is staged.
git diff --cached --quiet
if not errorlevel 1 goto nochanges

echo   Changes to be committed:
echo.
git status --short
echo.

REM --- Commit message ---------------------------------------

REM Anything passed on the command line becomes the message.
set "MSG=%*"
if not "%MSG%"=="" goto docommit

set "MSG="
set /p "MSG=  Commit message (leave blank for a timestamp): "
if not "%MSG%"=="" goto docommit

for /f "delims=" %%t in ('powershell -NoProfile -Command "Get-Date -Format yyyy-MM-dd_HH-mm-ss"') do set "MSG=Auto-commit %%t"

:docommit
echo.
git commit -m "%MSG%"
if errorlevel 1 goto commitfail

REM --- Push -------------------------------------------------

echo.
echo   Pushing...
echo.

REM Does this branch have an upstream yet?
git rev-parse --abbrev-ref --symbolic-full-name "@{u}" >nul 2>&1
if errorlevel 1 goto firstpush

git push
if errorlevel 1 goto pushfail
goto success

:firstpush
echo   No upstream set for %BRANCH% - setting origin/%BRANCH%.
echo.
git push -u origin "%BRANCH%"
if errorlevel 1 goto pushfail
goto success

REM --- Outcomes ----------------------------------------------

:success
echo.
echo   Done. Committed and pushed to %BRANCH%.
goto end

:nochanges
echo   Nothing to commit - working tree is clean.
echo.
echo   Checking whether anything is waiting to be pushed...
git push
goto end

:nogit
echo.
echo   ERROR: git was not found on PATH.
echo   Install Git for Windows, or run this from Git Bash.
goto end

:norepo
echo.
echo   ERROR: "%CD%" is not a git repository.
echo   Put this file inside the repo folder and try again.
goto end

:detached
echo.
echo   ERROR: HEAD is detached - you are not on a branch.
echo   Check out a branch first, then re-run.
goto end

:stagefail
echo.
echo   ERROR: "git add" failed. Nothing has been committed.
goto end

:commitfail
echo.
echo   ERROR: "git commit" failed. Nothing has been pushed.
echo   If this is your first commit on this machine, set your identity:
echo       git config --global user.name  "Your Name"
echo       git config --global user.email "you@example.com"
goto end

:pushfail
echo.
echo   ERROR: "git push" failed. The commit was made locally and is safe.
echo   Common causes: no network, credentials needed, or the remote has
echo   commits you do not have yet. If it is the last one, run:
echo       git pull --rebase
echo   ...resolve any conflicts, then run this script again.
goto end

:end
echo.
pause
endlocal
