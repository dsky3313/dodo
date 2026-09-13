# NamePlate 모듈 구현 체크리스트

> 참고: EnemyNameplateColors v1.2.0 (Zerkggz) 분석 기반  
> 표준: dodo 2dodo SKILL.md

---

## 파일 구조

- [x] `Module/NamePlate/Core.lua` — 공통 상태·유틸 (in_instance, other_tanks, interrupt_spells)
- [x] `Module/NamePlate/HealthColor.lua` — 체력바 색상 + 포커스 색상 모드
- [ ] `Module/NamePlate/CastBar.lua` — 캐스팅바 색상 + 인터럽트 테두리
- [ ] `Module/NamePlate/DispelGlow.lua` — Stealable/Purgeable 글로우

---

## dodoDB 키 (camelCase)

### 토글

| 키 | 기본값 | 설명 |
|----|--------|------|
| `enableNameplate` | false | 마스터 토글 |
| `nameplateZoneDungeon` | true | 던전 활성 |
| `nameplateZoneRaid` | true | 레이드 활성 |
| `nameplateZoneDelve` | true | 딜브/시나리오 활성 |
| `nameplateZoneWorld` | false | 오픈월드 활성 |
| `nameplateHealthColor` | true | 체력바 색상 토글 |
| `nameplateFocusColor` | false | 포커스 색상 모드 (색상 모드·텍스처 모드 상호 배타) |
| `nameplateFocusTexture` | false | 포커스 텍스처 모드 |
| `nameplateCastBarColor` | false | 캐스팅바 색상 토글 |
| `nameplateInterruptBorder` | true | 인터럽트 준비 테두리 |
| `nameplateDispelGlow` | true | 디스펠 글로우 |

### 색상 — 체력바 유닛 타입 (rgb)

| 키 | 기본값 |
|----|--------|
| `nameplateColorBoss` | `{r=0.8, g=0.2, b=1.0}` |
| `nameplateColorMiniBoss` | `{r=0.2, g=0.4, b=1.0}` |
| `nameplateColorCaster` | `{r=0.0, g=0.8, b=1.0}` |
| `nameplateColorStandard` | `{r=0.8, g=0.6, b=1.0}` |

### 색상 — 탱 위협 (rgb)

| 키 | 기본값 |
|----|--------|
| `nameplateColorTankOnOtherTank` | `{r=0.28, g=0.59, b=1.0}` |
| `nameplateColorTankNoThreat` | `{r=1.0, g=0.0, b=0.0}` |
| `nameplateColorTankLosingThreat` | `{r=1.0, g=0.6, b=0.0}` |

### 색상 — 딜/힐 위협 (rgb)

| 키 | 기본값 |
|----|--------|
| `nameplateColorDpsHasThreat` | `{r=1.0, g=0.0, b=0.0}` |
| `nameplateColorDpsGainingThreat` | `{r=1.0, g=0.6, b=0.0}` |

### 색상 — 포커스 (rgba)

| 키 | 기본값 |
|----|--------|
| `nameplateColorFocus` | `{r=1.0, g=0.3, b=0.9, a=1.0}` |

### 색상 — 캐스팅바 (rgba)

| 키 | 기본값 |
|----|--------|
| `nameplateCastBarStandard` | `{r=1.0, g=0.7, b=0.0, a=1.0}` |
| `nameplateCastBarUninterruptible` | `{r=0.275, g=0.275, b=0.275, a=1.0}` |
| `nameplateCastBarChannel` | `{r=0.0, g=1.0, b=0.0, a=1.0}` |
| `nameplateCastBarImportant` | `{r=1.0, g=0.0, b=1.0, a=1.0}` |
| `nameplateCastBarInterruptReady` | `{r=0.0, g=1.0, b=0.0, a=1.0}` |

### 색상 — 디스펠 글로우 (rgb)

| 키 | 기본값 |
|----|--------|
| `nameplateColorDispelGlow` | `{r=0.0, g=0.5, b=1.0}` |

