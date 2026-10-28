# 파티 쿨기 / 공생기 / 차단기 / 군중제어 추적 — 마이그레이션 계획서

> 원본: `KiraUI-Plugin` v1.25
> - `KiraUI-Plugin_PartyCDs.lua` (4521줄) — 파티원 생존기/공격 쿨 추적 엔진 + 표시
> - `KiraUI-Plugin_PartyDefensives.lua` (199줄) — 공생기 바 (PartyCDs 엔진 위에 얹힌 표시 껍데기)
> - `KiraUI-Plugin_Interrupts.lua` (1957줄) — 파티 차단기(인터럽트) 바
> - `KiraUI-Plugin_PartyStops.lua` (1332줄) — 적 이름표 디버프로 군중제어기(스턴/공포 등) 사용 감지
> - 공용 헬퍼: `KiraUI-Plugin.lua` (`ns.NewUnitSensor`, `ns.SensorLit`, `ns.TalentRanks`, `ns.SendInspect` 등)
>
> 대상: `dodoCombat/04 PartyTracker/` (설정: `/dd 전투 > 파티 추적` 탭, 항목은 `dodo.PTBuildOptions`에서 생성).

## 확정 사항
| 항목 | 결정 |
|---|---|
| 범위 | 파티 쿨 + 공생기 + **차단기(Interrupts)** + **군중제어(Stops)** 4종 모두 |
| 파일 구조 | `02 Mplus/08 PartyTracker/` 하위 폴더 + 자체 `99 Options.lua` |
| 붙일 프레임 | **블리자드 순정 파티 프레임** |
| 라이선스 | 개인용·미배포 → 원본 코드 참고/이식 허용. 단 dodo 스타일(snake_case, 정적 함수, dodoDB 키 규칙)로 변환 |
| 진행 | Phase 0 실험부터 |

> ⚠️ 규모 경고: PartyCDs는 Patch 12 **secret value** 우회용 트릭 덩어리. 그대로 다 옮기지 말고 **핵심만 단계적 이식 + 부가기능 보류**. 각 Phase 끝에 `/reload` 확인.

---

## 1. 기능 요약 (원본 기준)

### 1-1. PartyCDs (파티 쿨) (보류)
| 항목 | 내용 |
|---|---|
| 대상 | `player`(옵션), `party1~4`. 공격대면 비활성 |
| 추적 주문 | 전문화별 주요 생존기/공격쿨 (`SPECS[specID]`), 종족 특성, 장신구 2종 |
| 감지 | **파티원**: 해당 주문 *버프의 등장 순간*(edge) → 쿨 시작<br>**본인**: `C_Spell.GetSpellCooldownDuration` 정확값 (실패 시 `UNIT_SPELLCAST_SUCCEEDED`) |
| 쿨 보정 | 특성 인스펙트 → 쿨감(`mods`), 주문 대체(`swap`), 미습득 숨김(`gate`) |
| 충전 | 2충전 주문 카운트 |
| 표시 | 아이콘 + 남은 초 + 회색/어둡게 + 버프 활성 중 테두리 하이라이트 + 원형 스와이프 |
| 배치 | 파티 프레임 옆 붙이기 / 실패 시 떠있는 블록 |

### 1-2. PartyDefensives (공생기)
- PartyCDs 엔진의 `'guard'` 바에 프레임/설정만 넘기는 얇은 모듈 (`ns.PTCBar('guard', frame, look)`).
- 주문: `51052` 대마법 지대, `97462` 재집결의 함성, `196718` 어둠, `374227` 미풍, `31821` 오라 숙련(신기), `62618` 신의 권능: 방벽(수양), `98008` 정신 연결 토템(복원), `15286` 흡혈의 선물(암흑).
- 전문화 기본쿨 보정: `base = { [577]=180, [581]=180, [1480]=180, [65]=150 }`.
- 한 줄 나열, 아이콘 아래/안에 이름 몇 글자.

