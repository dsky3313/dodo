-- ==============================
-- PartyTracker 주문 데이터 (원본: H3ndallPartyCds SpellData.lua ← KiraUI PartyCDs)
-- ==============================
-- dodo 는 입력 양식만 바꿈. 로드 후 ns.PTCData (spells/specs/...) 형태는 원본과 동일 → 엔진 그대로 사용.
--
-- [원본 → dodo 대응표]
--   SPELLS[id] = { cd = N, ... }        → CLASS_SPELLS 항목 { id, 카테고리, 기본ON, cooldown = N, ... }
--   ADDITIONAL[id] = { cd = N, ... }    → 위와 동일 + known = true 직접 기입 (원본은 병합 루프에서 gate = true 자동 부여)
--   SPECS[spec] = { id | { id, 쿨, 충전 } } → CLASS_SPELLS[직업][spec] 항목. 쿨 → specCooldown, 충전 → charges
--   SHARED[직업] = { id... }            → CLASS_SPELLS[직업].shared
--   SPECIALIZED[spec] = { id... }       → CLASS_SPELLS[직업][spec]
--   Append(...) 병합 루프                → 삭제. SPECS 는 CLASS_SPELLS 에서 자동 생성 (아래 빌드 루프)
--   종족 특성 / 장신구 (race / item)     → EXTRA_SPELLS
--   MODS / EXTERNALS / bars / CLASSES / ROLE_SPEC → 원본 양식 그대로
--
-- [필드명 변경]
--   cd   → cooldown   (엔진 수정: 10 PartyCDs.lua sp.cooldown 5곳, 15 SpellList.lua 1곳)
--   gate → known      (주문 필드 + 자동 생성 swap.known. 엔진 수정: 10 PartyCDs.lua sw.known 2곳)
--
-- [dodo 추가]
--   카테고리 상수 CD/DEF/EXT/RAID/UTIL/RES/RACE/ITEM, CAT_ORDER (표시 순서), ns.PTCData.catOrder
--   항목 [2] 카테고리, [3] 기본 ON (엔진 미연결)
--   SPECS 정렬: 카테고리 → 공용(shared) → 특성 → 목록 순서. SPECS 항목에 category / on / at 필드 추가
--   assert: 정의 중복 / 정의 없는 참조 / 같은 특성 내 주문 중복
--
-- [항목 규칙]
--   cooldown 있는 항목 = 주문 정의 (주문당 1번, 감지 필드 buff/zone/selfOnly/... 같이 기입)
--   cooldown 없는 항목 = 다른 특성/공용에서 같은 주문 참조 (카테고리/기본ON/specCooldown/charges 만)
--   모든 특성에 있고 쿨·충전이 같은 주문만 shared. 특성마다 쿨이 다르면 각 특성에 따로 (참조)
--
-- [원본 업데이트 반영 방법]
--   1. 원본 SPELLS/ADDITIONAL 의 주문 정의 변경 → 같은 ID 의 "정의 항목" 필드에 그대로 옮김 (cd → cooldown, gate → known)
--   2. 원본 SPECS/SHARED/SPECIALIZED 의 목록 변경 → 해당 직업/특성 목록에 항목 추가/삭제, 카테고리·기본ON 지정
--   3. 원본 SPECS 의 { id, 쿨, 충전 } → specCooldown / charges
--   4. ADDITIONAL 출신 주문은 known = true 붙이기
--   5. MODS/EXTERNALS/bars 는 원본 블록 그대로 복사
--   6. 주문 이름 주석은 게임 C_Spell.GetSpellName 기준

local _, ns = ...
local tsort, tconcat = table.sort, table.concat

-- ==============================
-- EmmyLua 타입 정의 (dodo)
-- ==============================

---@class PTCSwap 특성에 따라 다른 주문으로 대체/숨김
---@field id number 대체 시 표시할 주문 ID
---@field talents table<number, boolean> 이 특성 중 하나라도 찍었으면 대체 적용
---@field likely? boolean 특성을 못 읽었을 때 "찍었다"고 가정
---@field specs? table<number, boolean> 이 전문화에서만 대체 적용
---@field known? boolean true면 대체가 아니라 "특성 없으면 아이콘 숨김" (known=true 주문은 자동 생성)

---@class PTCFree 다른 주문 사용 시 쿨 초기화 (예: 화신 → 광폭화)
---@field buff number[] 감지할 버프 ID
---@field cast table<number, number> [시전 주문ID] = 초기화 상태 유지 초
---@field filters? table (자동 생성) 오라 센서 필터
---@field sig? string (자동 생성) 센서 시그니처

---@class PTCProc 특성 발동으로 쿨 초기화 (예: Well-Honed)
---@field talent number 필요 특성 ID
---@field cast number[] 발동으로 간주할 시전 주문 ID
---@field casts? table<number, boolean> (자동 생성) cast 의 set

---@class PTCMod 특성 쿨 보정 (rank 곱해서 적용)
---@field [1]? number 필요 특성 ID (없으면 무조건 적용)
---@field add? number 쿨 초 가감
---@field pct? number 쿨 % 가감 (-10 = 10% 감소)
---@field spec? number 이 전문화에서만 적용
---@field likely? boolean 특성 못 읽었을 때 찍었다고 가정

