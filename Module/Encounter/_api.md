# C_EncounterEvents / C_EncounterTimeline API 정리
> Patch 12.0.1 추가. dodo Encounter 모듈 전용 참고.

---

## 1. ID 체계 — 세 가지 혼동 금지

| ID 종류 | 안정성 | 예시 | 용도 |
|---------|--------|------|------|
| `encounterEventID` | stable | 277 | `C_EncounterEvents.*` API 키 |
| `spellID` | stable | 388537 | wowhead 조회 가능. `GetEventInfo`로 역매핑 |
| `EncounterTimelineEventID` | **runtime 임시** | 매 세션 다름 | `ENCOUNTER_TIMELINE_EVENT_ADDED/HIGHLIGHT` tempID |
| EJ sectionID | stable | 33973 | EJ 능력 섹션 전용. EncounterEvents와 무관 |

> `encounterEventID ≠ EJ sectionID`. EXBoss가 기록한 숫자(277 등)는 Blizzard가 부여한 `encounterEventID`.

---

## 2. C_EncounterEvents

모두 **stable encounterEventID** 기반. PLAYER_ENTERING_WORLD 등 전투 전에 1회 등록.

### 2-1. 목록 조회

```lua
-- 모든 encounterEventID 배열 반환
encounterEventIDs = C_EncounterEvents.GetEventList()   -- number[]

-- ID 존재 여부
exists = C_EncounterEvents.HasEventInfo(encounterEventID)   -- boolean

-- 이벤트 상세 정보
info = C_EncounterEvents.GetEventInfo(encounterEventID)
-- info.encounterEventID  number
-- info.enabled           boolean   boss ability HUD 표시 여부
-- info.spellID           number    연결 스펠 (1개 스펠이 여러 encounterEventID에 매핑 가능)
-- info.iconFileID        number
-- info.severity          Enum.EncounterEventSeverity   (Low/Medium/High)
-- info.icons             Enum.EncounterEventIconmask   (역할 비트마스크)
```

### 2-2. 소리

```lua
-- trigger = Enum.EncounterEventSoundTrigger
--   0 = OnTextWarningShown      텍스트 경고 표시 시
--   1 = OnTimelineEventFinished 타임라인 이벤트 완료(시전) 시  ← 주로 사용
--   2 = OnTimelineEventHighlight 하이라이트 구간 (~5초 전)

C_EncounterEvents.SetEventSound(encounterEventID, trigger, sound)
-- sound = { file = "path.mp3", channel = "Master", volume = 1.0 }
-- sound = nil  →  해당 trigger 소리 삭제

sound = C_EncounterEvents.GetEventSound(encounterEventID, trigger)
-- 반환: EncounterEventSoundInfo 또는 nil

handle = C_EncounterEvents.PlayEventSound(encounterEventID, trigger)
-- 즉시 재생. 반환: SoundHandle
```

### 2-3. 색상

```lua
-- trigger = Enum.EncounterEventColorTrigger
--   0 = TextWarning          텍스트 경고 색상
--   1 = TimelineEvent        타임라인 막대 색상
--   2 = TimelineEventHighlight  하이라이트 색상 (~5초 전)
-- Patch 12.0.7에 trigger 파라미터 추가됨

C_EncounterEvents.SetEventColor(encounterEventID, trigger, color)
-- color = CreateColor(r, g, b)
-- color = nil  →  색상 오버라이드 삭제

color = C_EncounterEvents.GetEventColor(encounterEventID, trigger)
-- 반환: colorRGBA 또는 nil
```

### 2-4. spellID → encounterEventID 역매핑 (런타임 1회 빌드)

```lua
-- 주의: 1개 spellID가 여러 encounterEventID에 매핑될 수 있음
local spell_to_event = {}
for _, id in ipairs(C_EncounterEvents.GetEventList()) do
    local info = C_EncounterEvents.GetEventInfo(id)
    if info and info.spellID and info.spellID ~= 0 then
        -- 중복 시 마지막 값 덮어씀 (실전에서는 거의 1:1)
        spell_to_event[info.spellID] = id
    end
end
```

---

## 3. C_EncounterTimeline (runtime tempID 기반)

**ADDED/HIGHLIGHT 이벤트**가 주는 `EncounterTimelineEventID`는 세션마다 달라지는 임시값.
`GetEventInfo`로 `spellID` 추출 → Data.lua 항목 조회에 활용.

```lua
info = C_EncounterTimeline.GetEventInfo(runtimeTempID)
-- [non-secret] info.id               EncounterTimelineEventID (tempID 그대로)
-- [non-secret] info.source           Enum.EncounterTimelineEventSource
-- [non-secret] info.duration         DurationSeconds
-- [non-secret] info.maxQueueDuration DurationSeconds
-- [SECRET]     info.spellID          테이블 키/비교 불가. setter 전달만
-- [SECRET]     info.spellName        setter 전달만
-- [SECRET]     info.iconFileID       SetTexture 전달만
-- [SECRET]     info.severity         Enum.EncounterEventSeverity
-- [SECRET]     info.icons            Enum.EncounterEventIconmask
-- [SECRET]     info.isApproximate
-- ※ 전투 중 이벤트 식별 가능한 필드: source, duration 뿐 → duration 매칭 불가피

state = C_EncounterTimeline.GetEventState(runtimeTempID)
-- Enum.EncounterTimelineEventState: Active / Finished / Canceled 등

remaining = C_EncounterTimeline.GetEventTimeRemaining(runtimeTempID)
-- DurationSeconds. 쿨다운 표시에 사용
```

