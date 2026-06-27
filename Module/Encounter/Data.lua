-- ==============================
-- 설정 및 테이블
-- ==============================
---@diagnostic disable: lowercase-global, param-type-mismatch, redundant-parameter, undefined-field, undefined-global
local addonName, dodo = ...

--[[ TEXT
AOE     = "광역딜",
Frontal = "전방",
Dispel  = "해제",
Adds    = "쫄 등장",

Tank     = "탱커",
Mechanic = "사이페", ]]--

--[[ eventID 매크로
특정 spellID로 역조회:
/run local target=388537 for _,id in ipairs(C_EncounterEvents.GetEventList()) do local i=C_EncounterEvents.GetEventInfo(id) if i and i.spellID==target then print("eventID="..id) end end
]]

---@class EncounterEvent
---@field eventID number
---@field role "Tank"|"Heal"|"Mechanic"|"Adds"|"ETC"|"Other"
---@field sound? "Tank"|"Phase"|"AOE"|"Frontal"|"Mechanic"|"Adds"|"Dispel"|"Interrupt"|"Soak"|"Pool"|"Target"
---@field text? string

---@class EncounterRule
---@field dur number ENCOUNTER_TIMELINE_EVENT_ADDED 시점의 남은 시간(초)
---@field eID number eventID
---@field seq? number 동일 dur 배치 도착 순서

---@class EncounterEntry
---@field events EncounterEvent[]
---@field rules? EncounterRule[]

