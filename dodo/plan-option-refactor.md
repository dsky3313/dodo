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

### 3단계 — 기존 OptionRegistrations 모듈 마이그레이션 ✅ 완료

> **2025-09 애드온 분할로 모든 활성 모듈이 각자 분할 애드온으로 이동됨.**  
> 각 분할 애드온의 `99 Options.lua`에서 `dodo.RegisterOption` 사용. 완료.

| 분할 애드온 | 카테고리 | RegisterOption 파일 |
|---|---|---|
| `dodoActionbar` | 행동 단축바 | `99 Options.lua:221` |
| `dodoCombat` | 전투 | `99 Options.lua:43` |
| `dodoCursorSpellTracker` | 커서 스펠트래커 | `99 Options.lua:5` |
| `dodoEncounter` | 우두머리 경보 | `99 Options.lua:36` |
| `dodoInterface` | 인터페이스 | `99 Options.lua:47` |
| `dodoProfiles` | 프로필 | `99 Options.lua:62` |
| `dodoQOL` | 편의기능 | `99 Options.lua:33` (Camera/WorldMapIcon/InsDifficulty/KeystoneTimer/TimerReadyCheck/Position 포함) |
| `dodoQOL` | 음성 | `99 ETC/NewLFG.lua:192` |
| `dodoSound` | 음성 | `Audio.lua:176` |
| `dodoUnitframe` | 유닛프레임 | `99 Options.lua:157` |

### 4단계 — 구버전 OptionRegistrations 제거

- [x] `dodo.OptionRegistrations` 전역 테이블 참조 전부 제거 확인
- [x] Option.lua에서 OptionRegistrations 루프 제거
- [x] 2dodo SKILL.md에서 deprecated 섹션 제거
- [x] 최종 `/reload` 전체 설정창 점검

---

### 5단계 — RegisterEditModeModuleSetting → /dd 이관 후 제거 ✅ 완료

> **2025-09 애드온 분할 과정에서 완료.**  
> `dodo.RegisterEditModeModuleSetting` 함수 자체가 dodo 메인 애드온에서 제거됨.  
> 모든 활성 분할 애드온에 해당 함수 호출 없음.

**잔존 구버전 호출 (TOC-disabled — 당장 무해)**
- `Module/00 coming soon/99 Consumeable.lua:494` — `RegisterEditModeModuleSetting`
- `Module/00 coming soon/03 RaidFrame/Anchor.lua:223` — `RegisterEditModeModuleSetting`

**5단계 완료 사항**
- [x] `dodo.RegisterEditModeModuleSetting` 함수 및 `registered_settings` 테이블 제거
- [x] `create_edit_mode_panel()` 내 메뉴 렌더링 코드 제거
- [x] EditMode 패널 관련 모듈 파일 제거 (`Module/09 QOL/Editmode/` 디렉토리 없음)

---

### 6단계 — RegisterEditModeSystemSetting → /dd 이관 후 제거 ✅ 완료

> **2025-09 애드온 분할 과정에서 완료.**  
> `dodo.RegisterEditModeSystemSetting` 함수 자체가 dodo 메인 애드온에서 제거됨.  
> 모든 활성 분할 애드온에 해당 함수 호출 없음.

**잔존 구버전 호출 (TOC-disabled — 당장 무해)**
- `Module/00 coming soon/Short.lua:95` — `RegisterEditModeSystemSetting`

**경로 매핑** (참고용 — 이미 완료)

| EditMode 시스템 | /dd 경로 | order |
|---|---|---|
| `Enum.EditModeSystem.ChatFrame` | `"인터페이스.채팅창"` | 51 |
| `Enum.EditModeSystem.Minimap` | `"인터페이스.미니맵"` | 52 |
| `Enum.EditModeSystem.HudTooltip` | `"인터페이스.툴팁"` | 53 |
| `Enum.EditModeSystem.ObjectiveTracker` | `"편의기능"` | 60 |
| `Enum.EditModeSystem.EncounterEvents` | `"전투.전투일지"` | 41 |
| ActionBar `"N_M"` 형식 | `"전투.행동단축바"` | 42 |
| 커스텀 문자열 (`"Debuff"`, `"Stance"` 등) | 파일별 결정 | — |

**6단계 완료 사항**
- [x] `dodo.RegisterEditModeSystemSetting` 함수 제거
- [x] EditMode 윙 패널 코드 제거 (`Module/09 QOL/Editmode/SystemSettingsPanel.lua` 없음)

---

### 7단계 — 최종 정리

- [ ] `Agents.md` — deprecated `RegisterEditModeModuleSetting`/`RegisterEditModeSystemSetting` 문서 제거
- [ ] `Module/00 coming soon/` 파일들 TOC 활성화 시 RegisterOption으로 전환 필요
  - `99 Consumeable.lua` — `RegisterEditModeModuleSetting` → `dodo.RegisterOption`
  - `Short.lua` — `RegisterEditModeSystemSetting` → `dodo.RegisterOption`
  - `03 RaidFrame/Anchor.lua` — `RegisterEditModeModuleSetting` → `dodo.RegisterOption`
- [ ] 전체 `/reload` + 설정창 모든 섹션 순회 점검
- [ ] `Module/02 Nameplate/` — 별도 옵션 모듈 추가 (나중에)

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

이전 대상:
- [ ] `dodoUnitframe` — PartyFrame 관련 설정 등록

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
- [ ] `dodoCombat/01 ResourceBar/Core.lua` — 마스터토글 + 체크박스/슬라이더 설정

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
- `SetParentInitializer` 사용 모듈: `dodoQOL/99 ETC/NewLFG.lua` 1개뿐 — `buildFn(category)` 그대로 호출 구조라 별도 처리 불필요
- `dodo.EditMode` 시스템(위치 앵커 프레임)은 설정창과 무관 — 별도 판단 대상. 패널만 제거하고 앵커는 존치 가능
