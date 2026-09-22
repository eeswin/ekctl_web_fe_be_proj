@echo off
chcp 65001 > nul
cd /d "%~dp0"

if not exist ".venv\Scripts\python.exe" (
    echo [setup] .venv 생성 및 패키지 설치
    python -m venv .venv
    ".venv\Scripts\python.exe" -m pip install -r backend\requirements.txt
)

echo [server] 대시보드 http://127.0.0.1:8000/
start "" cmd /c "timeout /t 3 > /dev/null & start http://127.0.0.1:8000/"
".venv\Scripts\python.exe" -m uvicorn backend.main:app --reload --reload-dir backend --host 127.0.0.1 --port 8000
pause
