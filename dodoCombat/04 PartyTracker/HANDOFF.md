# 작업 인수인계 (2026-10-28)

새 대화 시작 시 이 파일 + `PartyTracker_PLAN.md` 먼저 읽을 것.
상태: 모든 변경 `luac5.1 -p` 문법 통과, **게임 내 확인은 대부분 미완** (아래 "미확인" 참고).

---

## 1. 파티 트래커 (KiraUI / H3ndall 이식)

**위치**: `dodoCombat/04 PartyTracker/` (dodoQOL 에서 이동, git 미추적 폴더)
**TOC**: `dodoCombat.toc` 의 `03 CursorSpellTracker` 다음. 순서: 99 Options → 01 Core → 02~09 엔진 → 10 PartyCDs → 11 Defensives → 12 Interrupts → 13 CC → 14 EditMode → 15 SpellList.lua
**dodoCombat 번호**: 04 PartyTracker / 05 BloodBrez / 06 Stance (git mv)
**저장**: 엔진 cfg `dodoDB.partyTracker.<모듈>`, 설정 토글 `dodoDB.*` (`dodo.PT_DEFAULTS`)
**초기화**: `/ptr` (dodoCommand/01 Slash.lua)
**디버그**: `/ptcd` `/ptdef` `/ptkick` `/ptcc`

### 설정 위치
| 기능 | 설정창 | 빌드 함수 (`04 PartyTracker/99 Options.lua`) |
|---|---|---|
| 파티원 주요 기술 (구 파티 CD) | `/dd 유닛프레임 > 파티프레임 탭` | `dodo.PTBuildPartyCDOptions` |
| 차단기 / 군중제어 / 공생기 | `/dd 전투 > 파티 주문 추적 탭` (6번) | `dodo.PTBuildOptions` |

- 부모-자식: 주요 기술 > 본인 포함·던전 안에서만 / 차단기 > 너비·높이 / 군중제어 > 아이콘 크기·간격·행 당 개수 / 공생기 > 너비·높이
- 주요 기술 미리보기: 유닛프레임 파티 목업 옆 아이콘 (`dodoUnitframe/99 Options Preview.lua`)
- 전투 탭6 미리보기: 군중제어 아이콘 + 차단기 바 (`dodoCombat/99 Options Preview.lua`)

### 주문 목록 (`15 SpellList.lua`)
- `dodoPTSpellListMixin`: 주요 기술 — 직업→특성 드롭다운 + 최하단 "공용"(종족특성, 키 `"race"`). 엔진 `ns.PTCSpecSpells / ns.PTCSetShown`
- `dodoPTTrackListMixin`: 파티 주문 추적 — 드롭다운(차단기/군중제어/공생기)
  - 차단기: `ns.IKSpells / ns.IKSetShown` (엔진에 `cfg.off` 신규 추가, 꺼진 차단기 가진 파티원 행 안 만듦)
  - 군중제어: `ns.CCSpells / ns.CCSetShown` (spells1 을 ORDER 순서로 재구성)
  - 공생기: `ns.PDFSpells / ns.PDFSetShown`

### 주요 변경
- **군중제어 1/2 → 하나로 합침** (`13 CC.lua` GROUPS=1, spells2 저장값은 spells1 뒤로 자동 병합, 편집모드 CC2 주석처리)
  - "4개씩만 보임" 원인: 편집모드 미리보기 `EDIT_ICONS = 7` 을 바 2개에 4+3 분배했던 것
