# dodo 설정 등록 시스템 리팩토링 (v3)

## 목표
모든 모듈 설정을 `/dd` 기본설정창 하나로 통합.  
`dodoEditModePanel` 및 EditMode 윙 패널 모두 점진적 제거.

현재 3개로 분산된 등록 경로 → 1개로:
1. ~~`dodo.OptionRegistrations`~~ → `/dd`
2. ~~`dodo.RegisterEditModeModuleSetting`~~ → `dodoEditModePanel` (마스터 토글) **→ `/dd`로 이관 후 제거**
3. ~~`dodo.RegisterEditModeSystemSetting`~~ → EditMode 윙 패널 (시스템 세부 설정) **→ `/dd`로 이관 후 제거**

---

## 현재 구조 문제점
- 새 모듈 → Option.lua 수정 필수
- `interface_sections` 별도 순서 관리
- 모듈당 3줄 보일러플레이트
- `combat` 카테고리(BloodBrez) Option.lua에 없어 설정창 미표시
- 모듈 마스터 토글은 EditMode 패널에만 존재 — `/dd` 미접근
- 시스템 세부 설정은 EditMode 윙 패널에만 존재 — `/dd` 미접근

---

## 새 API

### `dodo.RegisterOption(path, buildFn, order)` — 단일 통합 API
```lua
-- path: "이름표" | "음성" | "인터페이스.편의기능" | "전투" 등
-- buildFn(category): Checkbox(), DropDown(), Slider() 등 위젯 생성 콜백
-- order: 섹션 정렬 순서
dodo.RegisterOption("전투", function(category)
    Checkbox(category, "enableActionbar", "행동단축바", "", true, update_visual)
end, 40)
```

`RegisterEditModeModuleSetting` 항목은 get/set이 항상 `dodoDB[key]` 패턴이므로  
기존 `Checkbox()` 팩토리로 직접 변환 가능 — 별도 브릿지 API 불필요.

---

## 단계별 체크리스트

### 1단계 — OptionUI.lua: RegisterOption 추가

- [x] `dodo._optionRegistry = {}` 초기화 추가
- [x] `dodo.RegisterOption(path, buildFn, order)` 구현
  - `table.insert(dodo._optionRegistry, { path, build, order })`

### 2단계 — Option.lua: 범용 루프로 교체

- [x] `dodoCreateOptions()` 리팩토링
  - [x] `_optionRegistry`를 order 기준 정렬
  - [x] path 그룹핑 (`.` 있으면 parent subCategory + SectionHeader, 없으면 직접 subCategory)
  - [x] subCategory 캐시 (`subCats[name]`)로 중복 생성 방지
- [x] 하드코딩 제거: `subCategoryAudio/Interface/Nameplate/Commands`, `interface_sections` 상단 선언 제거
- [x] 구버전 `OptionRegistrations` 루프 제거
- [x] `/reload` 테스트

### 3단계 — 기존 OptionRegistrations 모듈 마이그레이션 (25개 파일)

각 파일: `OptionRegistrations` 3줄 → `dodo.RegisterOption(...)` 1줄  
한 파일 수정 후 `/reload` 확인.

**행동 단축바** (order: 1000) -- 나중에 모듈 업데이트할거임
- [x] `Module/01 Actionbar/99 Options.lua`

**이름표** (order: 2000) -- 나중에 모듈 업데이트할거임
<!-- - [ ] `Module/02 Nameplate/Core.lua` -->

**유닛프레임** (order: 3000) -- 나중에 모듈 업데이트할거임
- [x] `Module/03 Unitframe/99 Options.lua` -->

**전투** (order: 4000)
- [x] `Module/04 Combat/99 Options.lua` (order: 4010)
- [x] `Module/04 Combat/02 Debuff/Debuff.lua` (order: 4020)
- [x] `Module/04 Combat/03 BloodBrez.lua` (order: 4030)
- [x] `Module/04 Combat/04 Stance.lua` (order: 4040)

**인터페이스** (order: 5000~5300)
- [x] `Module/05 Interface/99 Options.lua`

**우두머리 경고** (order: 6000)
- [x] `Module/06 Encounter/99 Options.lua`

