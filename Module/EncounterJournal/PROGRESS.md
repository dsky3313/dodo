# EncounterJournal 작업 진행 상황 (이어서 작업용)

## 1. 완료: 업적 카테고리 그래프 비동기 빌드 (로딩 프리징 완화)

`AchievementsData.lua`에 청크 단위 비동기 빌드 추가 완료.

- `process_graph_task` / `graph_tick` / `complete_graph_build` / `M.request_graph` / `M.cancel_graph_build` 신규 추가
- 기존 row-scan과 동일 패턴: `SCAN_PER_TICK=50`, `TICK_INTERVAL=0.01`, `C_Timer.NewTicker`
- `M.get_graph()`은 진행 중인 비동기 작업이 있으면 동기로 강제 완료(promote-to-sync)
- `M.build_category_graph()`는 후처리를 `finish_graph_build(graph)`로 분리
- `AchievementsUI.lua`의 `preload_achievement_data()` / `ADDON_LOADED` 핸들러에서 `M.get_graph()` → `M.request_graph()`로 변경

상태: 코드 적용 완료. 게임 내 `/reload` 테스트 필요 (프리징 체감 변화 확인).

## 2. 완료: "던전 및 공격대"(168) 카테고리만 남기도록 그래프 프루닝

요청: 업적 카테고리 전체 스캔 대신 "던전 및 공격대" 서브트리만 사용.

- 결론: Blizzard API 한계상 `GetCategoryList()` + `GetCategoryInfo(id)` 풀스캔 자체는 회피 불가 (Blizzard 자체 `AchievementFrameCategories_MakeCategoryList()`도 동일 방식)
- 대신 `finish_graph_build()` 마지막에 `prune_graph_to_dungeons_and_raids(graph)` 추가:
  - `DUNGEONS_AND_RAIDS_CATEGORY_ID = 168` 루트 + 모든 자손만 `keep` 마킹 후 나머지 노드 제거
  - `M._graph` / `M._all_ids` 크기를 ~500-800개 → ~100-200개로 축소
  - `resolve_category_for_instance` 등 `get_all_ids()` 순회하는 fallback 루프 비용 감소
- 스캔 비용 자체는 동일하지만(이미 1번에서 비동기 처리됨), 빌드 후 그래프/all_ids 크기 축소로 후속 조회 비용 감소

상태: 코드 적용 완료, 사용자에게 결과 보고 아직 안 함. `/reload` 테스트 필요.

## 3. 완료(테스트 필요): 업적 → 능력/모델 탭 이동 시 "개요" 요소 재노출 버그

`show_native_content()` (277~324줄)을 `info.tab` 기준으로 분기하도록 재작성 완료.

- Blizzard 소스 `EJ_Tabs` 확인: `1=overviewScroll/overviewTab, 2=LootContainer/lootTab, 3=detailsScroll/bossTab, 4=model/modelTab`
- `EncounterJournal_SetTab` 후크는 Blizzard `SetTab` 실행 **이후** 호출되므로,
  호출 시점에 `info.tab`은 이미 사용자가 클릭한 목표 탭 번호로 갱신돼 있음 → 이를 `target_tab`으로 사용
- `enc.instance`/`_G.InstanceFrameBG`/`enc.overviewFrame`은 Blizzard `EJ_Tabs`에 속하지 않는
  "개요 모드 전용 오버레이"라 `EncounterJournal_SetTab`이 건드리지 않음(소스 확인: `EncounterJournal_ClearDetails`가 `enc.instance:Hide()`,
  `EncounterJournal_DisplayEncounter`가 `overviewFound` 여부로 `enc.overviewFrame` Show/Hide).
  → `target_tab == 1`(overviewTab)일 때만 Show, 그 외엔 Hide
- `enc.infoFrame`(`detailsScroll.child`, 능력 탭 콘텐츠) → `target_tab == 3`일 때만 Show
- `info.model.dungeonBG` → `target_tab == 4`일 때만 Show
- `info.BG`/`info.leftShadow`(종이 배경)는 기존처럼 모든 탭 공통으로 항상 Show 유지
- 마지막 `EncounterJournal_SetTab(native_tab)` 재호출부는 `target_tab`으로 통일, 로직 동일(이미 `has_visible`이면 스킵 → 무한루프 없음)