- **공생기 바 = 차단바 디자인** (`11 Defensives.lua`, 아이콘 모드 주석처리, style='bar' 고정)
  - 배경 직업색*0.15 알파0.6 / 준비 직업색 꽉 참 / 쿨 중 왼쪽부터 차오름 / 행 간격 -1 / 하단 EdgeBottom / 목록 전체 NineSlice
  - 준비 표시는 secret 비교 없이 숨김 StatusBar(역방향, 값=slot.v) 채움 끝에 b.ready 앵커 → 쿨 중이면 폭 0
  - **본인 주문은 엔진이 "exact" 경로**(09 ExactCooldowns, 슬롯 미사용) → `ExactFill` 에서 `GetSpellCooldownDuration` + `StatusBar:SetTimerDuration`
  - 쿨 숫자 바 오른쪽 이동: 엔진 `c.win` 가로 오프셋 `c.winX` (10 PartyCDs 2줄 수정) / exact 는 `ex.text` 재앵커
  - 쿨 중 아이콘 어둡게 하는 효과 끔: `c.clip:Hide()` + `c.noShade` (09 ExactCooldowns `exact.Grey` 예외) + `ex.rc` 알파 0
  - `/ptdef` 하단에 바 진단 줄 (ticks / fills / fails / last error)

---

## 2. 공용 UI (`dodo/Data/UIUX.lua`, `UIUX.xml`)
- `dodoSettingsPanelListTemplate` (빈 virtual 프레임, UIUX.xml)
- `dodo.UI:SettingsPanelList(category, mixin)` — 템플릿 프레임 돌려쓰기. mixin 별 전용 하위 프레임 생성, 현재 것만 표시
- `dodo.UI:CreateListBox(parent, top, columns)` — 목록 박스(SoftBlack 0.5 배경 + 회색 0.5 테두리) + 컬럼 헤더(전역 이름 자동) + content 반환
- 사용처: 커서 주문 추적 목록 / 주요 기술 목록 / 파티 주문 추적 목록. 모듈별 SpellList.xml 2개 삭제

---

## 3. 마스터 토글 정비 (행동단축바/유닛프레임 방식)
| 모듈 | 내용 |
|---|---|
| 전투 | `dodo.CombatIsEnabled(key)` + `dodo.CombatUpdateModuleState()` (99 Options.lua). 자원바/디버프/커서/블러드/태세/파티 주문 추적 연결. 주요 기술은 유닛프레임 설정이라 제외 |
| 인터페이스 | 레거시 `enableChatModule`/`enableTooltip` → `enableInterface` 로 통일, 미니맵·피해량 전투기 항상 활성화에 마스터 체크, 콜백에서 전 기능 재적용 |
| 우두머리 경보 | `dodo.EncounterApplyText()` (04 Text.lua) — 꺼지면 이벤트 해제 + 알림 숨김 |
| 편의기능 | `dodo.QOLIsEnabled(key)` 로 44개 파일 ~110곳 일괄 치환, autoAccept/autoTurnIn 은 "마스터 AND 값", 마스터 콜백에서 전 기능 적용 함수 호출 |

---

## 4. 기타
- 유닛프레임 구 파티 쿨타임 모듈 삭제 (`02 PartyFrame/04 PartyCD*.lua`, 옵션/기본값 정리)
- 명칭: 커서 주문 추적 / 파티 주문 추적 / 파티원 주요 기술
- 03 Pixels: `PixelBorderIcon`, `PixelEdge` 제거 (파일은 필요해서 유지), 05 Dragging 삭제

---

## 미확인 / 남은 일
1. **공생기 바**: 준비/쿨 표시(앵커 트릭), 파티원 주문(슬롯 경로) 차오름, 쿨 숫자 위치(`MoveTimer` 의 `barW - 7`) 게임 확인 필요
2. 마스터 토글 4개 모듈 끄기/켜기 실제 동작 확인
3. 편의기능 `07 Consumeable` 은 마스터 미연동 (설정 목록에 없는 기능) — 연동 여부 결정 필요
4. 일부 편의기능은 꺼짐 복구 로직 없음 → 마스터 꺼도 `/reload` 필요
5. 태세(06 Stance): 꺼져도 이벤트 등록 유지 (원래 구조)
6. 보류: 주요 기술 아이콘 순서 재배치 (딜쿨→생존→공생→종특) — 주문별 분류표 필요
7. 주요 기술 목록 주문명 폭(+10) 은 파티 주문 추적 목록만 적용
8. `TMP-PROF` 측정 코드가 dodoQOL CharacterFrame 등에 남아 있음 (사용자 작업, 미변경)