---

## 공통 상태

- [ ] `local in_instance` — 현재 구역 활성 여부
- [ ] `local player_in_combat` — 전투 중 여부
- [ ] `local other_tanks = {}` — 그룹 내 다른 탱 유닛 목록
- [ ] `local interrupt_spells = {}` — 플레이어 인터럽트 스킬ID 목록
- [ ] `local neutral_cache = {}` — 중립(노란) 네임플레이트 캐시

---

## 1. 구역 판별 `update_instance_status()`

- [ ] `IsInInstance()` → party/raid/scenario 분기 + dodoDB 구역 토글 체크
- [ ] `C_DelvesUI.HasActiveDelve()` fallback (딜브 감지 보조)
- [ ] 오픈월드: `nameplateZoneWorld` 키로 제어

---

## 2. 유닛 타입 판별 `get_unit_type(unit)`

- [ ] `UnitClassification(unit)` 분기:
  - `worldboss` → `"boss"`
  - `rare` → `"miniBoss"`
  - `elite` / `rareelite` + 레벨차:
    - `UnitLevel(unit) == -1` 또는 `levelDiff >= 2` → `"boss"`
    - `levelDiff >= 1` → `"miniBoss"`
- [ ] `UnitPowerType(unit) == 0` (마나 유닛) → `"caster"`
- [ ] 나머지 → `"standard"`

---

## 3. 체력바 색상 `HealthColor.lua`

- [ ] `hooksecurefunc("CompactUnitFrame_UpdateHealthColor", ...)` 후킹
- [ ] `strmatch(frame.unit, "^nameplate")` 필터
- [ ] 중립 감지: Blizzard가 세팅한 `GetStatusBarColor()` RGB로 `neutral_cache` 세팅
  - 조건: `r > 0.9 and g > 0.7 and b < 0.2` → 중립(yellow)
- [ ] `UnitIsTapDenied(unit)` → 스킵 (회색 유닛)
- [ ] `UnitIsPlayer(unit)` → 스킵 (플레이어 클래스색 유지)
- [ ] `neutral_cache[unit]` → 스킵 (중립 유지)
- [ ] 포커스 색상 모드: `nameplateFocusColor`이고 `UnitIsUnit(unit, "focus")` → 포커스 색 적용
- [ ] **전투 외**: `unitType ~= "standard"`인 경우만 유닛타입 색 적용
- [ ] **전투 중 탱 역할**:
  - [ ] `IsBeingTankedByOther(unit)` → onOtherTank 색 (`dodoDB` 또는 하드코딩)
  - [ ] `status >= 3` (내가 잡음) → unitType 색
  - [ ] `status == 2` (위협 잃는 중) → losingThreat 색
  - [ ] `status <= 1` 또는 `UnitAffectingCombat(unit)` → noThreat 색
- [ ] **전투 중 딜/힐 역할**:
  - [ ] `status >= 3` (어그로) → hasThreat 색
  - [ ] `status >= 1` (위협 올라감) → gainingThreat 색
  - [ ] 전투 중 유닛 or `unitType ~= "standard"` → unitType 색
- [ ] `get_threat_status()`: `UnitThreatSituation` → **`pcall` 필수** (secret number)
- [ ] `is_being_tanked_by_other()`: `other_tanks` 순회, `UnitThreatSituation(tankUnit, unit) >= 2`

---

## 4. 포커스 텍스처 오버레이

- [ ] 체력바(`healthBar`) 위에 Texture 생성: `OVERLAY`, `ADD` 블렌드
- [ ] `nameplateFocusTexture`가 켜진 경우, `UnitIsUnit(unit, "focus")`일 때 표시
- [ ] `PLAYER_FOCUS_CHANGED` 이벤트로 전체 네임플레이트 갱신
- [ ] 색상 모드(`nameplateFocusColor`)와 상호 배타 처리

---

## 5. 캐스팅바 색상 `CastBar.lua`