---@class PTCSpell 추적 주문 정의 (키 = 주문 ID)
---@field cooldown number 기본 재사용 대기시간 (초)
---@field buff? number[] 파티원 사용 감지용 버프 ID 목록 (없으면 { 주문ID })
---@field short? number 지속시간이 이 초 이하인 버프만 "사용"으로 인정 (패시브/연장 버프 오탐 방지)
---@field shortIf? number short 판정은 이 특성 찍었을 때만 (안 찍었으면 short 무시)
---@field zone? boolean 범위형: 시전자 말고 다른 파티원 몸에 붙은 버프로도 감지
---@field others? boolean 시전자 본인엔 버프 안 붙음 (외부 생존기: 고통 억제 등) → 대상 쪽에서만 감지
---@field selfOnly? boolean 신뢰할 버프 없음 → 본인만 추적 (게임 쿨 API), 파티원 행에서 제거
---@field known? boolean 특성(주문)을 배운 경우에만 표시. 미습득 시 숨김
---@field charge? boolean 2충전 주문
---@field chargeIf? number 이 특성을 찍었을 때만 2충전 (안 찍었으면 1충전)
---@field cast? number[] 본인 UNIT_SPELLCAST_SUCCEEDED 에서 같은 주문으로 볼 추가 시전 ID (변형 주문)
---@field swap? PTCSwap 특성 기반 대체 주문
---@field fast? boolean 버프가 짧게 붙었다 사라짐 → 오라 변경 후 3프레임 추가로 읽기
---@field free? PTCFree 다른 주문으로 쿨 초기화
---@field proc? PTCProc 특성 발동으로 쿨 초기화
---@field item? number 장신구 아이템 ID (장신구 주문)
---@field deathCut? number 파티원 사망 시 남은 쿨 감소 초 (장신구)
---@field race? string 종족 특성: 종족 토큰
---@field raceID? number 종족 특성: 종족 ID
---@field mods? PTCMod[] (MODS 에서 주입) 특성 쿨 보정
---@field id? number (자동 생성) 주문 ID
---@field sig? string (자동 생성) 버프 센서 시그니처
---@field include? table<number, boolean> (자동 생성) buff 의 set
---@field filters? table (자동 생성) AuraContainer 필터
---@field shortSig? string (자동 생성) short 센서 시그니처
---@field shortFilters? table (자동 생성) short 센서 필터 (maxDuration)
---@field casts? table<number, boolean> (자동 생성) 본인 시전 감지 ID set

---@class PTCClassEntry : PTCSpell CLASS_SPELLS / EXTRA_SPELLS 항목. cooldown 있으면 주문 정의(PTCSpell 필드 포함), 없으면 참조
---@field [1] number 주문ID
---@field [2] PTCCategory 카테고리
---@field [3] boolean 기본 ON
---@field cooldown? number 기본쿨. 있으면 이 항목이 주문 정의 (주문당 1번)
---@field specCooldown? number 이 전문화 기본쿨 (없으면 cooldown)
---@field charges? number 이 전문화 충전 수

---@class PTCSpecEntry SPECS 항목 (CLASS_SPELLS 에서 자동 생성)
---@field [1] number 주문ID
---@field [2]? number 전문화 기본쿨
---@field [3]? number 충전 수
---@field category PTCCategory
---@field on boolean 기본 ON
---@field at number 정렬 보조 (원래 순서)

---@class PTCBarDef 별도 묶음 바 (speed=이동기, guard=공생기)
---@field key string
---@field label string
---@field order number[] 표시 순서
---@field class table<string, number[]> [직업토큰] = 주문 목록
---@field specs? table<number, number> [주문ID] = 이 전문화만 보유
---@field base? table<number, number> [전문화ID] = 기본쿨 보정

-- ==============================
-- dodo: 주문 카테고리 (표시 순서 + 기본 ON/OFF)
-- ==============================
---@alias PTCCategory 'CD'|'DEF'|'EXT'|'RAID'|'UTIL'|'RES'|'RACE'|'ITEM'
local CD, DEF, EXT, RAID = 'CD', 'DEF', 'EXT', 'RAID' -- 딜쿨기, 갠생기, 외생기, 공생기
local UTIL, RES = 'UTIL', 'RES' -- 유틸, 부활·블러드
local RACE, ITEM = 'RACE', 'ITEM' -- 종특, 장신구

-- 표시 순서
---@type PTCCategory[]
local CAT_ORDER = { CD, DEF, EXT, RAID, UTIL, RES, RACE, ITEM }

local CAT_RANK = {}
for i, c in ipairs(CAT_ORDER) do CAT_RANK[c] = i end

local CLASSES = {
	{ token = 'DEATHKNIGHT', specs = { 250, 251, 252 } },
	{ token = 'DEMONHUNTER', specs = { 577, 581, 1480 } },
	{ token = 'DRUID', specs = { 102, 103, 104, 105 } },
	{ token = 'EVOKER', specs = { 1467, 1468, 1473 } },
	{ token = 'HUNTER', specs = { 253, 254, 255 } },
	{ token = 'MAGE', specs = { 62, 63, 64 } },
	{ token = 'MONK', specs = { 268, 269, 270 } },
	{ token = 'PALADIN', specs = { 65, 66, 70 } },
	{ token = 'PRIEST', specs = { 256, 257, 258 } },
	{ token = 'ROGUE', specs = { 259, 260, 261 } },
	{ token = 'SHAMAN', specs = { 262, 263, 264 } },
	{ token = 'WARLOCK', specs = { 265, 266, 267 } },
	{ token = 'WARRIOR', specs = { 71, 72, 73 } },
}

