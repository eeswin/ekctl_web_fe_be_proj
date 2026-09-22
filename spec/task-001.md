# task-001 — 스캐폴드 + UI + 연동 테스트 (UI-First)

> 출처 : `module_1/docs/PRD.md` (v3) · `module_1/data/*` · `.claude/DESIGN.md`
> 범위 : Phase-01 ~ Phase-05 · 후속 : task-002 (BE 핵심 로직) · task-003 (FE 기능 · 통합 검증)
> 상태 표기 : ✅ 완료 · ❌ 미착수 · ⚠️ 확인 필요 / 보류

---

## 0. 기준 정보

### 0.1 데이터 확인 결과

| 파일 | 확인 내용 |
|---|---|
| `img_1~3.png` | Agilent Swept SA 캡처 · Avg Type RMS · Span 9 MHz · RBW/VBW 1.0 MHz · 전력 단위 µW |
| `img_1~3.png` | Center · Mkr1 주파수 · Mkr1 전력 · 시각 = PRD §3.2 값과 일치 (육안 확인) |
| `report_template.docx` | A4 · 맑은 고딕 단일 · 표 5개 · 플레이스홀더 23개(고유 22개) · 모두 단일 run (분할 없음) · 머리글/바닥글 없음 |

| 템플릿 위치 | 플레이스홀더 |
|---|---|
| 표0 기본정보 | `doc_no` · `test_date` · `test_name` · `tester` · `standard` · `sample_name` · `cf_db` (측정거리 `3 m` 고정 텍스트) |
| 표1 판정 요약 | `total` · `pass_cnt` · `fail_cnt` · `verdict` |
| 표2 측정 결과 | 헤더 1행 + 반복 대상 1행 : `r.no` · `r.freq_mhz` · `r.power_uw` · `r.dbm` · `r.dbuv_m` · `r.limit` · `r.margin` · `r.verdict` |
| 표3 특이사항 | `remarks` |
| 표4 서명 | `tester` · `reviewer` |
| 본문 하단 | `generated_at` |

### 0.2 검증 기댓값 (기본 Limit §3.1 · 960~6000 MHz 구간 = 54.0 dBµV/m)

| 파일 | 주파수(MHz) | µW | dBm | dBµV/m (CF −50) | 마진 | 판정 | CF −52 |
|---|---|---|---|---|---|---|---|
| img_1 | 2405.095 | 641.83 | −1.93 | 55.07 | −1.07 | FAIL | +0.93 PASS |
| img_2 | 2440.095 | 477.12 | −3.21 | 53.79 | +0.21 | PASS | +2.21 PASS |
| img_3 | 2480.131 | 378.31 | −4.22 | 52.78 | +1.22 | PASS | +3.22 PASS |

- 종합 : CF −50 → FAIL 1 · PASS 2 · 종합 FAIL / CF −52 → 전부 PASS (PRD F4 수치와 재계산 일치)

### 0.3 스택 · 경로 결정

| 구분 | 결정 | 근거 |
|---|---|---|
| FE | Vite + TS (`vanilla-ts`) · `project/frontend` · 5173 | CLAUDE.md 기본 스택 (프레임워크 미지정) |
| BE | FastAPI · `project/backend` · 8000 · 가상환경 `project/.venv` | CLAUDE.md 기본 스택 |
| 저장소 | `project/backend/limits.json` (SQLite 미사용) | PRD §3.1 명시 우선 |
| 산출물 | 바이너리 응답 + `project/output/` 사본 저장 | PRD F5 · CLAUDE.md output 규칙 |
| API Key | `day5/.env` → `OPENAI_API_KEY` (backend 기준 상위 탐색 로드) | 기존 설정 |
| 디자인 | DESIGN.md 토큰(색 · 서체 · 라운드 · 간격) · 컴포넌트 스타일 적용 · 화면 범위는 PRD F6 | PRD 우선 |

### 0.4 모호 · 확인 필요 사항 ⚠️