**커서 스펠트래커** (order: 7000) -- 나중에 모듈 업데이트할거임
- [x] `Module/07 CursorSpellTracker/99 Options.lua` (카테고리 생성 완료)
<!-- - [ ] `Module/07 CursorSpellTracker/CursorSpellTracker.lua` -->

**음성** (order: 8000)
- [x] `Module/08 Sound/Audio.lua`
- [x] `Module/09 QOL/05 ETC/NewLFG.lua`

**편의기능.캐릭터 정보** (order: 9000)
**편의기능.쐐기돌** (order: 9010)
**편의기능.파티모집창** (order: 9020)
**편의기능.NPC 대화창** (order: 9030)
**편의기능.모험안내서** (order: 9040)
**편의기능.편의기능** (order: 9500)
- [ ] `Module/09 QOL/05 ETC/Camera.lua`
- [x] `Module/09 QOL/01 CharacterFrame/Core.lua`
- [x] `Module/09 QOL/ChallengesKeystoneFrame/InsertKeystone.lua`
- [x] `Module/09 QOL/05 ETC/ColorPicker.lua`
- [x] `Module/09 QOL/05 ETC/DeleteNow.lua`
<!-- - [ ] `Module/09 QOL/05 ETC/ExpFilter.lua` --> -- 블리자드 기본기능으로 편입. toc에서 비활성화.
- [x] `Module/09 QOL/05 ETC/Friends.lua`
- [x] `Module/09 QOL/05 ETC/Merchant.lua`
- [x] `Module/09 QOL/05 ETC/PartyKeystone.lua`
- [x] `Module/09 QOL/05 ETC/QuickBobber.lua`
- [x] `Module/09 QOL/05 ETC/Teleport.lua`
- [x] `Module/09 QOL/05 ETC/TimerLFG.lua`
<!-- - [ ] `Module/09 QOL/05 ETC/Token.lua` --> -- 나중에 모듈 업데이트할거임. toc에서 비활성화.
- [x] `Module/09 QOL/05 ETC/WowheadLink.lua`
- [ ] `Module/09 QOL/WorldMap/Icon.lua`
- [ ] `Module/09 QOL/ReadyCheck/Timer.lua`
- [ ] `Module/09 QOL/ReadyCheck/Consumeable.lua`  -- 나중에 모듈 업데이트할거임
- [ ] `Module/09 QOL/ObjectiveTracker/KeystoneTimer.lua`  -- 나중에 모듈 업데이트할거임
- [ ] `Module/09 QOL/05 ETC/InsDifficulty.lua`
- [ ] `Module/09 QOL/Editmode/Position.lua`

**명령어** (order: 9900)
<!-- - [ ] `Module/10 Command/Slash.lua` --> -- 나중에 모듈 업데이트할거임. 일단 보류.

**프로필** (order: 9950)
- [x] `Module/99 Profiles/99 Options.lua`

### 4단계 — 구버전 OptionRegistrations 제거

- [x] `dodo.OptionRegistrations` 전역 테이블 참조 전부 제거 확인 (Nameplate/Token/ExpFilter는 toc 비활성)
- [x] Option.lua에서 OptionRegistrations 루프 제거
- [x] 2dodo SKILL.md에서 deprecated 섹션 제거
- [x] 최종 `/reload` 전체 설정창 점검

---

### 5단계 — RegisterEditModeModuleSetting → /dd 이관 후 제거 (~25개 파일)

`RegisterEditModeModuleSetting` 항목은 `dodo.RegisterOption`으로 직접 교체.  
각 파일 수정 후 `/reload` — EditMode 패널에서 사라지고 `/dd`에 표시되는지 확인.

**전투** (order: 40)
- [ ] `Module/01 Actionbar/01 Core.lua` — `enableActionbar`
- [ ] `Module/04 Combat/03 BloodBrez.lua` — `useBloodBrez` (3단계에서 이미 처리)
- [ ] `Module/04 Combat/02 Debuff/Debuff.lua`
- [x] `Module/05 Interface/01 DamageMeter/Core.lua`
- [ ] `Module/04 Combat/01 ResourceBar/Core.lua`
- [ ] `Module/06 Encounter/01 Core.lua`

