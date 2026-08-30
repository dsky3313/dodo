-- ==============================
-- 설정 및 테이블
-- ==============================
---@diagnostic disable: lowercase-global, param-type-mismatch, redundant-parameter, undefined-field, undefined-global
local addonName, dodo = ...

--[[ eventID > spellID 역조회 매크로
/run local t={298,299,300,301} for _,id in ipairs(t) do local i=C_EncounterEvents.GetEventInfo(id) print(id.."→"..(i and tostring(i.spellID) or "nil")) end
]]

---@class EncounterEvent
---@field eventID number
---@field role "Tank"|"Heal"|"Mechanic"|"Adds"|"ETC"|"Other"
---@field sound "Tank"|"Phase"|"AOE"|"Frontal"|"Mechanic"|"Adds"|"Dispel"|"Interrupt"|"Soak"|"Pool"|"Target"
---@field text? string

---@class EncounterRule
---@field dur number ENCOUNTER_TIMELINE_EVENT_ADDED 시점의 남은 시간(초)
---@field eID number eventID
---@field seq? number 동일 dur 배치 도착 순서

---@class EncounterEntry
---@field events EncounterEvent[]
---@field rules? EncounterRule[]

dodo.EncounterDebug = false  -- true: Text.lua [dodo-dbg] 로그 출력

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
            { spellID = 1252733, role = "Other",    sound = "Pool" },    -- 강풍의 쇄도
            { spellID = 153757,  role = "Heal",     sound = "AOE" },     -- 칼날 뿌리기
            { spellID = 1258148, role = "Other",    sound = "Frontal" }, -- 바람 차크람
            { spellID = 156793,  role = "Mechanic", sound = "Phase" },   -- 회전 표창의 회오리
        },
        rules = {
            { dur = 5, eID = 1252733 },
            { dur = 12, eID = 153757 },
            { dur = 18, eID = 1258148 },
            { dur = 35, eID = 156793 },
            { dur = 10, eID = 1258148 },
            { dur = 20, eID = 153757 },
        },
    },
    [1699] = { -- 아라크나스
        events = {
            { spellID = 154115, role = "Tank",  sound = "Frontal"  }, -- 타오르는 강타
            { spellID = 154162, role = "Other", text = "선"     }, -- 기력 충전
            { spellID = 154135, role = "Heal",  sound = "AOE"   }, -- 초신성
        },
        rules = {
            { dur = 5,  eID = 154115 },
            { dur = 6,  eID = 154162 },
            { dur = 50, eID = 154135 },
            { dur = 10, eID = 154115 },
            { dur = 15, eID = 154115 },
            { dur = 24, eID = 154162 },
        },
    },
    [1700] = { -- 루크란
        events = {
            { spellID = 1253510, role = "Heal",     sound = "Adds"  }, -- 태양의 도래
            { spellID = 1253519, role = "Tank",     sound = "Tank"  }, -- 타오르는 발톱
            { spellID = 1253527, role = "Mechanic", sound = "Phase" }, -- 타오르는 깃털
            { spellID = 1283787, role = "Other"                     }, -- 영광의 불꽃
        },
        rules = {
            { dur = 5,  eID = 1253519 },
            { dur = 12, eID = 1253510, seq = 1 }, { dur = 12, eID = 1253519, seq = 2 },
            { dur = 38, eID = 1253527 },
            { dur = 21, eID = 1253510 },
        },
    },
    [1701] = { -- 대현자 비릭스
        events = {
            { spellID = 1253538, role = "Heal", },                         -- 이글거리는 광선
            { spellID = 1253998, role = "Mechanic", sound = "Adds" },      -- 아래로 던지기
            { spellID = 154396,  role = "Tank",     sound = "Interrupt" }, -- 태양 작렬
            { spellID = 1253840, role = "Other",    sound = "Pool" },      -- 렌즈 반사광 (바닥)
        },
        rules = {
            { dur = 5,  eID = 1253538 },  -- 이글거리는 광선 (첫 사이클)
            { dur = 8,  eID = 154396  },  -- 태양 작렬 (첫 사이클)
            { dur = 12, eID = 1253998 },  -- 아래로 던지기 (첫 사이클, sync)
            { dur = 30, eID = 1253840 },  -- 렌즈 반사광 (첫 사이클, sync)
            { dur = 10, eID = 1253538 },  -- 이글거리는 광선 (반복)
            { dur = 12, eID = 154396  },  -- 태양 작렬 (반복)
        },
    },

    -- 군단
    -- 삼두정의 권좌 (mapID 1753)
    [2065] = { -- 승천자 주라알
        events = {
            { spellID = 1268916, role = "Other",    sound = "Frontal"               }, -- 무효의 손바닥
            { spellID = 1263282, role = "Mechanic",                                 }, -- 척살
            { spellID = 1263399, role = "Heal",     sound = "AOE", text = "쫄 & 광역딜" }, -- 수액 격돌
            { spellID = 1263440, role = "Tank",     sound = "Tank"                  }, -- 공허의 습격
            { spellID = 1263304, role = "Mechanic", sound = "Phase"                 }, -- 밀어닥치는 공허
        },
        rules = {
            { dur = 4,  eID = 1263440 }, { dur = 7,  eID = 1263282 },
            { dur = 16, eID = 1268916 }, { dur = 22, eID = 1263399 },
            { dur = 28, eID = 1263282 }, { dur = 40, eID = 1263440 }, { dur = 50, eID = 1263304 },
        },
    },
    [2066] = { -- 사프리쉬
        events = {
            { spellID = 247175,  role = "Other"                     }, -- 공허 폭탄
            { spellID = 1263509, role = "Mechanic", sound = "Phase" }, -- 위상 질주
            { spellID = 248831,  role = "Tank",     sound = "Interrupt" }, -- 섬뜩한 비명
            { spellID = 245738,  role = "Heal"                      }, -- 어둠의 암습
            { spellID = 1263523, role = "Heal",     sound = "AOE"   }, -- 과부하
        },
        rules = {
            { dur = 4,  eID = 245738  }, { dur = 6,  eID = 247175  },
            { dur = 10, eID = 247175  }, { dur = 12, eID = 245738  },
            { dur = 20, eID = 1263509 }, { dur = 32, eID = 1263523 },
        },
    },
    [2067] = { -- 총독 네자르
        events = {
            { spellID = 244750,  role = "Tank",     sound = "Interrupt" }, -- 정신 분열
            { spellID = 1263542, role = "Heal",     sound = "AOE"       }, -- 대규모 공허 주입
            { spellID = 1263538, role = "Adds",     sound = "Adds"      }, -- 암영 촉수
            { spellID = 1263528, role = "Mechanic", sound = "Phase"     }, -- 공허의 폭풍
            { spellID = 1277358, role = "Other"                         }, -- 심연의 관문
        },
        rules = {
            { dur = 4,  eID = 244750  }, { dur = 6,  eID = 1277358 },
            { dur = 12, eID = 1263542 }, { dur = 18, eID = 1277358 },
            { dur = 26, eID = 1263538 }, { dur = 45, eID = 1263528 },
        },
    },
    [2068] = { -- 르우라
        events = {
            { spellID = 1265419, role = "Heal"                          }, -- 절망의 음표
            { spellID = 1265421, role = "Heal"                          }, -- 절망의 진혼곡
            { spellID = 1265426, role = "Other",    text = "선"         }, -- 불협의 광선
            { spellID = 1264151, role = "Heal",     sound = "AOE"       }, -- 파열 (할키야스)
            { spellID = 1265689, role = "Other",    text = "바닥"       }, -- 암울한 합창
            { spellID = 1266003, role = "Mechanic", sound = "Phase"     }, -- 영원한 밤의 교향곡
            { spellID = 1266001, role = "Mechanic", sound = "Phase"     }, -- 반발력
        },
        rules = {
            { dur = 1.5, eID = 1265421 }, { dur = 1.5, eID = 1266003 },
            { dur = 5,   eID = 1264151 }, { dur = 12,  eID = 1264151 },
            { dur = 17,  eID = 1265426 }, { dur = 20,  eID = 1266001 },
            { dur = 24,  eID = 1265426 }, { dur = 28,  eID = 1265689 },
            { dur = 35,  eID = 1265689 },
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
            { spellID = 466064, role = "Tank"    , sound = "Tank"  }, -- 불타는 부리
            { spellID = 466556, role = "Heal",     sound = "Pool"  }, -- 불타는 상승 기류
            { spellID = 467040, role = "Mechanic", sound = "Phase" }, -- 불타는 강풍
            { spellID = 466559, role = "Other" },                     -- 불타는 상승 기류
        },
        rules = {
            { dur = 6,    eID = 466556 }, { dur = 10,  eID = 466064 },
            { dur = 15,   eID = 467040 }, { dur = 13,  eID = 466064 },
            { dur = 15.5, eID = 466556 }, { dur = 30,  eID = 467040 },
        },
    },
    [3057] = { -- 버려진 2인조
        events = {
            { spellID = 472888, role = "Tank"    , sound = "Tank"  }, -- 뼈 베기
            { spellID = 474105, role = "Other" },                     -- 어둠의 저주
            { spellID = 472736, role = "Mechanic", sound = "Phase" }, -- 쇠약의 절규
            { spellID = 472745, role = "Heal",     sound = "Pool"  }, -- 흩어지는 분출
            { spellID = 472795, role = "Other" },                     -- 힘껏 당기기
        },
        rules = {
            { dur = 8,      eID = 472745 }, { dur = 17.333, eID = 472888 },
            { dur = 22.666, eID = 474105 }, { dur = 27.333, eID = 472745 },
            { dur = 48,     eID = 472736 },
        },
    },
    [3058] = { -- 지휘관 크롤루크
        events = {
            { spellID = 467620,  role = "Tank"    , sound = "Tank"  }, -- 광란
            { spellID = 1253026, role = "Mechanic" },                  -- 위협의 외침
            { spellID = 472081,  role = "Heal" },                      -- 무모한 도약
            { spellID = 1253272, role = "Mechanic" },                  -- 위협의 외침
            { spellID = 1253270, role = "Heal" },                      -- 무모한 도약
            { spellID = 472043,  role = "Mechanic", sound = "Phase" }, -- 재집결의 고함
            { spellID = 470963,  role = "Other" },                     -- 칼날폭풍
            { spellID = 1283335, role = "Tank"    , sound = "Tank"  }, -- 광란
        },
        rules = {
            { dur = 3,     eID = 467620  }, { dur = 10,  eID = 472081  }, { dur = 18,   eID = 1253272 },
            { dur = 30,    eID = 467620  }, { dur = 37,  eID = 472081  }, { dur = 45,   eID = 1253272 },
            { dur = 0.001, eID = 472043  }, { dur = 8,   eID = 470963  },
        },
    },
    [3059] = { -- 잠 못 드는 심장
        events = {
            { spellID = 468429,  role = "Mechanic", sound = "Phase" }, -- 백발백중 바람작렬
            { spellID = 474528,  role = "Heal" },                      -- 화살 강풍
            { spellID = 472556,  role = "Other" },                     -- 화살의 비
            { spellID = 472662,  role = "Tank"    , sound = "Tank"  }, -- 폭풍의 베기
            { spellID = 1253986, role = "Other" },                     -- 돌풍 사격
        },
        rules = {
            { dur = 9,    eID = 472556  }, { dur = 11,   eID = 472556  },
            { dur = 21,   eID = 472662  }, { dur = 23.5, eID = 1253986 },
            { dur = 24,   eID = 468429  }, { dur = 39,   eID = 474528  },
            { dur = 53,   eID = 468429  },
        },
    },

    -- 마법학자의 정원 (mapID 2811)
    [3071] = { -- 비전골렘 쿠스토스
        events = {
            { spellID = 474345,  role = "Mechanic", sound = "Phase" }, -- 연료 보급 프로토콜
            { spellID = 474496,  role = "Tank"    , sound = "Tank"  }, -- 반발하는 격돌
            { spellID = 1214032, role = "Heal" },                      -- 에테리얼 구속
            { spellID = 1214081, role = "Other" },                     -- 비전 방출
        },
        rules = {
            { dur = 5,    eID = 474496  }, { dur = 15,  eID = 1214081 },
            { dur = 22,   eID = 1214032 }, { dur = 45,  eID = 474345  },
            { dur = 22.5, eID = 474496  }, { dur = 23,  eID = 1214081 },
        },
    },
    [3072] = { -- 사라넬 선래쉬
        events = {
            { spellID = 1224903, role = "Other" },                     -- 억제 지대
            { spellID = 1248689, role = "Tank"    , sound = "Tank"  }, -- 쾌속의 수호물
            { spellID = 1225787, role = "Heal" },                      -- 룬 징표
            { spellID = 1225193, role = "Mechanic", sound = "Phase" }, -- 침묵의 물결
        },
        rules = {
            { dur = 7,  eID = 1225787 }, { dur = 17, eID = 1224903 },
            { dur = 26, eID = 1248689 }, { dur = 51, eID = 1225193 },
            { dur = 29, eID = 1225787 },
        },
    },
    [3073] = { -- 제멜루스
        events = {
            { spellID = 1253705, role = "Other" },                     -- 신경 연결
            { spellID = 1224129, role = "Mechanic", sound = "Phase" }, -- 천공의 손아귀
            { spellID = 1224088, role = "Other" },                     -- 공허의 분비물
            { spellID = 1223961, role = "Heal" },                      -- 우주의 독침
            { spellID = 1223847, role = "Other" },                     -- 3중 복제
            { spellID = 1296205, role = "Other" },                     -- 3중 복제
        },
        rules = {
            { dur = 16, eID = 1253705 }, { dur = 29, eID = 1224129 },
            -- dur=5 충돌(eID=100 sync / eID=635 non-sync) → 제외
        },
    },
    [3074] = { -- 디젠트리우스
        events = {
            { spellID = 1215893, role = "Heal" },                      -- 엔트로피 포식
            { spellID = 1215067, role = "Other", text = "공 튀기기" }, -- 불안정한 공허의 정수
            { spellID = 1280106, role = "Tank"    , sound = "Tank"  }, -- 거대한 파편
        },
        rules = {
            { dur = 3,  eID = 1280106 }, { dur = 9,  eID = 1215893 }, { dur = 15, eID = 1215067 },
            { dur = 24, eID = 1280106, seq = 1 }, { dur = 24, eID = 1215893, seq = 2 }, { dur = 24, eID = 1215067, seq = 3 },
        },
    },

    -- 마이사라 동굴 (mapID 2874)
    [3212] = { -- 무로진과 네크락스
        events = {
            { spellID = 1266480, role = "Tank"    , sound = "Tank"  }, -- 측방의 창
            { spellID = 1243900, role = "Other" },                     -- 악취 나는 깃털 폭풍
            { spellID = 1266731, role = "Other" },                     -- 빙결 덫
            { spellID = 1260643, role = "Heal" },                      -- 탄막
            { spellID = 1246666, role = "Heal", sound = "Dispel" },    -- 감염된 독
            { spellID = 1249479, role = "Mechanic", sound = "Phase" }, -- 썩어가는 강하
        },
        rules = {
            { dur = 5,  eID = 1266480 }, { dur = 12, eID = 1246666 },
            { dur = 20, eID = 1266731 }, { dur = 28, eID = 1243900 },
            { dur = 35, eID = 1260643 }, { dur = 41, eID = 1249479 },
            { dur = 45, eID = 1266480, seq = 1 }, { dur = 45, eID = 1246666, seq = 2 }, { dur = 45, eID = 1266731, seq = 3 },
            { dur = 45, eID = 1243900, seq = 4 }, { dur = 45, eID = 1260643, seq = 5 }, { dur = 45, eID = 1249479, seq = 6 },
        },
    },
    [3213] = { -- 보르다자
        events = {
            { spellID = 1251554, role = "Tank",     sound = "Tank"    }, -- 영혼 흡수
            { spellID = 1252054, role = "Other",    sound = "Frontal" }, -- 해체
            --{ eventID = 18,      role = "Other" },                       -- 죽음의 은총 (spellID 미확인)
            { spellID = 1251204, role = "Heal",     sound = "Adds"    }, -- 악령 왜곡
            { spellID = 1250708, role = "Mechanic", sound = "Phase"   }, -- 괴저의 수렴
            --{ eventID = 429,     role = "Other" },                       -- 최후의 추적 (spellID 미확인)
            --{ eventID = 688,     role = "Other" },                       -- 최후의 추적 (spellID 미확인)
        },
        rules = {
            { dur = 3,      eID = 1251554 }, { dur = 70,     eID = 1250708 },
            { dur = 14.166, eID = 1251204 }, { dur = 25.333, eID = 1252054 },
            { dur = 33.5, eID = 1251554, seq = 1 }, { dur = 33.5, eID = 1251204, seq = 2 }, { dur = 33.5, eID = 1252054, seq = 3 },
        },
    },
    [3214] = { -- 영혼의 그릇 락툴
        events = {
            { spellID = 1251023, role = "Tank"    , sound = "Tank"  }, -- 영혼파괴자
            { spellID = 1252676, role = "Heal" },                      -- 영혼 분쇄하기
            { spellID = 1253788, role = "Mechanic", sound = "Phase" }, -- 영혼을 찢는 포효
        },
        rules = {
            { dur = 4,  eID = 1251023 }, { dur = 17, eID = 1252676 }, { dur = 70, eID = 1253788 },
            { dur = 26, eID = 1251023, seq = 1 }, { dur = 26, eID = 1252676, seq = 2 },
        },
    },

    -- 공결탑 제나스 (mapID 2915)
    [3328] = { -- 수석 핵장인 카스레스
        events = {
            { spellID = 1257512, role = "Mechanic", sound = "Phase" },    -- 핵심불꽃 폭발
            { spellID = 1251767, role = "Heal",     text = "선 지우기" }, -- 역류 돌진
            { spellID = 1251183, role = "Other",    text = "선" },        -- 지맥 배열
            { spellID = 1264048, role = "Other" },                        -- 용제 붕괴
        },
        rules = {
            { dur = 1,  eID = 1251183 }, { dur = 5,  eID = 1251767 },
            { dur = 10, eID = 1264048 }, { dur = 38, eID = 1257512 },
            { dur = 11, eID = 1251183 }, { dur = 12, eID = 1251767 }, { dur = 13, eID = 1264048 },
        },
    },
    [3332] = { -- 핵감시관 니사라
        events = {
            { spellID = 1249014, role = "Other" },                     -- 일식의 발걸음
            { spellID = 1264439, role = "Mechanic", sound = "Phase" }, -- 빛흉터 섬광
            { spellID = 1247937, role = "Tank",     sound = "Tank"  }, -- 암영의 채찍
            { spellID = 1252703, role = "Adds",     sound = "Adds"  }, -- 무위의 선봉대
            { spellID = 1271684, role = "Other" },                     -- 무가치한 자는 포식당하리
        },
        rules = {
            { dur = 3,     eID = 1247937 }, { dur = 5,  eID = 1249014 },
            { dur = 15,    eID = 1252703 }, { dur = 28, eID = 1264439 },
            { dur = 16.85, eID = 1247937 }, { dur = 18, eID = 1249014 },
            -- dur=15 충돌(eID=36 sync / eID=313 non-sync) → eID=36만 유지
        },
    },
    [3333] = { -- 로스락시온
        events = {
            { spellID = 1253848, role = "Heal" },                      -- 찬란한 분산
            { spellID = 1257567, role = "Mechanic", sound = "Phase" }, -- 천상의 기만
            { spellID = 1253950, role = "Tank"    , sound = "Tank"  }, -- 이글거리는 분쇄
            { spellID = 1255531, role = "Other" },                     -- 깜빡임
        },
        rules = {
            { dur = 2,  eID = 1253950 }, { dur = 11, eID = 1253848 },
            { dur = 52, eID = 1257567 }, { dur = 24, eID = 1255531 },
            { dur = 26, eID = 1253950 }, { dur = 25, eID = 1253848 }, { dur = 10, eID = 1255531 },
        },
    },

    --진균나락 (mapID 1592)
    [3159] = { -- 부식수렁
        events = {
            { spellID = 1221637, role = "Mechanic", sound = "Phase" }, -- 균류 만개
            { spellID = 1221622, role = "Mechanic", sound = "Phase" }, -- 균류 소환
            { spellID = 1221787, role = "Heal" },                      -- 농포 폭발
            { spellID = 1221781, role = "Tank",     sound = "Tank"  }, -- 부패의 주먹
            { spellID = 1222088, role = "Heal" },                      -- 부패한 덩굴
            { spellID = 1299508, role = "Mechanic", sound = "Phase" }, -- 균류인 유충
            { spellID = 1221639, role = "Mechanic", sound = "Phase" }, -- 버섯인 유충
        },
        rules = {
            { dur = 41,  eID = 1222088 }, { dur = 21, eID = 1221781 },
            { dur = 8,   eID = 1221787 }, { dur = 13, eID = 1221622 }, { dur = 114, eID = 1221637 },
            { dur = 49,  eID = 1221622, seq = 1 }, { dur = 49, eID = 1221787, seq = 2 }, { dur = 49, eID = 1222088, seq = 3 },
            { dur = 21,  eID = 1221787 }, { dur = 12, eID = 1221781 }, { dur = 13, eID = 1221781 },
        },
    },

    -- 꿈의 균열 (mapID 2939, rules 없음)
    [3306] = { -- 꿈결을 벗어난 신 카이메루스
        events = {
            { spellID = 1245404, role = "Other" },                     -- 대식가 강하
            { spellID = 1251021, role = "Heal" },                      -- 균열 발생
            { spellID = 1246621, role = "Heal" },                      -- 부식성 가래
            { spellID = 1272726, role = "Other" },                     -- 찢어지다
            { spellID = 1245452, role = "Other" },                     -- 부패와 파괴
            { spellID = 1249017, role = "Other" },                     -- 끔찍한 전쟁의 함성
            { spellID = 1249207, role = "Heal" },                      -- 불협화음의 포효
            { spellID = 1257085, role = "Mechanic", sound = "Phase" }, -- 장기를 포식
            { spellID = 1245771, role = "Other" },                     -- 부패의 깃털
            { spellID = 1262289, role = "Mechanic", sound = "Phase" }, -- 엘린더스트의 격변
            { spellID = 1260088, role = "Other" },                     -- 균열 대격변
            { spellID = 1262616, role = "Other" },                     -- 부패한 산성액
            { spellID = 1268905, role = "Mechanic", sound = "Phase" }, -- 균열의 광기
            { spellID = 1245396, role = "Heal" },                      -- 포식
            { spellID = 1280127, role = "Mechanic", sound = "Phase" }, -- 2페이즈
            { spellID = 1282001, role = "Mechanic", sound = "Phase" }, -- 엘린더스트의 격변
            { spellID = 1282856, role = "Other" },                     -- 부패와 파괴
            { spellID = 1245844, role = "Other" },                     -- 삼켜진 정수
        },
    },

    -- 공허 첨탑 (mapID 2912, rules 없음)
    [3176] = { -- 아베르지안
        events = {
            { spellID = 1262776, role = "Mechanic", sound = "Phase" }, -- 어둠의 진격
            { spellID = 1251361, role = "Mechanic", sound = "Phase" }, -- 어둠의 진격
            { spellID = 1249251, role = "Heal" },                      -- 어둠의 지각 변동
            { spellID = 1249265, role = "Mechanic", sound = "Phase" }, -- 암영 붕괴
            { spellID = 1260712, role = "Other" },                     -- 망각의 분노
            { spellID = 1258880, role = "Other" },                     -- 공허 추락
            { spellID = 1251583, role = "Other" },                     -- 끝없는 행진
            { spellID = 1255702, role = "Other" },                     -- 칠흑 보루
            { spellID = 1266786, role = "Other" },                     -- 공허 추락
            { spellID = 1270949, role = "Other" },                     -- 황폐화
            { spellID = 1280015, role = "Mechanic", sound = "Phase" }, -- 공허 징표
            { spellID = 1283069, role = "Tank"    , sound = "Tank"  }, -- 약화됨
        },
    },
    [3177] = { -- 보라시우스
        events = {
            { spellID = 1241836, role = "Tank"    , sound = "Tank"  }, -- 그림자발톱 격돌
            { spellID = 1244293, role = "Tank"    , sound = "Tank"  }, -- 그림자발톱 격돌
            { spellID = 1243853, role = "Other" },                     -- 공허의 숨결
            { spellID = 1254199, role = "Heal" },                      -- 기생충 배출
            { spellID = 1244346, role = "Other" },                     -- 거대한 투척
            { spellID = 1260046, role = "Heal" },                      -- 태고의 포효
            { spellID = 1254112, role = "Other" },                     -- 시선 고정
            { spellID = 1234346, role = "Other" },                     -- 생성
        },
    },
    [3179] = { -- 몰락한 왕 살라다르
        events = {
            { spellID = 1243453, role = "Mechanic", sound = "Phase" }, -- 공허의 수렴
            { spellID = 1260823, role = "Heal" },                      -- 폭군의 지배
            { spellID = 1245081, role = "Other" },                     -- 분열된 투영
            { spellID = 1253911, role = "Other" },                     -- 부서지는 황혼
            { spellID = 1250686, role = "Heal" },                      -- 뒤틀린 암연
            { spellID = 1246175, role = "Mechanic", sound = "Phase" }, -- 무질서의 해체
            { spellID = 64238,   role = "Other" },                     -- 광폭화
            { spellID = 1272338, role = "Other" },                     -- 맹세를 저버리다
        },
    },
    [3178] = { -- 바엘고어와 에조라크
        events = {
            { spellID = 1262623, role = "Other" },                     -- 공허 빔
            { spellID = 1244917, role = "Mechanic", sound = "Phase" }, -- 공허의 울부짖음
            { spellID = 1245391, role = "Mechanic", sound = "Phase" }, -- 안개
            { spellID = 1244221, role = "Other" },                     -- 죽은 자의 숨결
            { spellID = 1249748, role = "Heal" },                      -- 한밤의 불꽃
            { spellID = 1280458, role = "Other" },                     -- 갈고리 턱
            { spellID = 1245645, role = "Tank"    , sound = "Tank"  }, -- 락팽
            { spellID = 1265131, role = "Tank"    , sound = "Tank"  }, -- 위어의 날개
            { spellID = 1277470, role = "Mechanic", sound = "Phase" }, -- 우주 침투: 안개
            { spellID = 1277471, role = "Other" },                     -- 우주 침투: 공허 빔
            { spellID = 1277472, role = "Other" },                     -- 우주 침투: 망자의 숨결
            { spellID = 1277473, role = "Mechanic", sound = "Phase" }, -- 우주 침투: 공허의 포효
            { spellID = 1248847, role = "Mechanic", sound = "Phase" }, -- 광역 장벽
        },
    },
    [3180] = { -- 빛에 눈이 먼 선봉대
        events = {
            { spellID = 1248451, role = "Mechanic", sound = "Phase" }, -- 평화로운 후광
            --{ eventID = 72,      role = "Other" },                     -- 이벤트 72 (spellID 미확인)
            { spellID = 1249130, role = "Other" },                     -- 천둥 코끼리 돌격
            { spellID = 1248674, role = "Mechanic", sound = "Phase" }, -- 거룩한 방패
            { spellID = 1276831, role = "Heal" },                      -- 티르의 분노
            { spellID = 1246162, role = "Mechanic", sound = "Phase" }, -- 경건의 아우라
            { spellID = 1155738, role = "Heal" },                      -- 뜨거운 빛
            { spellID = 1251857, role = "Tank"    , sound = "Tank"  }, -- 심판
            { spellID = 1246485, role = "Mechanic", sound = "Phase" }, -- 복수의 방패
            { spellID = 1248644, role = "Mechanic", sound = "Phase" }, -- 거룩한 종
            { spellID = 1248449, role = "Mechanic", sound = "Phase" }, -- 분노의 아우라
            { spellID = 1246736, role = "Tank"    , sound = "Tank"  }, -- 심판
            { spellID = 1246765, role = "Mechanic", sound = "Phase" }, -- 신성한 폭풍
            { spellID = 1246749, role = "Heal" },                      -- 거룩한 죄
            { spellID = 1276368, role = "Heal" },                      -- 사형 선고
            { spellID = 1272380, role = "Mechanic", sound = "Phase" }, -- 열성적인 영혼
            { spellID = 1272423, role = "Mechanic", sound = "Phase" }, -- 열성적인 영혼
            { spellID = 1272425, role = "Mechanic", sound = "Phase" }, -- 열성적인 영혼
            { spellID = 1276635, role = "Mechanic", sound = "Phase" }, -- 복수의 방패
            { spellID = 1276639, role = "Heal" },                      -- 뜨거운 빛
            { spellID = 1272310, role = "Other" },                     -- 신성한 폭풍
        },
    },
    [3181] = { -- 우주의 왕관
        events = {
            { spellID = 1233865, role = "Heal" },                      -- 무의 왕관
            { spellID = 1233819, role = "Mechanic", sound = "Phase" }, -- 공허한 반발
            { spellID = 1233602, role = "Mechanic", sound = "Phase" }, -- 은화살
            { spellID = 1234564, role = "Other" },                     -- 은화살 탄막
            { spellID = 1235622, role = "Other" },                     -- 특이점 폭발
            { spellID = 1237035, role = "Heal" },                      -- 공허추적자 스파이크
            { spellID = 1237837, role = "Mechanic", sound = "Phase" }, -- 공허의 부름
            { spellID = 1237614, role = "Heal" },                      -- 레인저 캡틴의 마크
            { spellID = 1246918, role = "Heal" },                      -- 우주 장벽
            { spellID = 1239080, role = "Mechanic", sound = "Phase" }, -- 최종 수호자
            { spellID = 1232467, role = "Heal" },                      -- 공허함의 파악
            { spellID = 1238843, role = "Mechanic", sound = "Phase" }, -- 우주를 삼켜라
            { spellID = 1243787, role = "Tank"    , sound = "Tank"  }, -- 어둠의 손
            { spellID = 1243753, role = "Mechanic", sound = "Phase" }, -- 폭식의 심연
            { spellID = 1243743, role = "Heal" },                      -- 간섭 진동
            { spellID = 1260010, role = "Heal" },                      -- 레인저 캡틴의 마크
            { spellID = 1260026, role = "Heal" },                      -- 공허함의 파악
            { spellID = 1261016, role = "Mechanic", sound = "Phase" }, -- 균열 환영
            { spellID = 1261339, role = "Mechanic", sound = "Phase" }, -- 우주 포털
            { spellID = 1246461, role = "Tank"    , sound = "Tank"  }, -- 균열 베기
            { spellID = 1239582, role = "Other" },                     -- 우주 에너지 과부하
        },
    },

    -- 쿠엘다나스 진격로 (mapID 2913, rules 없음)
    [3182] = { -- 알라르의 자손 벨로렌
        events = {
            { spellID = 1241282, role = "Mechanic", sound = "Phase" }, -- 벨로란의 불씨
            { spellID = 1242981, role = "Mechanic", sound = "Phase" }, -- 빛나는 메아리
            { spellID = 1260763, role = "Tank"    , sound = "Tank"  }, -- 수호자 칙령
            { spellID = 1244344, role = "Heal" },                      -- 영원한 소각
            { spellID = 1242260, role = "Mechanic", sound = "Phase" }, -- 주입된 깃털
            { spellID = 1242515, role = "Heal" },                      -- 공허빛 합류
            { spellID = 1246709, role = "Mechanic", sound = "Phase" }, -- 죽음의 낙하
            { spellID = 1242792, role = "Other" },                     -- 화염 부화
            { spellID = 1241992, role = "Mechanic", sound = "Phase" }, -- 성광의 깃털
            { spellID = 1242091, role = "Mechanic", sound = "Phase" }, -- 공허의 깃털
            --{ eventID = 417,     role = "Other" },                     -- 이벤트 417 (spellID 미확인)
            --{ eventID = 418,     role = "Other" },                     -- 이벤트 418 (spellID 미확인)
            { spellID = 1241162, role = "Mechanic", sound = "Phase" }, -- 성광의 깃털
            { spellID = 1241163, role = "Mechanic", sound = "Phase" }, -- 공허의 깃털
            { spellID = 1241292, role = "Heal" },                      -- 성광의 급습
            { spellID = 1241339, role = "Heal" },                      -- 공허 강하
            { spellID = 1241313, role = "Mechanic", sound = "Phase" }, -- 부활
            { spellID = 1241267, role = "Mechanic", sound = "Phase" }, -- 공허빛의 분노
            { spellID = 1241320, role = "Other" },                     -- 부활
        },
    },
    [3183] = { -- 한밤의 도래
        events = {
            { spellID = 1244412, role = "Mechanic", sound = "Phase" }, -- 죽음의 만가
            { spellID = 1253915, role = "Other" },                     -- 하늘의 대검
            { spellID = 1251386, role = "Other" },                     -- 수호 각기둥
            { spellID = 1249796, role = "Heal" },                      -- 부서진 하늘
            { spellID = 1261871, role = "Heal" },                      -- 개기일식
            { spellID = 1266622, role = "Mechanic", sound = "Phase" }, -- 가장 어두운 밤
            { spellID = 1266897, role = "Mechanic", sound = "Phase" }, -- 빛의 사이펀
            { spellID = 1266388, role = "Other" },                     -- 어두운 별자리
            { spellID = 1250898, role = "Other" },                     -- 암흑 대천사
            { spellID = 1273158, role = "Mechanic", sound = "Phase" }, -- 죽음의 레퀴엠
            { spellID = 1276202, role = "Heal" },                      -- 연결 끊기
            { spellID = 1267049, role = "Tank"    , sound = "Tank"  }, -- 하늘의 창
            { spellID = 1282047, role = "Mechanic", sound = "Phase" }, -- 어둠의 우물 깊이
            { spellID = 1282249, role = "Heal" },                      -- 우주 핵분열
            { spellID = 1282412, role = "Heal" },                      -- 핵심 수확
            { spellID = 1281194, role = "Other" },                     -- 암흑 붕괴
            { spellID = 1282441, role = "Heal" },                      -- 별조각
            { spellID = 1284525, role = "Heal" },                      -- 충전
            { spellID = 1284931, role = "Other" },                     -- 종단 각기둥
            { spellID = 1284980, role = "Mechanic", sound = "Phase" }, -- 말살 협주곡
            { spellID = 1279420, role = "Other" },                     -- 암흑 퀘이사
            { spellID = 1249609, role = "Heal" },                      -- 어두운 룬
            { spellID = 1295191, role = "Other" },                     -- 불협의 자장가
        },
    },

    -- 한밤의 전쟁 2시즌
    -- 왕들의 안식처 (mapID 1762)
    [2139] = { -- 황금 독사
        events = {
            { spellID = 265773,  role = "Other"                     }, -- 황금 분사
            { spellID = 265910,  role = "Tank",     sound = "Tank"  }, -- 꼬리 강타
            { spellID = 1311987, role = "Heal",     sound = "AOE"   }, -- 뱀의 바람
            { spellID = 265923,  role = "Mechanic", sound = "Phase" }, -- 루체의 소환
        },
    },
    [2142] = { -- 흑멸자 무친바
        events = {
            { spellID = 1311956, role = "Other"                     }, -- 불타는 부패
            { spellID = 267702,  role = "Mechanic", sound = "Phase" }, -- 매장
            { spellID = 267618,  role = "Other"                     }, -- 체액 배출
            { spellID = 1312146, role = "Adds",     sound = "Adds"  }, -- 각성 강타
        },
    },
    [2140] = { -- 부족 의회
        events = {
            { spellID = 266206,  role = "Other"                     }, -- 회전 날도끼
            { spellID = 266231,  role = "Other"                     }, -- 참수 도끼
            { spellID = 267494,  role = "Mechanic", sound = "Phase" }, -- 구르기
            { spellID = 266237,  role = "Tank",     sound = "Tank"  }, -- 약화 채찍질
            { spellID = 1305810, role = "Other"                     }, -- 전기 방전
            { spellID = 267273,  role = "Mechanic", sound = "Interrupt" }, -- 독성 신성
            { spellID = 267060,  role = "Mechanic", sound = "Phase" }, -- 정령 소환
        },
    },
    [2143] = { -- 다사 대왕
        events = {
            { spellID = 1303115, role = "Other"                     }, -- 허공 강타
            { spellID = 268586,  role = "Tank",     sound = "Tank"  }, -- 칼날 연타
            { spellID = 1303267, role = "Mechanic", sound = "Phase" }, -- 황금 파멸
            { spellID = 269230,  role = "Other",    sound = "Frontal" }, -- 사냥 도약
            { spellID = 1303488, role = "Tank",     sound = "Tank"  }, -- 야만 망치
        },
    },

    -- 세스랄리스 사원 (mapID 1877)
    [2124] = { -- 아드리스와 아스픽스
        events = {
            { spellID = 1288049, role = "Heal",     sound = "AOE"   }, -- 번개와 천둥
            { spellID = 1311804, role = "Heal",     sound = "AOE"   }, -- 과부하
            { spellID = 1311805, role = "Other"                     }, -- 폭풍
            { spellID = 1289059, role = "Heal",     sound = "AOE"   }, -- 강풍의 힘
            { spellID = 1289754, role = "Other"                     }, -- 폭풍
            { spellID = 1292518, role = "Heal",     sound = "AOE"   }, -- 번개와 천둥
        },
    },
    [2125] = { -- 밀리크사
        events = {
            { spellID = 264172,  role = "Mechanic", sound = "Phase" }, -- 굴파기
            { spellID = 1290029, role = "Other"                     }, -- 뱀 무리 휘감기
            { spellID = 1289109, role = "Other"                     }, -- 뇌격 분사
            { spellID = 1289205, role = "Mechanic", sound = "Adds"  }, -- 부화
            { spellID = 1290797, role = "Tank",     sound = "Tank"  }, -- 번개 물어뜯기
            { spellID = 1293048, role = "Heal",     sound = "AOE"   }, -- 독사 폭풍
        },
    },
    [2126] = { -- 가바즈트
        events = {
            { spellID = 1309525, role = "Heal",     sound = "AOE"   }, -- 유도
            { spellID = 1291618, role = "Mechanic", sound = "Phase" }, -- 번개 첨탑
        },
    },
    [2127] = { -- 세트랄리스의 화신
        events = {
            { spellID = 1301963, role = "Other"                     }, -- 정화
            { spellID = 1301202, role = "Other"                     }, -- 오염된 오물
        },
    },

    -- 루비 생명의 웅덩이 (mapID 2521)
    [2609] = { -- 메리두사 한빙
        events = {
            { spellID = 1307297, role = "Other"                     }, -- 우박 폭발
            { spellID = 1307308, role = "Heal",     sound = "AOE"   }, -- 서리 바람
            { spellID = 373686,  role = "Mechanic", sound = "Phase" }, -- 서리 과부하
            { spellID = 373046,  role = "Mechanic", sound = "Adds"  }, -- 어린 용 소환
        },
    },
    [2606] = { -- 코쿠야 염제
        events = {
            { spellID = 372864,  role = "Heal",     sound = "AOE"   }, -- 불꽃 포박 의식
            { spellID = 372110,  role = "Mechanic", sound = "Phase" }, -- 용암 바위
            { spellID = 372858,  role = "Tank",     sound = "Tank"  }, -- 작열하는 타격
        },
    },
    [2623] = { -- 기라카와 에르크하트
        events = {
            { spellID = 381516,  role = "Mechanic", sound = "Phase"   }, -- 폭풍우 저지
            { spellID = 381517,  role = "Mechanic", sound = "Phase"   }, -- 변화하는 바람
            { spellID = 381512,  role = "Tank",     sound = "Tank"    }, -- 폭풍 강타
            { spellID = 381602,  role = "Other"                       }, -- 화염 분사
            { spellID = 381525,  role = "Other",    sound = "Frontal" }, -- 포효 화염 숨결
            { spellID = 381605,  role = "Other"                       }, -- 화염 분사
        },
    },

    -- 죽음의 골목 (mapID 2813)
    [3101] = { -- 케스티아 마력심장
        events = {
            { spellID = 1264095, role = "Mechanic", sound = "Phase"   }, -- 거울 형상
            { spellID = 1253811, role = "Other",    sound = "Frontal" }, -- 마력 비산
            { spellID = 474240,  role = "Other"                       }, -- 마력 신성
            { spellID = 1230304, role = "Mechanic", sound = "Phase"   }, -- 빛 주입
        },
    },
    [3102] = { -- 잔 인부슬픔
        events = {
            { spellID = 1214357, role = "Other"                     }, -- 화염 폭탄
            { spellID = 474765,  role = "Other"                     }, -- 당일 배송
            { spellID = 1218347, role = "Mechanic", sound = "Phase" }, -- 절명 흉계
            { spellID = 474478,  role = "Heal",     sound = "AOE"   }, -- 그림자 춤 발걸음
            { spellID = 1222795, role = "Tank",     sound = "Tank"  }, -- 독 상처
        },
    },
    [3103] = { -- 섬멸자 사주크스
        events = {
            { spellID = 473898,  role = "Tank",     sound = "Tank"  }, -- 군단 타격
            { spellID = 474197,  role = "Mechanic", sound = "Phase" }, -- 마력 광분
            { spellID = 1214641, role = "Other"                     }, -- 날선 도끼 투척
            { spellID = 1295452, role = "Heal",     sound = "AOE"   }, -- 지옥 화염 압궤
        },
    },
    [3105] = { -- 리히르 잔분노
        events = {
            { spellID = 1218203, role = "Heal",     sound = "AOE"  }, -- 굴단의 손가락
            { spellID = 474408,  role = "Mechanic", sound = "Adds" }, -- 마왕 개 소환
            { spellID = 1224478, role = "Mechanic", sound = "Phase" }, -- 재앙의 파도
        },
    },

    -- 날로라크의 소굴 (mapID 2825)
    [3207] = { -- 보물도둑
        events = {
            { spellID = 1234233, role = "Heal",     sound = "AOE"    }, -- 부패한 보급
            { spellID = 1253268, role = "Other",    sound = "Frontal" }, -- 대지 가르기
            { spellID = 1235118, role = "Heal",     sound = "AOE"    }, -- 탐욕의 포효
        },
    },
    [3208] = { -- 혹한 보초
        events = {
            { spellID = 1235548, role = "Other",    sound = "Dispel" }, -- 빙하 고통
            { spellID = 1235623, role = "Other"                      }, -- 격노한 돌풍
            { spellID = 1235783, role = "Mechanic", sound = "Adds"   }, -- 얼음 가시 분쇄
            { spellID = 1235656, role = "Heal",     sound = "AOE"    }, -- 차가운 얼음 폭우
        },
    },
    [3209] = { -- 날로라크
        events = {
            { spellID = 1255385, role = "Other"                     }, -- 강력한 포효
            { spellID = 1242860, role = "Other"                     }, -- 메아리치는 강타
            { spellID = 1243011, role = "Mechanic", sound = "Phase" }, -- 전쟁의 신의 분노
            { spellID = 1243569, role = "Mechanic", sound = "Phase" }, -- 압도적 강공
            { spellID = 1262846, role = "Other"                     }, -- 영혼 채찍질
        },
    },

    -- 눈부신 골짜기 (mapID 2859)
    [3199] = { -- 빛의 꽃들
        events = {
            { spellID = 1234753, role = "Tank",     sound = "Tank"    }, -- 기반암 강타
            { spellID = 1234850, role = "Mechanic", sound = "Phase"   }, -- 빛의 급습
            { spellID = 1235640, role = "Other"                       }, -- 가시 칼날
            { spellID = 1261276, role = "Other"                       }, -- 가시 칼날
            { spellID = 1235564, role = "Mechanic", sound = "Phase"   }, -- 빛의 꽃 광선
        },
    },
    [3200] = { -- 성광 사냥꾼 이쿠즈
        events = {
            { spellID = 1236746, role = "Heal",  sound = "AOE" }, -- 초록 짓밟기
            { spellID = 1236709, role = "Heal",  sound = "AOE" }, -- 가시 소환사 포효
            { spellID = 1237090, role = "Other"                }, -- 살기의 응시
        },
    },
    [3201] = { -- 수광자 루이야
        events = {
            { spellID = 1239824, role = "Mechanic", sound = "Phase"   }, -- 빛의 불꽃
            { spellID = 1240098, role = "Other"                       }, -- 빛의 낙하
            { spellID = 1240210, role = "Other",    sound = "Frontal" }, -- 분쇄 강타
            { spellID = 1241058, role = "Heal",     sound = "AOE"    }, -- 잔혹한 강타
            { spellID = 1239885, role = "Mechanic", sound = "Phase"   }, -- 변형: 곰
            { spellID = 1239882, role = "Mechanic", sound = "Phase"   }, -- 변형: 부엉이곰
            { spellID = 1239883, role = "Mechanic", sound = "Phase"   }, -- 변형: 할라이니르
            { spellID = 1241067, role = "Mechanic", sound = "Phase"   }, -- 협곡의 영
        },
    },
    [3202] = { -- 즈요케트
        events = {
            { spellID = 1246372, role = "Mechanic", sound = "Phase" }, -- 빛 폭발 깨우기
            { spellID = 1247685, role = "Tank",     sound = "Tank"  }, -- 가시
            { spellID = 1246607, role = "Other"                     }, -- 응집 광선
            { spellID = 1246858, role = "Heal",     sound = "AOE"   }, -- 빛 폭발 정수
        },
    },

    -- 공허흉터 투기장 (mapID 2923)
    [3285] = { -- 타즈라르
        events = {
            { spellID = 1297017, role = "Tank",     sound = "Tank"  }, -- 공허 충격
            { spellID = 1262901, role = "Other"                     }, -- 암영 집결
            { spellID = 1300259, role = "Other"                     }, -- 어둠 폭발
            { spellID = 1225011, role = "Mechanic", sound = "Phase" }, -- 공허 영혼 파편
            { spellID = 1222098, role = "Mechanic", sound = "Phase" }, -- 유령 돌진
            { spellID = 1296963, role = "Other"                     }, -- 유령 파열
        },
    },
    [3286] = { -- 아트로수스
        events = {
            { spellID = 1222371, role = "Mechanic", sound = "Adds"   }, -- 격노한 기어가는 자
            { spellID = 1222642, role = "Tank",     sound = "Tank"   }, -- 거대한 발톱 타격
            { spellID = 1222721, role = "Other",    sound = "Frontal" }, -- 독성 숨결
            { spellID = 1226120, role = "Heal",     sound = "AOE"    }, -- 독액 분사
            { spellID = 1262497, role = "Heal",     sound = "AOE"    }, -- 엄청난 포효
        },
    },
    [3287] = { -- 사로누스
        events = {
            { spellID = 1282770, role = "Mechanic", sound = "Phase"   }, -- 불안정한 특이점
            { spellID = 1227264, role = "Heal",     sound = "AOE"    }, -- 별 낙하 강타
            { spellID = 1263982, role = "Mechanic", sound = "Phase"   }, -- 중력 보주
            { spellID = 1222758, role = "Other",    sound = "Frontal" }, -- 공허 급류
            { spellID = 1311923, role = "Tank",     sound = "Tank"   }, -- 암영의 파도
        },
    },

    -- 송곳니의 제단 (mapID 2993)
    [3456] = { -- 라비
        events = {
            { spellID = 1309522, role = "Mechanic", sound = "Phase"   }, -- 쉭쉭거리는 탐식
            { spellID = 1296219, role = "Other"                       }, -- 악취 포효
            { spellID = 1296220, role = "Heal",     sound = "AOE"    }, -- 삼중 분사
            { spellID = 1296050, role = "Other",    sound = "Frontal" }, -- 되새김
            { spellID = 1307894, role = "Mechanic", sound = "Phase"   }, -- 탐욕 짓밟기
        },
    },
    [3457] = { -- 뒤틀린 반뱀
        events = {
            { spellID = 1299154, role = "Heal",     sound = "AOE"       }, -- 동기화 독액
            { spellID = 1298949, role = "Tank",     sound = "Tank"      }, -- 낫 꼬리
            { spellID = 1299940, role = "Other"                         }, -- 복수 맹공
            { spellID = 1299053, role = "Mechanic", sound = "Phase"     }, -- 빈사 헐떡임
            { spellID = 1310357, role = "Other",    sound = "Interrupt" }, -- 극독 탄막
            { spellID = 1310547, role = "Other",    sound = "Interrupt" }, -- 극독 위축
        },
    },
    [3458] = { -- 줄가
        events = {
            { spellID = 1301413, role = "Other"                     }, -- 뼈 베는 자
            { spellID = 1300876, role = "Mechanic", sound = "Phase" }, -- 독아 의식
            { spellID = 1301111, role = "Mechanic", sound = "Phase" }, -- 도끼 파쇄
            { spellID = 1301350, role = "Tank",     sound = "Tank"  }, -- 베어 쓰러뜨리기
        },
    },

    -- 한밤의 전쟁 2시즌 레이드
    -- 파도속박 석굴 (mapID 2987)
    [3379] = { -- 파도 부르는 자 니므레샤
        events = {
            { spellID = 1257608, role = "Other"                     }, -- 서리 탄막
            { spellID = 1257717, role = "Mechanic", sound = "Phase" }, -- 유혹하는 물방울
            { spellID = 1258668, role = "Mechanic", sound = "Phase" }, -- 격동하는 소용돌이
            { spellID = 1260837, role = "Other"                     }, -- 심연의 비
            { spellID = 1276710, role = "Mechanic", sound = "Phase" }, -- 유혹하는 물방울
            { spellID = 1313393, role = "Other"                     }, -- 뼛속을 파고드는 한기
        },
    },

    -- 맹독의 심연 (mapID 3004)
    [3470] = { -- 영혼 감는 자 내크잘리
        events = {
            { spellID = 1287426, role = "Other"                     }, -- 정수 찢기
            { spellID = 1285681, role = "Mechanic", sound = "Phase" }, -- 영혼 감기 점화
            { spellID = 1289923, role = "Mechanic", sound = "Phase" }, -- 경건한 소환
            { spellID = 1295397, role = "Mechanic", sound = "Phase" }, -- 잠들지 않는 아마니
            { spellID = 1290679, role = "Other"                     }, -- 복수의 울부짖음
            { spellID = 1292036, role = "Other"                     }, -- 빙의 탄막
            { spellID = 1290001, role = "Other"                     }, -- 똬리 풀기
            { spellID = 1299673, role = "Mechanic", sound = "Phase" }, -- 기원
            { spellID = 1305421, role = "Other"                     }, -- 흡멸의 불꽃
        },
    },
    [3445] = { -- 능묘 보초
        events = {
            { spellID = 1284251, role = "Other"                     }, -- 독액 응고
            { spellID = 1284434, role = "Other"                     }, -- 극독 물방울
            { spellID = 1284458, role = "Other"                     }, -- 강화 강타
            { spellID = 1284487, role = "Other"                     }, -- 선혈 독액 주사
            { spellID = 1284483, role = "Other"                     }, -- 시듦의 피
            { spellID = 1284485, role = "Other"                     }, -- 약화 독기
            { spellID = 1284588, role = "Mechanic", sound = "Phase" }, -- 강산 정체
            { spellID = 26662,   role = "Mechanic", sound = "Phase" }, -- 광분
            { spellID = 1288232, role = "Other"                     }, -- 불안정한 독기
            { spellID = 1296878, role = "Mechanic", sound = "Phase" }, -- 변화하는 원형 독액
        },
    },
    [3497] = { -- 길 잃은 탐험가
        events = {
            { spellID = 1291390, role = "Mechanic", sound = "Phase" }, -- 재앙 기원
            { spellID = 1296025, role = "Other"                     }, -- 번쩍이는 신성
            { spellID = 1296092, role = "Other"                     }, -- 거대한 힘의 강타
            { spellID = 1295817, role = "Mechanic", sound = "Phase" }, -- 물고기 던지기
            { spellID = 1292104, role = "Mechanic", sound = "Phase" }, -- 버섯 투척
            { spellID = 1295854, role = "Other"                     }, -- 찢겨진 파편
            { spellID = 1295886, role = "Other"                     }, -- 서리불꽃 연사
            { spellID = 1295935, role = "Other"                     }, -- 서리불꽃 연사
            { spellID = 1297625, role = "Mechanic", sound = "Phase" }, -- 폭발 서프라이즈
            { spellID = 1292779, role = "Mechanic", sound = "Phase" }, -- 최후의 승천
        },
    },
    [3455] = { -- 만독 저주술사 바슈니크
        events = {
            { spellID = 1280935, role = "Other"                     }, -- 독 흐르는 이빨
        },
    },
    [3420] = { -- 스소락
        events = {
            { spellID = 1285425, role = "Other"                     }, -- 분노하는 측면 바람
            { spellID = 1305959, role = "Mechanic", sound = "Phase" }, -- 극독 용솟음
            { spellID = 1277025, role = "Other"                     }, -- 최상위 포식자
            { spellID = 1285732, role = "Mechanic", sound = "Phase" }, -- 포효하는 소용돌이
            { spellID = 1296898, role = "Mechanic", sound = "Phase" }, -- 억제할 수 없는 분노
        },
    },
    [3421] = { -- 쌍둥이 독아
        events = {
            { spellID = 1289192, role = "Other"                     }, -- 부식하는 홍수
            { spellID = 1288484, role = "Other"                     }, -- 쇄석 강타
            { spellID = 1294293, role = "Mechanic", sound = "Phase" }, -- 사악한 홍수
            { spellID = 1294921, role = "Mechanic", sound = "Phase" }, -- 홍수
            { spellID = 1290956, role = "Other"                     }, -- 심연 휘젓기
            { spellID = 1290809, role = "Other"                     }, -- 똬리 고름
            { spellID = 1291404, role = "Adds",     sound = "Adds"  }, -- 극독 용솟음
            { spellID = 1290516, role = "Mechanic", sound = "Phase" }, -- 탐욕의 잔치
            { spellID = 1291478, role = "Other"                     }, -- 부식하는 침
            { spellID = 1303230, role = "Other"                     }, -- 선혈 홍수
            { spellID = 1306872, role = "Mechanic", sound = "Phase" }, -- 핏빛 폭풍
            { spellID = 1308356, role = "Other"                     }, -- 자식 깨우기
            { spellID = 1308556, role = "Mechanic", sound = "Phase" }, -- 잠수
        },
    },
    [3429] = { -- 똬리 제단
        events = {
            { spellID = 1285911, role = "Other"                     }, -- 불안하게 하는 응시
            { spellID = 1287227, role = "Other"                     }, -- 시듦 독소
            { spellID = 1287200, role = "Other"                     }, -- 시듦 독소
            { spellID = 1282487, role = "Other"                     }, -- 똬리 제단의 이빨
            { spellID = 1298381, role = "Other"                     }, -- 똬리 제단의 더럽힘
            { spellID = 1283485, role = "Other"                     }, -- 처형
            { spellID = 1299266, role = "Other"                     }, -- 냉혹한 처형
            { spellID = 1286918, role = "Mechanic", sound = "Phase" }, -- 영원한 밤의 장막
            { spellID = 1289900, role = "Other"                     }, -- 공포의 행군
            { spellID = 1286573, role = "Other"                     }, -- 영혼 찢기
            { spellID = 1286441, role = "Other"                     }, -- 정령 광소
            { spellID = 1299680, role = "Other"                     }, -- 찢기
            { spellID = 1299960, role = "Other"                     }, -- 극독 홍수
            { spellID = 1307279, role = "Other"                     }, -- 시듦 찢기
        },
    },
    [3492] = { -- 울라테크
        events = {
            { spellID = 1298367, role = "Mechanic", sound = "Phase" }, -- 뱀 어미의 분노
            { spellID = 1311037, role = "Mechanic", sound = "Phase" }, -- 뱀 어미의 분노
            { spellID = 1286860, role = "Mechanic", sound = "Phase" }, -- 결박된 분노
            { spellID = 1292188, role = "Mechanic", sound = "Phase" }, -- 부식하는 조류
            { spellID = 1286905, role = "Mechanic", sound = "Phase" }, -- 분노의 불꽃 해방
            { spellID = 1298559, role = "Mechanic", sound = "Phase" }, -- 피비린내 나는 방울뱀 꼬리
            { spellID = 1304527, role = "Mechanic", sound = "Phase" }, -- 피비린내 나는 방울뱀 꼬리
            { spellID = 1295905, role = "Other"                     }, -- 독사의 물기
            { spellID = 1299757, role = "Other"                     }, -- 극독 부화
            { spellID = 1300530, role = "Other"                     }, -- 유령 똬리
            { spellID = 1300751, role = "Other"                     }, -- 독사 소환
            { spellID = 1301510, role = "Mechanic", sound = "Phase" }, -- 감고 조르는 먹이
            { spellID = 1302982, role = "Other"                     }, -- 극독 분사
            { spellID = 1296301, role = "Other"                     }, -- 악취 강타
            { spellID = 1287265, role = "Other"                     }, -- 유령 똬리
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
    [1592] = { 3159 },                                -- 진균나락
    [1753] = { 2065, 2066, 2067, 2068 },              -- 삼두정의 권좌
    [2526] = { 2562, 2563, 2564, 2565 },              -- 알게타르 대학
    [2805] = { 3056, 3057, 3058, 3059 },              -- 윈드러너 첨탑
    [2811] = { 3071, 3072, 3073, 3074 },              -- 마법학자의 정원
    [2874] = { 3212, 3213, 3214 },                    -- 마이사라 동굴
    [2912] = { 3176, 3177, 3179, 3178, 3180, 3181 },  -- 공허 첨탑
    [2913] = { 3182, 3183 },                          -- 쿠엘다나스 진격로
    [2915] = { 3328, 3332, 3333 },                    -- 공결탑 제나스
    [2939] = { 3306 },                                -- 꿈의 균열
    [1762] = { 2139, 2142, 2140, 2143 },              -- 왕들의 안식처
    [1877] = { 2124, 2125, 2126, 2127 },              -- 세스랄리스 사원
    [2521] = { 2609, 2606, 2623 },                    -- 루비 생명의 웅덩이
    [2813] = { 3101, 3102, 3103, 3105 },              -- 죽음의 골목
    [2825] = { 3207, 3208, 3209 },                    -- 날로라크의 소굴
    [2859] = { 3199, 3200, 3201, 3202 },              -- 눈부신 골짜기
    [2923] = { 3285, 3286, 3287 },                    -- 공허흉터 투기장
    [2993] = { 3456, 3457, 3458 },                    -- 송곳니의 제단
    [2987] = { 3379 },                                -- 파도속박 석굴
    [3004] = { 3470, 3445, 3497, 3455, 3420, 3421, 3429, 3492 },  -- 맹독의 심연
}
