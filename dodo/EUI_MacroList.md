# EllesmereUI 매크로 팩토리 목록

출처: `EUI_MacroFactory.lua` (EllesmereUI 애드온)  
`{n}` = 스펠 ID를 클라이언트 언어로 치환하는 토큰

---

## 범용 매크로 (GENERAL_DEFS)

| 매크로명 | 레이블 | 본문 |
|---|---|---|
| `EUI_Potion` | 포션 | 아이템 체크박스 (Fleeting Light's Potential / Light's Potential / Fleeting Recklessness / Recklessness) — 보유 수량 기준 우선순위 순으로 `/use` |
| `EUI_Health` | 체력 / 회복 (전투 여부 분기) | `/stopcasting` → `/cast [nocombat] Recuperate(1231418)` → `/use [combat] item:271884` → `/use [combat] item:271883` → `/use [combat] item:241304` → `/use [combat] item:241305` |
| `EUI_Food` | 음식 | 아이템 체크박스 (Conjured Mana Bun / Fairbreeze Feast / Silvermoon Soiree Spread / Quel'Danas Rations / Mana Lily Tea / Springrunner Sparkling / Tranquility Bloom Tea / Sanguithorn Tea / Azeroot Tea / Argentleaf Tea / Everspring Water) |
| `EUI_Trinket1` | 장신구 1 | `/use 13` |
| `EUI_Trinket2` | 장신구 2 | `/use 14` |
| `EUI_Focus` | 포커스 지정 | `/focus [@mouseover,exists,nodead] []` (+ 옵션: 자동 마커, 핑, 파티 알림) |

---

## 스펙별 매크로 (SPEC_DEFS)

### 죽음의 기사 (Death Knight)

**공통** (블러드·냉기·부정)

| 매크로명 | 레이블 | 본문 |
|---|---|---|
| `EUI_MindFreeze` | Mind Freeze (포커스) | `/cast [@focus,harm,nodead][] Mind Freeze(47528)` |
| `EUI_Asphyxiate` | Asphyxiate (포커스) | `/cast [@focus,harm,nodead][] Asphyxiate(221562)` |

**블러드** (specID 250)

| 매크로명 | 레이블 | 본문 |
|---|---|---|
| `EUI_DnDCursor` | Death and Decay (커서) | `/cast [@cursor] Death and Decay(43265)` |
| `EUI_GorefiendCursor` | Gorefiend's Grasp (커서) | `/cast [@cursor] Gorefiend's Grasp(108199)` |
| `EUI_AbomLimb` | Abomination Limb (포커스) | `/cast [@focus,harm,nodead][] Abomination Limb(315443)` |

**냉기** (specID 251)

| 매크로명 | 레이블 | 본문 |
|---|---|---|
| `EUI_PFObliterate` | PF Obliterate | `/cast Pillar of Frost(51271)` → `/cast Obliterate(49020)` → `/cast Raise Dead(46584)` |
| `EUI_PFReapersMark` | PF Reaper's Mark | `/cast Pillar of Frost(51271)` → `/cast Reaper's Mark(439843)` → `/cast Raise Dead(46584)` |

**부정** (specID 252)

| 매크로명 | 레이블 | 본문 |
|---|---|---|
| `EUI_DarkTransform` | Dark Transform (포커스) | `/cast [@focus,harm,nodead][] Dark Transformation(63560)` |
| `EUI_PetSwap` | Pet Target Swap | `/cast Leap(91809)` → `/petattack` → `/startattack` |
| `EUI_PetMove` | Pet Move | `/petmoveto` |
| `EUI_PetResummon` | Pet Resummon | `/script PetDismiss()` → `/cast [nopet] Raise Dead(46584)` |

---

### 악마 사냥꾼 (Demon Hunter)

**공통** (황폐·복수·포식자)

| 매크로명 | 레이블 | 본문 |
|---|---|---|
| `EUI_Disrupt` | Disrupt (포커스) | `/cast [@focus,harm,nodead][] Disrupt(183752)` |
| `EUI_ConsumeMagic` | Consume Magic (포커스) | `/cast [@focus,harm,nodead][] Consume Magic(278326)` |
| `EUI_MetaCursor` | Metamorphosis (커서) | `/cast [@cursor] Metamorphosis(191427)` |
| `EUI_SigilFlame` | Sigil of Flame (커서) | `/cast [@cursor] Sigil of Flame(204596)` |
| `EUI_SigilMisery` | Sigil of Misery (커서) | `/cast [@cursor] Sigil of Misery(207684)` |

**황폐** (specID 577)

| 매크로명 | 레이블 | 본문 |
|---|---|---|
| `EUI_TheHunt` | The Hunt (포커스) | `/cast [@focus,harm,nodead][] The Hunt(370965)` |
| `EUI_VRGlide` | Vengeful Retreat & Glide | `/cast Vengeful Retreat(198793)` → `/cast !Glide(131347)` |

**복수** (specID 581)

| 매크로명 | 레이블 | 본문 |
|---|---|---|
| `EUI_InfernalStrike` | Infernal Strike (커서) | `/cast [@cursor] Infernal Strike(189110)` |
| `EUI_SigilChains` | Sigil of Chains (커서) | `/cast [@cursor] Sigil of Chains(202138)` |
| `EUI_SigilSilence` | Sigil of Silence (커서) | `/cast [@cursor] Sigil of Silence(202137)` |

**포식자 — Devourer** (specID 1480, Midnight 신규 스펙)

| 매크로명 | 레이블 | 본문 |
|---|---|---|
| `EUI_VoidMeta` | Void Metamorphosis + 장신구 1 | `/cast Void Metamorphosis(1225789)` → `/use 13` |
| `EUI_ShiftCursor` | Shift (커서) | `/cast [@cursor] Shift(1234796)` |

---

### 드루이드 (Druid)

**공통**

| 매크로명 | 레이블 | 본문 |
|---|---|---|
| `EUI_UrsolVortex` | Ursol's Vortex (커서) | `/cast [@cursor] Ursol's Vortex(102793)` |
| `EUI_Innervate` | Innervate (포커스) | `/cast [@focus,help,nodead][] Innervate(29166)` |
| `EUI_RemoveCorrupt` | Remove Corruption (포커스) | `/cast [@focus,help,nodead][] Remove Corruption(2782)` |

**균형** (specID 102)

| 매크로명 | 레이블 | 본문 |
|---|---|---|
| `EUI_SolarBeam` | Solar Beam (포커스) | `/cast [@focus,harm,nodead][] Solar Beam(78675)` |
| `EUI_ForceOfNature` | Force of Nature (커서) | `/cast [@cursor] Force of Nature(205636)` |
| `EUI_CelestialAlign` | Celestial Alignment (커서) | `/cast [@cursor] Celestial Alignment(194223)` |

**야성** (specID 103) / **수호** (specID 104)

| 매크로명 | 레이블 | 본문 |
|---|---|---|
| `EUI_SkullBash` | Skull Bash (포커스) | `/cast [@focus,harm,nodead][] Skull Bash(106839)` |

**회복** (specID 105)

| 매크로명 | 레이블 | 본문 |
|---|---|---|
| `EUI_Ironbark` | Ironbark (포커스) | `/cast [@focus,help,nodead][] Ironbark(102342)` |
| `EUI_InnervateSelf` | Innervate (자신) | `/cast [@player] Innervate(29166)` |
| `EUI_NSConvoke` | Nature's Swiftness + Convoke | `/cast [nochanneling] Nature's Swiftness(132158)` → `/cast Convoke the Spirits(391528)` → `/cqs` |

---

### 용술사 (Evoker)

**공통**

| 매크로명 | 레이블 | 본문 |
|---|---|---|
| `EUI_CautFlame` | Cauterizing Flame (포커스) | `/cast [@focus,help,nodead][] Cauterizing Flame(374251)` |
| `EUI_RescueCursor` | Rescue (커서) | `/tar [@focus]` → `/cast [@cursor] Rescue(370665)` → `/targetlasttarget` |
| `EUI_RescueToYou` | Rescue (자신에게) | `/tar [@focus]` → `/cast [@player] Rescue(370665)` → `/targetlasttarget` |
| `EUI_SleepWalk` | Sleep Walk (포커스) | `/cast [@focus,harm,nodead][] Sleep Walk(360806)` |

**파멸** (specID 1467)

| 매크로명 | 레이블 | 본문 |
|---|---|---|
| `EUI_Quell` | Quell (포커스) | `/cast [@focus,harm,nodead][] Quell(351338)` |
| `EUI_DragonrageBurst` | Dragonrage + 장신구 1 | `/cast Dragonrage(375087)` → `/use 13` |

**보존** (specID 1468)

| 매크로명 | 레이블 | 본문 |
|---|---|---|
| `EUI_DreamFlight` | Dream Flight (커서) | `/cast [@cursor] Dream Flight(359816)` |

**증강** (specID 1473)

| 매크로명 | 레이블 | 본문 |
|---|---|---|
| `EUI_Quell` | Quell (포커스) | `/cast [@focus,harm,nodead][] Quell(351338)` |
| `EUI_BlistScales` | Blistering Scales (포커스) | `/cast [@focus,help,nodead][] Blistering Scales(360827)` |

---

### 사냥꾼 (Hunter)

**공통**

| 매크로명 | 레이블 | 본문 |
|---|---|---|
| `EUI_CounterMuzzle` | Counter Shot / Muzzle (포커스) | `/cast [@focus,harm,nodead][] Counter Shot(147362)` → `/cast [@focus,harm,nodead][] Muzzle(187707)` |
| `EUI_CancelTurtle` | Aspect of the Turtle 취소/시전 | `/cancelaura Aspect of the Turtle(186265)` → `/cast Aspect of the Turtle(186265)` |
| `EUI_Misdirection` | Misdirection (포커스/펫) | `/cast [@focus,help,nodead][@pet,exists] Misdirection(34477)` |
| `EUI_FreezeTrap` | Freezing Trap (커서) | `/cast [@cursor] Freezing Trap(187650)` |
| `EUI_FlareCursor` | Flare (커서) | `/cast [@cursor] Flare(1543)` |
| `EUI_TarTrap` | Tar Trap (커서) | `/cast [@cursor] Tar Trap(187698)` |
| `EUI_BindingShot` | Binding Shot (커서) | `/cast [@cursor] Binding Shot(109248)` |

**야수** (specID 253)

| 매크로명 | 레이블 | 본문 |
|---|---|---|
| `EUI_RoarSacrifice` | Roar of Sacrifice | `/target [@focus,help,nodead]` → `/cast Roar of Sacrifice(53480)` → `/targetlasttarget` → `/cast [@pet] Misdirection(34477)` |
| `EUI_SpiritMend` | Spirit Mend | `/cast [@target,help,nodead][@mouseover,help,nodead][@player] Spirit Mend(90361)` |

**생존** (specID 255)

| 매크로명 | 레이블 | 본문 |
|---|---|---|
| `EUI_Harpoon` | Harpoon (포커스) | `/cast [@focus,harm,nodead][] Harpoon(190925)` |

---

### 마법사 (Mage)

**공통**

| 매크로명 | 레이블 | 본문 |
|---|---|---|
| `EUI_Counterspell` | Counterspell (포커스) | `/cast [@focus,harm,nodead][] Counterspell(2139)` |
| `EUI_Spellsteal` | Spellsteal (포커스) | `/cast [@focus,harm,nodead][] Spellsteal(30449)` |
| `EUI_RemoveCurse` | Remove Curse (포커스) | `/cast [@focus,help,nodead][] Remove Curse(475)` |

**비전** (specID 62)

| 매크로명 | 레이블 | 본문 |
|---|---|---|
| `EUI_PoMBlast` | Presence of Mind + Arcane Blast | `/cast Presence of Mind(205025)` → `/cast Arcane Blast(30451)` → `/cqs` |

**화염** (specID 63)

| 매크로명 | 레이블 | 본문 |
|---|---|---|
| `EUI_Flamestrike` | Flamestrike (커서) | `/cast [@cursor] Flamestrike(2120)` |
| `EUI_MeteorCursor` | Meteor (커서) | `/cast [@cursor] Meteor(153561)` |

**냉기** (specID 64)

| 매크로명 | 레이블 | 본문 |
|---|---|---|
| `EUI_BlizzardCursor` | Blizzard (커서) | `/cast [@cursor] Blizzard(190356)` |

---

### 수도사 (Monk)

**공통**

| 매크로명 | 레이블 | 본문 |
|---|---|---|
| `EUI_Detox` | Detox (포커스) | `/cast [@focus,help,nodead][] Detox(115450)` |
| `EUI_TigersLust` | Tiger's Lust (포커스) | `/cast [@focus,help,nodead][] Tiger's Lust(116841)` |
| `EUI_RingOfPeace` | Ring of Peace (커서) | `/cast [@cursor] Ring of Peace(116844)` |

**양조** (specID 268)

| 매크로명 | 레이블 | 본문 |
|---|---|---|
| `EUI_SpearHand` | Spear Hand Strike (포커스) | `/cast [@focus,harm,nodead][] Spear Hand Strike(116705)` |
| `EUI_BlackOxStatue` | Black Ox Statue (커서) | `/cast [@cursor] Summon Black Ox Statue(115315)` |

**풍운** (specID 269)

| 매크로명 | 레이블 | 본문 |
|---|---|---|
| `EUI_SpearHand` | Spear Hand Strike (포커스) | `/cast [@focus,harm,nodead][] Spear Hand Strike(116705)` |

**운무** (specID 270)

| 매크로명 | 레이블 | 본문 |
|---|---|---|
| `EUI_LifeCocoon` | Life Cocoon (포커스) | `/cast [@focus,help,nodead][] Life Cocoon(116849)` |
| `EUI_JadeSerpent` | Jade Serpent Statue (커서) | `/cast [@cursor] Summon Jade Serpent Statue(115313)` |

---

### 성기사 (Paladin)

**공통**

| 매크로명 | 레이블 | 본문 |
|---|---|---|
| `EUI_BoFreedom` | Blessing of Freedom (포커스) | `/cast [@focus,help,nodead][] Blessing of Freedom(1044)` |
| `EUI_BoProtection` | Blessing of Protection (포커스) | `/cast [@focus,help,nodead][] Blessing of Protection(1022)` |
| `EUI_DivineShield` | Divine Shield 취소/시전 | `/stopcasting` → `/cancelaura Divine Shield(642)` → `/cast Divine Shield(642)` |
| `EUI_ToTLayOnHands` | Lay on Hands (타겟의 타겟) | `/cast [@targettarget] Lay on Hands(633)` |
| `EUI_Cleanse` | Cleanse (포커스) | `/cast [@focus,help,nodead][] Cleanse(4987)` |
| `EUI_LayOnHands` | Lay on Hands (포커스) | `/cast [@focus,help,nodead][] Lay on Hands(633)` |

**보호** (specID 66) / **징벌** (specID 70)

| 매크로명 | 레이블 | 본문 |
|---|---|---|
| `EUI_Rebuke` | Rebuke (포커스) | `/cast [@focus,harm,nodead][] Rebuke(96231)` |

---

### 사제 (Priest)

**공통**

| 매크로명 | 레이블 | 본문 |
|---|---|---|
| `EUI_DispelMagic` | Dispel Magic (포커스) | `/cast [@focus,harm,nodead][] Dispel Magic(528)` |
| `EUI_PowerInfusion` | Power Infusion (포커스) | `/cast [@focus,help,nodead][] Power Infusion(10060)` |
| `EUI_LeapOfFaith` | Leap of Faith (포커스) | `/cast [@focus,help,nodead][] Leap of Faith(73325)` |
| `EUI_MassDispel` | Mass Dispel (커서) | `/cast [@cursor] Mass Dispel(32375)` |
| `EUI_FeatherSelf` | Angelic Feather (자신) | `/cast [@player] Angelic Feather(121536)` → `/stopspelltarget` |
| `EUI_FeatherCursor` | Angelic Feather (커서) | `/cast [@cursor] Angelic Feather(121536)` → `/stopspelltarget` |
| `EUI_Purify` | Purify (포커스) | `/cast [@focus,help,nodead][] Purify(527)` |

**수양** (specID 256)

| 매크로명 | 레이블 | 본문 |
|---|---|---|
| `EUI_PainSuppress` | Pain Suppression (포커스) | `/cast [@focus,help,nodead][] Pain Suppression(33206)` |
| `EUI_PWBarrier` | PW: Barrier (커서) | `/cast [@cursor] Power Word: Barrier(62618)` |

**신성** (specID 257)

| 매크로명 | 레이블 | 본문 |
|---|---|---|
| `EUI_GuardSpirit` | Guardian Spirit (포커스) | `/cast [@focus,help,nodead][] Guardian Spirit(47788)` |
| `EUI_HWSanctify` | Holy Word: Sanctify (커서) | `/cast [@cursor] Holy Word: Sanctify(34861)` |

**암흑** (specID 258)

| 매크로명 | 레이블 | 본문 |
|---|---|---|
| `EUI_Silence` | Silence (포커스) | `/cast [@focus,harm,nodead][] Silence(15487)` |
| `EUI_PurifyDisease` | Purify Disease (포커스) | `/cast [@focus,help,nodead][] Purify Disease(213634)` |

---

### 도적 (Rogue)

**공통**

| 매크로명 | 레이블 | 본문 |
|---|---|---|
| `EUI_Kick` | Kick (포커스) | `/cast [@focus,harm,nodead][] Kick(1766)` |
| `EUI_TricksOfTrade` | Tricks of the Trade (포커스) | `/cast [@focus,help,nodead][] Tricks of the Trade(57934)` |
| `EUI_DistractCursor` | Distract (커서) | `/cast [@cursor] Distract(1725)` |

**무법** (specID 260)

| 매크로명 | 레이블 | 본문 |
|---|---|---|
| `EUI_GrapplingHook` | Grappling Hook (커서) | `/cast [@cursor] Grappling Hook(195457)` |

**잠행** (specID 261)

| 매크로명 | 레이블 | 본문 |
|---|---|---|
| `EUI_CoupDeGrace` | Coup de Grace + Black Powder | `/cast Coup de Grace(37171)` → `/cast Black Powder(319175)` |
| `EUI_EasyStealth` | Easy Stealth | `/cancelaura [nocombat] Shadow Dance(185313)` → `/cast !Stealth(1784)` |

---

### 주술사 (Shaman)

**공통**

| 매크로명 | 레이블 | 본문 |
|---|---|---|
| `EUI_WindShear` | Wind Shear (포커스) | `/cast [@focus,harm,nodead][] Wind Shear(57994)` |
| `EUI_Purge` | Purge (포커스) | `/cast [@focus,harm,nodead][] Purge(370)` |
| `EUI_CleanseSpirit` | Cleanse Spirit (포커스) | `/cast [@focus,help,nodead][] Cleanse Spirit(51886)` |
| `EUI_WindrushTotem` | Wind Rush Totem (커서) | `/cast [@cursor] Wind Rush Totem(192077)` |
| `EUI_CapacitorTotem` | Capacitor Totem (커서) | `/cast [@cursor] Capacitor Totem(192058)` |

**정기** (specID 262)

| 매크로명 | 레이블 | 본문 |
|---|---|---|
| `EUI_EarthquakeCursor` | Earthquake (커서) | `/cast [@cursor] Earthquake(61882)` |

**고양** (specID 263)

| 매크로명 | 레이블 | 본문 |
|---|---|---|
| `EUI_AutoTotemMove` | Auto Totem Move (토테믹) | `/cast Stormstrike(17364)` → `/cast [@player] Totemic Projection(108287)` |

**복원** (specID 264)

| 매크로명 | 레이블 | 본문 |
|---|---|---|
| `EUI_HealingRain` | Healing Rain (커서) | `/cast [@cursor] Healing Rain(73920)` |
| `EUI_SpiritLink` | Spirit Link Totem (커서) | `/cast [@cursor] Spirit Link Totem(98008)` |

---

### 흑마법사 (Warlock)

**공통** (고통·악마·파멸)

| 매크로명 | 레이블 | 본문 |
|---|---|---|
| `EUI_Shadowfury` | Shadowfury (커서) | `/cast [@cursor] Shadowfury(30283)` |
| `EUI_DemonicGateway` | Demonic Gateway (커서) | `/cast [@cursor] Demonic Gateway(111771)` |
| `EUI_SoulburnHS` | Soulburn + Healthstone | `/cast [known:385899] Soulburn(385899)` → `/use [known:386689] item:224464; item:5512` |

**악마술** (specID 266)

| 매크로명 | 레이블 | 본문 |
|---|---|---|
| `EUI_AxeToss` | Axe Toss / 펠가드 (포커스) | `/cast [@focus,harm,nodead][] Axe Toss(89766)` |

**파멸** (specID 267)

| 매크로명 | 레이블 | 본문 |
|---|---|---|
| `EUI_Havoc` | Havoc (포커스) | `/cast [@focus,harm,nodead][] Havoc(80240)` |
| `EUI_SummonInfernal` | Summon Infernal (커서) | `/cast [@cursor] Summon Infernal(1122)` |
| `EUI_RainOfFire` | Rain of Fire (커서) | `/cast [@cursor] Rain of Fire(5740)` |
| `EUI_Cataclysm` | Cataclysm (커서) | `/cast [@cursor] Cataclysm(152108)` |

---

### 전사 (Warrior)

**공통**

| 매크로명 | 레이블 | 본문 |
|---|---|---|
| `EUI_Pummel` | Pummel (포커스) | `/cast [@focus,harm,nodead][] Pummel(6552)` |
| `EUI_Intervene` | Intervene (포커스) | `/cast [@focus,help,nodead][] Intervene(3411)` |
| `EUI_HeroicLeap` | Heroic Leap (커서) | `/cast [@cursor] Heroic Leap(6544)` |