**인터페이스** (order: 50)
- [ ] `Module/09 QOL/Editmode/Position.lua`
- [x] `Module/05 Interface/03 Minimap/Core.lua`
- [ ] `Module/03 Unitframe/03 RaidFrame/Anchor.lua`
- [ ] `Module/03 Unitframe/01 UnitFrame/01 Core.lua`
- [ ] `Module/09 QOL/05 ETC/Camera.lua`

**편의기능** (order: 60)
- [ ] `Module/05 Interface/04 Tooltip/Core.lua`
- [ ] `Module/09 QOL/ReadyCheck/Timer.lua`
- [ ] `Module/09 QOL/ReadyCheck/Consumeable.lua`
- [ ] `Module/09 QOL/ObjectiveTracker/KeystoneTimer.lua`
- [ ] `Module/09 QOL/05 ETC/InsDifficulty.lua`
- [ ] `Module/09 QOL/05 ETC/PartyKeystone.lua` (3단계와 중복 → 통합)
- [ ] `Module/04 Combat/04 Stance.lua`

**기타**



**5단계 완료 후**
- [ ] `dodo.RegisterEditModeModuleSetting` 함수 및 `registered_settings` 테이블 제거
- [ ] `create_edit_mode_panel()` 내 메뉴 렌더링 코드 제거 (스크롤 패널 전체)
- [ ] EditMode 패널을 최소화 — "일반설정" 버튼만 남긴 단순 패널로 축소 또는 완전 제거
- [ ] `Module/09 QOL/Editmode/ModuleSettings.lua` 정리

---

### 6단계 — RegisterEditModeSystemSetting → /dd 이관 후 제거 (~35개 파일)

> 복잡도 높음. 5단계 완료 후 진행.

**방식**: `RegisterEditModeSystemSetting` 블록 전체를 `dodo.RegisterOption` 으로 교체.  
items의 get/set 콜백이 단순 `dodoDB[key]` 패턴이면 → `Checkbox()` 직접 사용.  
복잡한 콜백(nil 기본값, 다중 함수 호출 등)이면 → `Settings.RegisterProxySetting` 래핑.  
변수명: `"DODO_SYS_" .. tostring(systemID) .. "_" .. item.name`

**경로 매핑**

| EditMode 시스템 | /dd 경로 | order |
|---|---|---|
| `Enum.EditModeSystem.ChatFrame` | `"인터페이스.채팅창"` | 51 |
| `Enum.EditModeSystem.Minimap` | `"인터페이스.미니맵"` | 52 |
| `Enum.EditModeSystem.HudTooltip` | `"인터페이스.툴팁"` | 53 |
| `Enum.EditModeSystem.ObjectiveTracker` | `"편의기능"` | 60 |
| `Enum.EditModeSystem.EncounterEvents` | `"전투.전투일지"` | 41 |
| ActionBar `"N_M"` 형식 | `"전투.행동단축바"` | 42 |
| 커스텀 문자열 (`"Debuff"`, `"Stance"` 등) | 파일별 결정 | — |

**마이그레이션 대상**

채팅창
- [ ] `Module/05 Interface/02 ChatFrame/URL.lua`
- [ ] `Module/05 Interface/02 ChatFrame/Short.lua`
- [ ] `Module/05 Interface/02 ChatFrame/Font.lua`
- [ ] `Module/05 Interface/02 ChatFrame/GuildButton.lua`

미니맵
- [x] `Module/05 Interface/03 Minimap/Zoom.lua`
- [x] `Module/05 Interface/03 Minimap/Square.lua`
- [x] `Module/05 Interface/03 Minimap/IconAddons.lua`
- [x] `Module/05 Interface/03 Minimap/FPS.lua`
- [x] `Module/05 Interface/03 Minimap/MinimapCoords.lua`

툴팁
- [ ] `Module/05 Interface/04 Tooltip/Color.lua`
- [ ] `Module/05 Interface/04 Tooltip/Icon.lua`
- [ ] `Module/05 Interface/04 Tooltip/StatusBar.lua`
- [ ] `Module/05 Interface/04 Tooltip/ID.lua`
- [ ] `Module/05 Interface/04 Tooltip/Vehicle.lua`

