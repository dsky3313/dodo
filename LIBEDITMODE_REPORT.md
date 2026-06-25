# LibEditMode 학습 리포트

소스: https://github.com/p3lim-wow/LibEditMode/wiki

---

## 임베딩

### TOC 로드 방식 (2가지 중 하나 선택)

**namespaced 모드 (현재 dodo에 불필요 — LibStub 방식 사용 중):**
```
Libs/LibEditMode/namespaced.lua
Libs/LibEditMode/embed.xml
```

**LibStub 모드 (현재 dodo.toc에 적용된 방식):**
```
Libs/LibEditMode/LibStub/LibStub.lua
Libs/LibEditMode/embed.xml
```

로드 순서: LibStub → embed.xml → 나머지 애드온 파일

### 라이브러리 참조

**namespaced 방식:**
```lua
local _, ns = ...
local LibEditMode = ns.LibEditMode
```

**LibStub 방식:**
```lua
local LibEditMode = LibStub("LibEditMode")
```

---

## 핵심 API

### AddFrame — 커스텀 프레임 등록

```lua
LibEditMode:AddFrame(frame, callback, default, name)
```

| 파라미터 | 타입 | 설명 |
|---|---|---|
| frame | Frame | 등록할 프레임 |
| callback | function | 위치 변경 시 호출: `(frame, layoutName, point, x, y)` |
| default | table | 기본 위치: `{point, x, y}` |
| name | string? | 시스템 이름 (생략 시 frame:GetName()) |

```lua
LibEditMode:AddFrame(myFrame, function(frame, layoutName, point, x, y)
    MyDB[layoutName].point = point
    MyDB[layoutName].x = x
    MyDB[layoutName].y = y
end, { point = "CENTER", x = 350, y = 0 }, "MySystem")
```

### AddFrameSettings — 커스텀 프레임 설정 슬라이더/체크박스 등록

```lua
LibEditMode:AddFrameSettings(frame, settings)
```

설정 변경 시 자동으로 **되돌리기(Revert)** 버튼 활성화, Revert 클릭 시 `set(layoutName, originalValue, true)` 호출 (`fromReset = true`).

### AddSystemSettings — 블리자드 시스템에 설정 추가

```lua
LibEditMode:AddSystemSettings(systemID, settings, subSystemID)
```

| 파라미터 | 타입 | 설명 |
|---|---|---|
| systemID | Enum.EditModeSystem | 블리자드 시스템 ID |
| settings | table | SettingObject 배열 |
| subSystemID | number? | 서브시스템 ID (선택) |

### AddFrameSettingsButtons / AddSystemSettingsButtons

```lua
LibEditMode:AddFrameSettingsButtons(frame, buttons)
LibEditMode:AddSystemSettingsButtons(systemID, buttons, subSystemID)
```

버튼 오브젝트: `{ text = "버튼명", click = function() ... end }`

### EnableFrameSetting / DisableFrameSetting

```lua
LibEditMode:EnableFrameSetting(frame, settingName)
LibEditMode:DisableFrameSetting(frame, settingName)
```

개별 설정 항목 표시/숨김 토글. `settingName`은 SettingObject의 `name` 필드.

### EnableSystemSetting / DisableSystemSetting

```lua
LibEditMode:EnableSystemSetting(systemID, settingName, subSystemID)
LibEditMode:DisableSystemSetting(systemID, settingName, subSystemID)
```

블리자드 시스템용 설정 표시/숨김 토글.

### RefreshFrameSettings

```lua
LibEditMode:RefreshFrameSettings(frame)
```

설정 다이얼로그 강제 갱신.

### AddFrameSettingsButton (deprecated)

```lua
-- 사용 금지 — AddFrameSettingsButtons (복수형) 사용할 것
LibEditMode:AddFrameSettingsButton(frame, button)
```

### 콜백 등록

```lua
LibEditMode:RegisterCallback(event, callback)
```

| 이벤트 | 콜백 시그니처 | 설명 |
|---|---|---|
| `enter` | `()` | 편집모드 진입 |
| `exit` | `()` | 편집모드 종료 |
| `layout` | `(layoutName, layoutIndex)` | 레이아웃 변경 또는 로그인 시 |
| `create` | `(layoutName, layoutIndex, sourceLayoutName)` | 레이아웃 생성 |
| `rename` | `(oldName, newName, layoutIndex)` | 레이아웃 이름 변경 |
| `delete` | `(layoutName)` | 레이아웃 삭제 |

### 조회 메서드