### 1-3. Interrupts (차단기)
- **바(StatusBar) 형태 행**: 파티원 1명 = 1행 (아이콘 + 이름 + 쿨 바 + 남은 시간 + 차단한 적의 징표/주문 아이콘).
- 차단 주문 표 `KICKS` (직업별 + 전문화 예외 `SPEC_KICK`: 조화 드루 태양 광선, 생존 사냥꾼 재갈, 힐러 대부분은 없음).
- 흑마: 펫 차단(주문 잠금/도끼 던지기) — `UNIT_PET`, 펫 주문책 확인, `partypetN` → 주인 매핑.
- 쿨 보정: 특성 `add/pct` + **`landed`** (차단 성공 시 쿨감, 예: 죽기 -3초) + 힐러 주술사 30초.
- 본인: `C_Spell.GetSpellCooldown(poll)` 폴링(0.15초), 실측 쿨 길이를 캐릭터 DB에 학습(`ikLearned`).
- 정렬: 준비된 사람 먼저 → 쿨 짧은 순 (`StackBefore`).

**파티원 감지 (핵심, 4단 폴백)**
1. `UNIT_SPELLCAST_SUCCEEDED` (party1~4, partypet1~4): spellID가 **secret 아니면** 바로 확정. (인스턴스 전투 중엔 secret)
2. `UNIT_SPELLCAST_INTERRUPTED` / `UNIT_SPELLCAST_CHANNEL_STOP` (적 유닛): 4번째 인자 `interruptedBy` GUID가 읽히면 → GUID로 파티원/펫 매칭해서 확정.
3. GUID secret이면 → **`C_DamageMeter` 차단 집계** (`Enum.DamageMeterType.Interrupts`)로 누가 했는지 판정:
   - `GetCombatSessionSourceFromType(Current, Interrupts, guid)` 의 `combatSpells` 개수 증가한 멤버 = 차단자 (`mtr.Update`).
   - `DAMAGE_METER_COMBAT_SESSION_UPDATED` ↔ 차단 이벤트를 ±1초(`PAIR` 0.25초)로 짝지음 (`Pair`).
   - 개수 증가 2 이상 / 이름표 여러 개 동시 차단 = 광역 차단(`area`)으로 판단해 무시.
   - 개수까지 secret → **"stack" 트릭**: `totalAmount`(secret) 이전/현재 값을 StatusBar `SetMinMaxValues(0, cur)` + `SetValue(prev)` 로 넣고 클립 영역 폭으로 "증가했을 때만 보이는" 타이머 레이어를 멤버별로 겹쳐 그림 (`stack.Put`). 사용 전 `stack.Check()`로 클립 측정 가능 여부 검사.
   - 세션 목록 순위 변동(새로 등장/순위 상승)으로 후보 좁히기 (`DiffMeter`, `MatchMember`: 직업/이름/전문화 아이콘 비교).
4. 그래도 모르면 **추정**(`Guess`): 후보 중 준비 상태인 사람 → 정렬 우선순위 첫 번째. 본인 차단 시각과 0.8초 내면 본인으로 귀속.
- 한계: secret 상황에선 **성공한 차단만** 잡힘 (헛친 차단 감지 불가).

### 1-4. PartyStops (군중제어)
- **적 이름표(nameplate1~40)의 CC 디버프**를 센서로 감시 → 디버프 등장 = 누군가 그 CC 사용.
- 필터 `HARMFUL|!PLAYER` (본인 것 제외, 거부되면 `HARMFUL` 폴백). 본인 CC는 `UNIT_SPELLCAST_SUCCEEDED`.
- **귀속 불가**: 시전자 모름 → 그 주문 가진 파티원 *전원*의 타이머 시작.
- 바 2개 (원본 기본 배치, spellID 기준):
  - 바1: `119381` 팽이 차기, `179057` 혼돈의 회오리, `30283` 어둠의 격노, `192058` 축전 토템, `46968` 충격파, `109248` 구속의 사격, `853` 심판의 망치, `19577` 위협
  - 바2: `207167` 눈멀게 하는 진눈깨비, `115750` 눈부신 빛, `8122` 정신 절규, `99` 행동 불가의 포효, `5246` 위협의 외침, `207684` 불행의 인장, `202138` 사슬의 인장(복수), `108199` 고어핀드의 손아귀(혈죽), `102793` 우르솔의 회오리, `132469` 태풍, `2094` 실명
  - 각 주문은 실제 감지 디버프 ID가 따로 있음 (`debuff`, 예: 축전 토템 → `118905`, 불행의 인장 → `207685`).