### 알려진 한계 (의도적으로 미처리)
- `EncounterJournal_DisplayInstance`에서 인스턴스에 "개요" 섹션이 전혀 없는 경우(`overviewFound=false`)
  Blizzard가 `EJ_Tabs[1]`/`EJ_Tabs[3]`의 `frame`을 서로 swap함(1↔detailsScroll, 3↔overviewScroll).
  이 edge case에서는 `target_tab==1`이 실제로는 능력 콘텐츠를 가리킬 수 있어 위 분기가 어긋날 수 있음.
  기존 코드도 이 케이스는 처리 안 했고, 이번 수정 범위 밖으로 둠 (대부분 인스턴스는 개요 섹션 보유).

상태: 코드 적용 완료. 게임 내 `/reload` 후 "업적 → 능력 → 모델 → 업적 → 개요" 등 탭 왕복 테스트 필요.

## 4. 완료(테스트 필요): 업적 탭 활성 중 보스 변경 → 능력 탭 콘텐츠 미표시 버그

### 증상 (3번 수정 후 새로 발견됨)
- 업적 탭 클릭, 로딩 끝난 상태에서 다른 네임드(보스)를 클릭
- 그 상태에서 "능력" 탭을 누르면 능력 콘텐츠가 안 보임
- "업적" 탭을 다시 눌렀다가 요소를 누르면 그제서야 정상 표시됨

### 원인
`activate_custom_tab()`이 `infoFrame.tab = 4`로 점유(모델탭 번호 재사용)하는데,
Blizzard `EncounterJournal_DisplayEncounter()` 마지막 줄
`self.info[EJ_Tabs[self.info.tab].button]:Click()` ("현재 탭 유지")가
`info.tab == 4`이므로 **modelTab:Click()** → `EncounterJournal_SetTab(4)`를 내부적으로 재호출.

이 내부 호출도 dodo의 `hooksecurefunc("EncounterJournal_SetTab", ...)`를 그대로 타서
"사용자가 탭을 클릭함"으로 오인 → `is_active`가 `false`로 강제 비활성화됨.
이후 `EncounterJournal_DisplayEncounter` 후크의 `if is_active then refresh_content() end`도
이미 `is_active=false`라 스킵됨 → 업적 탭이 조용히 꺼지고 native modelTab이 활성화된 채로 남음.

이 상태에서 사용자가 진짜로 "능력(bossTab=3)"을 클릭하면 `EncounterJournal_SetTab(3)`은 정상 실행되지만,
이미 `is_active=false`라 dodo 후크가 아무것도 안 함 → `enc.infoFrame`이 (3번 수정으로 인해)
`target_tab!=3`일 때 Hide된 상태 그대로 남아있어 능력 콘텐츠가 안 보임.

### 수정
`AchievementsUI.lua`:
- `wrap_native_display(name)` 추가 (768~781줄): `EncounterJournal_DisplayInstance` / `EncounterJournal_DisplayEncounter`를
  감싸서 실행 구간 동안 `native_display_active = true` 플래그 설정
- `EncounterJournal_SetTab` 후크 조건에 `and not native_display_active` 추가 (791줄)
  → Blizzard 내부 "탭 유지" 재호출로는 `deactivate_custom_tab()` 트리거 안 됨
- `refresh_content()`에 `clear_native_tab_selection()` 추가 (657줄)
  → 내부 SetTab(4) 재호출로 인해 modelTab이 시각적으로 selected 표시되는 것 정리

### 동작 확인 (코드 추적)
1. 업적 탭 활성 중 새 보스 클릭 → `EncounterJournal_DisplayEncounter` 진입, `native_display_active=true`
2. 내부 `modelTab:Click()` → `SetTab(4)` 실행되지만 SetTab 후크는 `native_display_active`로 인해 스킵
3. `DisplayEncounter` 종료, `native_display_active=false`
4. `DisplayEncounter` 후크 실행 → `is_active=true`라 `refresh_content()` 호출
   → `clear_native_tab_selection()` + `hide_native_content()`로 SetTab(4)가 Show한 native 요소 재정리, 업적 패널 유지
5. 이후 사용자가 진짜 "능력" 클릭 → `SetTab(3)` → 후크 정상 동작 → `deactivate_custom_tab()` → `show_native_content()`에서
   `target_tab=3` → `enc.infoFrame:SetShown(true)` → 정상 표시

상태: 코드 적용 완료. 게임 내 `/reload` 후 "업적 탭 → 보스 변경 → 능력 탭" 시나리오 재테스트 필요.