-- ==============================
-- dodo: 직업별 주문 목록 (공용 shared + 특성별)
-- ==============================
-- { 주문ID, 카테고리, 기본ON, cooldown = 기본쿨, <감지 필드>, specCooldown = 전문화 기본쿨, charges = 충전수 }
-- cooldown 있는 항목 = 주문 정의 (주문당 1번). 없는 항목 = 다른 특성에서 같은 주문 참조.
-- 표시 순서는 카테고리(CAT_ORDER) → 공용 → 특성 → 목록 순서로 자동 정렬.
---@type table<string, table<string|number, PTCClassEntry[]>>
local CLASS_SPELLS = {
	DEATHKNIGHT = { -- 죽음의 기사
		shared = { -- 공용
			{ 48792,   DEF,  true,  cooldown = 120 }, -- 얼음같은 인내력
			{ 48707,   DEF,  true,  cooldown = 60,  buff = { 48707, 444741 }, specCooldown = 40 }, -- 대마법 보호막
			{ 49039,   DEF,  true,  cooldown = 120, known = true }, -- 리치의 혼
			{ 48743,   DEF,  true,  cooldown = 120, selfOnly = true, known = true }, -- 죽음의 서약
			{ 51052,   RAID, true,  cooldown = 240, buff = { 51052, 145629 }, zone = true }, -- 대마법 지대
			{ 48265,   UTIL, false, cooldown = 45,  selfOnly = true, charge = true, known = true }, -- 죽음의 진군
			{ 61999,   RES,  false, cooldown = 600, selfOnly = true, known = true }, -- 아군 되살리기
		},
		[250] = { -- 혈기
			{ 49028,   DEF,  true,  cooldown = 120, buff = { 81256 }, short = 10, shortIf = 377668, specCooldown = 90 }, -- 춤추는 룬 무기
			{ 55233,   DEF,  true,  cooldown = 90,  selfOnly = true, known = true }, -- 흡혈
		},
		[251] = { -- 냉기
			{ 51271,   CD,   true,  cooldown = 45 }, -- 얼음 기둥
			{ 47568,   CD,   true,  cooldown = 30,  selfOnly = true, charge = true, known = true }, -- 룬 무기 강화
			{ 1249658, CD,   true,  cooldown = 90,  selfOnly = true, known = true }, -- 신드라고사의 숨결
			{ 279302,  CD,   true,  cooldown = 90,  selfOnly = true, known = true }, -- 서리고룡의 격노
		},
		[252] = { -- 부정
			{ 42650,   CD,   true,  cooldown = 90 }, -- 사자의 군대
			{ 1233448, CD,   true,  cooldown = 45,  selfOnly = true, known = true }, -- 어둠의 변신
		},
	},
	DEMONHUNTER = { -- 악마사냥꾼
		shared = { -- 공용
			{ 196718,  RAID, true,  cooldown = 300, buff = { 209426 } }, -- 어둠
			{ 188501,  UTIL, false, cooldown = 30,  known = true }, -- 영혼 시야
		},
		[577] = { -- 파멸
			{ 191427,  CD,   true,  cooldown = 120, buff = { 162264 }, short = 10 }, -- 탈태
			{ 370965,  CD,   true,  cooldown = 90,  selfOnly = true, known = true }, -- 사냥
			{ 198589,  DEF,  true,  cooldown = 60,  buff = { 212800 }, charge = true, chargeIf = 1266307, specCooldown = 60, charges = 2 }, -- 흐릿해지기
		},
		[581] = { -- 복수
			{ 212084,  CD,   true,  cooldown = 40,  selfOnly = true, known = true }, -- 지옥 황폐
			{ 187827,  DEF,  true,  cooldown = 120 }, -- 탈태
			{ 203720,  DEF,  true,  cooldown = 20,  buff = { 203819 }, charge = true, specCooldown = 20, charges = 2 }, -- 악마 쐐기
			{ 204021,  DEF,  true,  cooldown = 60,  selfOnly = true, charge = true, chargeIf = 389732, known = true, specCooldown = 60, charges = 2 }, -- 불타는 낙인
		},
		[1480] = { -- 포식
			{ 1246167, CD,   true,  cooldown = 90,  selfOnly = true, known = true }, -- 사냥
			{ 198589,  DEF,  true,  specCooldown = 60, charges = 2 }, -- 흐릿해지기
		},
	},
	DRUID = { -- 드루이드
		shared = { -- 공용
			{ 391528,  CD,   true,  cooldown = 120, selfOnly = true, known = true }, -- 영혼 소집
			{ 29166,   UTIL, false, cooldown = 180, zone = true, others = true, known = true }, -- 정신 자극
			{ 106898,  UTIL, false, cooldown = 120, buff = { 106898, 77761, 77764 }, cast = { 77761, 77764 }, zone = true, known = true }, -- 쇄도의 포효
			{ 20484,   RES,  false, cooldown = 600, selfOnly = true, known = true }, -- 환생
		},
		[102] = { -- 조화
			{ 194223,  CD,   true,  cooldown = 180, buff = { 194223, 102560, 390414 }, cast = { 102560, 390414 }, charge = true, chargeIf = 468743, swap = { id = 102560, talents = { [394013] = true }, likely = true }, specCooldown = 120, charges = 2 }, -- 천체의 정렬
			{ 22812,   DEF,  true,  cooldown = 60 }, -- 나무 껍질
		},
		[103] = { -- 야성
			{ 106951,  CD,   true,  cooldown = 180, buff = { 106951, 102543 }, cast = { 102543 }, specCooldown = 90 }, -- 광폭화
			{ 22812,   DEF,  true }, -- 나무 껍질
			{ 61336,   DEF,  true,  cooldown = 180 }, -- 생존 본능
		},
		[104] = { -- 수호
			{ 1253799, CD,   true,  cooldown = 60,  known = true }, -- 분리의 포효
			{ 1252871, CD,   true,  cooldown = 30,  known = true }, -- 붉은 달
			{ 22812,   DEF,  true,  specCooldown = 34 }, -- 나무 껍질
			{ 61336,   DEF,  true,  specCooldown = 137, charges = 2 }, -- 생존 본능
			{ 22842,   DEF,  true,  cooldown = 20,  charge = true, chargeIf = 377811, known = true, free = { buff = { 102558, 50334 }, cast = { [102558] = 30, [50334] = 15 } }, proc = { talent = 377847, cast = { 396425, 382912 } }, specCooldown = 20, charges = 2 }, -- 광포한 재생력
			{ 204066,  DEF,  true,  cooldown = 60,  known = true, specCooldown = 40 }, -- 달 광선
			{ 102558,  DEF,  true,  cooldown = 180, selfOnly = true, known = true }, -- 화신: 우르속의 수호자
		},
		[105] = { -- 회복
			{ 22812,   DEF,  true }, -- 나무 껍질
			{ 102342,  EXT,  true,  cooldown = 90,  zone = true, specCooldown = 70 }, -- 무쇠껍질
			{ 740,     RAID, true,  cooldown = 180, buff = { 740, 157982, 1264623 } }, -- 평온
			{ 33891,   RAID, true,  cooldown = 180, known = true }, -- 화신: 생명의 나무
			{ 132158,  UTIL, false, cooldown = 60,  selfOnly = true, known = true }, -- 자연의 신속함
		},
	},
	EVOKER = { -- 기원사
		shared = { -- 공용
			{ 370553,  CD,   true,  cooldown = 120, selfOnly = true, known = true }, -- 전세역전
			{ 363916,  DEF,  true,  cooldown = 90 }, -- 흑요석 비늘
			{ 374227,  RAID, true,  cooldown = 120, known = true }, -- 미풍
			{ 374968,  UTIL, false, cooldown = 120, zone = true, buff = { 375226, 375229, 375230, 375234, 375238, 375240, 375252, 375253, 375254, 375255, 375256, 375257, 375258 }, known = true }, -- 시간의 와류
			{ 374251,  UTIL, false, cooldown = 60,  selfOnly = true, known = true }, -- 소작의 불길
			{ 370665,  UTIL, false, cooldown = 60,  selfOnly = true, known = true }, -- 구출
			{ 406732,  UTIL, false, cooldown = 180, zone = true, known = true }, -- 공간의 역설
			{ 390386,  RES,  false, cooldown = 300, selfOnly = true, known = true }, -- 위상의 격노
		},
		[1467] = { -- 황폐
			{ 375087,  CD,   true,  cooldown = 120 }, -- 용의 분노
			{ 357210,  CD,   true,  cooldown = 120, selfOnly = true, known = true }, -- 깊은 숨결
		},
		[1468] = { -- 보존
			{ 357210,  CD,   true }, -- 깊은 숨결
			{ 357170,  EXT,  true,  cooldown = 60,  zone = true, charge = true }, -- 시간 팽창
			{ 363534,  RAID, true,  cooldown = 240 }, -- 되돌리기
			{ 359816,  RAID, true,  cooldown = 120, selfOnly = true, known = true }, -- 꿈의 비행
			{ 370537,  RAID, true,  cooldown = 90,  selfOnly = true, known = true }, -- 정지장
		},
		[1473] = { -- 증강
			{ 403631,  CD,   true,  cooldown = 120, cast = { 442204 } }, -- 영겁의 숨결
			{ 404977,  CD,   true,  cooldown = 180, selfOnly = true, known = true }, -- 시간 건너뛰기
		},
	},
	HUNTER = { -- 사냥꾼
		shared = { -- 공용
			{ 186265,  DEF,  true,  cooldown = 180, specCooldown = 120 }, -- 거북의 상
			{ 264735,  DEF,  true,  cooldown = 90 }, -- 적자생존
			{ 109304,  DEF,  true,  cooldown = 120, selfOnly = true, known = true }, -- 활기
			{ 5384,    DEF,  true,  cooldown = 30,  known = true }, -- 죽은 척하기
			{ 53480,   EXT,  true,  cooldown = 120, selfOnly = true, known = true }, -- 희생의 포효
			{ 34477,   UTIL, false, cooldown = 30,  selfOnly = true, known = true }, -- 눈속임
			{ 186257,  UTIL, false, cooldown = 180, known = true }, -- 치타의 상
		},
		[253] = { -- 야수
			{ 19574,   CD,   true,  cooldown = 90,  buff = { 19574, 186254, 1235388, 1285912 }, specCooldown = 30 }, -- 야수의 격노
		},
		[254] = { -- 사격
			{ 288613,  CD,   true,  cooldown = 120 }, -- 정조준
		},
		[255] = { -- 생존
			{ 1250646, CD,   true,  cooldown = 90,  buff = { 1250646, 1251703 } }, -- 제압
			{ 186289,  CD,   true,  cooldown = 90,  known = true }, -- 독수리의 상
		},
	},
	MAGE = { -- 마법사
		shared = { -- 공용
			{ 66,      UTIL, false, cooldown = 300, buff = { 66, 32612, 110960, 113862 }, cast = { 110959 }, swap = { id = 110959, talents = { [110959] = true }, likely = true }, specCooldown = 60 }, -- 투명화
			{ 414664,  UTIL, false, cooldown = 300, selfOnly = true, known = true }, -- 대규모 투명화
			{ 80353,   RES,  false, cooldown = 300, selfOnly = true, known = true }, -- 시간 왜곡
		},
		[62] = { -- 비전
			{ 365350,  CD,   true,  cooldown = 90,  buff = { 365350, 365362 } }, -- 비전 쇄도
			{ 45438,   DEF,  true,  cooldown = 240, buff = { 45438, 414658 }, cast = { 414658 }, swap = { id = 414658, talents = { [414659] = true, [414658] = true }, likely = true }, specCooldown = 150 }, -- 얼음 방패
			{ 342245,  DEF,  true,  cooldown = 60,  buff = { 342246 }, specCooldown = 55 }, -- 시간 돌리기
			{ 235450,  DEF,  true,  cooldown = 30,  charge = true, chargeIf = 321745, known = true, specCooldown = 30, charges = 2 }, -- 오색 방벽
			{ 55342,   DEF,  true,  cooldown = 120, known = true, specCooldown = 60 }, -- 환영 복제
			{ 12051,   UTIL, false, cooldown = 45,  selfOnly = true, known = true }, -- 환기
		},
		[63] = { -- 화염
			{ 190319,  CD,   true,  cooldown = 120, short = 8, specCooldown = 60 }, -- 발화
			{ 45438,   DEF,  true,  specCooldown = 150 }, -- 얼음 방패
			{ 342245,  DEF,  true,  specCooldown = 50 }, -- 시간 돌리기
			{ 55342,   DEF,  true }, -- 환영 복제
			{ 235313,  DEF,  true,  cooldown = 30,  charge = true, chargeIf = 321708, known = true, specCooldown = 30, charges = 2 }, -- 이글거리는 방벽
		},
		[64] = { -- 냉기
			{ 205021,  CD,   true,  cooldown = 60,  selfOnly = true, charge = true, known = true }, -- 서리 광선
			{ 45438,   DEF,  true,  specCooldown = 120 }, -- 얼음 방패
			{ 342245,  DEF,  true,  specCooldown = 50 }, -- 시간 돌리기
			{ 55342,   DEF,  true }, -- 환영 복제
			{ 11426,   DEF,  true,  cooldown = 30,  charge = true, chargeIf = 1244069, known = true, specCooldown = 30, charges = 2 }, -- 얼음 보호막
			{ 235219,  DEF,  true,  cooldown = 300, selfOnly = true, known = true }, -- 매서운 한파
		},
	},
	MONK = { -- 수도사
		shared = { -- 공용
			{ 322109,  CD,   true,  cooldown = 180, selfOnly = true, known = true }, -- 절명의 손길
			{ 116841,  UTIL, false, cooldown = 30,  zone = true, known = true }, -- 범의 욕망
		},
		[268] = { -- 양조
			{ 132578,  CD,   true,  cooldown = 120 }, -- 흑우 니우짜오의 원령
			{ 325153,  CD,   true,  cooldown = 60,  selfOnly = true, known = true }, -- 폭발하는 맥주통
			{ 322507,  DEF,  true,  cooldown = 90,  selfOnly = true, known = true }, -- 천신주
			{ 1241059, DEF,  true,  cooldown = 90,  selfOnly = true, known = true }, -- 천신의 주입
			{ 115399,  DEF,  true,  cooldown = 120, selfOnly = true, known = true }, -- 흑우주
			{ 115203,  DEF,  true,  cooldown = 360, buff = { 115203, 120954 } }, -- 강화주
		},
		[269] = { -- 풍운
			{ 123904,  CD,   true,  cooldown = 120, buff = { 123904, 1248992 } }, -- 백호 쉬엔의 원령
			{ 115203,  DEF,  true,  specCooldown = 90 }, -- 강화주
			{ 122470,  DEF,  true,  cooldown = 90,  buff = { 125174 } }, -- 업보의 손아귀
		},
		[270] = { -- 운무
			{ 443028,  CD,   true,  cooldown = 90,  selfOnly = true, known = true }, -- 천신합일
			{ 115203,  DEF,  true,  specCooldown = 90 }, -- 강화주
			{ 116849,  EXT,  true,  cooldown = 120, zone = true, charge = true, specCooldown = 75 }, -- 기의 고치
			{ 322118,  RAID, true,  cooldown = 120, selfOnly = true, known = true }, -- 옥룡 위론의 원령
			{ 325197,  RAID, true,  cooldown = 120, selfOnly = true, known = true }, -- 주학 츠지의 원령
			{ 115310,  RAID, true,  cooldown = 180, selfOnly = true, known = true }, -- 재활
			{ 388615,  RAID, true,  cooldown = 180, selfOnly = true, known = true }, -- 회복
			{ 116680,  UTIL, false, cooldown = 30,  selfOnly = true, known = true }, -- 집중의 천둥 차
		},
	},
	PALADIN = { -- 성기사
		shared = { -- 공용
			{ 375576,  CD,   true,  cooldown = 60,  selfOnly = true, known = true }, -- 천상의 종
			{ 633,     EXT,  true,  cooldown = 600, selfOnly = true, known = true }, -- 신의 축복
			{ 1044,    UTIL, false, cooldown = 25,  zone = true, known = true }, -- 자유의 축복
			{ 391054,  RES,  false, cooldown = 600, selfOnly = true, known = true }, -- 중재
		},
		[65] = { -- 신성
			{ 31884,   CD,   true,  cooldown = 120, buff = { 31884, 231895, 454351, 216331, 389539 }, cast = { 231895, 216331, 389539 }, swap = { id = 389539, talents = { [389539] = true }, likely = true, specs = { [66] = true } }, specCooldown = 90 }, -- 응징의 격노
			{ 114165,  CD,   true,  cooldown = 45,  selfOnly = true, known = true }, -- 신성한 반사
			{ 642,     DEF,  true,  cooldown = 300, specCooldown = 210 }, -- 천상의 보호막
			{ 498,     DEF,  true,  cooldown = 60,  buff = { 498, 403876 }, cast = { 403876 }, specCooldown = 42 }, -- 신의 가호
			{ 6940,    EXT,  true,  cooldown = 120, zone = true, others = true }, -- 희생의 축복
			{ 1022,    EXT,  true,  cooldown = 300, buff = { 1022, 204018 }, cast = { 204018 }, zone = true, specCooldown = 240 }, -- 보호의 축복
			{ 31821,   RAID, true,  cooldown = 180, known = true }, -- 오라 숙련
		},
		[66] = { -- 보호
			{ 31884,   CD,   true,  specCooldown = 60 }, -- 응징의 격노
			{ 642,     DEF,  true }, -- 천상의 보호막
			{ 31850,   DEF,  true,  cooldown = 90,  specCooldown = 63 }, -- 헌신적인 수호자
			{ 86659,   DEF,  true,  cooldown = 180, charge = true, chargeIf = 1246481, known = true, specCooldown = 180, charges = 2 }, -- 고대 왕의 수호자
			{ 6940,    EXT,  true,  specCooldown = 60 }, -- 희생의 축복
			{ 1022,    EXT,  true }, -- 보호의 축복
		},
		[70] = { -- 징벌
			{ 31884,   CD,   true,  specCooldown = 60 }, -- 응징의 격노
			{ 642,     DEF,  true,  specCooldown = 210 }, -- 천상의 보호막
			{ 498,     DEF,  true,  specCooldown = 63 }, -- 신의 가호
			{ 6940,    EXT,  true,  specCooldown = 60 }, -- 희생의 축복
			{ 1022,    EXT,  true }, -- 보호의 축복
		},
	},
	PRIEST = { -- 사제
		shared = { -- 공용
			{ 10060,   CD,   true,  cooldown = 120, zone = true, known = true }, -- 마력 주입
			{ 586,     DEF,  true,  cooldown = 30,  selfOnly = true, known = true }, -- 소실
			{ 73325,   UTIL, false, cooldown = 90,  selfOnly = true, known = true }, -- 신의의 도약
			{ 32375,   UTIL, false, cooldown = 120, selfOnly = true, known = true }, -- 대규모 무효화
		},
		[256] = { -- 수양
			{ 19236,   DEF,  true,  cooldown = 90 }, -- 구원의 기도
			{ 33206,   EXT,  true,  cooldown = 180, zone = true, charge = true }, -- 고통 억제
			{ 62618,   RAID, true,  cooldown = 180, buff = { 81782 } }, -- 신의 권능: 방벽
			{ 472433,  RAID, true,  cooldown = 90,  selfOnly = true, known = true }, -- 사도
			{ 421453,  RAID, true,  cooldown = 240, selfOnly = true, known = true }, -- 궁극의 참회
		},
		[257] = { -- 신성
			{ 120517,  CD,   true,  cooldown = 60,  selfOnly = true, known = true }, -- 후광
			{ 19236,   DEF,  true,  specCooldown = 70 }, -- 구원의 기도
			{ 47788,   EXT,  true,  cooldown = 180, zone = true, others = true }, -- 수호 영혼
			{ 200183,  RAID, true,  cooldown = 120 }, -- 절정
			{ 64843,   RAID, true,  cooldown = 180, buff = { 64844 }, zone = true, known = true }, -- 천상의 찬가
		},
		[258] = { -- 암흑
			{ 120517,  CD,   true }, -- 후광
			{ 228260,  CD,   true,  cooldown = 120, buff = { 194249 } }, -- 공허의 형상
			{ 19236,   DEF,  true,  specCooldown = 70 }, -- 구원의 기도
			{ 47585,   DEF,  true,  cooldown = 120 }, -- 분산
			{ 15286,   RAID, true,  cooldown = 120 }, -- 흡혈의 선물
		},
	},
	ROGUE = { -- 도적
		shared = { -- 공용
			{ 31224,   DEF,  true,  cooldown = 120 }, -- 그림자 망토
			{ 5277,    DEF,  true,  cooldown = 120 }, -- 회피
			{ 1966,    DEF,  true,  cooldown = 15,  charge = true, chargeIf = 423647, specCooldown = 15, charges = 2 }, -- 교란
			{ 185311,  DEF,  true,  cooldown = 30 }, -- 진홍색 약병
			{ 1856,    UTIL, false, cooldown = 120, buff = { 11327 }, charge = true, fast = true }, -- 소멸
			{ 114018,  UTIL, false, cooldown = 360, selfOnly = true, known = true }, -- 은폐의 장막
		},
		[259] = { -- 암살
			{ 360194,  CD,   true,  cooldown = 120, buff = { 1249810 } }, -- 죽음표식
			{ 385627,  CD,   true,  cooldown = 60,  selfOnly = true, known = true }, -- 왕의 파멸
		},
		[260] = { -- 무법
			{ 13750,   CD,   true,  cooldown = 180, known = true }, -- 아드레날린 촉진
			{ 51690,   CD,   true,  cooldown = 180, selfOnly = true, known = true }, -- 광기의 학살자
			{ 381989,  CD,   true,  cooldown = 360, selfOnly = true, known = true }, -- 도박의 연속
			{ 1277933, UTIL, false, cooldown = 240, selfOnly = true, known = true }, -- 마음가짐
		},
		[261] = { -- 잠행
			{ 121471,  CD,   true,  cooldown = 90 }, -- 어둠의 칼날
			{ 185313,  CD,   true,  cooldown = 20,  selfOnly = true, known = true }, -- 어둠의 춤
		},
	},
	SHAMAN = { -- 주술사
		shared = { -- 공용
			{ 108271,  DEF,  true,  cooldown = 120, specCooldown = 90 }, -- 영혼 이동
			{ 198103,  UTIL, false, cooldown = 180, buff = { 198103, 381755 } }, -- 대지의 정령
			{ 192077,  UTIL, false, cooldown = 120, buff = { 192082 }, zone = true, known = true }, -- 바람 질주 토템
			{ 8143,    UTIL, false, cooldown = 60,  selfOnly = true, known = true }, -- 진동의 토템
			{ 383013,  UTIL, false, cooldown = 120, selfOnly = true, known = true }, -- 독 정화 토템
			{ 378081,  UTIL, false, cooldown = 60,  selfOnly = true, cast = { 443454 }, known = true }, -- 자연의 신속함
			{ 2825,    RES,  false, cooldown = 300, selfOnly = true, known = true }, -- 피의 욕망
			{ 32182,   RES,  false, cooldown = 300, selfOnly = true, known = true }, -- 영웅심
		},
		[262] = { -- 정기
			{ 114050,  CD,   true,  cooldown = 180, buff = { 114050, 1219480 }, short = 10, specCooldown = 120 }, -- 승천
			{ 191634,  CD,   true,  cooldown = 60,  known = true }, -- 폭풍수호자
			{ 79206,   UTIL, false, cooldown = 120, known = true }, -- 영혼나그네의 은총
		},
		[263] = { -- 고양
			{ 114051,  CD,   true,  cooldown = 180, short = 10, specCooldown = 120 }, -- 승천
			{ 384352,  CD,   true,  cooldown = 60,  selfOnly = true, known = true }, -- 파멸의 바람
		},
		[264] = { -- 복원
			{ 98008,   RAID, true,  cooldown = 180, buff = { 325174 } }, -- 정신의 고리 토템
			{ 114052,  RAID, true,  cooldown = 180, selfOnly = true, known = true }, -- 승천
			{ 108280,  RAID, true,  cooldown = 180, selfOnly = true, known = true }, -- 치유의 해일 토템
			{ 79206,   UTIL, false }, -- 영혼나그네의 은총
		},
	},
	WARLOCK = { -- 흑마법사
		shared = { -- 공용
			{ 104773,  DEF,  true,  cooldown = 180 }, -- 영원한 결의
			{ 108416,  DEF,  true,  cooldown = 60,  specCooldown = 45 }, -- 어둠의 서약
			{ 333889,  UTIL, false, cooldown = 180, known = true }, -- 지옥 지배
			{ 48020,   UTIL, false, cooldown = 30,  selfOnly = true, known = true }, -- 악마의 마법진: 순간이동
			{ 20707,   RES,  false, cooldown = 600, selfOnly = true, known = true }, -- 영혼석
		},
		[265] = { -- 고통
			{ 205180,  CD,   true,  cooldown = 120 }, -- 암흑시선 소환
			{ 1257052, CD,   true,  cooldown = 60,  selfOnly = true, known = true }, -- 암흑의 수확
			{ 442726,  CD,   true,  cooldown = 60,  selfOnly = true, known = true }, -- 적개심
		},
		[266] = { -- 악마
			{ 265187,  CD,   true,  cooldown = 60,  buff = { 1276767 } }, -- 악마 폭군 소환
			{ 1276672, CD,   true,  cooldown = 120, selfOnly = true, known = true }, -- 파멸수호병 소환
			{ 1276467, CD,   true,  cooldown = 120, selfOnly = true, known = true }, -- 흑마법서: 지옥 유린자
		},
		[267] = { -- 파괴
			{ 442726,  CD,   true }, -- 적개심
			{ 1122,    CD,   true,  cooldown = 120, buff = { 111685, 266087, 417282 } }, -- 지옥불정령 소환
		},
	},
	WARRIOR = { -- 전사
		shared = { -- 공용
			{ 107574,  CD,   true,  cooldown = 90,  known = true }, -- 투신
			{ 376079,  CD,   false, cooldown = 90,  selfOnly = true, known = true }, -- 용사의 창
			{ 23920,   DEF,  true,  cooldown = 25,  charge = true, specCooldown = 23 }, -- 주문 반사
			{ 202168,  DEF,  false, cooldown = 25,  selfOnly = true, known = true }, -- 예견된 승리
			{ 97462,   RAID, true,  cooldown = 180, buff = { 97463 } }, -- 재집결의 함성
		},
		[71] = { -- 무기
			{ 227847,  CD,   false, cooldown = 90,  selfOnly = true, known = true }, -- 칼날폭풍
			{ 228920,  CD,   true,  cooldown = 90,  selfOnly = true, known = true }, -- 쇠날발톱
			{ 167105,  CD,   true,  cooldown = 45,  selfOnly = true, known = true }, -- 거인의 강타
			{ 118038,  DEF,  true,  cooldown = 120, specCooldown = 108 }, -- 투사의 혼
		},
		[72] = { -- 분노
			{ 227847,  CD,   false, }, -- 칼날폭풍
			{ 1719,    CD,   true,  cooldown = 90 }, -- 무모한 희생
			{ 184364,  DEF,  true,  cooldown = 120, specCooldown = 108 }, -- 격노의 재생력
		},
		[73] = { -- 방어
			{ 228920,  CD,   true }, -- 쇠날발톱
			{ 871,     DEF,  true,  cooldown = 180, known = true }, -- 방패의 벽
			{ 1160,    DEF,  true,  cooldown = 45,  selfOnly = true, known = true }, -- 사기의 외침
			{ 3411,    EXT,  true,  cooldown = 30,  selfOnly = true, known = true }, -- 가로막기
		},
	},
}


