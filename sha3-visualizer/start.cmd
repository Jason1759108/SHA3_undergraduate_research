@echo off
where node >nul 2>nul
if not errorlevel 1 (
  node "%~dp0server.cjs"
) else if exist "%USERPROFILE%\.cache\codex-runtimes\codex-primary-runtime\dependencies\node\bin\node.exe" (
  "%USERPROFILE%\.cache\codex-runtimes\codex-primary-runtime\dependencies\node\bin\node.exe" "%~dp0server.cjs"
) else (
  echo Node.js was not found. You can open index.html directly without a server.
)
pause