---

## 4. 관련 이벤트

| 이벤트 | arg1 | 설명 |
|--------|------|------|
| `ENCOUNTER_START` | encounterID (dungeonEncounterID) | 보스전 시작 |
| `ENCOUNTER_END` | encounterID | 보스전 종료 |
| `ENCOUNTER_TIMELINE_EVENT_ADDED` | eventInfo table | 타임라인 이벤트 추가. `eventInfo.id` = tempID |
| `ENCOUNTER_TIMELINE_EVENT_HIGHLIGHT` | tempID | 이벤트 하이라이트 시작 (~5초 전) |
| `ENCOUNTER_TIMELINE_EVENT_STATE_CHANGED` | tempID | 상태 변경 (Finished/Canceled) |
| `ENCOUNTER_TIMELINE_EVENT_REMOVED` | tempID | 이벤트 제거 |

---

## 5. 리팩토링 계획

### 핵심 방향

**현재**: Data.lua에 `eventID`(encounterEventID) + `rules`(duration 매칭) 하드코딩  
**목표**: `spellID`만 저장 → 런타임 API로 모든 매핑 자동화, `rules` 제거

---

### 5-1. Data.lua

**변경 전:**
```lua
{ eventID = 277, role = "Mechanic", sound = "Phase" }
rules = { { dur = 40, eID = 277 }, ... }
```

**변경 후:**
```lua
{ spellID = 388537, role = "Mechanic", sound = "Phase" }
-- rules 섹션 전체 삭제
```

- `eventID` → `spellID` (wowhead에서 바로 확인 가능)
- `rules` 섹션 전체 삭제
- spellID는 `/spell:388537` or wowhead URL로 확인

---

### 5-2. Sound.lua

**변경 내용:**
- `apply_sounds()` 진입 시 `spell_to_event` 맵 1회 빌드
- `SetEventSound(entry.eventID, ...)` → `SetEventSound(spell_to_event[entry.spellID], ...)`
- `clear_sounds()`: `entry.eventID` → `clear_event_ids[]`(적용한 encounterEventID 목록)로 교체

```lua
local function build_spell_map()
    local m = {}
    for _, id in ipairs(C_EncounterEvents.GetEventList()) do
        local info = C_EncounterEvents.GetEventInfo(id)
        if info and info.spellID ~= 0 then m[info.spellID] = id end
    end
    return m
end

-- apply_sounds() 내부
local spell_map = build_spell_map()
local applied = {}
for _, entry in ipairs(all_events) do
    local eid = spell_map[entry.spellID]
    if eid then
        C_EncounterEvents.SetEventSound(eid, 1, sound1)
        applied[#applied+1] = eid
    end
end
current_event_ids = applied  -- 해제용 저장
```

---

### 5-3. TimelineColor.lua

Sound.lua와 동일 패턴:
- `spell_to_event` 맵 빌드
- `SetEventColor(spell_map[entry.spellID], trigger, color)`
- `clear_current()`: 저장된 encounterEventID 목록으로 해제

---

### 5-4. Text.lua — 가장 큰 변화

**제거 대상 (duration 매칭 시스템 전체):**
- `pending_adds`, `flush_scheduled`, `BATCH_WINDOW`, `MATCH_TOL`
- `flush_pending_adds()`, `do_flush()`
- `global_rule_used`, `temp_to_rule_idx`, `release_rule_slot()`
- `ENCOUNTER_TIMELINE_EVENT_ADDED` 리스너

**새 로직 (`on_timeline_highlight` 교체):**
```lua
local function on_timeline_highlight(tempID)
    if not current_encounter then return end
    local info = C_EncounterTimeline.GetEventInfo(tempID)
    if not info or info.source ~= dodo.Encounter.ENCOUNTER_SOURCE then return end

    local data = dodo.EncounterData[current_encounter]
    local entry = data and data[info.spellID]  -- spellID로 직접 조회
    if not entry or entry.enable == false then return end

    show_alert(tempID, info, entry.role, entry.text or SOUND_DEFAULT_TEXT[entry.sound])
end
```

- `ENCOUNTER_TIMELINE_EVENT_ADDED`: 이벤트 등록 자체 제거
- `on_state_changed` / `ENCOUNTER_TIMELINE_EVENT_REMOVED`: 유지 (hide_alert 용도)

---

### 5-5. 진행 순서

1. **Data.lua** — `eventID` → `spellID` 전환, `rules` 제거 (데이터 작업, 검증 필요)
2. **Text.lua** — duration 매칭 제거, spellID 직접 조회로 교체
3. **Sound.lua** — `spell_to_event` 맵 방식으로 교체
4. **TimelineColor.lua** — Sound와 동일 패턴 적용
5. `/reload` 검증 → 각 단계 완료 후 인게임 확인

---

### 5-6. 주의사항

- **1 spellID : N encounterEventID**: 희귀하지만 존재. 현재 계획은 마지막 값 사용(덮어씀). 실전 문제 발생 시 배열로 저장 후 전체 적용 고려.
- **GetEventList() 12.0.1+**: 현재 클라이언트 버전 확인 필요. 없으면 `HasEventInfo()`로 범위 순회 대안.
- **spellName secret value**: `GetEventInfo().spellName`은 전투 중 secret일 수 있음. `SetText` 직접 전달만, 비교/조건 금지.