- 전투 중인 적 우선 감시, 보스 제외, 감시 적 수 제한(`maxUnits` 10, 광역은 `aoeUnits` 4). 전투 밖 적은 `hold`(실명 같은 긴 CC)만 감시.
- `lag`: 디버프가 시전 후 늦게 붙는 주문 보정(축전 토템, 문양 2초).
- 여러 센서를 `DisableUntrustedLayoutScriptsTemplate` 앵커 체인(head → 센서들 → tail, span이 전체 감쌈)으로 이어서 **span 하나의 IsMouseOver로 "아무 적에게나 붙었나"** 한 번에 읽음.

---

## 2. 핵심 로직 해설

### 2-1. 오라 센서 (AuraContainer 트릭) — 12.1 전용
```lua
local c = CreateFrame('AuraContainer', nil, host, 'CustomAuraContainerTemplate')
c:AddAuraGroup(key, 'HELPFUL', {
    maxFrameCount = 1,
    candidateFilters = { includeSpellIDs = { [버프ID] = true } },  -- maxDuration 도 가능
    initializeFrame = init_1px,  -- 1x1, 마우스 끔
    layout = { elementWidth = 50000, elementHeight = 1, elementSpacing = 0, lineSpacing = 0 },
})
c:SetUnit('party1'); c:SetEnabled(true)
local lit = c:IsMouseOver(1e5, -1e5, 0, 0)  -- 버프 있으면 true (전투 중엔 secret boolean)
```
- 버프 있으면 폭 50000짜리 자식 → IsMouseOver 확장영역에 걸림.
- 센서는 **전투 중 생성 불가** → 전투 밖에서 미리 생성 (`waitBuild`), 전투 끝나면 보충.
- `UNIT_AURA` → `AuraPayloadChurns`(added/removed 있을 때만) → 0.2초 간격 2회 읽기.
- `short` 센서: `maxDuration` 필터로 짧은 버프만 (시전/패시브 구분).
- `zone` 센서: 범위형 → 다른 파티원 몸의 버프로 감지. `others`: 시전자 본인엔 안 붙음.
- `filters` 변경은 `SetAuraGroupCandidateFilters(key, filters)` 로 재사용, `UpdateAllAuras()`.

### 2-2. Secret 상태에서 타이머 유지 (가장 어려운 부분)
1. `C_CurveUtil.EvaluateColorValueFromBoolean(bool, a, b)` = secret-safe 삼항 (`EvalBool`). 결과도 secret.
2. 시작 시각을 **255단계 코드값(0~1)** 으로 인코딩 → StatusBar `SetValue` (setter는 secret 허용).
   - `u = ceil(cd/254)` 초 해상도, `Stamp = (255 - floor((n - epoch)/u)) / 255`.
   - 2슬롯 롤링 epoch(`Roll`)로 코드 범위 초과 대응.
3. 텍스트: `"cd\n cd-1\n ... 1"` **숫자 띠** 미리 렌더 → 클립 창 뒤에서 StatusBar 채움 끝에 앵커해 띠를 밀어 올림. 매초 `SetMinMaxValues(m, m+1)` 로 스크롤 (`Range`).
4. 회색/어둡게: `veil`/`shade` Alpha 에 secret 값.
5. edge 감지(`Feed`): `EvalBool(cur, EvalBool(prev, old, new), old)` = "이전 false & 현재 true 일 때만 new".
6. `door` 테스트: EvalBool이 k/255 정확 왕복하는지 로드 시 검사.
7. 비-secret 일 땐 `plain` 경로 (그냥 숫자).

### 2-3. 충전(charge) — 보류
커서 위치 + IsMouseOver 오프셋으로 secret StatusBar 값을 임계값 비교. 1충전 근사로 대체.

### 2-4. 본인 쿨 (exact)
`C_Spell.GetSpellCooldownDuration(id)` → `Cooldown:SetCooldownFromDurationObject` + `C_DurationUtil.CreateDurationTextBinding`. `SPELL_UPDATE_COOLDOWN`/`SPELL_UPDATE_CHARGES` 에서 갱신. **공식 secret-safe 경로.**

### 2-5. 전문화/특성 (inspect) — 3모듈 공용으로 1개만
- 전문화: 본인 `GetSpecialization`, 파티원 `GetInspectSpecialization` → 실패 시 역할로 추정.
- 특성: `NotifyInspect` 큐 (1초 티커, 최소 간격 2초, 인스펙트창 열려 있으면 대기, 12회 실패 시 30초 쉼) → `INSPECT_READY` → `C_Traits` INSPECT config 에서 원하는 특성 spellID 랭크.
- 던전 안에서만, 준비확인(쐐기 전)에 재요청.
- 원본은 PartyCDs/Stops/Interrupts가 각자 큐를 돌림 → **dodo는 공용 `05 Inspect.lua` 하나로 통합** (중복 인스펙트 방지).

