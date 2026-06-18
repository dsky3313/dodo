# EncounterTimeline TopToBottom 구현 방식 검토

## 목표
블리자드 기본 BottomToTop에서 TopToBottom(위에서 아래로 쌓기) 옵션 추가.

---

## 근본 문제 (진단 확정)

`tv.timerLayoutDirection = dir` — addon에서 이 field를 쓰면 tainted.

블리자드 코드가 `GetTimerLayoutDirection()` → `IsFlippedVertically()`에서 이 tainted field를
읽는 순간 execution 전체가 오염됨 → `UpdateCountdownText`에서 secret value 비교 에러.

진단 결과:
- `MarkDirty`는 clean context(블리자드 이벤트 핸들러)에서 호출됨 — dodo 스택 없음
- `dir_issecure=false` — timerLayoutDirection field 자체가 tainted
- C_Timer 자체가 tainted된 게 아니라, callback 내부에서 tainted field를 읽어 execution이 오염됨

clean context에서 timerLayoutDirection을 설정하는 공식 API 없음:
- `Enum.EditModeEncounterEventsSetting`에 TimerLayoutDirection 항목 없음
- EditMode SavedData 경로 불가

---

## 시도 결과

### [실패] 방식 A: timerLayoutDirection 직접 설정
```lua
tv.timerLayoutDirection = dir
tv:MarkDirty(TimerViewDirtyFlag.TimerLayout)
```
결과: 170x taint 에러

### [실패] 방식 A-1: MarkDirty + SetPoint 제거
timerLayoutDirection만 남기고 MarkDirty, SetPoint 제거.
결과: 1x 에러 지속. timerLayoutDirection field 자체가 원인 확정.

### [적용됨] 방식 A-2: Color 모듈 UnregisterEvent
Color 모듈 SetEventColor 호출 전후 `ENCOUNTER_TIMELINE_STATE_UPDATED` 이벤트 일시 해제.
결과: 170x → 1x로 감소. EncounterTimelineColor.lua에 현재 적용됨.

### [불가] 방식 B: EditMode SavedData 조작
블리자드가 clean context에서 SetTimerLayoutDirection을 호출하도록 유도.
결과: EditModeEncounterEventsSetting에 해당 enum 없음 → 불가.

---

## 앞으로 시도할 방식

### [현재 시도] 방식 1: InitializeEventFrameSettings hook
`hooksecurefunc(tv, "InitializeEventFrameSettings", fn)` 로 각 프레임 앵커 재설정.
- timerLayoutDirection 건드리지 않음
- hook은 original 실행 후 추가 실행 → 우리가 앵커를 덮어씀
- 문제: UpdateTimerLayout의 SetVerticalOffset/OnVerticalOffsetChanged가 앵커를 다시 바꿀 수 있음
  → 그 경우 SetVerticalOffset도 hook 필요

### 방식 2: SetVerticalOffset hook
UpdateTimerLayout이 `offsetDirectionMultiplier = flipped and 1 or -1 = 1`(아래 방향)로
계산한 timerOffset을 SetVerticalOffset hook에서 부호 반전.
timerLayoutDirection 건드리지 않음.
문제: hook이 addon tainted context에서 실행되므로 추가 taint 유발 가능성 검증 필요.

### 방식 3: Y오프셋만 구현 (방향 전환 포기)
timerLayoutDirection 없이 TimerView Y 오프셋 기능만 구현.
안전하게 작동하나 핵심 기능 포기.

### 방식 4: TimerView 시각적 flip
`tv:SetScale(...)` 또는 transform으로 시각적 뒤집기.
텍스트/아이콘도 뒤집히는 문제 있어 UX 손상.

---

## 참고: 블리자드 관련 코드 위치
- `InitializeEventFrameSettings` — EncounterTimelineTimerView.lua:313
- `SetPointWithVerticalFlip` 호출 — EncounterTimelineTimerView.lua:317
- `IsFlippedVertically` — EncounterTimelineTimerView.lua:278
- `GetTimerLayoutDirection` — EncounterTimelineSettings.lua
- `UpdateTimerLayout` — EncounterTimelineTimerView.lua:396
- `SetVerticalOffset` — EncounterTimelineTimerEvent.lua:349
- `UpdateCountdownText` (에러 위치) — EncounterTimelineTimerEvent.lua:566
