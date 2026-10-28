-- ==============================
-- 보관용: 구 레이드 (TOC 미등록, 로드되지 않음)
-- 복원: 아래 항목을 02 Data.lua 의 dodo.EncounterData / dodo.EncounterMapBosses 에 붙여넣기
-- ==============================
---@diagnostic disable: unused-local

local EncounterData = {
    -- 한밤
    -- 꿈의 균열 (mapID 2939, rules 없음)
    [3306] = { -- 꿈결을 벗어난 신 카이메루스
        events = {
            { spellID = 1245404, role = "Other"                  }, -- 게걸스러운 뛰어들기
            { spellID = 1251021, role = "Heal"                   }, -- 균열 출현
            { spellID = 1246621, role = "Heal"                   }, -- 부식성 가래
            { spellID = 1272726, role = "Other"                  }, -- 균열 찢기
            { spellID = 1245452, role = "Other"                  }, -- 더럽혀진 파멸
            { spellID = 1249017, role = "Other"                  }, -- 무시무시한 울부짖음
            { spellID = 1249207, role = "Heal"                   }, -- 불협의 포효
            { spellID = 1257085, role = "Phase", sound = "Phase" }, -- 잠식하는 독기
            { spellID = 1245771, role = "Other"                  }, -- 타락의 깃털
            { spellID = 1262289, role = "Phase", sound = "Phase" }, -- 알른가루 지각 변동
            { spellID = 1260088, role = "Other"                  }, -- 균열 대격변
            { spellID = 1262616, role = "Other"                  }, -- 산성 구토
            { spellID = 1268905, role = "Phase", sound = "Phase" }, -- 균열의 광기
            { spellID = 1245396, role = "Heal"                   }, -- 집어삼키기
            { spellID = 1280127, role = "Phase", sound = "Phase" }, -- 2단계
            { spellID = 1282001, role = "Phase", sound = "Phase" }, -- 알른가루 지각 변동
            { spellID = 1282856, role = "Other"                  }, -- 더럽혀진 파멸
            { spellID = 1245844, role = "Other"                  }, -- 잡아먹힌 정수
        },
    },

    -- 공허첨탑 (mapID 2912, rules 없음)
    [3176] = { -- 전제군주 아베르지안
        events = {
            { spellID = 1262776, role = "Phase", sound = "Phase" }, -- 어둠의 진격
            { spellID = 1251361, role = "Phase", sound = "Phase" }, -- 어둠의 진격
            { spellID = 1249251, role = "Heal"                   }, -- 어둠의 지각 변동
            { spellID = 1249265, role = "Phase", sound = "Phase" }, -- 암영 붕괴
            { spellID = 1260712, role = "Other"                  }, -- 망각의 분노
            { spellID = 1258880, role = "Other"                  }, -- 공허 추락
            { spellID = 1251583, role = "Other"                  }, -- 끝없는 행진
            { spellID = 1255702, role = "Other"                  }, -- 칠흑 보루
            { spellID = 1266786, role = "Other"                  }, -- 공허 추락
            { spellID = 1270949, role = "Other"                  }, -- 황폐화
            { spellID = 1280015, role = "Phase", sound = "Phase" }, -- 공허 징표
            { spellID = 1283069, role = "Tank",  sound = "Tank"  }, -- 약화됨
        },
    },
    [3177] = { -- 보라시우스
        events = {
            { spellID = 1241836, role = "Tank", sound = "Tank" }, -- 그림자발톱 격돌
            { spellID = 1244293, role = "Tank", sound = "Tank" }, -- 그림자발톱 격돌
            { spellID = 1243853, role = "Other"                }, -- 공허의 숨결
            { spellID = 1254199, role = "Heal"                 }, -- 기생충 배출
            { spellID = 1244346, role = "Other"                }, -- 거대한 투척
            { spellID = 1260046, role = "Heal"                 }, -- 태고의 포효
            { spellID = 1254112, role = "Other"                }, -- 시선 고정
            { spellID = 1234346, role = "Other"                }, -- 생성
        },
    },
    [3179] = { -- 몰락한 왕 살라다르
        events = {
            { spellID = 1243453, role = "Phase", sound = "Phase" }, -- 공허의 수렴
            { spellID = 1260823, role = "Heal"                   }, -- 폭군의 지배
            { spellID = 1245081, role = "Other"                  }, -- 분열된 투영
            { spellID = 1253911, role = "Other"                  }, -- 부서지는 황혼
            { spellID = 1250686, role = "Heal"                   }, -- 뒤틀린 암연
            { spellID = 1246175, role = "Phase", sound = "Phase" }, -- 무질서의 해체
            { spellID = 64238,   role = "Other"                  }, -- 광폭화
            { spellID = 1272338, role = "Other"                  }, -- 깨어진 서약
        },
    },
    [3178] = { -- 바엘고어와 에조라크
        events = {
            { spellID = 1262623, role = "Other"                  }, -- 무위의 광선
            { spellID = 1244917, role = "Phase", sound = "Phase" }, -- 공허의 울음
            { spellID = 1245391, role = "Phase", sound = "Phase" }, -- 암울
            { spellID = 1244221, role = "Other"                  }, -- 공포의 숨결
            { spellID = 1249748, role = "Heal"                   }, -- 한밤 화염
            { spellID = 1280458, role = "Other"                  }, -- 옭아매는 아귀
            { spellID = 1245645, role = "Tank",  sound = "Tank"  }, -- 암반송곳니
            { spellID = 1265131, role = "Tank",  sound = "Tank"  }, -- 부정날개
            { spellID = 1277470, role = "Phase", sound = "Phase" }, -- 우주 삼투: 암울
            { spellID = 1277471, role = "Other"                  }, -- 우주 삼투: 무위의 광선
            { spellID = 1277472, role = "Other"                  }, -- 우주 삼투: 공포의 숨결
            { spellID = 1277473, role = "Phase", sound = "Phase" }, -- 우주 삼투: 공허의 울음
            { spellID = 1248847, role = "Phase", sound = "Phase" }, -- 광휘의 방벽
        },
    },
    [3180] = { -- 빛에 눈이 먼 선봉대
        events = {
            { spellID = 1248451, role = "Phase", sound = "Phase" }, -- 평화의 오라
            --{ eventID = 72,      role = "Other" },                     -- 이벤트 72 (spellID 미확인)
            { spellID = 1249130, role = "Other"                  }, -- 엘레크 돌진
            { spellID = 1248674, role = "Phase", sound = "Phase" }, -- 성스러운 보호막
            { spellID = 1276831, role = "Heal"                   }, -- 티르의 분노
            { spellID = 1246162, role = "Phase", sound = "Phase" }, -- 헌신의 오라
            { spellID = 1155738, role = "Heal"                   }, -- 뜨거운 빛
            { spellID = 1251857, role = "Tank",  sound = "Tank"  }, -- 심판
            { spellID = 1246485, role = "Phase", sound = "Phase" }, -- 응징의 방패
            { spellID = 1248644, role = "Phase", sound = "Phase" }, -- 천상의 종
            { spellID = 1248449, role = "Phase", sound = "Phase" }, -- 진노의 오라
            { spellID = 1246736, role = "Tank",  sound = "Tank"  }, -- 심판
            { spellID = 1246765, role = "Phase", sound = "Phase" }, -- 천상의 폭풍
            { spellID = 1246749, role = "Heal"                   }, -- 신성한 종
            { spellID = 1276368, role = "Heal"                   }, -- 사형 선고
            { spellID = 1272380, role = "Phase", sound = "Phase" }, -- 열성적인 영혼
            { spellID = 1272423, role = "Phase", sound = "Phase" }, -- 열성적인 영혼
            { spellID = 1272425, role = "Phase", sound = "Phase" }, -- 열성적인 영혼
            { spellID = 1276635, role = "Phase", sound = "Phase" }, -- 응징의 방패
            { spellID = 1276639, role = "Heal"                   }, -- 이글거리는 광휘
            { spellID = 1272310, role = "Other"                  }, -- 천상의 폭풍
        },
    },
    [3181] = { -- 우주의 왕관
        events = {
            { spellID = 1233865, role = "Heal"                   }, -- 무위의 광환
            { spellID = 1233819, role = "Phase", sound = "Phase" }, -- 공허 배출
            { spellID = 1233602, role = "Phase", sound = "Phase" }, -- 은빛강타 화살
            { spellID = 1234564, role = "Other"                  }, -- 은빛강타 탄막
            { spellID = 1235622, role = "Other"                  }, -- 특이점 분출
            { spellID = 1237035, role = "Heal"                   }, -- 공허추적자 독침
            { spellID = 1237837, role = "Phase", sound = "Phase" }, -- 공허의 부름
            { spellID = 1237614, role = "Heal"                   }, -- 순찰대장의 징표
            { spellID = 1246918, role = "Heal"                   }, -- 우주의 방벽
            { spellID = 1239080, role = "Phase", sound = "Phase" }, -- 최후의 상
            { spellID = 1232467, role = "Heal"                   }, -- 공백의 손아귀
            { spellID = 1238843, role = "Phase", sound = "Phase" }, -- 포식하는 우주
            { spellID = 1243787, role = "Tank",  sound = "Tank"  }, -- 어둠의 손
            { spellID = 1243753, role = "Phase", sound = "Phase" }, -- 굶주린 심연
            { spellID = 1243743, role = "Heal"                   }, -- 방해의 진동
            { spellID = 1260010, role = "Heal"                   }, -- 순찰대장의 징표
            { spellID = 1260026, role = "Heal"                   }, -- 공백의 손아귀
            { spellID = 1261016, role = "Phase", sound = "Phase" }, -- 균열 복제물
            { spellID = 1261339, role = "Phase", sound = "Phase" }, -- 우주의 차원문
            { spellID = 1246461, role = "Tank",  sound = "Tank"  }, -- 균열 베기
            { spellID = 1239582, role = "Other"                  }, -- 우주의 과부하
        },
    },

    -- 쿠엘다나스 진격로 (mapID 2913, rules 없음)
    [3182] = { -- 알라르의 자손 벨로렌
        events = {
            { spellID = 1241282, role = "Phase", sound = "Phase" }, -- 벨로렌의 불씨
            { spellID = 1242981, role = "Phase", sound = "Phase" }, -- 광휘의 메아리
            { spellID = 1260763, role = "Tank",  sound = "Tank"  }, -- 수호자의 칙령
            { spellID = 1244344, role = "Heal"                   }, -- 영원의 화상
            { spellID = 1242260, role = "Phase", sound = "Phase" }, -- 마력 깃든 깃
            { spellID = 1242515, role = "Heal"                   }, -- 공허불꽃의 합일
            { spellID = 1246709, role = "Phase", sound = "Phase" }, -- 죽음의 낙하
            { spellID = 1242792, role = "Other"                  }, -- 화염 격류
            { spellID = 1241992, role = "Phase", sound = "Phase" }, -- 빛의 깃
            { spellID = 1242091, role = "Phase", sound = "Phase" }, -- 공허 깃
            --{ eventID = 417,     role = "Other" },                     -- 이벤트 417 (spellID 미확인)
            --{ eventID = 418,     role = "Other" },                     -- 이벤트 418 (spellID 미확인)
            { spellID = 1241162, role = "Phase", sound = "Phase" }, -- 빛 깃털
            { spellID = 1241163, role = "Phase", sound = "Phase" }, -- 공허 깃털
            { spellID = 1241292, role = "Heal"                   }, -- 빛 강하
            { spellID = 1241339, role = "Heal"                   }, -- 공허 강하
            { spellID = 1241313, role = "Phase", sound = "Phase" }, -- 환생
            { spellID = 1241267, role = "Phase", sound = "Phase" }, -- 공허불빛 분노
            { spellID = 1241320, role = "Other"                  }, -- 환생
        },
    },
    [3183] = { -- 한밤의 도래
        events = {
            { spellID = 1244412, role = "Phase", sound = "Phase" }, -- 죽음의 진혼곡
            { spellID = 1253915, role = "Other"                  }, -- 천상의 글레이브
            { spellID = 1251386, role = "Other"                  }, -- 안전 분광경
            { spellID = 1249796, role = "Heal"                   }, -- 조각난 하늘
            { spellID = 1261871, role = "Heal"                   }, -- 개기 월식
            { spellID = 1266622, role = "Phase", sound = "Phase" }, -- 한밤
            { spellID = 1266897, role = "Phase", sound = "Phase" }, -- 빛 흡수
            { spellID = 1266388, role = "Other"                  }, -- 어둠의 별자리
            { spellID = 1250898, role = "Other"                  }, -- 어둠의 대천사
            { spellID = 1273158, role = "Phase", sound = "Phase" }, -- 죽음의 만가
            { spellID = 1276202, role = "Heal"                   }, -- 단절
            { spellID = 1267049, role = "Tank",  sound = "Tank"  }, -- 천상의 찌르기
            { spellID = 1282047, role = "Phase", sound = "Phase" }, -- 암흑샘 속으로
            { spellID = 1282249, role = "Heal"                   }, -- 우주의 분열
            { spellID = 1282412, role = "Heal"                   }, -- 핵 채취
            { spellID = 1281194, role = "Other"                  }, -- 어둠의 용해
            { spellID = 1282441, role = "Heal"                   }, -- 별빛파열
            { spellID = 1284525, role = "Heal"                   }, -- 활력 주입
            { spellID = 1284931, role = "Other"                  }, -- 말소 분광경
            { spellID = 1284980, role = "Phase", sound = "Phase" }, -- 암울한 교향곡
            { spellID = 1279420, role = "Other"                  }, -- 암흑의 준항성
            { spellID = 1249609, role = "Heal"                   }, -- 암흑의 룬
            { spellID = 1295191, role = "Other"                  }, -- 불화
        },
    },

    -- 진균나락 (mapID 1592)
    [3159] = { -- 부식수렁
        events = {
            { spellID = 1221637, role = "Phase", sound = "Phase" }, -- 진균 꽃송이
            { spellID = 1221622, role = "Phase", sound = "Phase" }, -- 버섯 깨우기
            { spellID = 1221787, role = "Heal"                   }, -- 터진 고름
            { spellID = 1221781, role = "Tank",  sound = "Tank"  }, -- 부패한 철권
            { spellID = 1222088, role = "Heal"                   }, -- 부패의 덩굴
            { spellID = 1299508, role = "Phase", sound = "Phase" }, -- 진균 무리붙이
            { spellID = 1221639, role = "Phase", sound = "Phase" }, -- 어린 버섯전사
        },
        rules = {
            { dur = 41,  eID = 1222088 }, { dur = 21, eID = 1221781 },
            { dur = 8,   eID = 1221787 }, { dur = 13, eID = 1221622 }, { dur = 114, eID = 1221637 },
            { dur = 49,  eID = 1221622, seq = 1 }, { dur = 49, eID = 1221787, seq = 2 }, { dur = 49, eID = 1222088, seq = 3 },
            { dur = 21,  eID = 1221787 }, { dur = 12, eID = 1221781 }, { dur = 13, eID = 1221781 },
        },
    },
}

local EncounterMapBosses = {
    [2939] = { 3306 },                                            -- 꿈의 균열
    [2912] = { 3176, 3177, 3179, 3178, 3180, 3181 },              -- 공허첨탑
    [2913] = { 3182, 3183 },                                      -- 쿠엘다나스 진격로
    [1592] = { 3159 },                                            -- 진균나락
}