```lua
LibEditMode:GetActiveLayout()        -- 현재 레이아웃 데이터 (서버 로드 후에만 유효)
LibEditMode:GetActiveLayoutName()    -- 현재 레이아웃 이름 문자열 (서버 로드 후에만 유효)
LibEditMode:IsInEditMode()           -- 편집모드 여부 boolean
LibEditMode:GetFrameDefaultPosition(frame)  -- 등록된 기본 위치 {point, x, y}
```

> `GetActiveLayout` / `GetActiveLayoutName`은 서버 로드 완료 전 호출 시 nil 반환. `layout` 콜백에서 사용 권장.

---

## SettingObject 타입

| 필드 | 타입 | 필수 | 설명 |
|---|---|---|---|
| kind | SettingType | ✓ | 설정 종류 |
| name | string | ✓ | 표시 이름 |
| desc | string | | 툴팁 설명 |
| default | any | ✓ | 기본값 |
| get | function | ✓ | `(layoutName) → value` |
| set | function | ✓ | `(layoutName, value, fromReset)` |
| disabled | bool/function | | 비활성화 여부 |
| hidden | bool/function | | 숨김 여부 |

### SettingType 열거값

| 값 | 설명 |
|---|---|
| `LEM.SettingType.Checkbox` | 체크박스 |
| `LEM.SettingType.Slider` | 슬라이더 |
| `LEM.SettingType.Dropdown` | 드롭다운 |
| `LEM.SettingType.Divider` | 구분선 |
| `LEM.SettingType.ColorPicker` | 색상 선택 |
| `LEM.SettingType.Expander` | 접기/펼치기 |

### Slider 추가 필드

| 필드 | 기본값 | 설명 |
|---|---|---|
| minValue | 0 | 최솟값 |
| maxValue | 1 | 최댓값 |
| valueStep | 1 | 스텝 |
| formatter | nil | `(value) → string` |

### Dropdown 추가 필드

| 필드 | 타입 | 설명 |
|---|---|---|
| values | table/function | `{ text, value? }` 배열 — `value` 생략 시 `text` 사용 |
| generator | function | 복잡한 메뉴용 콜백: `(dropdown, rootDescription, settingObject)` |
| multiple | boolean | 다중 선택 여부 |
| height | integer | 메뉴 최대 높이 |

> `values` 또는 `generator` 둘 중 하나는 반드시 필요.

### ColorPicker 추가 필드

| 필드 | 기본값 | 설명 |
|---|---|---|
| hasOpacity | false | 불투명도 슬라이더 표시 여부 |

> `get`/`set`은 ColorMixin 객체를 사용. `hasOpacity` 값에 무관하게 alpha 값은 항상 포함됨.

### Divider 추가 필드

| 필드 | 기본값 | 설명 |
|---|---|---|
| hideLabel | false | 구분선 레이블 숨김 여부 |

### Expander 추가 필드

| 필드 | 기본값 | 설명 |
|---|---|---|
| hideArrow | false | 화살표 아이콘 숨김 여부 |
| expandedLabel | nil | 펼쳐진 상태 레이블 (`collapsedLabel`과 함께 둘 다 지정해야 작동) |
| collapsedLabel | nil | 접힌 상태 레이블 (`expandedLabel`과 함께 둘 다 지정해야 작동) |

---

## dodo 현재 구조 vs LibEditMode 대응

| dodo 현재 API | LibEditMode 대응 | 비고 |
|---|---|---|
| `dodo.EditMode:CreateSystem(name, ...)` | `LibEditMode:AddFrame(frame, cb, default, name)` | 프레임을 직접 생성 후 등록 |
| `dodo.RegisterEditModeSystemSetting(stringName, items)` | `LibEditMode:AddFrameSettings(frame, settings)` | `fromReset`으로 되돌리기 자동 처리 |
| `dodo.RegisterEditModeSystemSetting(numID, items)` | `LibEditMode:AddSystemSettings(systemID, settings)` | 블리자드 시스템 |
| `dodo.RegisterEditModeModuleSetting(...)` | LibEditMode 범위 밖 | dodoEditModePanel 자체 유지 |

### 되돌리기 동작 차이

- **현재 dodo**: 위치만 되돌리기, 설정값 되돌리기 미구현
- **LibEditMode**: `set(layoutName, value, fromReset=true)` 호출로 자동 처리

### layout 기반 저장 구조

LibEditMode는 레이아웃별 독립 저장을 지원:
```lua
-- get/set에 layoutName 전달됨
get = function(layoutName) return MyDB[layoutName].size end,
set = function(layoutName, value, fromReset) MyDB[layoutName].size = value end,
```

dodo는 현재 단일 dodoDB 구조 — 마이그레이션 시 레이아웃별 저장 고려 필요.