| # | 항목 | 내용 | 잠정 처리 |
|---|---|---|---|
| Q1 | dry-run 정의 | 헤더 상태 `dry-run` · §3.2 "dry-run 고정 샘플" 언급만 존재 · 동작 미정의 · F1은 Key 미설정 시 `/api/ocr` 400 | Key 미설정 = 헤더 `dry-run` 표시 · OCR 400 · §3.2는 테스트 픽스처 전용 |
| Q2 | `{{test_name}}` | 값 출처 미정의 | 템플릿 부제 기반 `방사성 방출(RE) 측정` |
| Q3 | `{{test_date}}` · 문서번호 연도 | 시험일 출처 미정의 (OCR timestamp / 생성일) | OCR timestamp 최초 날짜 (예 : `2025-01-08` → `RE-2025-0001`) |
| Q4 | 판정 기준 주파수 | F4 `f` = Center / Mkr1 미명시 | Mkr1 (`marker_freq_ghz × 1000` MHz) |
| Q5 | OCR_FAIL 행 판정 | judge 입력 포함 여부 미정의 (포함 시 N/A → INCOMPLETE 가능) | `OK` 행만 판정 대상 |
| Q6 | 수치 자릿수 | 미정의 | MHz 3자리 · µW 2자리 · dBm/dBµV/m/마진 2자리 (검증 기댓값 기준) |
| Q7 | temperature 0 | `gpt-5.6-luna` temperature 지원 여부 미확인 | 5.4 실호출 확인 · 미지원 시 제거 + JSON 스키마 강제로 대체 |
| Q8 | 전력 단위 | 샘플 전부 µW · mW/nW 표시 화면 처리 미정의 | µW 전제 (범위 외) |
| Q9 | export 요청의 CF | xlsx 각주 · docx `{{cf_db}}` 에 CF 필요 · judge 응답 스펙(`rows` · `summary`)에 CF 없음 | judge 응답에 `cf_db` 필드 추가 |
| Q10 | DESIGN ↔ PRD 충돌 | DESIGN : 사이드바 · 차트 · 채팅 · 승인 배너 · KPI WARN · "승인 전 다운로드 비활성" / PRD : 미포함 · KPI 종합판정 · 판정 후 다운로드 활성 | PRD 우선 (사이드바 · 차트 · 채팅 · 승인 게이트 제외) |
| Q11 | 업로더 문구 | DESIGN "CSV · XLSX 드래그 또는 클릭" | PRD 기준 "PNG 드래그 또는 클릭" |
| Q12 | docx 1페이지 | 행 수 증가 시 초과 가능 · 페이지 수 확인 수단 미정 | 샘플 3행 기준 검증 · Word 수동 확인 |

---

## Phase-01 환경 · BE 스캐폴드

| # | task | 상태 | 비고 |
|---|---|---|---|
| 1.1 | `project/.venv` 생성 (Python 3.14.2) | ✅ | |
| 1.2 | `backend/requirements.txt` 작성 · 설치 | ✅ | fastapi 0.141.1 · uvicorn 0.53.0 · python-multipart · python-dotenv · openai 3.16.2 · openpyxl · python-docx (버전 고정) |
| 1.3 | `backend/main.py` : `GET /api/health` · CORS (5173) | ✅ | `{status, api_key_loaded}` |
| 1.4 | `backend/.env.example` | ✅ | |
| 1.5 | `project/run_backend.bat` (CRLF) | ✅ | `.venv` 부재 시 자동 생성 · 설치 |
| 1.6 | 테스트 : health 200 · Key 유/무 → `true`/`false` · CORS 프리플라이트 | ✅ | 테스트 포트 반환 완료 |

## Phase-02 FE 스캐폴드

| # | task | 상태 | 비고 |
|---|---|---|---|
| 2.1 | `npm create vite@latest frontend -- --template vanilla-ts` (`project/` 하위) | ❌ | |
| 2.2 | 폴더 구조 생성 | ❌ | 아래 구조 참조 |
| 2.3 | `.env.development` : `VITE_API_BASE=http://127.0.0.1:8000` | ❌ | |
| 2.4 | ESLint + `tsc --noEmit` 스크립트 (`npm run lint` · `npm run typecheck`) | ❌ | PRD F6 타입/린트 0건 조건 |
| 2.5 | `styles/tokens.css` : DESIGN.md YAML 토큰 → CSS 변수 | ❌ | 색 · 서체 · 라운드 · 간격 |
| 2.6 | 웹폰트 로드 : SUIT · Pretendard (jsdelivr) · Poppins · Montserrat (Google Fonts) | ❌ | 폴백 `"Malgun Gothic",sans-serif` |

```
frontend/src/
├─ main.ts            # 진입 · 화면 조립
├─ api/  client.ts · types.ts      # fetch 래퍼 · 요청/응답 타입
├─ state/ store.ts                 # 단계 상태 · 잠금 규칙 (F6 규칙 1~7)
├─ ui/   header · step1 · step2 · step3 · limitModal · toast · badge (.ts)
└─ styles/ tokens.css · app.css
```

## Phase-03 UI 구조 (목업 데이터)

- 라우팅 : 단일 페이지 `/` (PRD 상 별도 페이지 없음) · Limit 설정 = 모달
- Primary 버튼 : 현재 활성 STEP 실행 버튼 1개만 (DESIGN "화면당 1개" 규칙)

