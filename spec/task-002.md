# task-002 — BE 핵심 로직 (F2 ~ F5 · F7 BE)

> 선행 : task-001 완료 · 기댓값 : task-001 §0.2 · 모호사항 : task-001 §0.4 (Q1 ~ Q12)
> 범위 : Phase-06 ~ Phase-09 · 후속 : task-003
> 상태 표기 : ✅ 완료 · ❌ 미착수 · ⚠️ 확인 필요 / 보류

---

## BE 모듈 구성

```
backend/
├─ main.py      # 앱 · CORS · 라우트 등록
├─ schemas.py   # 요청/응답 모델
├─ limits.py    # 기본값 · 로드/저장 · 검증 · 매칭 (F7 · §3.1)
├─ ocr.py       # GPT Vision 호출 · JSON 검증 · 재질의 (F2)
├─ judge.py     # 단위 변환 · 판정 (F3 · F4)
├─ export.py    # xlsx · docx 생성 (F5)
├─ limits.json  # 사용자 수정 시 생성 (재기동 유지)
└─ tests/       # pytest
```

---

## Phase-06 Limit 테이블 (§3.1 · F7 BE)

| # | task | 상태 | 비고 |
|---|---|---|---|
| 6.1 | `DEFAULT_LIMITS` 상수 4행 (30/88/40.0 · 88/216/43.5 · 216/960/46.0 · 960/6000/54.0) | ❌ | 외부 파일 의존 없음 |
| 6.2 | 로드 : `limits.json` 존재 → `source: "user"` / 부재 → `"default"` | ❌ | |
| 6.3 | 검증 : 하한 < 상한 · 모두 0 초과 · limit 숫자 (음수 허용) · 0행 금지 | ❌ | |
| 6.4 | 중복 검증 : 하한 기준 정렬 후 `rows[i].max > rows[i+1].min` → 중복 | ❌ | 반개구간 → 경계 접함 허용 |
| 6.5 | 위반 시 400 + `[{row, reason}]` 목록 · 기존 테이블 미변경 | ❌ | 행 번호 = 요청 순서 기준 |
| 6.6 | `GET /api/limits` → `{rows, source}` | ❌ | |
| 6.7 | `PUT /api/limits` → 검증 → 정렬 → 저장 → `{rows, source: "user"}` | ❌ | |
| 6.8 | `POST /api/limits/reset` → `limits.json` 삭제 → `{rows, source: "default"}` | ❌ | |
| 6.9 | 매칭 함수 : `min ≤ f < max` → limit / 없음 → `None` | ❌ | |
| 6.10 | 테스트 : 기본 4행 · PUT 후 재기동 유지 · reset 복귀 · 하한≥상한 / 중복 / 0행 → 400 | ❌ | |

## Phase-07 OCR (F2)

| # | task | 상태 | 비고 |
|---|---|---|---|
| 7.1 | Key 미설정 → 400 + 안내 메시지 (`.env` 의 `OPENAI_API_KEY` 설정 안내) · 크래시 금지 | ❌ | Q1 |
| 7.2 | 이미지 base64 인코딩 → Responses API 호출 (`gpt-5.6-luna`) | ❌ | task-001 5.2 확인 문법 적용 |
| 7.3 | JSON 스키마 강제 : `center_freq_ghz` · `marker_freq_ghz` · `marker_power_uw` (number) · `timestamp` (string) · 4필드 한정 | ❌ | `additionalProperties: false` |
| 7.4 | 프롬프트 : 숫자 외 텍스트 금지 · 단위 제거 · Mkr1 값 지정 · temperature 0 | ⚠️ | Q7 결과 반영 |
| 7.5 | 파싱 · 스키마 검증 실패 → 1회 재질의 → 재실패 `status: "OCR_FAIL"` | ❌ | |
| 7.6 | 이미지별 독립 처리 · 1장 실패 시 나머지 계속 | ❌ | |
| 7.7 | API 예외 (네트워크 · rate limit) 처리 | ⚠️ | PRD 미정의 · 해당 이미지 `OCR_FAIL` 잠정 |
| 7.8 | 응답 : `[{file, center_freq_ghz, marker_freq_ghz, marker_power_uw, timestamp, status}]` | ❌ | |
| 7.9 | 테스트 : img_1 ~ 3 → 3건 `OK` · §3.2 값 일치 · Key 제거 시 400 | ❌ | 실호출 (비용 발생) |

## Phase-08 단위 변환 · 판정 (F3 · F4)