### 2-6. 블리자드 파티 프레임 붙이기
원본의 EllesmereUI 후킹/UIParent 전체 스캔은 불필요. 순정 프레임만:
- 레이드 스타일 파티 프레임: `CompactPartyFrameMember1~5` (`:GetAttribute('unit')` / `.unit`)
- 일반 파티 프레임: `PartyFrame.MemberFrame1~4` (본인은 `PlayerFrame`)
- `EditModeManagerFrame:UseRaidStylePartyFrames()` 로 어느 쪽인지 판정, `CompactPartyFrame_UpdateVisibility`/`GROUP_ROSTER_UPDATE` 후 재배치.
- 버튼 순서(정렬)가 바뀌므로 매번 unit 속성으로 매칭.

---

## 3. dodo 쪽 설계

### 3-1. 파일 구조
```
dodoQOL/02 Mplus/08 PartyTracker/
    99 Options.lua      -- dodo.PT_DEFAULTS + /dd "편의기능.파티 추적" 등록. TOC 최상단
    01 Core.lua         -- 이벤트 통합 프레임, 토글 on/off, 그룹/던전 조건, optional-chain 호출
    02 Data.lua         -- 주문 DB: SPECS, SPELLS(+mods), GUARD, KICKS, STOPS, 전문화/역할 표
    03 Sensor.lua       -- AuraContainer 센서 생성/읽기, EvalBool, door 테스트
    04 Timer.lua        -- 트래커 상태 (plain / secret 경로), edge 처리, 아이콘 셀
    05 Inspect.lua      -- 전문화/특성 공용 인스펙트 큐
    06 PartyCD.lua      -- 파티원별 행 + 블리자드 파티 프레임 붙이기
    07 Defensives.lua   -- 공생기 바
    08 Interrupts.lua   -- 차단기 바 (독립 표시, 데미지 미터 판정)
    09 Stops.lua        -- 군중제어 바 (이름표 센서)
```
TOC 등록 순서 (`dodoQOL.toc`, `07 Consumeable.lua` 다음):
```
02 Mplus/08 PartyTracker/99 Options.lua
02 Mplus/08 PartyTracker/01 Core.lua
02 Mplus/08 PartyTracker/02 Data.lua
... 03 ~ 09
```

### 3-2. 네임스페이스
- `local dodo = _G.dodo` (07 Consumeable.lua 와 동일 패턴).
- 모듈 내부 공유는 `dodo.PT = {}` 하나 (Sensor/Timer/Inspect 함수 노출). 외부 공개 API PascalCase.

### 3-3. dodoDB 키
| 키 | 기본 | 설명 |
|---|---|---|
| `enablePartyCD` | false | 파티 쿨 마스터 |
| `usePartyCDShowSelf` | false | 본인 포함 |
| `usePartyCDDungeonOnly` | false | 던전에서만 |
| `usePartyCDTalents` | true | 특성 인스펙트 반영 (4모듈 공용) |
| `usePartyCDAttach` | true | 파티 프레임에 붙이기 |
| `partyCDSide` / `partyCDSize` / `partyCDSpacing` / `partyCDTextSize` | RIGHT / 28 / 2 / 12 | |
| `partyCDOff` | {} | `"spec:spellID"` → true |
| `enablePartyDefensives` | false | 공생기 마스터 |
| `partyDefensivesSize` / `partyDefensivesGrow` | 36 / RIGHT | |
| `partyDefensivesOff` / `partyDefensivesOrder` | {} / {} | |
| `enablePartyInterrupts` | false | 차단기 마스터 |
| `usePartyInterruptsShowSelf` / `usePartyInterruptsShowReady` | true / true | 본인, 준비 행 표시 |
| `usePartyInterruptsMark` / `usePartyInterruptsMeter` | true / true | 징표 표시, 데미지 미터 판정 |
| `partyInterruptsWidth` / `partyInterruptsHeight` / `partyInterruptsGrow` | 180 / 20 / DOWN | |
| `partyInterruptsLearned` | {} | 본인 실측 쿨 (SavedVariablesPerCharacter 쓸지 확인 — 없으면 `dodoDB` 내 캐릭터 키 하위) |
| `enablePartyStops` | false | 군중제어 마스터 |
| `partyStopsMaxUnits` / `partyStopsAoeUnits` | 10 / 4 | |
| `partyStopsSpells1` / `partyStopsSpells2` | 기본 목록 | |
| 위치 | — | `dodoDB.editMode["PartyCD"]`, `["PartyDefensives"]`, `["PartyInterrupts"]`, `["PartyStops1"]`, `["PartyStops2"]` |

