# dodo 멀티-애드온 분리 계획

참고: [EllesmereUI](https://github.com/EllesmereGaming/EllesmereUI)

---

## 개요

현재 dodo는 단일 애드온 폴더(`dodo/`) 안에 모든 모듈이 있음.
EUI 방식은 **각 기능 모듈을 독립적인 WoW 애드온 폴더**로 분리해서 관리.

**장점:**
- 모듈 단위로 WoW 설정창에서 on/off 가능
- 특정 모듈 작업 시 나머지 파일이 시야에서 사라짐
- 모듈 간 의존성이 코드가 아닌 TOC로 명시됨
- 향후 모듈 삭제/추가 범위가 폴더 단위로 깔끔해짐

**단점/주의:**
- `AddOns/` 폴더에 서브폴더가 많아짐 (WoW 애드온 목록에 항목 증가)
- 네임스페이스 공유 패턴 변경 필요 (아래 기술 결정 참고)
- 기존 SavedVariables 마이그레이션 고려 필요

---

## 목표 구조

```
Interface/AddOns/
├── dodo/                          ← 코어 (Libs, Data, Option.lua, Slash.lua)
│   ├── dodo.toc
│   ├── Data/
│   ├── Libs/
│   ├── Module/98 Command/Slash.lua
│   └── Option.lua
│
├── dodo_Actionbar/                ← 01 Actionbar 모듈
│   ├── dodo_Actionbar.toc
│   └── (기존 Module/01 Actionbar/ 파일들 이동)
│
├── dodo_Unitframe/                ← 03 Unitframe 모듈
│   ├── dodo_Unitframe.toc
│   └── (기존 Module/03 Unitframe/ 파일들 이동)
│
├── dodo_Combat/                   ← 04 Combat 모듈
│   ├── dodo_Combat.toc
│   └── (기존 Module/04 Combat/ 파일들 이동)
│
├── dodo_Interface/                ← 05 Interface 모듈
│   ├── dodo_Interface.toc
│   └── (기존 Module/05 Interface/ 파일들 이동)
│
├── dodo_Encounter/                ← 06 Encounter 모듈
│   ├── dodo_Encounter.toc
│   └── (기존 Module/06 Encounter/ 파일들 이동)
│
├── dodo_CursorSpellTracker/       ← 07 CursorSpellTracker 모듈
│   ├── dodo_CursorSpellTracker.toc
│   └── (기존 Module/07 CursorSpellTracker/ 파일들 이동)
│
├── dodo_Sound/                    ← 08 Sound 모듈
│   ├── dodo_Sound.toc
│   └── (기존 Module/08 Sound/ 파일들 이동)
│
├── dodo_QOL/                      ← 09 QOL 모듈
│   ├── dodo_QOL.toc
│   └── (기존 Module/09 QOL/ 파일들 이동)
│
└── dodo_Profiles/                 ← 99 Profiles 모듈
    ├── dodo_Profiles.toc
    └── (기존 Module/99 Profiles/ 파일들 이동)
```

---

## 핵심 기술 결정사항

### 1. 네임스페이스 공유

현재 패턴 (`local addonName, dodo = ...`)은 **같은 TOC에 속한 파일들끼리만** 공유됨.
분리 후 서브 모듈은 다른 TOC에 속하므로 이 방법으로 `dodo` 테이블 접근 불가.

**해결책: 코어에서 전역 노출**

```lua
-- dodo/Option.lua (또는 init 파일) 맨 아래에 추가
_G.dodo = dodo
```

서브 모듈 파일들은:
```lua
-- dodo_Actionbar/99 Options.lua 예시
local addonName, ns = ...
local dodo = _G.dodo  -- 코어 네임스페이스 참조
```

> `dodo.RegisterOption`, `dodo.UI`, `dodo.Colors` 등 모두 동일하게 사용 가능.
> 단, 코어(`dodo`)가 반드시 먼저 로드되어야 하므로 TOC Dependencies 선언 필수.

### 2. SavedVariables

현재 `dodoDB` 하나를 전체 모듈이 공유.
**분리 후에도 동일하게 유지 권장** — 서브 모듈 TOC에 SavedVariables 선언 없이,
코어가 선언한 `dodoDB` 전역에 그냥 접근.

```toml
# dodo.toc
## SavedVariables: dodoDB

# dodo_Actionbar.toc
## Dependencies: dodo
# SavedVariables 선언 없음 → dodoDB 전역에 직접 R/W
```

EUI처럼 모듈별 별도 DB로 쪼개면 기존 저장값 마이그레이션 코드가 필요하므로 비권장.

### 3. TOC 의존성 선언

EUI 패턴 그대로 적용:

```toml
## Dependencies: dodo
```

WoW가 `dodo` 애드온을 `dodo_Actionbar`보다 먼저 로드하도록 보장.

---

## TOC 예시

**코어 `dodo/dodo.toc`** (간소화):
```
## Interface: 120100
## Title: dodo
## SavedVariables: dodoDB

# Libs
Libs/LibEditMode/LibStub/LibStub.lua
Libs/LibEditMode/embed.xml
Libs/oUF/oUF.xml
...

# Data
Data/Colors.lua
Data/Icon.lua
Data/UIUX.xml
Data/UIUX.lua
Data/Dungeons.lua
Data/CDM.lua

# Command / Options
Module/98 Command/Slash.lua
Option.lua
```

**모듈 `dodo_Actionbar/dodo_Actionbar.toc`**:
```
## Interface: 120100
## Title: dodo - 액션바
## Dependencies: dodo

99 Options Preview.lua
99 Options.lua
00 ActionBar.xml
01 Core.lua
02 IconPadding.lua
03 IconColor.lua
04 OverlayCDM.lua
04 OverlayCDMOptions.lua
05 OverlayInterrupt.lua
06 OverlayPotion.lua
07 IconText.lua
```

---

## 단계별 마이그레이션 순서

분리는 **모듈 하나씩** 진행. 한 모듈 /reload 확인 후 다음으로.

```
Phase 0: 코어 준비
  - dodo/Option.lua 맨 아래 _G.dodo = dodo 추가
  - /reload 확인

Phase 1: dodo_Actionbar
  - 폴더 생성, 파일 이동, TOC 작성
  - dodo.toc에서 해당 줄 제거
  - 파일 내 namespace 접근 패턴 수정
  - /reload 확인

Phase 2: dodo_Unitframe
Phase 3: dodo_Combat
Phase 4: dodo_Interface
Phase 5: dodo_Encounter
Phase 6: dodo_CursorSpellTracker
Phase 7: dodo_Sound
Phase 8: dodo_QOL
Phase 9: dodo_Profiles
```

---

## 주의사항

1. **`local addonName, dodo = ...` 패턴 전수 교체 필요**
   서브 모듈 파일 모두 `local dodo = _G.dodo` 방식으로 변경.
   `addonName`도 필요하다면 `"dodo"` 리터럴로 교체.

2. **`ADDON_LOADED` 이벤트 체크**
   서브 모듈에서 `ADDON_LOADED` 이벤트로 자기 자신 체크 시,
   `addonName`이 `"dodo_Actionbar"` 등 새 이름으로 바뀜.

3. **99 Options.lua의 `dodo.RegisterOption` 호출 타이밍**
   코어가 먼저 로드되고 `dodo.RegisterOption`이 준비된 뒤에 서브 모듈이 로드되므로
   Dependencies 선언만 제대로 하면 순서 보장됨.

4. **XML 파일 경로**
   XML 내 `<Script file="..."/>` 경로는 해당 TOC 기준 상대경로 유지됨 → 문제없음.

5. **`oUF` 접근**
   `Libs/oUF`는 코어 TOC에서 로드되고 전역으로 노출되므로 서브 모듈에서 그대로 사용 가능.

---

## 미결정 사항

- `Module/99 Profiles/`는 EditMode 프로필 등 코어 종속성이 강함.
  코어에 합칠지 별도 모듈로 분리할지 추가 검토 필요.
- `Module/08 Sound/Audio.lua`는 파일 1개짜리라 별도 폴더화 실익 낮음.
  코어에 병합 고려.