## 5. 완료(테스트 필요): "개요" 요소 겹침 + "능력" 요소 누락/늦은 로딩 (3/4번 수정 부작용)

### 증상 (3, 4번 수정 후에도 반복 발생)
- "개요" 탭 요소들이 겹쳐서 나옴
- "능력" 탭 요소들이 누락되거나 늦게 로딩됨

### 원인 (RefineUI `Modules/EncounterAchievements/UI.lua` 원본과 비교)

3번 수정에서 도입한 `info.tab` 기준 `target_tab` 분기 + `enc.instance`/`_G.InstanceFrameBG` 처리가 범인:

1. **`enc.overviewFrame`/`enc.infoFrame`/`info.model.dungeonBG`는 각각
   `overviewScroll`/`detailsScroll`/`model`의 자식(child)** → 부모가 Hide면 자식 Show 여부 무관하게 화면에 안 나타남.
   부모 Show/Hide는 `EncounterJournal_SetTab`이 관리하므로, 자식은 **무조건 Show해도 안전**(RefineUI도 이렇게 함).
   → 3번에서 추가한 `target_tab==3/4` 조건부 `SetShown()`은 불필요했고,
   `target_tab` 계산이 타이밍상 어긋나는 경우(예: 보스 변경 직후 `info.tab` 갱신 전) "능력 누락/늦은 로딩"의 원인이 됨.
2. **`enc.instance`/`_G.InstanceFrameBG`는 `EJ_Tabs`에 속하지 않는 독립 오버레이** → Blizzard가
   `EncounterJournal_DisplayInstance`(인스턴스 개요, 보스 미선택)/`EncounterJournal_ClearDetails`(보스 선택 시 hide)로
   "인스턴스 개요 모드"와 "보스 선택 모드"를 상호배타적으로 관리함.
   3번 수정은 `target_tab==1`일 때 이를 강제로 다시 `:Show()` 했는데,
   이때 `enc.overviewFrame`(보스별 개요, `overviewScroll` 자식)도 같이 Show되면서
   "인스턴스 개요(`enc.instance`)"와 "보스 개요(`enc.overviewFrame`)"가 동시에 표시 → **"개요" 요소 겹침**.
   RefineUI 원본은 `enc.instance`/`_G.InstanceFrameBG`를 아예 건드리지 않음(hide도 show도 안 함) — Blizzard의
   상호배타 관리를 그대로 신뢰하고, 커스텀 패널이 같은 영역을 덮어 가리는 방식으로 처리.

### 수정
`AchievementsUI.lua`:
- `install_visibility_guards()`: `enc.instance`/`_G.InstanceFrameBG` guard 제거 (211-215줄 부근)
- `hide_native_content()`: `enc.instance:Hide()` / `_G.InstanceFrameBG:Hide()` 제거,
  대신 RefineUI에 있고 dodo엔 없던 `info.rightShadow:Hide()` 추가
- `show_native_content()`: `info.tab` 기준 `target_tab` 분기 전부 제거, RefineUI처럼
  `enc.overviewFrame`/`enc.infoFrame`/`info.model.dungeonBG`/`overviewScroll.child`/`detailsScroll.child`를
  무조건 `:Show()`. `enc.instance`/`_G.InstanceFrameBG`는 아예 참조 안 함. `info.rightShadow:Show()` 추가.
- 마지막 `EncounterJournal_SetTab(native_tab)` 재호출부는 기존 로직(타입 체크 후 호출) 유지

결과적으로 3번에서 작성한 tab-branching은 전부 되돌리고, "3-구버전"(아래) + RefineUI 방식으로 재정렬됨.
4번(`native_display_active` / `clear_native_tab_selection`) 수정은 이 변경과 독립적이라 유지.

### 알려진 한계 (RefineUI 원본과 공유, 회귀 아님)
업적 탭 활성화 직전이 "인스턴스 개요(보스 미선택) 모드"였던 경우 (`enc.instance` 표시 중),
업적 비활성화 후 "개요" 탭으로 복귀하면 `enc.instance`(인스턴스 일러스트)와 `enc.overviewFrame`(직전 보스의 개요, stale)이
동시에 Show 상태일 수 있음. 이는 dodo가 손대지 않아도 발생 가능한 Blizzard 자체 동작이며,
RefineUI 원본도 동일한 한계를 가짐 — 재현되면 별도 항목으로 다룰 것.