| # | task | 상태 | 비고 |
|---|---|---|---|
| 3.1 | 헤더 : 타이틀 · 단계 안내 (STEP 1 → 2 → 3) · 연결 상태 배지 (Key 로드 / dry-run / 연결 실패) | ❌ | |
| 3.2 | STEP 1 : 드래그앤드롭 업로더 (PNG 다중) · 파일 칩 · 초기화 · OCR 실행 · 결과 표 (읽기 전용 6컬럼) | ❌ | 업로더 높이 160px · 점선 2px |
| 3.3 | STEP 2 : CF 입력 (−50.0) · Limit 설정 · 판정 실행 · KPI 4타일 · 결과 표 9컬럼 | ❌ | FAIL 행 좌측 4px 바만 |
| 3.4 | STEP 3 : 메타 입력 (담당자 · 시료명 · 검토자) · Excel · DOCX 다운로드 | ❌ | Secondary + 다운로드 아이콘 |
| 3.5 | Limit 모달 : 행 표 (구간 하한 · 구간 상한 · Limit) · 출처 배지 · 행 추가/삭제 · 기본값 복원 · 저장 | ❌ | |
| 3.6 | 상태 3종 : 빈 상태 문구 · 로딩 (진행 바 + 단계 라벨) · 토스트 (4초 소멸) | ❌ | |
| 3.7 | 잠금 표현 : STEP 2 · 3 흐림 + 조작 차단 | ❌ | 목업 상태 토글로 확인 |
| 3.8 | 판정 배지 : 색 + 텍스트 + 아이콘 (PASS 체크 · FAIL X) | ❌ | `-strong` 텍스트색 |
| 3.9 | 수치 컬럼 : Poppins `tnum` · 우측 정렬 · 단위는 헤더 1회 | ❌ | |

## Phase-04 BE API 스텁 · FE ↔ BE ↔ 저장소 연결

| # | task | 상태 | 비고 |
|---|---|---|---|
| 4.1 | `schemas.py` : OcrRow · JudgeRequest · JudgeRow · Summary · JudgeResponse · LimitRow · ExportDocxRequest | ❌ | Q9 `cf_db` 포함 |
| 4.2 | F1 전 엔드포인트 스텁 : `/api/ocr` · `/api/judge` · `/api/export/xlsx` · `/api/export/docx` · `/api/limits` (GET · PUT) · `/api/limits/reset` | ❌ | 고정 응답 = §0.2 값 |
| 4.3 | 저장소 스캐폴드 : `limits.json` 읽기/쓰기 (부재 시 기본값) | ❌ | |
| 4.4 | 테스트 도구 : `pytest` · `httpx` (TestClient) 추가 | ❌ | requirements 반영 |
| 4.5 | FE `api/client.ts` : fetch 래퍼 · 오류 → 토스트 · Blob 다운로드 헬퍼 | ❌ | |
| 4.6 | FE 기동 시 health 호출 → 헤더 상태 반영 | ❌ | 실패 = 연결 실패 |
| 4.7 | 스텁 기준 STEP 1 → 2 → 3 흐름 · Limit 조회/저장 왕복 확인 | ❌ | |

## Phase-05 라이브러리 · 외부 API 동작 테스트

| # | task | 상태 | 비고 |
|---|---|---|---|
| 5.1 | 브라우저 5173 → 8000 : GET · PUT · POST(multipart) · Blob 다운로드 CORS 확인 | ❌ | `Content-Disposition` 필요 시 `expose_headers` |
| 5.2 | OpenAI 최신 문법 확인 : SDK 3.16.2 · Responses API (`client.responses.create` · `input_image`) · 구조화 출력 (`text.format` JSON 스키마) | ❌ | SDK 내 `responses.create` · `text` · `temperature` 파라미터 존재 확인됨 |
| 5.3 | `gpt-5.6-luna` 실호출 1회 (img_1) : 응답 JSON · 소요 시간 · 프록시/네트워크 이슈 | ❌ | |
| 5.4 | temperature 0 지원 여부 확인 | ⚠️ | Q7 |
| 5.5 | openpyxl : 시트 `RE_Result` 생성 · 저장 | ❌ | |
| 5.6 | python-docx : 템플릿 로드 → 플레이스홀더 1건 치환 → 저장 · 맑은 고딕 유지 | ❌ | |
| 5.7 | 웹폰트 CDN 접근 확인 (사내망 차단 여부) | ❌ | |

## 완료 기준 (task-001)

- 5173 접속 → 헤더 연결 상태 표시 (Key 로드)
- 스텁 기준 STEP 1 → 3 화면 전환 · 잠금 동작
- OpenAI 실호출 1회 성공 · CORS 오류 0건 · 라이브러리 3종 동작
- 테스트 종료 후 5173 · 8000 프로세스 종료