행동단축바
- [ ] `Module/01 Actionbar/04 OverlayCDM.lua`
- [ ] `Module/01 Actionbar/06 OverlayPotion.lua`
- [ ] `Module/01 Actionbar/03 IconColor.lua`
- [ ] `Module/01 Actionbar/02 IconPadding.lua`
- [ ] `Module/01 Actionbar/05 OverlayInterrupt.lua`
- [ ] `Module/01 Actionbar/07 IconText.lua`

전투일지
- [ ] `Module/06 Encounter/05 TimelineColor.lua`
- [ ] `Module/06 Encounter/04 Text.lua`
- [ ] `Module/06 Encounter/03 Sound.lua`

유닛프레임
- [ ] `Module/03 Unitframe/01 UnitFrame/01 Component/01 Power.lua`
- [ ] `Module/03 Unitframe/01 UnitFrame/01 Component/02 Castbar.lua`
- [ ] `Module/03 Unitframe/01 UnitFrame/01 Component/03 Auras.lua`
- [ ] `Module/03 Unitframe/01 UnitFrame/01 Component/04 Absorb.lua`
- [ ] `Module/03 Unitframe/03 RaidFrame/Anchor.lua`
- [ ] `Module/03 Unitframe/02 PartyFrame/AurasHealthColor.lua`
- [ ] `Module/03 Unitframe/02 PartyFrame/Leader.lua`
- [ ] `Module/03 Unitframe/02 PartyFrame/Overshield.lua`
- [ ] `Module/03 Unitframe/02 PartyFrame/SoloMode.lua`

기타 커스텀 시스템
- [ ] `Module/04 Combat/01 ResourceBar/Core.lua` (`"ResourceBar"` → `"전투"`)
- [ ] `Module/05 Interface/01 DamageMeter/Core.lua` (`"전투.딜미터"`)
- [ ] `Module/04 Combat/02 Debuff/Debuff.lua` (`"Debuff"` → `"전투"`)
- [ ] `Module/04 Combat/04 Stance.lua` (`"Stance"` → `"편의기능"`)
- [ ] `Module/09 QOL/05 ETC/FrameOption.lua` (TalkingHeadFrame → `"인터페이스"`)
- [ ] `Module/09 QOL/ObjectiveTracker/Collapse.lua` (→ `"편의기능"`)

---

### 6단계 완료 후
- [ ] `dodo.RegisterEditModeSystemSetting` 함수 제거
- [ ] `Module/09 QOL/Editmode/SystemSettingsPanel.lua` — EditMode 윙 패널 코드 제거 또는 파일 전체 제거
- [ ] `Module/09 QOL/Editmode/SystemSettings.lua` 잔여 코드 정리

---

### 7단계 — 최종 정리

- [ ] `Module/09 QOL/Editmode/ModuleSettings.lua` 잔여 코드 정리
- [ ] `dodo.EditMode` 시스템 자체 존치 여부 재검토 (위치 앵커 기능은 별도 — 설정창과 무관)
- [ ] 전체 `/reload` + 설정창 모든 섹션 순회 점검

---

## 미리보기 프레임 계획

### 배경
Blizzard "공격대창" 설정 페이지에는 `RaidFrameSettingsPreviewFrame`(`CompactUnitFrameTemplate` 버튼)이
설정 항목들 위에 삽입되어 CVar 변경 시 실시간 반영됨.
이를 참고해 dodo 설정 페이지에도 유닛프레임·자원바·액션바 미리보기를 추가한다.

### API 방식
`SettingsPanel:GetLayout(category)` — Option.lua 36번줄에서 이미 사용 중.
`buildFn(category)` 안에서 동일하게 호출 가능 → API 변경 불필요.

**헬퍼 (OptionUI.lua에 추가)**
```lua
function AddPreview(category, templateName, data)
    local layout = SettingsPanel:GetLayout(category)
    if layout then
        layout:AddInitializer(Settings.CreatePanelInitializer(templateName, data or {}))
    end
end
```
`buildFn` 첫 줄에 호출 → 설정 항목들보다 위에 렌더링.

---

### 단계별 구현

#### A. 유닛프레임.파티 (먼저 — 가장 단순)