상태: 코드 적용 완료. 게임 내 `/reload` 후 "개요 겹침" / "보스 변경 후 능력 탭" 시나리오 재테스트 필요.

## 6. 완료(테스트 필요): "개요(인스턴스 대문)" → "업적" 전환 시 개요 요소 겹침 (5번 "알려진 한계" 해결)

### 증상
- 보스 미선택 상태("던전 대문" / 인스턴스 개요 화면)에서 "업적" 탭 클릭 시
  `enc.instance`(`EncounterJournalEncounterFrameInstanceFrame`, 던전 일러스트/설명)가 사라지지 않고
  업적 패널과 겹쳐 표시됨.
- `/fstack`으로 확인 (`1.png`): `EncounterJournalEncounterFrameInstanceFrame80`이 업적 패널 위/아래로 잔존.

### 원인
5번 수정에서 "업적→개요" 겹침(인스턴스 개요 + 보스 개요 동시 노출)을 막기 위해
`enc.instance`/`_G.InstanceFrameBG`를 `hide_native_content()`/`show_native_content()`에서 아예 제거함.
그 결과 "개요(보스 미선택)→업적" 방향에서 `enc.instance`가 그대로 남는 회귀 발생 (5번 "알려진 한계"에 명시된 케이스).

참고: `_G.InstanceFrameBG`는 Blizzard Mainline 소스(`Blizzard_EncounterJournal.lua`) 전체에 정의/참조 없음 — 항상 nil,
nil 가드로 인해 무해한 no-op (실제 동작에 영향 없음).

### 수정
`AchievementsUI.lua`:
- `instance_overview_was_shown` 상태 변수 추가
- `activate_custom_tab()`: `hide_native_content()` 호출 전 `enc.instance:IsShown()` 값을 `instance_overview_was_shown`에 저장
- `hide_native_content()`: `enc.instance:Hide()` / `_G.InstanceFrameBG:Hide()` 재추가
- `show_native_content()`: `instance_overview_was_shown`이 true이고 **현재 보스 미선택 상태(`journal.encounterID`가 nil)**일 때만
  `enc.instance:Show()` / `_G.InstanceFrameBG:Show()` 복원. 보스가 선택된 상태면 Blizzard `ClearDetails`가 이미
  `enc.instance:Hide()` 처리했으므로 건드리지 않음 → `enc.overviewFrame`과 동시 노출되는 5번의 회귀 재발 방지.
- `install_visibility_guards()`: `enc.instance`에 OnShow 가드 추가 (overviewFrame/infoFrame과 동일 패턴, 깜빡임 방지)

### 검증 포인트
- "개요(인스턴스 대문, 보스 미선택)→업적→개요" 왕복 시 `enc.instance` 겹침 없이 정상 복원되는지
- "업적→개요(보스 선택 상태)" 시 5번에서 고친 "인스턴스 개요+보스 개요 동시 노출" 회귀 없는지
- "업적 활성 중 보스 선택→능력 탭" 시 4번 수정 동작 그대로 유지되는지

상태: 코드 적용 완료. 게임 내 `/reload` 후 위 3개 시나리오 테스트 필요.

## 7. 완료: 업적 탭 클릭 시 렉 완화 (행 데이터 중복조회 제거)

### 배경
"업적" 탭 클릭 → `refresh_content()` → `M.request_rows()` (비동기 청크 빌드, `GetCategoryNumAchievements`/`GetAchievementInfo` 반복) →
완료 후 `populate_rows` → ScrollBox가 보이는 행마다 `init_row` 실행. 이 과정에서 클릭 시점에 체감 렉 발생.

### 수정: `init_row` 중복 `GetAchievementInfo` 호출 제거
- `process_task`(`AchievementsData.lua`)가 `GetAchievementInfo(cid, achIndex)`의 4번째 리턴값(`completed`)을
  `row.completed`로 같이 저장하도록 변경
- `init_row`(`AchievementsUI.lua`)에서 `GetAchievementInfo(aid)` 재호출 제거, `row.completed`/`row.name`/`row.icon`/`row.rewardText` 그대로 사용
- 효과: ScrollBox에 보이는 행(~10~15개)마다 발생하던 추가 API 호출 제거