### 3-4. dodo 규칙 대응
- 핫패스(OnUpdate/티커/UNIT_AURA/UNIT_SPELLCAST_*) 익명 클로저 금지 → 정적 local 함수. (원본 `C_Timer.After(0, function() ... end)` 류 전부 교체)
- 토글 off → `UnregisterEvent`, 티커 `Cancel()`, 센서 `SetEnabled(false)`, OnUpdate nil.
- `issecretvalue()` 검사 후에만 비교. secret 은 setter로만.
- 색상 `dodo.Colors` (클래스색, 하이라이트 금색, 바 배경).
- 위치 LibEditMode 직접 등록 (원본 우클릭 드래그 `MakeDraggable` 대체).
- 원본 `ns.Probe`, 픽셀 스냅(`PixelPoint/PixelSize`), 진단용 `stats/obs` 카운터와 슬래시 출력은 이식 안 함.
- 바 텍스처: 원본 `KiraBar`/LSM 대신 dodo 기존 텍스처 사용.

---

## 4. 단계별 구현 계획

각 Phase 끝에 `/reload` 확인 후 다음. **한 번에 한 파일/한 기능.**

### Phase 0 — 실현 가능성 실험 (임시 테스트 파일, 끝나면 삭제)
1. AuraContainer 센서로 `party1` 특정 버프 감지 → IsMouseOver 결과. 전투 중 secret 여부.
2. `EvaluateColorValueFromBoolean(true, k/255, 0)` 정확 왕복 (door 테스트).
3. **단순화 후보**: `Cooldown:SetCooldown(secretStart, cd)` 가 secret 숫자 받는지.
   - 받으면 → 숫자 띠/코드값 인코딩 전부 불필요. `start = EvalBool(edge, now, prevStart)` → Cooldown 프레임 + 블리자드 숫자. **PartyCD/Stops 구현량 대폭 감소.**
   - 안 받으면 → 원본 방식(2-2) 이식.
4. `C_DurationUtil` 로 secret 시작시각에서 Duration 객체 생성 가능한지 (대안).
5. 차단기용: 인스턴스 전투 중 `UNIT_SPELLCAST_INTERRUPTED` 의 `interruptedBy`, `C_DamageMeter` 차단 집계의 `combatSpells`/`totalAmount` 가 secret 인지 확인 → 판정 폴백 몇 단까지 필요한지 결정.

### Phase 1 — 골격 + 데이터 + 본인 쿨
- `99 Options.lua`(마스터 토글 4개), `01 Core.lua`, `02 Data.lua`(종족/장신구 제외).
- PartyCD 본인 행: `GetSpellCooldownDuration` + `SetCooldownFromDurationObject` + DurationTextBinding.
- 떠있는 블록 + LibEditMode.
- ✅ 본인 쿨 쓰면 아이콘 쿨 돔.

### Phase 2 — 차단기 (독립성 높고 체감 큼 → 먼저)
- `08 Interrupts.lua`: 행 UI(바/아이콘/이름/시간), 본인 `GetSpellCooldown` 폴링, `UNIT_SPELLCAST_SUCCEEDED` 비-secret 확정, `interruptedBy` GUID 확정, 흑마 펫.
- 준비/쿨 정렬, 징표 + 차단당한 주문 아이콘.
- ✅ 던전 밖 파티에서 차단 → 해당 행 쿨.
- Phase 2b: 데미지 미터 판정(`mtr.Update`, `Pair`) + 추정(`Guess`). Phase 0-5 결과 따라 "stack" 레이어 트릭 이식 여부 결정.
- ✅ 쐐기 전투 중 파티원 차단 → 해당 행 쿨.

### Phase 3 — 인스펙트 공용 모듈
- `05 Inspect.lua`: 큐 + `INSPECT_READY` → 전문화/특성 랭크 캐시 (`byGUID`), 콜백으로 각 모듈 갱신.
- 차단기 쿨 보정(`mods`, `landed`, 힐러 주술사)부터 연결.

