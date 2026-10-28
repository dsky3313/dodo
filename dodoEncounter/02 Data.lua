-- ==============================
-- 설정 및 테이블
-- ==============================
---@diagnostic disable: lowercase-global, param-type-mismatch, redundant-parameter, undefined-field, undefined-global
local dodo = _G.dodo

-- eventID > spellID 역조회 매크로
-- /run local t={298,299,300,301} for _,id in ipairs(t) do local i=C_EncounterEvents.GetEventInfo(id) print(id.."→"..(i and tostring(i.spellID) or "nil")) end

-- 스킬명 조회 매크로
-- /run local t={1301111,1301350} for _,id in ipairs(t) do print(id, C_Spell.GetSpellName(id)) end


-- role 기준으로 타임라인 막대 색상 자동 적용
-- sound = "Tank" 지정하면 "탱커" 텍스트 자동. text 필드로 오버라이드 가능.
-- sound 필드 수동 지정 필요 → 없으면 무음.

---@class EncounterEvent
---@field eventID number
---@field role "Tank"|"Heal"|"Phase"|"Adds"|"ETC"|"Other"
---@field sound "Adds"|"AOE"|"Dispel"|"Dodge"|"Frontal"|"Intermission"|"Interrupt"|"Phase"|"Pool"|"Share"|"Soak"|"Spread"|"Tank"|"Wave"
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
    -- 격아
    -- 왕들의 안식처 (mapID 1762)
    [2139] = { -- 황금 날뱀
        events = {
            { spellID = 265773,  role = "Other"                         }, -- 황금 뱉기
            { spellID = 265910,  role = "Tank",  sound = "Tank"         }, -- 꼬리 난타
            { spellID = 1311987, role = "Heal",  sound = "AOE"          }, -- 구불구불 돌풍
            { spellID = 265923,  role = "Phase", sound = "Intermission" }, -- 더러운 돈의 부름
        },
        rules = {
            { dur = 5,  eID = 265773  }, { dur = 8,  eID = 265910 },
            { dur = 14, eID = 1311987 }, { dur = 54, eID = 265923 },
            { dur = 28, eID = 1311987 },
            { dur = 25, eID = 265773, seq = 1 }, { dur = 25, eID = 265910, seq = 2 },
        },
    },
    [2142] = { -- 장의사 음침바
        events = {
            { spellID = 1311956, role = "Other"                         }, -- 부패 태우기
            { spellID = 267702,  role = "Phase", sound = "Intermission" }, -- 매장
            { spellID = 267618,  role = "Other"                         }, -- 체액 흡수
            { spellID = 1312146, role = "Adds",  sound = "Adds"         }, -- 각성의 격돌
        },
        rules = {
            { dur = 5,  eID = 267618  },
            { dur = 20, eID = 1311956 },
            { dur = 30, eID = 1312146, seq = 1 }, { dur = 30, eID = 1311956, seq = 2 },
            { dur = 32, eID = 267618  }, { dur = 60, eID = 267702  },
        },
    },
    [2140] = { -- 부족 의회
        events = {
            { spellID = 266206,  role = "Other"                         }, -- 회오리 도끼
            { spellID = 266231,  role = "Other"                         }, -- 무쇠날 도끼
            { spellID = 267494,  role = "Phase", sound = "Intermission" }, -- 질주 돌파
            { spellID = 266237,  role = "Tank",  sound = "Tank"         }, -- 쇠약의 손등치기
            { spellID = 1305810, role = "Other"                         }, -- 굽이치는 번개
            { spellID = 267273,  role = "Phase", sound = "Interrupt"    }, -- 독 회오리
            { spellID = 267060,  role = "Phase", sound = "Intermission" }, -- 정령의 부름
        },
        rules = {
            { dur = 8,  eID = 266206  }, { dur = 15, eID = 266231  }, -- P1
            { dur = 5,  eID = 267494  }, { dur = 14, eID = 266237  }, -- P2
            { dur = 2,  eID = 1305810 }, { dur = 10, eID = 267273  }, { dur = 20, eID = 267060 }, -- P3
        },
    },
    [2143] = { -- 초대 왕 다자르
        events = {
            { spellID = 1303115, role = "Other"                         }, -- 공중 강타
            { spellID = 268586,  role = "Tank",  sound = "Tank"         }, -- 칼날 연계
            { spellID = 1303267, role = "Phase", sound = "Intermission" }, -- 금빛 폭발
            { spellID = 269230,  role = "Other", sound = "Frontal"      }, -- 사냥의 도약
            { spellID = 1303488, role = "Tank",  sound = "Tank"         }, -- 야만의 후려갈기기
        },
        rules = {
            { dur = 8,  eID = 269230  }, { dur = 15, eID = 1303115 }, { dur = 23, eID = 268586  }, { dur = 30, eID = 1303267 },
            { dur = 10, eID = 269230  },
            { dur = 24, eID = 1303267 }, { dur = 36, eID = 1303488 }, { dur = 38, eID = 268586  }, -- P2
        },
    },

    -- 세스랄리스 사원 (mapID 1877)
    [2124] = { -- 애더리스와 아스픽스
        events = {
            { spellID = 1288049, role = "Heal",  sound = "Soak" }, -- 천둥과 번개
            { spellID = 1311804, role = "Tank",  sound = "Tank" }, -- 과부하
            { spellID = 1311805, role = "Other", sound = "Pool" }, -- 뇌우의 바람
            { spellID = 1289059, role = "Heal",  sound = "AOE"  }, -- 풍력
            { spellID = 1289754, role = "Other"                 }, -- 뇌우의 바람
            { spellID = 1292518, role = "Heal",  sound = "AOE"  }, -- 천둥과 번개
        },
        rules = {
            { dur = 5,  eID = 1289059 }, { dur = 9,  eID = 1288049 }, { dur = 29, eID = 1311805 }, { dur = 39, eID = 1311804 },
            { dur = 45, eID = 1289059, seq = 1 }, { dur = 45, eID = 1288049, seq = 2 },
            { dur = 45, eID = 1311805, seq = 3 }, { dur = 45, eID = 1311804, seq = 4 },
            { dur = 12, eID = 1311805 }, -- P2
            { dur = 19, eID = 1289059, seq = 1 }, { dur = 19, eID = 1311805, seq = 2 }, -- P2 loop
        },
    },
    [2125] = { -- 메레크타
        events = {
            { spellID = 264172,  role = "Phase", sound = "Intermission"             }, -- 잠복
            { spellID = 1290029, role = "Other",                        text = "CC" }, -- 뱀들의 똬리
            { spellID = 1289109, role = "Other", sound = "Pool"                     }, -- 천둥 타액
            { spellID = 1289205, role = "Other"                                     }, -- 부화
            { spellID = 1290797, role = "Tank",  sound = "Tank"                     }, -- 번개 물기
            { spellID = 1293048, role = "Heal",  sound = "AOE"                      }, -- 뱀의 폭풍
        },
        rules = {
            { dur = 5,  eID = 1290797 }, { dur = 13, eID = 1290029 }, { dur = 25, eID = 1289109 },
            { dur = 36, eID = 1293048 }, { dur = 44, eID = 1289205 }, { dur = 49, eID = 264172  },
        },
    },
    [2126] = { -- 갈바즈트
        events = {
            { spellID = 1309525, role = "Heal",  sound = "AOE"          }, -- 전기 유도
            { spellID = 1291618, role = "Phase", sound = "Intermission" }, -- 번개의 첨탑
        },
        rules = {
            { dur = 5,  eID = 1291618 }, { dur = 20, eID = 1309525 },
            { dur = 22, eID = 1291618, seq = 1 }, { dur = 22, eID = 1309525, seq = 2 },
        },
    },
    [2127] = { -- 세스랄리스의 화신
        events = {
            { spellID = 1301963, role = "Other"                }, -- 청소 완료
            { spellID = 1301202, role = "Adds", sound = "Adds" }, -- 모독의 오염
        },
        rules = {
            { dur = 15, eID = 1301202 },
        },
    },


    -- 용군단
    -- 루비 생명의 웅덩이 (mapID 2521)
    [2609] = { -- 멜리드루사 칠원
        events = {
            { spellID = 1307297, role = "Other", sound = "Pool"         }, -- 우박파열
            { spellID = 1307308, role = "Heal",  sound = "Pool"         }, -- 냉기폭풍
            { spellID = 373686,  role = "Phase", sound = "Intermission" }, -- 서리 과부하
            { spellID = 373046,  role = "Phase", sound = "Adds"         }, -- 새끼용 깨우기
        },
        rules = {
            { dur = 5,  eID = 1307297 }, { dur = 12, eID = 373686  }, { dur = 15, eID = 1307308 },
            { dur = 24, eID = 1307297, seq = 1 }, { dur = 24, eID = 1307308, seq = 2 },
        },
    },
    [2606] = { -- 코키아 블레이즈후프
        events = {
            { spellID = 372864, role = "Adds",  sound = "Adds"    }, -- 화염결속의 의식
            { spellID = 372110, role = "Other", sound = "Frontal" }, -- 타오르는 바위
            { spellID = 372858, role = "Tank",  sound = "Tank"    }, -- 이글거리는 강타
        },
        rules = {
            { dur = 8,  eID = 372864 }, { dur = 19, eID = 372110 }, { dur = 28, eID = 372858 },
            { dur = 20, eID = 372110 },
            { dur = 40, eID = 372864, seq = 1 }, { dur = 40, eID = 372858, seq = 2 },
        },
    },
    [2623] = { -- 카이락카와 에크하트 스톰베인
        events = {
            { spellID = 381516, role = "Phase", sound = "Intermission" }, -- 방해의 소나기구름
            { spellID = 381517, role = "Phase", sound = "Intermission" }, -- 변화의 바람
            { spellID = 381512, role = "Tank",  sound = "Tank"         }, -- 폭풍격돌
            { spellID = 381862, role = "Other", sound = "Pool"         }, -- 지옥불 타액
            { spellID = 381525, role = "Other", sound = "Frontal"      }, -- 우렁찬 불꽃숨결
            { spellID = 381605, role = "Other"                         }, -- 지옥불 타액
        },
        rules = {
            { dur = 0.8,  eID = 381525 }, { dur = 5,  eID = 381512 }, { dur = 9,  eID = 381605 },
            { dur = 10, eID = 381517 }, { dur = 12, eID = 381862 }, { dur = 21, eID = 381516 },
            { dur = 20, eID = 381525, seq = 1 }, { dur = 20, eID = 381602, seq = 2 },
        },
    },


    -- 한밤
    -- 공허흉터 투기장 (mapID 2923)
    [3285] = { -- 타즈라
        events = {
            { spellID = 1297017, role = "Tank",  sound = "Tank"         }, -- 공허의 폭발
            { spellID = 1262901, role = "Other"                         }, -- 모여드는 그림자
            { spellID = 1300259, role = "Other"                         }, -- 암흑 만개
            { spellID = 1225011, role = "Phase", sound = "Intermission" }, -- 에테리얼 파편
            { spellID = 1222098, role = "Phase", sound = "Intermission" }, -- 황천의 질주
            { spellID = 1296963, role = "Other"                         }, -- 암영 파열
        },
        rules = {
            { dur = 6,  eID = 1222098 }, { dur = 16, eID = 1296963 },
            { dur = 25, eID = 1297017 }, { dur = 31, eID = 1300259 },
        },
    },
    [3286] = { -- 아트로서스
        events = {
            { spellID = 1222371, role = "Phase", sound = "Adds"    }, -- 살금벌레 도발
            { spellID = 1222642, role = "Tank",  sound = "Tank"    }, -- 거대한 발톱
            { spellID = 1222721, role = "Other", sound = "Frontal" }, -- 산성 숨결
            { spellID = 1226120, role = "Heal",  sound = "AOE"     }, -- 독 분출
            { spellID = 1262497, role = "Heal",  sound = "AOE"     }, -- 기괴한 포효
        },
        rules = {
            { dur = 5,  eID = 1226120 }, { dur = 10, eID = 1222642 }, { dur = 15, eID = 1222721 }, { dur = 35, eID = 1262497 },
            { dur = 20, eID = 1226120, seq = 1 }, { dur = 20, eID = 1222642, seq = 2 },
            { dur = 30, eID = 1222721 },
        },
    },
    [3287] = { -- 차로누스
        events = {
            { spellID = 1282770, role = "Phase", sound = "Intermission" }, -- 불안정한 특이점
            { spellID = 1227264, role = "Heal",  sound = "AOE"          }, -- 우주 충돌
            { spellID = 1263982, role = "Phase", sound = "Intermission" }, -- 중력 보주
            { spellID = 1222758, role = "Other", sound = "Frontal"      }, -- 공허 폭포수
            { spellID = 1311923, role = "Tank",  sound = "Tank"         }, -- 암흑 물결
        },
        rules = {
            { dur = 5,  eID = 1282770 }, { dur = 17, eID = 1227264 }, { dur = 28, eID = 1263982 },
            { dur = 34, eID = 1311923 }, { dur = 43, eID = 1222758 },
        },
    },

    -- 날로라크의 소굴 (mapID 2825)
    [3207] = { -- 비축광
        events = {
            { spellID = 1234233, role = "Heal",  sound = "AOE"     }, -- 더럽혀진 보급품
            { spellID = 1253268, role = "Other", sound = "Frontal" }, -- 대지를 가르는 격돌
            { spellID = 1235118, role = "Heal",  sound = "AOE"     }, -- 게걸스러운 고함
        },
        rules = {
            { dur = 6,  eID = 1235118 }, { dur = 16, eID = 1253268 }, { dur = 30, eID = 1234233 },
        },
    },
    [3208] = { -- 겨울의 파수꾼
        events = {
            { spellID = 1235548, role = "Heal",  sound = "Dispel"       }, -- 혹한의 고문
            { spellID = 1235623, role = "Other", sound = "Pool"         }, -- 분노하는 돌풍
            { spellID = 1235783, role = "Adds",  sound = "Adds"         }, -- 분쇄의 혹한쐐기
            { spellID = 1235656, role = "Phase", sound = "Intermission" }, -- 얼어붙은 폭풍우
        },
        rules = {
            { dur = 7,  eID = 1235548 }, { dur = 13, eID = 1235623 },
            { dur = 25, eID = 1235783 }, { dur = 50, eID = 1235656 },
        },
    },
    [3209] = { -- 날로라크
        events = {
            { spellID = 1255385, role = "Other"                         }, -- 강대한 포효
            { spellID = 1242860, role = "Other", sound = "Pool"         }, -- 메아리치는 후려갈기기
            { spellID = 1243011, role = "Phase", sound = "Intermission" }, -- 전쟁 신의 격노
            { spellID = 1243569, role = "Tank",  sound = "Tank"         }, -- 압도적인 맹공
            { spellID = 1262846, role = "Other"                         }, -- 영혼 난타
        },
        rules = {
            { dur = 5,  eID = 1242860 }, { dur = 13, eID = 1243569 }, { dur = 54, eID = 1243011 },
            { dur = 25, eID = 1242860, seq = 1 }, { dur = 25, eID = 1243569, seq = 2 },
        },
    },

    -- 눈부신 골짜기 (mapID 2859)
    [3199] = { -- 빛송이 삼위일체
        events = {
            { spellID = 1234753, role = "Tank",  sound = "Tank"         }, -- 기반암 격돌
            { spellID = 1234850, role = "Other", sound = "Frontal"      }, -- 빛을 흩뿌리는 질주
            { spellID = 1235640, role = "Other", sound = "Pool"         }, -- 뾰족칼
            { spellID = 1261276, role = "Other", sound = "Pool"         }, -- 뾰족칼
            { spellID = 1235564, role = "Phase", sound = "Intermission" }, -- 빛송이 광선
        },
        rules = {
            { dur = 5,  eID = 1234753 }, { dur = 8,  eID = 1235640 }, { dur = 20, eID = 1234850 }, { dur = 35, eID = 1235564 },
            { dur = 45, eID = 1234753, seq = 1 }, { dur = 45, eID = 1235640, seq = 2 },
            { dur = 45, eID = 1234850, seq = 3 }, { dur = 45, eID = 1235564, seq = 4 },
        },
    },
    [3200] = { -- 빛 사냥꾼 이쿠즈
        events = {
            { spellID = 1236746, role = "Heal",  sound = "AOE"          }, -- 신록의 발구르기
            { spellID = 1236709, role = "Heal",  sound = "AOE"          }, -- 가시소환사 포효
            { spellID = 1237090, role = "Phase", sound = "Intermission" }, -- 피에 굶주린 눈길
        },
        rules = {
            { dur = 6,  eID = 1236746 }, { dur = 22, eID = 1236709 }, { dur = 50, eID = 1237090 },
            { dur = 29, eID = 1236746 },
        },
    },
    [3201] = { -- 빛의 감시자 루이아
        events = {
            { spellID = 1239824, role = "Other"                         }, -- 빛화염
            { spellID = 1240098, role = "Other"                         }, -- 빛내림
            { spellID = 1240210, role = "Other", sound = "Frontal"      }, -- 짓이기는 일격
            { spellID = 1241058, role = "Heal",  sound = "AOE"          }, -- 치명적인 난타
            { spellID = 1239885, role = "Phase", sound = "Intermission" }, -- 변신: 곰
            { spellID = 1239882, role = "Phase", sound = "Intermission" }, -- 변신: 달빛야수
            { spellID = 1239883, role = "Phase", sound = "Intermission" }, -- 변신: 하라니르
            { spellID = 1241067, role = "Phase", sound = "Intermission" }, -- 골짜기의 영혼
        },
        rules = {
            { dur = 0.5, eID = 1239882 }, { dur = 5,   eID = 1239824 }, { dur = 18,  eID = 1240098 }, -- P1
            { dur = 3,   eID = 1241058 }, { dur = 9,   eID = 1240210 }, -- P2
            { dur = 2.5, eID = 1241067 }, -- P3
        },
    },
    [3202] = { -- 지케트
        events = {
            { spellID = 1246372, role = "Phase", sound = "Adds"                  }, -- 빛만개 깨우기
            { spellID = 1247685, role = "Tank",  sound = "Tank"                  }, -- 가시뿔
            { spellID = 1246607, role = "Tank",  sound = "Frontal"               }, -- 집중된 빛줄기
            { spellID = 1246858, role = "Heal",                    text = "구슬" }, -- 빛만개의 정수
        },
        rules = {
            { dur = 4,  eID = 1246372 }, { dur = 14, eID = 1246858 }, { dur = 26, eID = 1247685 }, { dur = 40, eID = 1246607 },
            { dur = 50, eID = 1246372, seq = 1 }, { dur = 50, eID = 1246858, seq = 2 },
            { dur = 50, eID = 1247685, seq = 3 }, { dur = 50, eID = 1246607, seq = 4 },
        },
    },

    -- 송곳니의 제단 (mapID 2993)
    [3456] = { -- 라비
        events = {
            { spellID = 1309522, role = "Phase", sound = "Intermission" }, -- 뱀의 탐색
            { spellID = 1296219, role = "Other"                         }, -- 악취 나는 포효
            { spellID = 1296220, role = "Heal",  sound = "AOE"          }, -- 삼중 사격
            { spellID = 1296050, role = "Other", sound = "Frontal"      }, -- 게워내기
            { spellID = 1307894, role = "Heal",  sound = "AOE"          }, -- 게걸스러운 발구르기
        },
        rules = {
            { dur = 8,  eID = 1296220 }, { dur = 13, eID = 1296050 }, { dur = 23, eID = 1307894 },
            { dur = 24, eID = 1296220 }, { dur = 25, eID = 1309522 }, { dur = 45, eID = 1309522 },
        },
    },
    [3457] = { -- 격동하는 똬리
        events = {
            { spellID = 1299154, role = "Heal",  sound = "AOE"          }, -- 동화된 맹독
            { spellID = 1298949, role = "Tank",  sound = "Tank"         }, -- 꼬리 낫
            { spellID = 1299940, role = "Other", sound = "Frontal"      }, -- 원한 서린 공세
            { spellID = 1299053, role = "Phase", sound = "Intermission" }, -- 죽음의 방울 소리
            { spellID = 1310357, role = "Other", sound = "Interrupt"    }, -- 맹독 포화
            { spellID = 1310547, role = "Other", sound = "Interrupt"    }, -- 유독한 쇠약
        },
        rules = {
            { dur = 1,  eID = 1299154 }, { dur = 7,  eID = 1298949 }, { dur = 14, eID = 1310357 },
            { dur = 30, eID = 1299940 }, { dur = 44, eID = 1299053 },
            { dur = 10, eID = 1310547 }, -- P2
        },
    },
    [3458] = { -- 줄잔
        events = {
            { spellID = 1301413, role = "Heal",  sound = "Soak"         }, -- 뼈절단자
            { spellID = 1300876, role = "Phase", sound = "Intermission" }, -- 송곳니의 의식
            { spellID = 1301111, role = "Other", sound = "Frontal"      }, -- 도끼분쇄자
            { spellID = 1301350, role = "Tank",  sound = "Tank"         }, -- 찍어 넘기기
        },
        rules = {
            { dur = 32, eID = 1301413 },
            { dur = 14, eID = 1301111, seq = 1 }, { dur = 14, eID = 1301413, seq = 2 },
            { dur = 26, eID = 1301350 }, { dur = 30, eID = 1301350 }, { dur = 64, eID = 1300876 },
        },
    },

    -- 죽음의 골목 (mapID 2813)
    [3101] = { -- 키스티아 마나하트
        events = {
            { spellID = 1264095, role = "Heal",  sound = "Interrupt"    }, -- 환영 복제
            { spellID = 1253811, role = "Other", sound = "Frontal"      }, -- 지옥 분사
            { spellID = 474240,  role = "Other"                         }, -- 지옥 회오리
            { spellID = 1230304, role = "Phase", sound = "Intermission" }, -- 빛 주입
        },
        rules = {
            { dur = 8,    eID = 1253811 }, { dur = 12,   eID = 474240  }, { dur = 15,   eID = 1264095 },
            { dur = 27.5, eID = 1253811 }, { dur = 30,   eID = 1264095 },
        },
    },
    [3102] = { -- 자엔 블레이드소로우
        events = {
            { spellID = 1214357, role = "Other"                         }, -- 불폭탄
            { spellID = 474765,  role = "Other"                         }, -- 당일 배송
            { spellID = 1218347, role = "Phase", sound = "Intermission" }, -- 죽음의 사선
            { spellID = 474478,  role = "Heal",  sound = "AOE"          }, -- 광기의 학살자
            { spellID = 1222795, role = "Tank",  sound = "Tank"         }, -- 독살
        },
        rules = {
            { dur = 8,  eID = 474478  }, { dur = 12, eID = 474765  }, { dur = 18, eID = 1214357 },
            { dur = 26, eID = 1222795 }, { dur = 36, eID = 1218347 },
            { dur = 16, eID = 474765  },
        },
    },
    [3103] = { -- 파멸자 자투스
        events = {
            { spellID = 473898,  role = "Tank",  sound = "Tank"         }, -- 군단의 일격
            { spellID = 474197,  role = "Phase", sound = "Intermission" }, -- 악마의 분노
            { spellID = 1214641, role = "Adds",  sound = "Adds"         }, -- 도끼 던지기
            { spellID = 1295452, role = "Heal",  sound = "AOE"          }, -- 불지옥 충돌
        },
        rules = {
            { dur = 6,  eID = 473898  }, { dur = 15, eID = 1214641 }, { dur = 30, eID = 1295452 }, { dur = 35, eID = 474197  },
            { dur = 27, eID = 473898  },
        },
    },
    [3105] = { -- 리시엘 신더퓨리
        events = {
            { spellID = 1218203, role = "Heal",  sound = "AOE"          }, -- 굴단의 손가락
            { spellID = 474408,  role = "Adds",  sound = "Adds"         }, -- 썩은마귀 소환
            { spellID = 1224478, role = "Phase", sound = "Intermission" }, -- 사악한 파장
        },
        rules = {
            { dur = 10, eID = 474408  }, { dur = 15, eID = 1218203 }, { dur = 24, eID = 1224478 },
            { dur = 55, eID = 1218203 }, { dur = 57, eID = 474408  }, { dur = 59, eID = 1224478 },
        },
    },


    -- 한밤의 전쟁 2시즌 레이드
    -- 해일결속 동굴 (mapID 2987)
    [3379] = { -- 님리사 웨이브콜러
        events = {
            { spellID = 1257608, role = "Other"                         }, -- 냉기 포화
            { spellID = 1257717, role = "Adds",  sound = "Adds"         }, -- 매혹하는 거품
            { spellID = 1258668, role = "Phase", sound = "Intermission" }, -- 휘몰아치는 소용돌이
            { spellID = 1260837, role = "Heal",  sound = "AOE"          }, -- 심연의 비
            { spellID = 1276710, role = "Adds",  sound = "Adds"         }, -- 매혹하는 거품
            { spellID = 1313393, role = "Other"                         }, -- 오싹한 서리
            { spellID = 1268562, role = "Other"                         }, -- 물 분출
        },
    },

    -- 맹독 심연 (mapID 3004)
    [3470] = { -- 영혼살무사 네크잘리
        events = {
            { spellID = 1287426, role = "Heal",  sound = "Dispel"       }, -- 정수 분쇄
            { spellID = 1285681, role = "Other"                         }, -- 영혼똬리 점화
            { spellID = 1289923, role = "Other"                         }, -- 헌신의 부름
            { spellID = 1295397, role = "Adds",  sound = "Adds"         }, -- 잠 못 드는 아마니
            { spellID = 1290679, role = "Other"                         }, -- 원한에 찬 쉭쉭거림
            { spellID = 1292036, role = "Tank",  sound = "Frontal"      }, -- 귀신 들린 포화
            { spellID = 1290001, role = "Other"                         }, -- 똬리 풀리는 중
            { spellID = 1299673, role = "Other"                         }, -- 기원
            { spellID = 1305421, role = "Heal",  sound = "Soak"         }, -- 굶주린 장작더미
            { spellID = 1293497, role = "Other"                         }, -- 휘감긴 걸음
            { spellID = 1293212, role = "Phase", sound = "Intermission" }, -- 움켜쥐는 심연
            { spellID = 1305993, role = "Other"                         }, -- 잔류의 대가
        },
    },
    [3445] = { -- 매장된 파수꾼
        events = {
            { spellID = 1284251, role = "Other", sound = "Adds"         }, -- 맹독 응고물
            { spellID = 1284434, role = "Other", sound = "Soak"         }, -- 유독한 물방울
            { spellID = 1284458, role = "Other"                         }, -- 강화의 격돌
            { spellID = 1284487, role = "Other"                         }, -- 피맹독 주입
            { spellID = 1284483, role = "Other"                         }, -- 역병에 물든 피
            { spellID = 1284485, role = "Other"                         }, -- 쇠약의 독기
            { spellID = 1284588, role = "Phase", sound = "Intermission" }, -- 황산성 정지장
            { spellID = 26662,   role = "Phase", sound = "Intermission" }, -- 광폭화
            { spellID = 1288232, role = "Other", sound = "Share"        }, -- 불안정한 독기
            { spellID = 1296878, role = "Phase", sound = "Intermission" }, -- 변화무쌍한 원시맹독
        },
    },
    [3497] = { -- 길 잃은 탐험가
        events = {
            { spellID = 1291390, role = "Phase", sound = "Intermission" }, -- 대재앙의 기원
            { spellID = 1296025, role = "Other"                         }, -- 점멸 회오리
            { spellID = 1296092, role = "Other", sound = "Share"        }, -- 강력한 후려치기
            { spellID = 1295817, role = "Phase", sound = "Intermission" }, -- 생선 내던지기
            { spellID = 1292104, role = "Phase", sound = "Intermission" }, -- 버섯 던지기
            { spellID = 1295854, role = "Other"                         }, -- 찢어발기는 파편
            { spellID = 1295886, role = "Other"                         }, -- 서리불꽃 연사
            { spellID = 1295935, role = "Other"                         }, -- 서리불꽃 연사
            { spellID = 1297625, role = "Phase", sound = "Intermission" }, -- 폭발적인 깜짝 선물
            { spellID = 1292779, role = "Phase", sound = "Intermission" }, -- 최후의 승천
            { spellID = 1286921, role = "Other"                         }, -- 얼음결속 불꽃
            { spellID = 1290742, role = "Other"                         }, -- 점멸 회오리
            { spellID = 1296061, role = "Other", sound = "Frontal"      }, -- 등껍질 회전
            { spellID = 1291933, role = "Other"                         }, -- 쓰레기 투척
            { spellID = 1290740, role = "Other"                         }, -- 점멸 회오리
            { spellID = 1290743, role = "Other"                         }, -- 점멸 회오리
        },
    },
    [3455] = { -- 악성의 바쉬니크
        events = {
            { spellID = 1280935, role = "Other"                   }, -- 독 맺힌 송곳니
            { spellID = 1283164, role = "Other", sound = "Adds"   }, -- 시음
            { spellID = 1282509, role = "Other", sound = "Soak"   }, -- 악성 촉매
            { spellID = 1281907, role = "Other", sound = "Spread" }, -- 역병 거품
            { spellID = 1282114, role = "Other"                   }, -- 적응성 감염
            { spellID = 1295224, role = "Other"                   }, -- 흡수의 전염병
            { spellID = 1295244, role = "Other"                   }, -- 흡수의 전염병
            { spellID = 1295173, role = "Other"                   }, -- 폭발 전염병
            { spellID = 1295174, role = "Other"                   }, -- 폭발 전염병
            { spellID = 1294994, role = "Other"                   }, -- 저승 전염병
        },
    },
    [3420] = { -- 스조라크
        events = {
            { spellID = 1285425, role = "Other"                         }, -- 격렬한 교차의 바람
            { spellID = 1305959, role = "Phase", sound = "Intermission" }, -- 맹독성 쇄도
            { spellID = 1277025, role = "Other"                         }, -- 최상위 포식자
            { spellID = 1285732, role = "Phase", sound = "Intermission" }, -- 울부짖는 혼란의 소용돌이
            { spellID = 1296898, role = "Phase", sound = "Intermission" }, -- 속박 풀린 야성
            { spellID = 1296310, role = "Other"                         }, -- 부식성 발톱
        },
    },
    [3421] = { -- 쌍둥이 송곳니
        events = {
            { spellID = 1289192, role = "Other"                         }, -- 부식의 폭우
            { spellID = 1288484, role = "Other"                         }, -- 돌 파괴자
            { spellID = 1294293, role = "Phase", sound = "Intermission" }, -- 썩은 홍수
            { spellID = 1294921, role = "Phase", sound = "Intermission" }, -- 홍수
            { spellID = 1290956, role = "Other"                         }, -- 심연 휘젓기
            { spellID = 1290809, role = "Other"                         }, -- 휘감는 체액
            { spellID = 1291404, role = "Adds",  sound = "Adds"         }, -- 맹독의 출현
            { spellID = 1290516, role = "Phase", sound = "Share"        }, -- 걸신들린 탐식
            { spellID = 1291478, role = "Other"                         }, -- 부식성 타액
            { spellID = 1303230, role = "Other"                         }, -- 몰아치는 피
            { spellID = 1306872, role = "Phase", sound = "Dodge"        }, -- 핏빛 폭풍
            { spellID = 1308356, role = "Other"                         }, -- 무리 자극
            { spellID = 1308556, role = "Phase", sound = "Intermission" }, -- 잠복
        },
    },
    [3429] = { -- 똬리의 제단
        events = {
            { spellID = 1285911, role = "Other"                         }, -- 섬뜩한 집착
            { spellID = 1287227, role = "Other"                         }, -- 황폐한 독소
            { spellID = 1287200, role = "Other"                         }, -- 황폐한 독소
            { spellID = 1282487, role = "Other"                         }, -- 똬리의 제단의 송곳니
            { spellID = 1298381, role = "Other"                         }, -- 똬리의 제단의 오염
            { spellID = 1283485, role = "Other"                         }, -- 단두대
            { spellID = 1299266, role = "Other"                         }, -- 냉혹한 단두대
            { spellID = 1286918, role = "Phase", sound = "Intermission" }, -- 영원한 일몰
            { spellID = 1289900, role = "Other"                         }, -- 공포의 행진
            { spellID = 1286573, role = "Other"                         }, -- 영혼 절단
            { spellID = 1286441, role = "Other", sound = "Interrupt"    }, -- 영혼의 웃음
            { spellID = 1299680, role = "Tank",  sound = "Tank"         }, -- 절단
            { spellID = 1299960, role = "Other"                         }, -- 유독한 폭우
            { spellID = 1307279, role = "Other"                         }, -- 역병의 절단
            { spellID = 1282281, role = "Other"                         }, -- 맹독송곳니
            { spellID = 1283832, role = "Other"                         }, -- 도끼분쇄자
            { spellID = 1286308, role = "Other"                         }, -- 그림자송곳니
            { spellID = 1310882, role = "Other"                         }, -- 암영폭탄
        },
    },
    [3492] = { -- 울라텍
        events = {
            { spellID = 1298367, role = "Tank",  sound = "Tank"         }, -- 어미의 분노
            { spellID = 1311037, role = "Tank",  sound = "Tank"         }, -- 어미의 분노
            { spellID = 1286860, role = "Phase", sound = "Intermission" }, -- 구속된 자의 격노
            { spellID = 1292188, role = "Heal",  sound = "Wave"         }, -- 부식의 파도
            { spellID = 1286905, role = "Other"                         }, -- 해방된 격노
            { spellID = 1298559, role = "Other"                         }, -- 선혈 방울꼬리
            { spellID = 1304527, role = "Other"                         }, -- 선혈 방울꼬리
            { spellID = 1295905, role = "Other", sound = "Share"        }, -- 뱀의 물어뜯기
            { spellID = 1299757, role = "Other"                         }, -- 독성 배양
            { spellID = 1300530, role = "Heal",  sound = "Share"        }, -- 유령의 똬리
            { spellID = 1300751, role = "Other", sound = "Adds"         }, -- 독사의 부름
            { spellID = 1301510, role = "Heal",  sound = "Phase"        }, -- 사냥감 포위
            { spellID = 1302982, role = "Other"                         }, -- 악성 타액
            { spellID = 1296301, role = "Other"                         }, -- 유해한 난타
            { spellID = 1287265, role = "Phase", sound = "Share"        }, -- 유령의 똬리
            { spellID = 1292999, role = "Other"                         }, -- 잠복
        },
    },
}

-- ==============================
-- mapID 매핑
-- ==============================
-- mapID → encounterID 목록 (TimelineColor / Sound 인스턴스 전체 적용용)
---@type table<number, number[]>
dodo.EncounterMapBosses = {
    [1762] = { 2139, 2142, 2140, 2143 },                          -- 왕들의 안식처
    [1877] = { 2124, 2125, 2126, 2127 },                          -- 세스랄리스 사원
    [2521] = { 2609, 2606, 2623 },                                -- 루비 생명의 웅덩이
    [2923] = { 3285, 3286, 3287 },                                -- 공허흉터 투기장
    [2825] = { 3207, 3208, 3209 },                                -- 날로라크의 소굴
    [2859] = { 3199, 3200, 3201, 3202 },                          -- 눈부신 골짜기
    [2993] = { 3456, 3457, 3458 },                                -- 송곳니의 제단
    [2813] = { 3101, 3102, 3103, 3105 },                          -- 죽음의 골목
    [2987] = { 3379 },                                            -- 해일결속 동굴
    [3004] = { 3470, 3445, 3497, 3455, 3420, 3421, 3429, 3492 },  -- 맹독 심연
}