### 검토했으나 되돌림: 인스턴스/보스 화면 진입 시 행 데이터 프리페치
`EncounterJournal_DisplayInstance`/`DisplayEncounter` 훅에서 `is_active` 무관하게 `M.request_rows()` 미리 호출하는
프리페치 방식 적용해봤으나, 사용자 테스트 결과 "탭 클릭 시 로드"와 체감 렉 차이 없음(렉이 발생 시점만 EJ 오픈/인스턴스
전환 시점으로 옮겨갈 뿐). 사용자 요청으로 되돌림 — 데이터 로드는 기존처럼 **"업적" 탭 클릭 시점**(`activate_custom_tab` →
`refresh_content`)에만 트리거됨, `is_active`일 때만 인스턴스/보스 변경에 반응.

### 미해결/참고
- 카테고리 그래프(`M.request_graph`) promote-to-sync(1번 항목)는 그대로 — `M.get_graph()`가 비동기 빌드 미완료 시
  남은 카테고리를 동기로 강제완료. 업적 탭 클릭 시 그래프 빌드가 안 끝났으면 이 시점에 추가 렉 가능 (별도 조치 안 함)
- `GetAchievementInfo`/`GetCategoryNumAchievements` 자체 비용(텍스처/캐시 미스)은 addon에서 제어 불가
- `M.collect_achievement_ids` / `M.build_rows_from_ids`(`AchievementsData.lua` 487~520줄)는 어디서도 호출 안 되는 죽은 코드 — 이번 수정 범위 밖, 필요시 별도 정리

상태: 코드 적용 완료. 게임 내 `/reload` 후 "업적 탭 클릭 시 체감 렉 감소" 확인 필요 (특히 첫 진입/대형 레이드).

---

## 3-구버전 (참고용, 위 항목으로 대체됨): 업적 → 능력/모델 탭 이동 시 "개요" 요소 재노출 버그

### 증상
- 이전에 "개요 → 업적" 이동 시 개요 요소가 남는 버그는 수정 완료.
- 그런데 "업적 → 능력(bossTab)" 또는 "업적 → 모델(modelTab)"로 이동하면 개요 탭 요소가 다시 나타남.

### 원인 분석 (Blizzard_EncounterJournal Mainline 소스 기준, Explore agent로 확인 완료)

`AchievementsUI.lua`의 `show_native_content()` (현재 277~308줄)이 범인으로 추정:

```lua
local function show_native_content()
    local journal, enc, info = get_encounter_frames()
    if not journal or not enc or not info then return end
    if not journal:IsShown() or not enc:IsShown() then return end

    if info.BG then info.BG:Show() end
    if info.leftShadow then info.leftShadow:Show() end
    if info.model and info.model.dungeonBG then info.model.dungeonBG:Show() end
    if info.overviewScroll and info.overviewScroll.child then info.overviewScroll.child:Show() end
    if info.detailsScroll and info.detailsScroll.child then info.detailsScroll.child:Show() end
    if enc.overviewFrame then enc.overviewFrame:Show() end
    if enc.infoFrame then enc.infoFrame:Show() end
    if enc.instance then enc.instance:Show() end
    if _G.InstanceFrameBG then _G.InstanceFrameBG:Show() end

    local has_visible = (info.overviewScroll and info.overviewScroll:IsShown())
        or (info.detailsScroll and info.detailsScroll:IsShown())
        or (info.LootContainer and info.LootContainer:IsShown())
        or (info.model and info.model:IsShown())
    if has_visible then return end

    if type(_G.EncounterJournal_SetTab) == "function" then
        local native_tab = type(info.tab) == "number" and info.tab
        if not native_tab then
            local ot = info.OverviewTab or info.overviewTab
            if ot then native_tab = ot:GetID() end
        end
        if type(native_tab) == "number" then
            _G.EncounterJournal_SetTab(native_tab)
        end
    end
end
```

**핵심 문제**: `show_native_content()`가 어떤 탭으로 전환하든 상관없이
`enc.overviewFrame`, `enc.infoFrame`, `enc.instance`, `_G.InstanceFrameBG`,
`overviewScroll.child`, `detailsScroll.child`, `info.model.dungeonBG`를
무조건 `:Show()` 함.

Blizzard 소스 확인 결과:

- `EncounterJournal_SetTab(tabType)` (Blizzard_EncounterJournal.lua:2182-2200)는
  `EJ_Tabs` 테이블 (41-46줄) 기준 **`overviewScroll` / `LootContainer` / `detailsScroll` / `model`** 4개 프레임만 Show/Hide.
  - Tab1=overviewScroll/overviewTab, Tab2=LootContainer/lootTab, Tab3=detailsScroll/bossTab, Tab4=model/modelTab