### Phase 4 — 파티 쿨: 파티원 감지 (plain 경로)
- `03 Sensor.lua`, `04 Timer.lua` plain 경로, `06 PartyCD.lua` 파티원 행.
- ✅ 던전 밖 파티에서 파티원 쿨 사용 → 타이머 시작.

### Phase 5 — 파티 쿨: secret 경로 (Phase 0-3 결과로 A/B)
- A안: EvalBool 시작시각 → Cooldown 프레임.
- B안: 원본 `Stamp/Roll/Left/Range/Feed/Pick/State` + 숫자 띠 이식.
- 특성 보정(`mods/swap/gate`) 연결.
- ✅ 쐐기 전투 중 파티원 쿨 감지.

### Phase 6 — 블리자드 파티 프레임 붙이기
- 2-6 대로 CompactPartyFrame / PartyFrame 판정 + 방향 4종(RIGHT/LEFT/BELOW/ABOVE).
- 차단기 바도 옵션으로 붙일지는 나중 판단 (원본은 독립 블록만).

### Phase 7 — 공생기 바
- `07 Defensives.lua`: Phase 4~5 엔진 재사용, 주문 `GUARD`. 순서/개별 숨김.

### Phase 8 — 군중제어 바
- `09 Stops.lua`: 이름표 슬롯 관리(`NAME_PLATE_UNIT_ADDED/REMOVED`, 2초 재스캔, 전투 중 적 우선, 보스 제외), head/tail/span 센서 체인, 광역 CC 감시 수 제한, `lag` 보정, 본인 `UNIT_SPELLCAST_SUCCEEDED`.
- Phase 5 타이머 재사용.

### Phase 9 — 설정창 마무리
- `/dd` 편의기능 → 파티 추적: 마스터 토글, 크기/간격, 본인 포함, 던전만, 특성 반영, 차단기 바 옵션.
- 전문화별 주문 on/off 목록은 마지막 (`SettingsMultiDropDown` 검토).

---

## 5. 보류/제외 (원본에 있으나 이식 안 함)

| 기능 | 이유 |
|---|---|
| 2충전 secret 카운트 (커서 위치 트릭) | 1충전 근사로 대체 |
| 원형 스와이프, 픽셀 정렬(`Seat`, `LineMetrics`) | 장식 / B안일 때만 필요 |
| 드루 화신·광폭화 쿨 초기화, Well-Honed 발동 (`free`/`proc`) | 특수 케이스 |
| 장신구 + 사망 시 쿨감 (`deathCut`), 종족 특성 | 우선순위 낮음, 데이터만 나중 추가 가능 |
| 이동속도 바(`speed`), 외부 생존기 바(`PTCExt`) | 요청 범위 밖 |
| EllesmereUI 연동 / UIParent 전체 스캔 / 가짜 파티 프레임(mock) | 순정 프레임만 지원 |
| 랜덤 미리보기 덱, 진단 슬래시 명령, 통계 카운터 | 개인용 불필요 (미리보기는 EditMode 시 고정 샘플만) |

---

## 6. 위험 요소

1. **12.1 전용 API** (`CustomAuraContainerTemplate`, `AddAuraGroup`, `DisableUntrustedLayoutScriptsTemplate`, `C_DamageMeter`) — 막히면 해당 기능 사망. `C_XMLUtil.GetTemplateInfo` 로 존재 확인 후 없으면 조용히 비활성.
2. **IsMouseOver/레이아웃/클립 폭 트릭** 은 비공식 용도 → 핫픽스로 막힐 수 있음.
3. **버프 기반 감지 오탐/누락**: 데이터 정확도가 품질 좌우.
4. **차단기 판정 오류**: secret 상황에선 데미지 미터 + 추정이라 동시 차단/광역 차단 시 엉뚱한 사람에게 귀속 가능. 헛친 차단은 못 잡음.
5. **센서 프레임 수**: 파티 4×10 + Stops 주문×적 수. 전투 중 생성 불가.
6. **인스펙트 충돌**: 다른 애드온과 NotifyInspect 경쟁 → 공용 큐 + 최소 간격 2초.
7. **Stops 귀속 불가** — 구조적 한계.

---

## 7. Phase 0 실험 결과 (1차)