| # | task | 상태 | 비고 |
|---|---|---|---|
| 8.1 | 변환 : µW → dBm `10·log10(µW/1000)` · dBm → dBµV `+107` · dBµV → dBµV/m `+CF` | ❌ | 50 Ω |
| 8.2 | `POST /api/judge` 입력 : OCR 배열 + `cf_db` (기본 −50.0) | ❌ | |
| 8.3 | 판정 대상 : `status: "OK"` 행만 | ⚠️ | Q5 |
| 8.4 | 판정 주파수 : `marker_freq_ghz × 1000` (MHz) | ⚠️ | Q4 |
| 8.5 | Limit : 현재 활성 테이블 (`limits.py` 매칭) | ❌ | 요청 시점 로드 |
| 8.6 | 마진 = Limit − 측정값 · ≥ 0 PASS · < 0 FAIL · 매칭 없음 N/A | ❌ | |
| 8.7 | 종합 : FAIL ≥ 1 → FAIL · (FAIL 0 · N/A 포함) → INCOMPLETE · 전부 PASS → PASS | ❌ | 우선순위 FAIL > INCOMPLETE > PASS (PRD 나열 순서 기준) |
| 8.8 | 판정은 원값 기준 · 응답 수치는 Q6 자릿수 반올림 | ❌ | |
| 8.9 | 응답 : `{rows, summary: {total, pass, fail, verdict}, cf_db}` | ❌ | Q9 `cf_db` 추가 |
| 8.10 | 단위 테스트 : CF −50 → FAIL 1 · PASS 2 · 종합 FAIL / CF −52 → 전부 PASS | ❌ | task-001 §0.2 |
| 8.11 | 경계 테스트 : 960 MHz → 54.0 · 6000 MHz → N/A · 매칭 없음 → INCOMPLETE | ❌ | |

### judge 행 필드

| 필드 | 내용 |
|---|---|
| `no` | 순번 (1부터) |
| `file` | 파일명 |
| `freq_mhz` | 측정 주파수 (MHz) |
| `power_uw` | 측정 전력 (µW) |
| `dbm` · `dbuv_m` | 변환값 |
| `limit` | 매칭 Limit (없음 → `null`) |
| `margin` | Limit − dBµV/m (없음 → `null`) |
| `verdict` | `PASS` · `FAIL` · `N/A` |

## Phase-09 엑셀 · 보고서 (F5)

| # | task | 상태 | 비고 |
|---|---|---|---|
| 9.1 | `POST /api/export/xlsx` : 시트 `RE_Result` · 컬럼 9개 · 파일명 `re_result.xlsx` | ❌ | 아래 컬럼 표 |
| 9.2 | xlsx 하단 각주 `※ CF = {cf} dB 가정치 적용` | ❌ | Q9 |
| 9.3 | `POST /api/export/docx` : 요청 = judge 응답 + `tester` · `sample_name` · `reviewer` · 파일명 `re_report.docx` | ❌ | |
| 9.4 | 단일 값 치환 : 본문 문단 + 표 셀 순회 · run 단위 치환 (서식 · 맑은 고딕 유지) | ❌ | 템플릿 run 분할 없음 확인됨 |
| 9.5 | 결과 표 (표2) 반복 : 템플릿 행 deepcopy × 판정 행 수 → 원본 템플릿 행 제거 | ❌ | |
| 9.6 | 특이사항 : FAIL 항목 `{주파수} MHz Limit {초과량} dB 초과` 나열 + 고정 문구 | ❌ | 초과량 = \|마진\| |
| 9.7 | 고정 문구 : `※ 측정 검출기 RMS(Avg) · Limit 기준 QP — 교육용 참고 판정` | ❌ | FAIL 0건 시 고정 문구만 |
| 9.8 | 산출물 `project/output/` 사본 저장 + 바이너리 응답 (`Content-Disposition`) | ❌ | |
| 9.9 | 테스트 : 미치환 `{{` 0건 · 표 행 수 = 판정 행 수 · 한글 깨짐 0건 · 1페이지 | ⚠️ | Q12 1페이지 = Word 수동 확인 |

### xlsx 컬럼

`순번 · 파일명 · 측정주파수(MHz) · 측정전력(µW) · 측정값(dBm) · 측정값(dBµV/m) · Limit(dBµV/m) · 마진(dB) · 판정`

### docx 치환 매핑

| 플레이스홀더 | 값 |
|---|---|
| `doc_no` | `RE-{시험일 연도}-0001` (Q3) |
| `test_date` | OCR timestamp 날짜 (Q3) |
| `test_name` | `방사성 방출(RE) 측정` (Q2 잠정) |
| `tester` · `sample_name` · `reviewer` | STEP 3 메타 입력 |
| `standard` | `FCC Part 15 Subpart B Class B (3 m)` |
| `cf_db` | judge 응답 `cf_db` |
| `total` · `pass_cnt` · `fail_cnt` · `verdict` | judge `summary` |
| `r.*` | judge `rows` (행 반복) |
| `remarks` | 9.6 · 9.7 |
| `generated_at` | 생성 시각 (`YYYY-MM-DD HH:mm`) |

## 완료 기준 (task-002)

- pytest 전체 통과 (Limit 검증 · 판정 기댓값 · 경계값 · export 검사)
- img_1 ~ 3 실 OCR → 판정 → xlsx · docx 생성 · PRD F1 ~ F5 · F7 BE 통과 조건 충족
- 테스트 종료 후 8000 프로세스 종료