`RaidFramePreviewTemplate` 그대로 재사용.  
dodo 훅(`CompactUnitFrame_UpdateHealthColor`, `CompactUnitFrame_UpdateAll`, `CompactUnitFrame_SetUnit` 등)이  
이 프레임에도 자동 적용되므로 추가 코드 불필요.

```lua
dodo.RegisterOption("유닛프레임.파티", function(category)
    AddPreview(category, "RaidFramePreviewTemplate")
    Checkbox(category, "useRaidframeAurasHealthColor", ...)
    -- ...
end, 1000)
```

이전 대상 (RegisterEditModeSystemSetting → RegisterOption):
- [ ] `Module/03 Unitframe/02 PartyFrame/AurasHealthColor.lua`
- [ ] `Module/03 Unitframe/02 PartyFrame/Overshield.lua`
- [ ] `Module/03 Unitframe/02 PartyFrame/Leader.lua`
- [ ] `Module/03 Unitframe/02 PartyFrame/SoloMode.lua`

관련 Blizzard 소스:
- `Blizzard_SettingsDefinitions_Frame/Interface.xml` — `RaidFramePreviewTemplate` 정의
- `Blizzard_SettingsDefinitions_Frame/Mainline/InterfaceOverrides.lua` — `CreateRaidFrameSettings()` 구현
- `RaidFramePreviewMixin:OnLoad()` — `CompactUnitFrame_SetUpFrame(self.RaidFrame, DefaultCompactUnitFrameSetup)` + `CompactUnitFrame_SetUnit(self.RaidFrame, "player")`

#### B. 자원바

커스텀 XML 템플릿 신규 작성 필요 (`dodoResourceBarPreviewTemplate`).  
`ResourceBar1`, `ResourceBar2`는 UIParent에 붙어 있어 직접 embed 불가 →  
별도 StatusBar 2개짜리 미리보기 프레임을 템플릿으로 생성.  
슬라이더(바 크기·폰트 크기) `set` 콜백에서 미리보기 프레임도 함께 갱신 필요.

이전 대상:
- [ ] `Module/04 Combat/01 ResourceBar/Core.lua` — RegisterEditModeModuleSetting(마스터토글) + RegisterEditModeSystemSetting(체크박스3·슬라이더3)

#### C. 액션바

복잡도 높음 (N_M 다수, 버튼 오버레이 etc.).  
유닛프레임·자원바 완료 후 판단.

---

### 주의사항 (미리보기)
- `RaidFramePreviewTemplate`은 "player" 유닛 기준 → 파티원 데이터 아님, 외형(체력바 색상 등)만 반영
- `AddPreview`는 `buildFn` 첫 줄에 호출해야 설정 항목 위에 표시됨
- 같은 path에 여러 `dodo.RegisterOption` 등록 시(섹션 분리) 미리보기는 가장 낮은 order 항목에만 추가

---

## 주의사항

- `dodo.RegisterOption`은 `ADDON_LOADED` 전에 호출 → `dodo._optionRegistry` 먼저 초기화 필수
- subCategory는 `dodoCreateOptions()` 시점에 생성 (ADDON_LOADED 이후) — 안전
- 6단계 ProxySetting 변수명 충돌: `"DODO_SYS_"` 접두사 + systemID + item.name 조합
- `SetParentInitializer` 사용 모듈: `Module/09 QOL/05 ETC/NewLFG.lua` 1개뿐 — `buildFn(category)` 그대로 호출 구조라 별도 처리 불필요
- `Module/04 Combat/03 BloodBrez.lua`의 `"combat"` → `"전투"` 확정
- 5단계 `Module/09 QOL/05 ETC/PartyKeystone.lua`는 3단계(`"인터페이스.편의기능"`)와 5단계(`"편의기능"`) 양쪽에 걸침 — 하나로 통합 필요
- 6단계 `Module/06 Encounter/04 Text.lua`는 `RegisterEditModeSystemSetting`을 조건부로 여러 번 호출 — 마이그레이션 시 주의
- 6단계는 복잡도 최고 (ActionBar `"N_M"` 다수, Encounter 중복 등록, 복잡한 get/set) — 5단계 완전 완료 후 시작
- `dodo.EditMode` 시스템(위치 앵커 프레임)은 설정창과 무관 — 별도 판단 대상. 패널만 제거하고 앵커는 존치 가능