| 항목 | 결과 | 의미 |
|---|---|---|
| door (EvalBool 왕복) | 최대 오차 7.2e-08 → **close** | 원본 B안(코드값 인코딩) 사용 가능 |
| DurationObject | userdata, 메서드 열거 불가 | 후보 이름 조회로 재확인 필요 (`/pttest dur` 보강함) |
| `StatusBar.SetTimerDuration` | 있음 | Duration 경로 쓸 수 있으면 바 표시 단순화 가능 |
| `C_Spell.GetSpellCooldownDuration` | 있음 | 본인 쿨 정확 경로 OK |
| Cooldown secret 수용 | **미실행** (센서 안 만들고 `cd` 실행) | 재실험 필요 |
| 파티원 `UNIT_SPELLCAST_SUCCEEDED` spellID | **SECRET** | 인스턴스에서 파티원 시전 직접 감지 불가 → 차단기 1단계 무용 |
| 적 `CHANNEL_STOP` interruptedBy | **SECRET** | 차단기 2단계(GUID 확정) 무용 |
| `UNIT_SPELLCAST_INTERRUPTED party3/4` | 파티원 자기 시전 끊김 이벤트 (interruptedBy nil) | 무관, 적 유닛만 볼 것 |
| 데미지미터 차단 `combatSpells` | 읽히지만 **개수 0** (빈 목록) | 개수 비교 판정 무용 |
| 데미지미터 `totalAmount` | **SECRET** | Kira "stack" 트릭(secret 이전/현재값 → 클립 폭) 필수 |

**결론**
- 차단기: 쐐기 전투 중엔 원본 3단계 중 **"stack" 레이어 트릭 + 추정(Guess)** 만 살아있음. Phase 2b에서 이것 이식 필수.
- 파티 쿨: B안은 확정 가능. A안(Cooldown secret 수용)은 재실험 후 결정.

**2차 실험 (남은 것)**
1. `/pttest dur` — DurationObject 메서드 확인.
2. 파티 + 던전에서: `/pttest sensor party1 <버프ID>` (전투 밖) → 전투 중 파티원이 버프 사용 후 `lit = SECRET` 확인 → 그 상태에서 `/pttest cd`.

---

## 8. H3ndallPartyCds 검토

### 정체
**KiraUI PartyCDs를 독립 애드온으로 떼어낸 포크.** 엔진 코드(센서, EvalBool 타이머, charge, exact, swipe, 프레임 탐색) 줄 단위로 동일. 파일만 분리(`Charges.lua`, `ExactCooldowns.lua`, `PartyFrames.lua`, `Sensors.lua`, `SpellData.lua`) 하고 `ns.Init*()` 로 상태 주입. Interface `120105`.
공생기/차단기/군중제어는 **없음** (PartyCDs만).

### Kira 대비 달라진 점
| 구분 | 내용 | dodo 반영 |
|---|---|---|
| 주문 DB 확장 | `ADDITIONAL` ~100개 (부활, 블러드, 주요 딜쿨/생존기 등), `SHARED`(직업 공통) + `SPECIALIZED`(전문화) 로 `SPECS` 에 덧붙임 | **반영** — 데이터만. 단 대부분 `selfOnly`(본인만, 버프 감지 불가) + `gate`(특성 없으면 숨김)라 파티원 추적엔 일부만 유효 |
| 파티원 감지 가능한 추가분 | 리치본, 영혼 시야, 생명의 나무, 정신 자극(zone/others), 수호 고대 왕, 신성한 찬가(zone), 아드레날린 촉진, 영혼걸음, 투신, 방패의 벽, 치타/독수리의 상, 죽은 척, 지옥 지배, 공간 역설 등 | 반영 후보 (버프 ID 검증 필요) |
| 복수 악사 | 탈태(187827), 악마 쐐기(203720), 불타는 낙인(204021, 본인), 지옥 황폐(212084, 본인) | 반영 |
| 아이콘 개수 상한 | 고정 10 → 스펙별 최대치 자동 계산 (`maxSpells`), 루프 `1..s.n` | **반영** (주문 늘리면 필수) |
| zone 센서 소유 중복 | 같은 버프 시그니처를 여러 주문이 공유할 때 센서 필요 여부를 소유자 수로 계산 (`ownedZones`) — Kira 버그 수정 | **반영** |
| 본인 중복 제거 | 본인 행에서 override ID 같은 주문 중복 제거 + 대체 아이콘 | 반영 |
| gate 판정 | `GetOverrideSpell` 결과를 `IsPlayerSpell`로 재확인 | 반영 |
| 특성 토글 | 항상 켬 (`cfg.talents` 제거) | 그대로 따라감 (토글 키 `usePartyCDTalents` 제거) |
| 프레임 탐색 | Kira와 동일 (UIParent 전체 스캔 + EllesmereUI) | 미반영 (블리자드 순정만) |