-- 종족 특성 / 장신구 (직업 무관)
---@type PTCClassEntry[]
local EXTRA_SPELLS = {
	{ 20594,   RACE, true,  cooldown = 120, buff = { 65116 }, race = 'Dwarf', raceID = 3 }, -- 석화
	{ 265221,  RACE, true,  cooldown = 120, buff = { 265226, 273104 }, race = 'DarkIronDwarf', raceID = 34 }, -- 불꽃피
	{ 58984,   RACE, true,  cooldown = 120, race = 'NightElf', raceID = 4 }, -- 그림자 숨기
	{ 1254339, ITEM, true,  cooldown = 90,  buff = { 1255200 }, zone = true, item = 250255 }, -- 불안정한 지옥심장 수정
	{ 1291894, ITEM, true,  cooldown = 120, buff = { 1307578 }, zone = true, item = 270162, deathCut = 30 }, -- 영혼살무사 의식 그릇
}

-- 정의 항목(cooldown 있음) → SPELLS[주문ID]
---@type table<number, PTCSpell>
local SPELLS = {}
local NOT_SPELL = { specCooldown = true, charges = true }
local function Define(e)
	if e.cooldown == nil then return end
	local id = e[1]
	assert(not SPELLS[id], 'Duplicate cooldown definition: ' .. id)
	local sp = {}
	for k, v in pairs(e) do
		if type(k) == 'string' and not NOT_SPELL[k] then sp[k] = v end
	end
	SPELLS[id] = sp
