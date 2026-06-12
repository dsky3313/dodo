# 참고: Blizzard LootContainer 디자인 코드 학습

`Blizzard_EncounterJournal.xml` 기준 (`1temp/Inspire/wow-ui-source-live/.../Mainline/Blizzard_EncounterJournal.xml`)

## LootContainer 프레임 자체
- Size 345x382, Anchor `BOTTOMRIGHT -5,1` (relativeTo 생략 → infoFrame 기준)
- 우리 achievements `panel` (`infoFrame.model` 기준, TOPLEFT_local=392,-1 ~ BOTTOMRIGHT_local=782,-424) 과 footprint 거의 동일
- `ScrollBox`: Size 345x382, anchor `BOTTOMRIGHT -20,1` (LootContainer 기준, 스크롤바 자리 20px 확보)
- `ScrollBar`: `MinimalScrollBar` 상속, ScrollBox TOPRIGHT(5,-5)/BOTTOMRIGHT(5,5) 앵커
- `filter`/`slotFilter`: `WowStyle1DropdownTemplate` 드롭다운
- `classClearFilter`: 클래스 필터 초기화용 작은 서브프레임

## EncounterItemTemplate (루팅 한 줄, Size 321x45)
- `icon` (42x42), TOPLEFT 2,-2
- BORDER 레이어 — 배경 텍스처 2종 토글:
  - `bossTexture` ← inherits `UI-EJ-DungeonLootFrame`
  - `bosslessTexture` ← inherits `UI-EJ-LootFrame`
  - 둘 다 LEFT 0,0 앵커, **같은 파일 522972** (`UI-EncounterJournalTextures`), TexCoord만 다름
    - bossTexture: UV폭 0.72 (보스 초상화 들어갈 자리 포함)
    - bosslessTexture: UV폭 0.63, UL(0,0.82) BL(0,0.91) UR(0.63,0.82) BR(0.63,0.91)
  - `Blizzard_EncounterJournal.lua` (~190/195줄): 보스 있으면 `bossTexture:Show()/bosslessTexture:Hide()`, 없으면 반대
- OVERLAY: `name`(GameFontNormalMed3, 250x12), `armorType`/`slot`/`boss`(GameFontBlack)
- `IconBorder`/`IconOverlay`/`IconOverlay2`: 기본 hidden

## OnShow 패턴 (rightShadow/encounterTitle)
LootContainer OnShow:
```
EncounterJournal_HideCreatures()
instance:Hide()
info.rightShadow:Show()
EncounterJournal_LootUpdate()
info.encounterTitle:Hide()
```
→ Loot탭도 encounterTitle 숨기고 rightShadow 켬. `AchievementsUI.lua`의 `hide_native_content`/`show_native_content`가 rightShadow 안 건드리고 encounterTitle만 숨기는 현재 방식과 동일 패턴 (정석 확인됨).

## 파일 522972 (`UI-EncounterJournalTextures`)
- `rightShadow`/`leftShadow`와 같은 시트 — 공용 아틀라스에 row 배경/그림자/보더 텍스처가 모두 들어있음

## 우리 업적 row에 적용 시 참고
- 보스 구분 없으니 `bosslessTexture` (`UI-EJ-LootFrame`) 한 종류만 적용 가능
- 파일 522972 + TexCoord UL(0,0.82) BL(0,0.91) UR(0.63,0.82) BR(0.63,0.91), LEFT 0,0 앵커로 행 배경 추가 가능