### 평가
- 새 로직은 없음. **가치 = 확장된 주문 DB + 버그 수정 3개.**
- `ADDITIONAL` 은 주석에 "신뢰할 시전자 오라 없는 효과는 본인 전용"이라 명시 — 즉 파티원 쪽 커버리지는 크게 안 늘어남.
- 주문 ID/버프 ID는 12.x 기준이라 Kira보다 최신일 가능성. `02 Data.lua` 작성 시 **H3ndall `SpellData.lua` 를 베이스**로 쓰는 게 나음.

---

## 9. 방향 전환 (사용자 지시: "어렵게 돌지 말고 코드 복사")

2차 실험: DurationObject 메서드 확인(`SetTimeFromStart` 등 있음), 센서 lit 전투 중 SECRET 확인. → 실험 종료, **원본 B안 코드 그대로 복사**로 확정. 3장 파일 구조/4장 Phase 계획은 아래로 대체.

### 실제 파일 구조 (H3ndall 엔진 복사)
| 파일 | 원본 | 수정 |
|---|---|---|
| `99 Options.lua` | 신규 | `/dd 편의기능 > 파티 추적` 토글 3개 → 엔진 cfg 동기화 |
| `01 Core.lua` | H3ndall `Core.lua` | 저장소 `dodoDB.partyTracker`, `ns.L` 패스스루 (Locale 제외) |
| `02 Talents.lua` ~ `09 ExactCooldowns.lua` | H3ndall 동명 파일 | 없음 |
| `10 PartyCDs.lua` | H3ndall `PartyCDs.lua` | 전역 프레임명 `dodoPartyCDs`, 디버그 슬래시 `/ptcd` |
- 제외: `Locale.lua`, `Options.lua`, `OptionsPage.lua`, `Minimap.lua`, `Bootstrap.lua`
- `ns` = dodoQOL 애드온 private 테이블 (기존 dodoQOL 파일은 `ns` 미사용 → 충돌 없음)

### 추가 이식 (Kira 복사)
| 파일 | 원본 | 수정 |
|---|---|---|
| `11 Defensives.lua` | Kira `PartyDefensives.lua` | 프레임명 `dodoPartyDefensives`, 슬래시 `/ptdef` |
| `12 Interrupts.lua` | Kira `Interrupts.lua` | 프레임명 `dodoPartyInterrupts`, 슬래시 `/ptkick`, 바 텍스처 dodo `KuiNameplateBar`, 실측 쿨 저장 `dodoDB.partyTracker.ikLearned` |
| `13 Stops.lua` | Kira `PartyStops.lua` | 프레임명 `dodoPartyStops1/2`, 슬래시 `/ptstop` |
| `14 EditMode.lua` | 신규 | LibEditMode 등록 (공생기/차단기/군중제어 1·2), 편집모드 중 켜진 모듈 미리보기 |
| `01 Core.lua` | + shim | `PlayerSpec`, `LSM`(nil), `BarTexture`, `Msg`, `EditModeActive`(LEM) |
| `10 PartyCDs.lua` | + LibIcon | `NewCell` → `dodo.LibIcon:Create`, `Dress` 에서 `RescaleIcon` (백업 `.bak`) |

### 이전 남은 단계 (참고)
1. ✅ 파티 쿨 (H3ndall 복사) — 인게임 확인 중
2. 공생기 — Kira `PartyDefensives.lua` 복사 (`ns.PTCBar('guard')` 사용, 엔진에 이미 있음)
3. 차단기 — Kira `Interrupts.lua` 복사 (필요 헬퍼: `BarTexture`, `PlayerSpec`, `LSM` 등 shim)
4. 군중제어 — Kira `PartyStops.lua` 복사 (`PTCKit` 사용, `EditModeActive` shim)
5. 위치 이동: 현재 엔진 드래그는 설정창 열림 조건이라 막혀 있음 → LibEditMode 연결