- [ ] `hooksecurefunc(CastingBarMixin, "OnEvent", ...)` 후킹
  - `UNIT_SPELLCAST_STOP` / `CHANNEL_STOP` / `FAILED` / `INTERRUPTED` → 텍스처 복원
  - `UNIT_SPELLCAST_START` / `CHANNEL_START` / `INTERRUPTIBLE` / `NOT_INTERRUPTIBLE` → 색상 적용
- [ ] `hooksecurefunc(CastingBarMixin, "OnUpdate", ...)` 후킹
  - 비전투 시: **secret boolean pcall 전에 먼저** 정리 (`ENC_hasColor` 초기화, 테두리 Hide)
  - `pcall(UnitIsFriend, "player", unit)` 필터
  - `ENC_hasColor` 유지: 텍스처·버텍스색 재적용 (OnUpdate가 덮어쓰기 때문)
  - 0.1초 쓰로틀로 인터럽트 테두리 갱신
- [ ] **색상 우선순위**: Uninterruptible > Important > Channel > Standard
- [ ] 색 합성: `C_CurveUtil.EvaluateColorValueFromBoolean` 사용 — 직접 if 분기 금지
  - `isImportant` (C_Spell.IsSpellImportant) → important 색 레이어
  - `notInterruptible` → uninterruptible 색 레이어 (최우선)
- [ ] 전투 중에만 적용 (`player_in_combat` 체크)
- [ ] 커스텀 텍스처: `SetTexture(...)` + `SetVertexColor(r,g,b,a)` 조합
- [ ] `HookIfExists("UpdateInterruptibleState")` / `"UpdateHighlightImportantCast"` 후킹

---

## 6. 인터럽트 준비 테두리

- [ ] 캐스팅바 위에 borderFrame 생성 (`FrameLevel + 2`)
- [ ] `castBar.BorderShield` 존재 확인 (없으면 Hide)
- [ ] 쿨다운 체크 (pcall 감싸기):
  - `C_Spell.GetSpellCooldownDuration(spellID):IsZero()` → 준비됨
  - `C_CurveUtil.EvaluateColorValueFromBoolean(isZero, 1, result)` 로 `anyReady` 계산 (secret number)
- [ ] `BorderShield:IsShown()` → `pcall` 감싸기 (secret boolean)
  - `borderFrame:SetAlphaFromBoolean(isShielded, 0, anyReady)`
  - Shield 표시(비인터럽트) → alpha 0 / Shield 숨김(인터럽트 가능) → alpha anyReady
- [ ] 비전투 시 즉시 Hide
- [ ] `SPELL_UPDATE_COOLDOWN` 이벤트로 전체 테두리 갱신 (전투 중만)

---

## 7. 디스펠/Stealable 글로우 `DispelGlow.lua`

- [ ] `UNIT_AURA` 이벤트 등록 (전용 frame)
- [ ] `strmatch(unit, "^nameplate")` 필터
- [ ] `C_Timer.After(0, ...)` 1프레임 지연 (Blizzard 버프 프레임 갱신 대기)
- [ ] `C_UnitAuras.GetAuraDataByAuraInstanceID(unit, auraInstanceID)` 로 `isStealable` 확인
- [ ] `EvaluateColorValueFromBoolean(isStealable, 0.7, 0)` 으로 alpha 적용 — 분기 없음
- [ ] `BuffListFrame` 자식 순회 → 글로우 on/off
- [ ] `DebuffListFrame` / `CrowdControlListFrame` → 글로우 강제 Hide (프레임 재활용 방지)
- [ ] 글로우 크기: **`GetWidth/Height` 금지** → 앵커 기반
  - `TOPLEFT -8, 8` / `BOTTOMRIGHT 8, -8`
- [ ] `NAME_PLATE_UNIT_ADDED` 시 즉시 글로우 업데이트

---

## 8. 인터럽트 스킬 갱신 `update_interrupt_spells()`