end
for _, def in pairs(CLASS_SPELLS) do
	for _, list in pairs(def) do
		for _, e in ipairs(list) do Define(e) end
	end
end
for _, e in ipairs(EXTRA_SPELLS) do Define(e) end

-- CLASS_SPELLS → SPECS[전문화ID] (엔진 형식 { 주문ID, 기본쿨, 충전수 } + category/on)
---@type table<number, PTCSpecEntry[]>
local SPECS = {}
for _, class in ipairs(CLASSES) do
	local def = CLASS_SPELLS[class.token]
	for _, spec in ipairs(class.specs) do
		local list, seen = {}, {}
		for _, src in ipairs({ def.shared or {}, def[spec] or {} }) do
			for _, e in ipairs(src) do
				local id = e[1]
				assert(SPELLS[id], 'Missing cooldown definition: ' .. id)
				assert(not seen[id], 'Duplicate spell in spec ' .. spec .. ': ' .. id)
				seen[id] = true
				list[#list + 1] = { id, e.specCooldown, e.charges, category = e[2], on = e[3], at = #list + 1 }
			end
		end
		tsort(list, function(a, b)
			local ra, rb = CAT_RANK[a.category], CAT_RANK[b.category]
			if ra ~= rb then return ra < rb end
			return a.at < b.at
		end)
		SPECS[spec] = list
	end
end

-- [전문화ID] = 외부 생존기 주문 목록
---@type table<number, number[]>
local EXTERNALS = {
	[256] = { 33206 }, [257] = { 47788 }, [105] = { 102342 }, [270] = { 116849 },
	[65] = { 6940, 1022 }, [1468] = { 357170 },
}
ns.PTCExternals = EXTERNALS

for id, sp in pairs(SPELLS) do
	sp.id = id
	if sp.known then sp.swap = { id = id, talents = { [id] = true }, known = true, likely = true } end
	sp.buff = sp.buff or { id }
	tsort(sp.buff)
	sp.sig = tconcat(sp.buff, ',')
	sp.include = {}
	for _, b in ipairs(sp.buff) do sp.include[b] = true end
	sp.filters = { includeSpellIDs = sp.include }
	if sp.short then
		sp.shortSig = sp.sig .. '<' .. sp.short
		sp.shortFilters = { includeSpellIDs = sp.include, maxDuration = sp.short }
	end
	sp.casts = { [id] = true }
	if sp.cast then
		for _, c in ipairs(sp.cast) do sp.casts[c] = true end
	end
	if sp.free then
		local inc = {}
		for _, b in ipairs(sp.free.buff) do inc[b] = true end
		sp.free.filters = { includeSpellIDs = inc }
		sp.free.sig = 'free:' .. tconcat(sp.free.buff, ',')
		for c in pairs(sp.free.cast) do sp.casts[c] = true end
	end
	if sp.proc then
		sp.proc.casts = {}
		for _, c in ipairs(sp.proc.cast) do
			sp.proc.casts[c] = true
			sp.casts[c] = true
		end
	end
end

do
	-- [주문ID] = 특성 쿨 보정 목록
	---@type table<number, PTCMod[]>
	local MODS = {
		[49028] = { { 377637, add = -30 } },
		[48707] = { { 205727, add = -20 }, { 457574, add = 20 } },
		[51052] = { { 374383, add = -60 } },
		[196718] = { { 389783, add = -120 } },
		[194223] = { { 390378, add = -60 }, { 468743, add = -60 } },
		[106951] = { { 391174, add = -60 }, { 391548, add = -30 } },
		[22812] = { { spec = 104, add = -15 }, { 203965, pct = -12 } },
		[61336] = { { 203965, pct = -12 } },
		[102342] = { { 382552, add = -20 } },
		[363534] = { { 381922, add = -60 } },
		[403631] = { { 412713, pct = -10 } },
		[363916] = { { 412713, pct = -10 } },
		[357170] = { { 376204, add = -10 } },
		[19574] = { { 231548, add = -60 } },
		[288613] = { { 260404, add = -30 } },
		[1250646] = { { 1251790, add = -15 } },
		[186265] = { { 266921, add = -15 }, { 1258485, add = -30 } },
		[190319] = { { 1254194, add = -60 } },
		[45438] = { { 382424, add = -30 }, { 1265517, add = -30 }, { 1244110, add = -30 } },
		[342245] = { { 342249, add = -5 }, { 1255166, add = -10 } },
		[132578] = { { 450989, add = -25 } },
		[123904] = { { 392986, add = -30 } },
		[115203] = { { spec = 269, add = -240 }, { spec = 270, add = -240 }, { 388813, add = -30 } },
		[116849] = { { 202424, add = -45 } },
		[31884] = { { spec = 70, add = -60 }, { 1241511, add = -15 }, { 204074, pct = -50 } },
		[642] = { { 114154, pct = -30 }, { 378425, pct = -15 } },
		[498] = { { spec = 70, add = 30 }, { 114154, pct = -30 } },
		[31850] = { { 114154, pct = -30 } },
		[6940] = { { 384820, add = -60 }, { 384820, spec = 65, add = 45 } },
		[1022] = { { 384909, add = -60 }, { 378425, pct = -15 } },
		[19236] = { { 238100, add = -20 } },
		[47585] = { { 288733, add = -30 } },
		[114050] = { { 462440, add = -60 } },
		[114051] = { { 384444, add = -60 } },
		[191634] = { { 468571, add = -15 }, { 454026, add = -15 } },
		[108271] = { { 381647, add = -30 } },
		[1122] = { { 1280483, add = -30 } },
		[104773] = { { 386659, add = -45 } },
		[108416] = { { 386686, add = -15 } },
		[118038] = { { 391271, pct = -10 } },
		[184364] = { { 391271, pct = -10 } },
		[23920] = { { spec = 73, add = -5 }, { 391271, pct = -10 } },
		[31821] = { { 392911, add = -30 } },
		[106898] = { { 288826, add = -60 } },
		[192077] = { { 462791, add = -30 } },
		[66] = { { 110959, add = -180 }, { 210476, add = -60 } },
		[374227] = { { 412713, pct = -10 } },
		[374968] = { { 412713, pct = -10 } },
		[55342] = { { 1244025, add = -30 } },
		[204066] = { { 429539, add = -20 } },
	}
	for id, mods in pairs(MODS) do SPELLS[id].mods = mods end
end

---@type PTCBarDef[]
local bars = {
	{ key = 'speed', label = 'party movespeed bar',
		order = { 106898, 192077, 1044, 116841, 374968 },
		class = { DRUID = { 106898 }, SHAMAN = { 192077 }, PALADIN = { 1044 }, MONK = { 116841 }, EVOKER = { 374968 } },
		base = { [104] = 60 } },
	{ key = 'guard', label = 'party defensives bar',
		order = { 51052, 97462, 196718, 374227, 31821, 62618, 98008, 15286 },
		class = { DEATHKNIGHT = { 51052 }, WARRIOR = { 97462 }, DEMONHUNTER = { 196718 }, EVOKER = { 374227 },
			PALADIN = { 31821 }, PRIEST = { 62618, 15286 }, SHAMAN = { 98008 } },
		specs = { [31821] = 65, [62618] = 256, [98008] = 264, [15286] = 258 },
		base = { [577] = 180, [581] = 180, [1480] = 180, [65] = 150 } },
}
for _, b in ipairs(bars) do
	bars[b.key] = b
	b.who, b.look, b.demo, b.slot, b.count = {}, {}, {}, { tr = {}, n = 0 }, 0
	b.specs = b.specs or {}
	for class, ids in pairs(b.class) do
		for _, id in ipairs(ids) do b.who[id] = class end
	end
end

-- Reserve space for a racial, both trinkets, externals and every auxiliary bar.
-- A fixed ten-icon cap silently discarded the tail of larger catalogues.
local maxSpells = 0
for _, class in ipairs(CLASSES) do
	for _, spec in ipairs(class.specs) do
		local count = #SPECS[spec] + 3 + #(EXTERNALS[spec] or {})
		for _, bar in ipairs(bars) do count = count + #(bar.class[class.token] or {}) end
		maxSpells = math.max(maxSpells, count)
	end
end
for _, bar in ipairs(bars) do maxSpells = math.max(maxSpells, #bar.order) end

local ROLE_SPEC = {
	DEATHKNIGHT = { TANK = 250 },
	DEMONHUNTER = { TANK = 581 },
	DRUID = { TANK = 104, HEALER = 105 },
	EVOKER = { HEALER = 1468 },
	MONK = { TANK = 268, HEALER = 270 },
	PALADIN = { TANK = 66, HEALER = 65 },
	SHAMAN = { HEALER = 264 },
	WARRIOR = { TANK = 73 },
}

-- Reverse lookup shared by preview generation and catalogue consumers.
local SPEC_CLASS = {}
for _, class in ipairs(CLASSES) do
	for _, spec in ipairs(class.specs) do SPEC_CLASS[spec] = class.token end
end

ns.PTCData = {
	spells = SPELLS, specs = SPECS, externals = EXTERNALS, bars = bars,
	classes = CLASSES, roleSpecs = ROLE_SPEC, specClass = SPEC_CLASS, maxSpells = maxSpells,
	catOrder = CAT_ORDER, -- dodo
}