- `enc.overviewFrame` (`= info.overviewScroll.child`), `enc.infoFrame` (`= info.detailsScroll.child`),
  `enc.instance`, `info.model.dungeonBG`, `_G.InstanceFrameBG`는
  **탭 전환과 무관**하게 "인스턴스 개요 모드 vs 특정 보스 모드"에 따라
  `EncounterJournal_DisplayInstance()` / `EncounterJournal_DisplayEncounter()` / `EncounterJournal_ClearDetails()`가 따로 제어함.
  - `enc.instance:Show()`는 `DisplayInstance` (1284줄), `:Hide()`는 `ClearDetails` (2153줄)
  - `enc.overviewFrame` / `enc.infoFrame`은 `DisplayEncounter`에서 `overviewFound` 여부로 조건부 Show/Hide (1387-1394줄)

즉 `show_native_content()`가 이 4개(overviewScroll/LootContainer/detailsScroll/model) 외의
"모드 종속" 요소들까지 일괄 Show 해버려서, 업적→능력/모델 전환 시
개요 모드 잔재(`enc.overviewFrame`, `enc.instance`, `InstanceFrameBG` 등)가 다시 나타남.

### 미해결 설계 이슈

1. `enc.infoFrame = info.detailsScroll.child`는 Blizzard 매핑상 사실 "능력(Abilities) 탭"의 콘텐츠 프레임임.
   → 지금 `show_native_content()`/`hide_native_content()`가 `overviewFrame`과 `infoFrame`을 항상 대칭으로 같이 Show/Hide 하고 있는데,
   이게 맞는지 재검토 필요. (능력 탭으로 갈 때는 `infoFrame`은 보여야 하고 `overviewFrame`만 숨겨야 할 수도)
2. `_G.InstanceFrameBG`가 실제 Blizzard 전역 프레임으로 존재하는지 미검증
   (Explore agent가 소스에서 못 찾음). dodo 코드에서 참조 중이나 출처 불명 - 실제 게임에서 존재 여부 확인 필요.

### 다음 작업 방향 (제안)

`show_native_content()`를 "어떤 탭으로 가는지"에 따라 분기하도록 수정:

- 목표 탭이 **업적(커스텀 탭)** → 기존 로직 유지 (모든 native 요소 hide, 커스텀 패널만 표시) - 이건 이미 동작 중
- 목표 탭이 **overviewTab** → `enc.overviewFrame`, `enc.instance`, `InstanceFrameBG`, `overviewScroll.child` 등 개요 요소 Show
- 목표 탭이 **bossTab(능력)** → `enc.infoFrame`(`detailsScroll.child`) Show, `enc.overviewFrame`/`enc.instance`/`InstanceFrameBG`는 Hide (또는 손대지 않음 - Blizzard `SetTab`이 `detailsScroll` 자체는 처리하므로 `child`만 신경쓰면 됨)
- 목표 탭이 **modelTab(모델)** → `model.dungeonBG`만 Show, 나머지 개요/능력 요소는 Hide

→ 결국 "탭별로 필요한 최소 요소만 Show, 나머지는 손대지 않거나 명시적으로 Hide" 방식으로 재작성 필요.
실제 변경 전에 게임 내에서 `enc.overviewFrame`, `enc.infoFrame`, `enc.instance`, `_G.InstanceFrameBG`,
`info.model.dungeonBG`가 각 탭(개요/능력/모델) 전환 시 실제로 어떻게 동작하는지
`/dump` 또는 디버그 print로 한번 확인해보는 것도 고려.

## 참고 파일 경로
- `Module/EncounterJournal/AchievementsData.lua`
- `Module/EncounterJournal/AchievementsUI.lua` (특히 191-310줄 근처: `install_visibility_guards`, `hide_native_content`, `show_native_content`)
- Blizzard 원본: `1temp/Inspire/wow-ui-source-live/wow-ui-source-live/Interface/AddOns/Blizzard_EncounterJournal/Mainline/Blizzard_EncounterJournal.lua`
  - `EJ_Tabs` (41-46줄), `EncounterJournal_SetTab` (2182-2200줄), `EncounterJournal_DisplayInstance` (1202-1305줄),
    `EncounterJournal_DisplayEncounter` (1307-1410줄), `EncounterJournal_ClearDetails` (2153줄)
- 참고 스샷: `1.png` (업적 카테고리 "던전 및 공격대" 위치)