- [ ] `UnitClassBase("player")` 로 클래스 확인
- [ ] 클래스별 스킬ID 테이블 정의 (ENC interruptMap 참고):
  - DK: 47528 / 전사: 6552 / 술사: 57994 / 도적: 1766
  - 사제: 15487 / 성기사: 96231 / 수도사: 116705 / 마법사: 2139
  - 사냥꾼: 187707, 147362 / 기원사: 351338 / 드루이드: 78675, 106839
  - 악마사냥꾼: 183752 / 흑마: 19647, 89766 등
- [ ] `C_SpellBook.IsSpellKnownOrInSpellBook(spellID)` 확인 후 목록 추가
- [ ] `SPELLS_CHANGED` 이벤트마다 재갱신

---

## 9. 이벤트 목록

| 이벤트 | 처리 |
|--------|------|
| `ADDON_LOADED` | DB 초기화 |
| `PLAYER_LOGIN` | 후킹, 구역 판별, 인터럽트 스킬 갱신, 탱 목록 갱신 |
| `PLAYER_ENTERING_WORLD` | 구역 판별 + 전체 갱신 |
| `ZONE_CHANGED_NEW_AREA` | 구역 판별 + 전체 갱신 |
| `GROUP_ROSTER_UPDATE` | 탱 목록 갱신 + 전체 갱신 |
| `SPELLS_CHANGED` | 인터럽트 스킬 갱신 |
| `SPELL_UPDATE_COOLDOWN` | 인터럽트 테두리 갱신 (전투 중만) |
| `NAME_PLATE_UNIT_ADDED` | 해당 네임플레이트 색상·캐스팅바·글로우 갱신 |
| `NAME_PLATE_UNIT_REMOVED` | `neutral_cache[unit] = nil` |
| `PLAYER_REGEN_ENABLED` | `player_in_combat = false`, 캐스팅바 전체 정리, 전체 갱신 |
| `PLAYER_REGEN_DISABLED` | `player_in_combat = true`, 전체 갱신 |
| `UNIT_THREAT_LIST_UPDATE` | 해당 단일 네임플레이트만 갱신 (고빈도 주의) |
| `UNIT_THREAT_SITUATION_UPDATE` | 전체 네임플레이트 갱신 |
| `PLAYER_FOCUS_CHANGED` | 전체 네임플레이트 갱신 |
| `UNIT_AURA` | 글로우 갱신 (nameplate 유닛만) |

---

## 10. dodo 설정 등록

- [ ] `dodo.RegisterEditModeModuleSetting("NamePlate", {...})` — 마스터 토글
- [ ] 구역 토글 체크박스 (던전/레이드/딜브/오픈월드)
- [ ] 기능별 토글 체크박스 (체력바 색상 / 포커스 / 캐스팅바 / 인터럽트 테두리 / 디스펠 글로우)

---

## 11. dodo.toc 등록

```
# NamePlate
Module/NamePlate/Core.lua        ← 공통 상태 먼저
Module/NamePlate/HealthColor.lua
Module/NamePlate/CastBar.lua
Module/NamePlate/DispelGlow.lua
```

등록 위치: `# Tooltip` 섹션 앞 (독립 모듈, 순서 무관)

---

## Secret Value 체크리스트

- [ ] `UnitThreatSituation` 반환값 → `pcall` 후 사용, `>=` 직접 비교 금지
- [ ] `UnitIsFriend` 반환값 → `pcall(UnitIsFriend, "player", unit)`
- [ ] `BorderShield:IsShown()` → `pcall` + `SetAlphaFromBoolean`
- [ ] 캐스팅바 색 분기 → `EvaluateColorValueFromBoolean` 전용
- [ ] 글로우/테두리 크기 → `GetWidth/Height` 금지, 앵커 사용
- [ ] OnUpdate 비전투 정리 → secret boolean 처리 **전에** 먼저 실행

---

## 결정 필요

- [ ] `/dd debug` 유사 타겟 진단 명령어 필요 여부