---@type table<number, EncounterEntry>
dodo.EncounterData = {
    -- 리치왕의 분노
    -- 사론의 구덩이 (mapID 658)
    [1999] = { -- 제련장인 가프로스트
        events = {
            { spellID = 1261546, role = "Tank",     sound = "Tank"  }, -- 광석 파괴자
            { spellID = 1261847, role = "Heal",     sound = "AOE"   }, -- 냉각 발구르기
            { spellID = 1261299, role = "Other",    sound = "Pool" },  -- 사로나이트 던지기
            { spellID = 1262029, role = "Mechanic", sound = "Phase" }, -- 빙하 과잉
        },
        rules = {
            { dur = 7,  eID = 1261299 },
            { dur = 20, eID = 1261546 },
            { dur = 33, eID = 1262029 },
            { dur = 42, eID = 1261847 },
        },
    },
    [2001] = { -- 이크와 크리크
        events = {
            { spellID = 1264363, role = "Mechanic", sound = "Phase" }, -- 이크, 물어뜯어!
            { spellID = 1264027, role = "Other" },                     -- 망령의 이동
            { spellID = 1264336, role = "Heal",     sound = "AOE"   }, -- 역병 배출
            { spellID = 1264287, role = "Tank",     sound = "Tank"  }, -- 역병 강타
            { spellID = 1264453, role = "Mechanic" },                  -- 육중한 집착
        },
        rules = {
            { dur = 11, eID = 1264287 },
            { dur = 19, eID = 1264287, seq = 1 }, { dur = 19, eID = 1264336, seq = 2 },
            { dur = 21, eID = 1264336 },
            { dur = 29, eID = 1264027 },
            { dur = 50, eID = 1264363 },
        },
    },
    [2000] = { -- 스컬지군주 티라누스
        events = {
            { spellID = 1262582, role = "Tank" ,    sound = "Tank"  },  -- 스컬지군주의 낙인
            { spellID = 1263406, role = "Mechanic", sound = "Phase" },  -- 사자의 군대
            { spellID = 1262745, role = "Heal",     sound = "Pool"   }, -- 서릿발 작렬
            { spellID = 1276648, role = "Heal",     sound = "AOE"   },  -- 해골 주입
            { spellID = 1263756, role = "Other",    text = "바닥"   },  -- 망자의 손아귀
            { spellID = 1276948, role = "Other",    sound = "Pool"   },  -- 얼음 탄막
        },
        rules = {
            { dur = 7,  eID = 1262745 },
            { dur = 14, eID = 1262582 },
            { dur = 24, eID = 1263756 },
            { dur = 28, eID = 1262745, seq = 1 }, { dur = 28, eID = 1262582, seq = 2 }, { dur = 28, eID = 1276648, seq = 3 },
            { dur = 52, eID = 1263406 },
            { dur = 12, eID = 1276948 },
        },
    },

    -- 드레노어의 전쟁군주
    -- 하늘탑 (mapID 1209)
    [1698] = { -- 란지트
        events = {
            { eventID = 298, role = "Other" },                     -- 강풍의 쇄도
            { eventID = 299, role = "Heal", sound = "AOE" },                      -- 칼날 뿌리기
            { eventID = 300, role = "Other", sound = "Frontal" },                     -- 바람 차크람
            { eventID = 301, role = "Mechanic", sound = "Phase" }, -- 회전 표창의 회오리
        },
        rules = {
            { dur = 12,     eID = 299 }, { dur = 5,  eID = 298 },
            { dur = 35,     eID = 301 }, { dur = 18, eID = 300 },
            { dur = 20,     eID = 299 }, { dur = 10, eID = 300 },
            { dur = 19.999, eID = 299 },
        },
    },
    [1699] = { -- 아라크나스
        events = {
            { eventID = 302, role = "Tank"    , sound = "Tank"  }, -- 타오르는 강타
            { eventID = 303, role = "Other", text = "선" },                      -- 충전
            { eventID = 304, role = "Heal", sound = "AOE" },                      -- 초신성
        },
        rules = {
            { dur = 5,  eID = 302 }, { dur = 6,  eID = 303 },
            { dur = 10, eID = 302 }, { dur = 15, eID = 302 },
            { dur = 24, eID = 303 }, { dur = 50, eID = 304 },
        },
    },
    [1700] = { -- 루크란
        events = {
            { eventID = 305, role = "Heal", sound = "Adds" },                      -- 태양의 도래
            { eventID = 306, role = "Tank"    , sound = "Tank"  }, -- 타오르는 발톱
            { eventID = 308, role = "Mechanic", sound = "Phase" }, -- 타오르는 깃털
            { eventID = 603, role = "Other" },                     -- 영광의 불꽃
        },
        rules = {
            { dur = 5,  eID = 306 }, { dur = 12, eID = 305 },
            { dur = 38, eID = 308 }, { dur = 12, eID = 306 },
            { dur = 21, eID = 305 },
        },
    },
    [1701] = { -- 대현자 비릭스
        events = {
            { eventID = 309, role = "Heal", sound = "AOE" },                      -- 이글거리는 광선
            { eventID = 310, role = "Mechanic", sound = "Adds" }, -- 아래로 던지기
            { eventID = 311, role = "Tank", sound = "Tank" },                     -- 태양 작렬
            { eventID = 312, role = "Other", }, -- 렌즈 반사광 바닥
        },
        rules = {
            { dur = 8,  eID = 311 }, { dur = 12, eID = 310 },
            { dur = 5,  eID = 309 }, { dur = 30, eID = 312 },
            { dur = 10, eID = 309 }, { dur = 12, eID = 311 },
        },
    },

    -- 군단
    -- 삼두정의 권좌 (mapID 1753)
    [2065] = { -- 승천자 주라알
        events = {
            { eventID = 223, role = "Other", sound = "Frontal" },                     -- 무효의 손바닥
            { eventID = 224, role = "Mechanic", }, -- 척살
            { eventID = 225, role = "Heal", sound = "AOE", text = "쫄 & 광역딜" },                      -- 수액 격돌
            { eventID = 226, role = "Tank"    , sound = "Tank"  }, -- 공허의 습격
            { eventID = 238, role = "Mechanic", sound = "Phase" }, -- 밀어닥치는 공허
        },
        rules = {
            { dur = 16, eID = 223 }, { dur = 7,  eID = 224 },
            { dur = 22, eID = 225 }, { dur = 4,  eID = 226 }, { dur = 50, eID = 238 },
            { dur = 40, eID = 226 }, { dur = 28, eID = 224 },
        },
    },
    [2066] = { -- 사프리쉬
        events = {
            { eventID = 234, role = "Other" },                     -- 공허 폭탄
            { eventID = 235, role = "Mechanic", sound = "Phase" }, -- 위상 질주
            { eventID = 236, role = "Tank", sound = "Interrupt" },                     -- 섬뜩한 비명
            { eventID = 237, role = "Heal" },                      -- 어둠의 암습
            { eventID = 243, role = "Heal", sound = "AOE" },                      -- 과부하
        },
        rules = {
            { dur = 4,  eID = 237 }, { dur = 32, eID = 243 },
            { dur = 6,  eID = 234 }, { dur = 20, eID = 235 },
            { dur = 10, eID = 234 }, { dur = 12, eID = 237 },
        },
    },
    [2067] = { -- 총독 네자르
        events = {
            { eventID = 244, role = "Tank", sound = "Interrupt" },                     -- 정신 분열
            { eventID = 245, role = "Heal", sound = "AOE" },                      -- 대규모 공허 주입
            { eventID = 246, role = "Adds", sound = "Adds" },                      -- 암영 촉수
            { eventID = 247, role = "Mechanic", sound = "Phase" }, -- 공허의 폭풍
            { eventID = 376, role = "Other" },                     -- 심연의 관문
        },
        rules = {
            { dur = 6,  eID = 376 }, { dur = 26, eID = 246 },
            { dur = 45, eID = 247 }, { dur = 4,  eID = 244 }, { dur = 12, eID = 245 },
            { dur = 18, eID = 376 },
        },
    },
    [2068] = { -- 르우라
        events = {
            { eventID = 248, role = "Heal" },                      -- 절망의 음표
            { eventID = 249, role = "Heal" },                      -- 절망의 진혼곡
            { eventID = 250, role = "Other", text ="선" }, -- 불협의 광선
            { eventID = 251, role = "Heal", sound = "AOE" },       -- 파열 (할키야스)
            { eventID = 252, role = "Other", text ="바닥" },                     -- 암울한 합창
            { eventID = 253, role = "Mechanic", sound = "Phase" }, -- 영원한 밤의 교향곡
            { eventID = 254, role = "Mechanic", sound = "Phase" }, -- 반발력
        },
        rules = {
            { dur = 1.5, eID = 249 }, { dur = 12, eID = 251 },
            { dur = 24,  eID = 250 }, { dur = 35, eID = 252 },
            { dur = 5,   eID = 251 }, { dur = 17, eID = 250 }, { dur = 28, eID = 252 },
            { dur = 1.5, eID = 253 }, { dur = 20, eID = 254 },
        },
    },

    -- 용군단
    -- 알게타르 대학 (mapID 2526)
    [2562] = { -- 벡사무스
        events = {
            { spellID = 387691, role = "Other",    text = "구슬" },      -- 비전 보주
            { spellID = 386173, role = "Heal",     sound = "AOE"      }, -- 마나 폭탄
            { spellID = 385958, role = "Tank",     sound = "Frontal"  }, -- 비전 방출
            { spellID = 388537, role = "Mechanic", sound = "Phase" },    -- 비전 균열
        },
        rules = {
            { dur = 2,  eID = 387691 },
            { dur = 5,  eID = 385958 },
            { dur = 15, eID = 386173 },
            { dur = 18, eID = 387691, seq = 1 }, { dur = 18, eID = 385958, seq = 2 },  { dur = 18, eID = 386173, seq = 3 },
            { dur = 40, eID = 388537 },
        },
    },
    [2563] = { -- 비대해진 고대정령
        events = {
            { spellID = 388544, role = "Tank",     sound = "Tank" }, -- 나무껍질 파괴자
            { spellID = 388567, role = "Heal",     sound = "Adds" }, -- 가지 뻗기
            { spellID = 388796, role = "Other",    sound = "Pool" }, -- 발아
            { spellID = 388923, role = "Mechanic", sound = "AOE"  }, -- 밀려드는 분출
        },
        rules = {
            { dur = 9,  eID = 388544 },
            { dur = 18, eID = 388796 },
            { dur = 30, eID = 388567 },
            { dur = 29, eID = 388544 },
            { dur = 33, eID = 388796 },
            { dur = 55, eID = 388923 },
        },
    },
    [2564] = { -- 크로스
        events = {
            { spellID = 376997, role = "Tank"    , sound = "Tank"    }, -- 흉포한 쪼기
            { spellID = 377004, role = "Heal"    , sound = "AOE"     }, -- 귀청 터질듯한 비명
            { spellID = 377034, role = "Other"   , sound = "Frontal" }, -- 압도적인 돌풍
            { spellID = 377182, role = "Mechanic", sound = "Phase"   }, -- 공놀이
        },
        rules = {
            { dur = 5,  eID = 376997 }, { dur = 14, eID = 377004 }, { dur = 20, eID = 377034 },
        },
    },
    [2565] = { -- 도라고사의 메아리
        events = {
            { spellID = 373325,  role = "Other" },                      -- 신비한 화살
            { spellID = 1282251, role = "Tank",     sound = "Tank" },   -- 천공의 작렬
            { spellID = 374341,  role = "Heal",     sound = "Dispel" }, -- 마력 폭탄
            { spellID = 388820,  role = "Mechanic", sound = "Phase" },  -- 힘의 공백
        },
        rules = {
            { dur = 7,  eID = 373325  },
            { dur = 9,  eID = 1282251 },
            { dur = 10, eID = 373325  },
            { dur = 12, eID = 1282251 },
            { dur = 14, eID = 374341  },
            { dur = 28, eID = 388820  },
        },
    },

    -- 한밤
    -- 윈드러너 첨탑 (mapID 2805)
    [3056] = { -- 잿불여명
        events = {
            { eventID = 239, role = "Tank"    , sound = "Tank"  }, -- 불타는 부리
            { eventID = 241, role = "Heal", sound = "Pool" },                      -- 불타는 상승 기류
            { eventID = 242, role = "Mechanic", sound = "Phase" },                      -- 불타는 강풍
            { eventID = 736, role = "Other" },                     -- 불타는 상승 기류
        },
        rules = {
            { dur = 6,    eID = 241 }, { dur = 10,  eID = 239 },
            { dur = 15,   eID = 242 }, { dur = 13,  eID = 239 },
            { dur = 15.5, eID = 241 }, { dur = 30,  eID = 242 },
        },
    },
    [3057] = { -- 버려진 2인조
        events = {
            { eventID = 25,  role = "Tank"    , sound = "Tank"  }, -- 뼈 베기
            { eventID = 26,  role = "Other" },                      -- 어둠의 저주
            { eventID = 27,  role = "Mechanic", sound = "Phase" },                      -- 쇠약의 절규
            { eventID = 28,  role = "Heal", sound = "Pool" },                     -- 흩어지는 분출
            { eventID = 29,  role = "Other" }, -- 힘껏 당기기
        },
        rules = {
            { dur = 8,      eID = 28 },  { dur = 17.333, eID = 25 },
            { dur = 22.666, eID = 26 },  { dur = 27.333, eID = 28 },
            { dur = 48,     eID = 27 },
        },
    },
    [3058] = { -- 지휘관 크롤루크
        events = {
            { eventID = 210, role = "Tank"    , sound = "Tank"  }, -- 광란
            { eventID = 211, role = "Mechanic" }, -- 위협의 외침
            { eventID = 212, role = "Heal" },                      -- 무모한 도약
            { eventID = 213, role = "Mechanic" }, -- 위협의 외침
            { eventID = 214, role = "Heal" },                      -- 무모한 도약
            { eventID = 215, role = "Mechanic", sound = "Phase" }, -- 재집결의 고함
            { eventID = 216, role = "Other" },                     -- 칼날폭풍
            { eventID = 556, role = "Tank"    , sound = "Tank"  }, -- 광란
        },
        rules = {
            { dur = 3,     eID = 210 }, { dur = 10,  eID = 212 }, { dur = 18,   eID = 213 },
            { dur = 30,    eID = 210 }, { dur = 37,  eID = 212 }, { dur = 45,   eID = 213 },
            { dur = 0.001, eID = 215 }, { dur = 8,   eID = 216 },
        },
    },
    [3059] = { -- 잠 못 드는 심장
        events = {
            { eventID = 21,  role = "Mechanic", sound = "Phase" }, -- 백발백중 바람작렬
            { eventID = 22,  role = "Heal" },                      -- 화살 강풍
            { eventID = 23,  role = "Other" },                     -- 화살의 비
            { eventID = 24,  role = "Tank"    , sound = "Tank"  }, -- 폭풍의 베기
            { eventID = 538, role = "Other" },                      -- 돌풍 사격
        },
        rules = {
            { dur = 9,    eID = 23 },  { dur = 11,   eID = 23 },
            { dur = 21,   eID = 24 },  { dur = 23.5, eID = 538 },
            { dur = 24,   eID = 21 },  { dur = 39,   eID = 22 },
            { dur = 53,   eID = 21 },
        },
    },

    -- 마법학자의 정원 (mapID 2811)
    [3071] = { -- 비전골렘 쿠스토스
        events = {
            { eventID = 281, role = "Mechanic", sound = "Phase" }, -- 연료 보급 프로토콜
            { eventID = 286, role = "Tank"    , sound = "Tank"  }, -- 반발하는 격돌
            { eventID = 287, role = "Heal" },                      -- 에테리얼 구속
            { eventID = 288, role = "Other" },                     -- 비전 방출
        },
        rules = {
            { dur = 5,    eID = 286 }, { dur = 15,  eID = 288 },
            { dur = 22,   eID = 287 }, { dur = 45,  eID = 281 },
            { dur = 22.5, eID = 286 }, { dur = 23,  eID = 288 },
        },
    },
    [3072] = { -- 사라넬 선래쉬
        events = {
            { eventID = 93,  role = "Other" }, -- 억제 지대
            { eventID = 94,  role = "Tank"    , sound = "Tank"  }, -- 쾌속의 수호물
            { eventID = 95,  role = "Heal" },                      -- 룬 징표
            { eventID = 96,  role = "Mechanic", sound = "Phase" }, -- 침묵의 물결
        },
        rules = {
            { dur = 7,  eID = 95 }, { dur = 17, eID = 93 },
            { dur = 26, eID = 94 }, { dur = 51, eID = 96 },
            { dur = 29, eID = 95 },
        },
    },
    [3073] = { -- 제멜루스
        events = {
            { eventID = 97,  role = "Other" }, -- 신경 연결
            { eventID = 98,  role = "Mechanic", sound = "Phase" },                      -- 천공의 손아귀
            { eventID = 99,  role = "Other" },                     -- 공허의 분비물
            { eventID = 100, role = "Heal" },                      -- 우주의 독침
            { eventID = 635, role = "Other" }, -- 3중 복제
            { eventID = 760, role = "Other" },                     -- 3중 복제
        },
        rules = {
            { dur = 16, eID = 97 }, { dur = 29, eID = 98 },
            -- dur=5 충돌(eID=100 sync / eID=635 non-sync) → 제외
        },
    },
    [3074] = { -- 디젠트리우스
        events = {
            { eventID = 290, role = "Heal" },                      -- 엔트로피 포식
            { eventID = 292, role = "Other", text = "공 튀기기" },                     -- 불안정한 공허의 정수
            { eventID = 420, role = "Tank"    , sound = "Tank"  }, -- 거대한 파편
        },
        rules = {
            { dur = 3,  eID = 420 }, { dur = 9,  eID = 290 }, { dur = 15, eID = 292 },
            { dur = 24, eID = 420, seq = 1 }, { dur = 24, eID = 290, seq = 2 }, { dur = 24, eID = 292, seq = 3 },
        },
    },

    -- 메아리치는 동굴 (mapID 2874)
    [3212] = { -- 무로진과 네크락스
        events = {
            { eventID = 150, role = "Tank"    , sound = "Tank"  }, -- 측방의 창
            { eventID = 151, role = "Other" },                     -- 악취 나는 깃털 폭풍
            { eventID = 152, role = "Other" }, -- 빙결 덫
            { eventID = 153, role = "Heal" },                      -- 탄막
            { eventID = 154, role = "Heal", sound = "Dispel" },                      -- 감염된 독
            { eventID = 155, role = "Mechanic", sound = "Phase" }, -- 썩어가는 강하
        },
        rules = {
            { dur = 5,  eID = 150 }, { dur = 12, eID = 154 },
            { dur = 20, eID = 152 }, { dur = 28, eID = 151 },
            { dur = 35, eID = 153 }, { dur = 41, eID = 155 },
            { dur = 45, eID = 150, seq = 1 }, { dur = 45, eID = 154, seq = 2 }, { dur = 45, eID = 152, seq = 3 },
            { dur = 45, eID = 151, seq = 4 }, { dur = 45, eID = 153, seq = 5 }, { dur = 45, eID = 155, seq = 6 },
        },
    },
    [3213] = { -- 보르다자
        events = {
            { eventID = 16,  role = "Tank",     sound = "Tank"  }, -- 영혼 흡수
            { eventID = 17,  role = "Other", sound = "Frontal" },                     -- 해체
            { eventID = 18,  role = "Other" },                     -- 죽음의 은총
            { eventID = 19,  role = "Heal", sound = "Adds" }, -- 악령 왜곡
            { eventID = 20,  role = "Mechanic", sound = "Phase" },                      -- 괴저의 수렴
            { eventID = 429, role = "Other" }, -- 최후의 추적
            { eventID = 688, role = "Other" },                     -- 최후의 추적
        },
        rules = {
            { dur = 3,      eID = 16 },  { dur = 70,     eID = 20 },
            { dur = 14.166, eID = 19 },  { dur = 25.333, eID = 17 },
            { dur = 33.5, eID = 16, seq = 1 }, { dur = 33.5, eID = 19, seq = 2 }, { dur = 33.5, eID = 17, seq = 3 },
        },
    },
    [3214] = { -- 영혼의 그릇 락툴
        events = {
            { eventID = 156, role = "Tank"    , sound = "Tank"  }, -- 영혼파괴자
            { eventID = 157, role = "Heal" },                      -- 영혼 분쇄하기
            { eventID = 158, role = "Mechanic", sound = "Phase" }, -- 영혼을 찢는 포효
        },
        rules = {
            { dur = 4,  eID = 156 }, { dur = 17, eID = 157 }, { dur = 70, eID = 158 },
            { dur = 26, eID = 156, seq = 1 }, { dur = 26, eID = 157, seq = 2 },
        },
    },

    -- 공결탑 제나스 (mapID 2915)
    [3328] = { -- 수석 핵장인 카스레스
        events = {
            { eventID = 106, role = "Mechanic", sound = "Phase" }, -- 핵심불꽃 폭발
            { eventID = 107, role = "Heal" },                      -- 역류 돌진
            { eventID = 108, role = "Other" },                                      -- 지맥 배열
            { eventID = 172, role = "Other" },                                      -- 용제 붕괴
        },
        rules = {
            { dur = 1,  eID = 108 }, { dur = 5,  eID = 107 },
            { dur = 10, eID = 172 }, { dur = 38, eID = 106 },
            { dur = 11, eID = 108 }, { dur = 12, eID = 107 }, { dur = 13, eID = 172 },
        },
    },
    [3332] = { -- 핵감시관 니사라
        events = {
            { eventID = 33,  role = "Other" },                                      -- 일식의 발걸음
            { eventID = 34,  role = "Mechanic", sound = "Phase" }, -- 빛흉터 섬광
            { eventID = 35,  role = "Tank",     sound = "Tank"  }, -- 암영의 채찍
            { eventID = 36,  role = "Adds",     sound = "Adds"  }, -- 무위의 선봉대
            { eventID = 313, role = "Other" },                                      -- 무가치한 자는 포식당하리
        },
        rules = {
            { dur = 3,     eID = 35 },  { dur = 5,  eID = 33 },
            { dur = 15,    eID = 36 },  { dur = 28, eID = 34 },
            { dur = 16.85, eID = 35 },  { dur = 18, eID = 33 },
            -- dur=15 충돌(eID=36 sync / eID=313 non-sync) → eID=36만 유지
        },
    },
    [3333] = { -- 로스락시온
        events = {
            { eventID = 109, role = "Heal" },                      -- 찬란한 분산
            { eventID = 110, role = "Mechanic", sound = "Phase" }, -- 천상의 기만
            { eventID = 111, role = "Tank"    , sound = "Tank"  }, -- 이글거리는 분쇄
            { eventID = 112, role = "Other" },                     -- 깜빡임
        },
        rules = {
            { dur = 2,  eID = 111 }, { dur = 11, eID = 109 },
            { dur = 52, eID = 110 }, { dur = 24, eID = 112 },
            { dur = 26, eID = 111 }, { dur = 25, eID = 109 }, { dur = 10, eID = 112 },
        },
    },

    --진균나락 (mapID 1592)
    [3159] = { -- 부식수렁
        events = {
            { eventID = 424, role = "Mechanic", sound = "Phase" }, -- 균류 만개
            { eventID = 425, role = "Mechanic", sound = "Phase" }, -- 균류 소환
            { eventID = 426, role = "Heal" },                      -- 농포 폭발
            { eventID = 427, role = "Tank", sound = "Tank"  }, -- 부패의 주먹
            { eventID = 428, role = "Heal" },                      -- 부패한 덩굴
            { eventID = 808, role = "Mechanic", sound = "Phase" }, -- 균류인 유충
            { eventID = 809, role = "Mechanic", sound = "Phase" }, -- 버섯인 유충
        },
        rules = {
            { dur = 41,  eID = 428 }, { dur = 21, eID = 427 },
            { dur = 8,   eID = 426 }, { dur = 13, eID = 425 }, { dur = 114, eID = 424 },
            { dur = 49,  eID = 425, seq = 1 }, { dur = 49, eID = 426, seq = 2 }, { dur = 49, eID = 428, seq = 3 },
            { dur = 21,  eID = 426 }, { dur = 12, eID = 427 }, { dur = 13, eID = 427 },
        },
    },

    -- 꿈의 균열 (mapID 2939, rules 없음)
    [3306] = { -- 꿈결을 벗어난 신 카이메루스
        events = {
            { eventID = 48,  role = "Other" },                     -- 대식가 강하
            { eventID = 49,  role = "Heal" },                      -- 균열 발생
            { eventID = 50,  role = "Heal" },                      -- 부식성 가래
            { eventID = 51,  role = "Other" },                     -- 찢어지다
            { eventID = 53,  role = "Other" },                     -- 부패와 파괴
            { eventID = 117, role = "Other" },                     -- 끔찍한 전쟁의 함성
            { eventID = 118, role = "Heal" },                      -- 불협화음의 포효
            { eventID = 119, role = "Mechanic", sound = "Phase" }, -- 장기를 포식
            { eventID = 126, role = "Other" },                     -- 부패의 깃털
            { eventID = 149, role = "Mechanic", sound = "Phase" }, -- 엘린더스트의 격변
            { eventID = 170, role = "Other" },                     -- 균열 대격변
            { eventID = 208, role = "Other" },                     -- 부패한 산성액
            { eventID = 217, role = "Mechanic", sound = "Phase" }, -- 균열의 광기
            { eventID = 307, role = "Heal" },                      -- 포식
            { eventID = 353, role = "Mechanic", sound = "Phase" }, -- 2페이즈
            { eventID = 431, role = "Mechanic", sound = "Phase" }, -- 엘린더스트의 격변
            { eventID = 458, role = "Other" },                     -- 부패와 파괴
            { eventID = 555, role = "Other" },                     -- 삼켜진 정수
        },
    },

    -- 공허 첨탑 (mapID 2912, rules 없음)
    [3176] = { -- 아베르지안
        events = {
            { eventID = 194, role = "Mechanic", sound = "Phase" }, -- 어둠의 진격
            { eventID = 195, role = "Mechanic", sound = "Phase" }, -- 어둠의 진격
            { eventID = 196, role = "Heal" },                      -- 어둠의 지각 변동
            { eventID = 197, role = "Mechanic", sound = "Phase" }, -- 암영 붕괴
            { eventID = 198, role = "Other" },                     -- 망각의 분노
            { eventID = 199, role = "Other" },                     -- 공허 추락
            { eventID = 200, role = "Other" },                     -- 끝없는 행진
            { eventID = 201, role = "Other" },                     -- 칠흑 보루
            { eventID = 209, role = "Other" },                     -- 공허 추락
            { eventID = 361, role = "Other" },                     -- 황폐화
            { eventID = 419, role = "Mechanic", sound = "Phase" }, -- 공허 징표
            { eventID = 492, role = "Tank"    , sound = "Tank"  }, -- 약화됨
        },
    },
    [3177] = { -- 보라시우스
        events = {
            { eventID = 59,  role = "Tank"    , sound = "Tank"  }, -- 그림자발톱 격돌
            { eventID = 60,  role = "Tank"    , sound = "Tank"  }, -- 그림자발톱 격돌
            { eventID = 61,  role = "Other" },                     -- 공허의 숨결
            { eventID = 62,  role = "Heal" },                      -- 기생충 배출
            { eventID = 63,  role = "Other" },                     -- 거대한 투척
            { eventID = 133, role = "Heal" },                      -- 태고의 포효
            { eventID = 557, role = "Other" },                     -- 시선 고정
            { eventID = 749, role = "Other" },                     -- 생성
        },
    },
    [3179] = { -- 몰락한 왕 살라다르
        events = {
            { eventID = 139, role = "Mechanic", sound = "Phase" }, -- 공허의 수렴
            { eventID = 140, role = "Heal" },                      -- 폭군의 지배
            { eventID = 141, role = "Other" },                     -- 분열된 투영
            { eventID = 142, role = "Other" },                     -- 부서지는 황혼
            { eventID = 143, role = "Heal" },                      -- 뒤틀린 암연
            { eventID = 148, role = "Mechanic", sound = "Phase" }, -- 무질서의 해체
            { eventID = 633, role = "Other" },                     -- 광폭화
            { eventID = 802, role = "Other" },                     -- 맹세를 저버리다
        },
    },
    [3178] = { -- 바엘고어와 에조라크
        events = {
            { eventID = 101, role = "Other" },                     -- 공허 빔
            { eventID = 102, role = "Mechanic", sound = "Phase" }, -- 공허의 울부짖음
            { eventID = 103, role = "Mechanic", sound = "Phase" }, -- 안개
            { eventID = 104, role = "Other" },                     -- 죽은 자의 숨결
            { eventID = 105, role = "Heal" },                      -- 한밤의 불꽃
            { eventID = 219, role = "Other" },                     -- 갈고리 턱
            { eventID = 220, role = "Tank"    , sound = "Tank"  }, -- 락팽
            { eventID = 221, role = "Tank"    , sound = "Tank"  }, -- 위어의 날개
            { eventID = 377, role = "Mechanic", sound = "Phase" }, -- 우주 침투: 안개
            { eventID = 378, role = "Other" },                     -- 우주 침투: 공허 빔
            { eventID = 379, role = "Other" },                     -- 우주 침투: 망자의 숨결
            { eventID = 380, role = "Mechanic", sound = "Phase" }, -- 우주 침투: 공허의 포효
            { eventID = 381, role = "Mechanic", sound = "Phase" }, -- 광역 장벽
        },
    },
    [3180] = { -- 빛에 눈이 먼 선봉대
        events = {
            { eventID = 71,  role = "Mechanic", sound = "Phase" }, -- 평화로운 후광
            { eventID = 72,  role = "Other" },                     -- 이벤트 72
            { eventID = 73,  role = "Other" },                     -- 천둥 코끼리 돌격
            { eventID = 74,  role = "Mechanic", sound = "Phase" }, -- 거룩한 방패
            { eventID = 75,  role = "Heal" },                      -- 티르의 분노
            { eventID = 76,  role = "Mechanic", sound = "Phase" }, -- 경건의 아우라
            { eventID = 77,  role = "Heal" },                      -- 뜨거운 빛
            { eventID = 78,  role = "Tank"    , sound = "Tank"  }, -- 심판
            { eventID = 79,  role = "Mechanic", sound = "Phase" }, -- 복수의 방패
            { eventID = 80,  role = "Mechanic", sound = "Phase" }, -- 거룩한 종
            { eventID = 81,  role = "Mechanic", sound = "Phase" }, -- 분노의 아우라
            { eventID = 82,  role = "Tank"    , sound = "Tank"  }, -- 심판
            { eventID = 83,  role = "Mechanic", sound = "Phase" }, -- 신성한 폭풍
            { eventID = 84,  role = "Heal" },                      -- 거룩한 죄
            { eventID = 85,  role = "Heal" },                      -- 사형 선고
            { eventID = 358, role = "Mechanic", sound = "Phase" }, -- 열성적인 영혼
            { eventID = 359, role = "Mechanic", sound = "Phase" }, -- 열성적인 영혼
            { eventID = 360, role = "Mechanic", sound = "Phase" }, -- 열성적인 영혼
            { eventID = 365, role = "Mechanic", sound = "Phase" }, -- 복수의 방패
            { eventID = 373, role = "Heal" },                      -- 뜨거운 빛
            { eventID = 374, role = "Other" },                     -- 신성한 폭풍
        },
    },
    [3181] = { -- 우주의 왕관
        events = {
            { eventID = 4,   role = "Heal" },                      -- 무의 왕관
            { eventID = 5,   role = "Mechanic", sound = "Phase" }, -- 공허한 반발
            { eventID = 6,   role = "Mechanic", sound = "Phase" }, -- 은화살
            { eventID = 7,   role = "Other" },                     -- 은화살 탄막
            { eventID = 8,   role = "Other" },                     -- 특이점 폭발
            { eventID = 9,   role = "Heal" },                      -- 공허추적자 스파이크
            { eventID = 10,  role = "Mechanic", sound = "Phase" }, -- 공허의 부름
            { eventID = 11,  role = "Heal" },                      -- 레인저 캡틴의 마크
            { eventID = 12,  role = "Heal" },                      -- 우주 장벽
            { eventID = 13,  role = "Mechanic", sound = "Phase" }, -- 최종 수호자
            { eventID = 14,  role = "Heal" },                      -- 공허함의 파악
            { eventID = 15,  role = "Mechanic", sound = "Phase" }, -- 우주를 삼켜라
            { eventID = 64,  role = "Tank"    , sound = "Tank"  }, -- 어둠의 손
            { eventID = 65,  role = "Mechanic", sound = "Phase" }, -- 폭식의 심연
            { eventID = 66,  role = "Heal" },                      -- 간섭 진동
            { eventID = 131, role = "Heal" },                      -- 레인저 캡틴의 마크
            { eventID = 132, role = "Heal" },                      -- 공허함의 파악
            { eventID = 135, role = "Mechanic", sound = "Phase" }, -- 균열 환영
            { eventID = 136, role = "Mechanic", sound = "Phase" }, -- 우주 포털
            { eventID = 137, role = "Tank"    , sound = "Tank"  }, -- 균열 베기
            { eventID = 169, role = "Other" },                     -- 우주 에너지 과부하
        },
    },

    -- 쿠엘다나스 진격로 (mapID 2913, rules 없음)
    [3182] = { -- 알라르의 자손 벨로렌
        events = {
            { eventID = 128, role = "Mechanic", sound = "Phase" }, -- 벨로란의 불씨
            { eventID = 130, role = "Mechanic", sound = "Phase" }, -- 빛나는 메아리
            { eventID = 134, role = "Tank"    , sound = "Tank"  }, -- 수호자 칙령
            { eventID = 138, role = "Heal" },                      -- 영원한 소각
            { eventID = 161, role = "Mechanic", sound = "Phase" }, -- 주입된 깃털
            { eventID = 218, role = "Heal" },                      -- 공허빛 합류
            { eventID = 272, role = "Mechanic", sound = "Phase" }, -- 죽음의 낙하
            { eventID = 273, role = "Other" },                     -- 화염 부화
            { eventID = 384, role = "Mechanic", sound = "Phase" }, -- 성광의 깃털
            { eventID = 385, role = "Mechanic", sound = "Phase" }, -- 공허의 깃털
            { eventID = 417, role = "Other" },                     -- 이벤트 417
            { eventID = 418, role = "Other" },                     -- 이벤트 418
            { eventID = 482, role = "Mechanic", sound = "Phase" }, -- 성광의 깃털
            { eventID = 483, role = "Mechanic", sound = "Phase" }, -- 공허의 깃털
            { eventID = 494, role = "Heal" },                      -- 성광의 급습
            { eventID = 495, role = "Heal" },                      -- 공허 강하
            { eventID = 497, role = "Mechanic", sound = "Phase" }, -- 부활
            { eventID = 500, role = "Mechanic", sound = "Phase" }, -- 공허빛의 분노
            { eventID = 748, role = "Other" },                     -- 부활
        },
    },
    [3183] = { -- 한밤의 도래
        events = {
            { eventID = 255, role = "Mechanic", sound = "Phase" }, -- 죽음의 만가
            { eventID = 256, role = "Other" },                     -- 하늘의 대검
            { eventID = 257, role = "Other" },                     -- 수호 각기둥
            { eventID = 258, role = "Heal" },                      -- 부서진 하늘
            { eventID = 259, role = "Heal" },                      -- 개기일식
            { eventID = 260, role = "Mechanic", sound = "Phase" }, -- 가장 어두운 밤
            { eventID = 261, role = "Mechanic", sound = "Phase" }, -- 빛의 사이펀
            { eventID = 262, role = "Other" },                     -- 어두운 별자리
            { eventID = 263, role = "Other" },                     -- 암흑 대천사
            { eventID = 362, role = "Mechanic", sound = "Phase" }, -- 죽음의 레퀴엠
            { eventID = 363, role = "Heal" },                      -- 연결 끊기
            { eventID = 364, role = "Tank"    , sound = "Tank"  }, -- 하늘의 창
            { eventID = 433, role = "Mechanic", sound = "Phase" }, -- 어둠의 우물 깊이
            { eventID = 434, role = "Heal" },                      -- 우주 핵분열
            { eventID = 435, role = "Heal" },                      -- 핵심 수확
            { eventID = 436, role = "Other" },                     -- 암흑 붕괴
            { eventID = 437, role = "Heal" },                      -- 별조각
            { eventID = 632, role = "Heal" },                      -- 충전
            { eventID = 636, role = "Other" },                     -- 종단 각기둥
            { eventID = 644, role = "Mechanic", sound = "Phase" }, -- 말살 협주곡
            { eventID = 649, role = "Other" },                     -- 암흑 퀘이사
            { eventID = 650, role = "Heal" },                      -- 어두운 룬
            { eventID = 750, role = "Other" },                     -- 불협의 자장가
        },
    },
}

-- ==============================
-- mapID 매핑
-- ==============================
-- mapID → encounterID 목록 (TimelineColor / Sound 인스턴스 전체 적용용)
---@type table<number, number[]>
dodo.EncounterMapBosses = {
    [658]  = { 1999, 2001, 2000 },                    -- 사론의 구덩이
    [1209] = { 1698, 1699, 1700, 1701 },              -- 하늘탑
    [1592] = { 3159 },                                -- 孢陨幽境
    [1753] = { 2065, 2066, 2067, 2068 },              -- 삼두정의 권좌
    [2526] = { 2562, 2563, 2564, 2565 },              -- 알게타르 대학
    [2805] = { 3056, 3057, 3058, 3059 },              -- 윈드러너 첨탑
    [2811] = { 3071, 3072, 3073, 3074 },              -- 마법학자의 정원
    [2874] = { 3212, 3213, 3214 },                    -- 메아리치는 동굴
    [2912] = { 3176, 3177, 3179, 3178, 3180, 3181 }, -- 공허 첨탑
    [2913] = { 3182, 3183 },                          -- 쿠엘다나스 진격로
    [2915] = { 3328, 3332, 3333 },                    -- 공결탑 제나스
    [2939] = { 3306 },                                -- 꿈의 균열
}
