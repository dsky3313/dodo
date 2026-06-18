-- EXBoss - 블리자드 순정 인카운터 타임라인 바 색상 변경 기능 포팅

---@diagnostic disable: lowercase-global, param-type-mismatch, redundant-parameter, undefined-field, undefined-global
local addonName, dodo = ...
dodoDB = dodoDB or {}

-- ==============================
-- 설정 및 테이블
-- ==============================
-- mapID → 이벤트 목록. eventID는 EXBossData/EncounterData.lua 기준 블리자드 고정 ID.
local INSTANCE_EVENTS = {

    [2526] = { -- 알게타르 대학
        -- 벡사무스
        { eventID = 274, role = "Other" },    -- 비전 보주
        { eventID = 275, role = "Heal" },     -- 마나 폭탄
        { eventID = 276, role = "Tank" },     -- 비전 방출
        { eventID = 277, role = "Mechanic" }, -- 비전 균열
        -- 비대해진 고대정령
        { eventID = 282, role = "Tank" },     -- 나무껍질 파괴자
        { eventID = 283, role = "Heal" },     -- 가지 뻗기
        { eventID = 284, role = "Mechanic" }, -- 발아
        { eventID = 285, role = "Other" },    -- 밀려드는 분출
        -- 크로스
        { eventID = 278, role = "Tank" },     -- 흉포한 쪼기
        { eventID = 279, role = "Heal" },     -- 귀청 터질듯한 비명
        { eventID = 280, role = "Other" },    -- 압도적인 돌풍
        { eventID = 397, role = "Mechanic" }, -- 공놀이
        -- 도라고사의 메아리
        { eventID = 293, role = "Other" },    -- 신비한 화살
        { eventID = 294, role = "Tank" },     -- 천공의 작렬
        { eventID = 295, role = "Heal" },     -- 마력 폭탄
        { eventID = 296, role = "Mechanic" }, -- 힘의 공백
    },

    [658] = { -- 사론의 구덩이
        -- 제련장인 가프로스트
        { eventID = 144, role = "Tank" },     -- 광석 파괴자
        { eventID = 145, role = "Heal" },     -- 냉각 발구르기
        { eventID = 146, role = "Other" },    -- 사로나이트 던지기
        { eventID = 147, role = "Mechanic" }, -- 빙하 과잉
        -- 이크와 크리크
        { eventID = 203, role = "Mechanic" }, -- 이크, 물어뜯어!
        { eventID = 204, role = "Other" },    -- 망령의 이동
        { eventID = 205, role = "Heal" },     -- 역병 배출
        { eventID = 206, role = "Tank" },     -- 역병 강타
        { eventID = 560, role = "Mechanic" }, -- 육중한 집착
        -- 스컬지군주 티라누스
        { eventID = 164, role = "Tank" },     -- 스컬지군주의 낙인
        { eventID = 165, role = "Mechanic" }, -- 사자의 군대
        { eventID = 166, role = "Heal" },     -- 서릿발 작렬
        { eventID = 167, role = "Heal" },     -- 해골 주입
        { eventID = 168, role = "Other" },    -- 망자의 손아귀
        { eventID = 375, role = "Mechanic" }, -- 얼음 탄막
    },

    [1209] = { -- 하늘탑
        -- 란지트
        { eventID = 298, role = "Other" },    -- 강풍의 쇄도
        { eventID = 299, role = "Heal" },     -- 칼날 뿌리기
        { eventID = 300, role = "Other" },    -- 바람 차크람
        { eventID = 301, role = "Mechanic" }, -- 회전 표창의 회오리
        -- 아라크나스
        { eventID = 302, role = "Tank" },     -- 타오르는 강타
        { eventID = 303, role = "Heal" },     -- 충전
        { eventID = 304, role = "Heal" },     -- 초신성
        -- 루크란
        { eventID = 305, role = "Heal" },     -- 태양의 도래
        { eventID = 306, role = "Tank" },     -- 타오르는 발톱
        { eventID = 308, role = "Mechanic" }, -- 타오르는 깃털
        { eventID = 603, role = "Other" },    -- 영광의 불꽃
        -- 대현자 비릭스
        { eventID = 309, role = "Heal" },     -- 이글거리는 광선
        { eventID = 310, role = "Mechanic" }, -- 내려놓기
        { eventID = 311, role = "Other" },    -- 태양 작렬
        { eventID = 312, role = "Mechanic" }, -- 렌즈 반사광
    },

    [1592] = { -- 孢陨幽境
        -- 부패한 늪 (腐沼)
        { eventID = 424, role = "Mechanic" }, -- 균류 만개
        { eventID = 425, role = "Mechanic" }, -- 균류 소환
        { eventID = 426, role = "Heal" },     -- 농포 폭발
        { eventID = 427, role = "Tank" },     -- 부패의 주먹
        { eventID = 428, role = "Heal" },     -- 부패한 덩굴
        { eventID = 808, role = "Mechanic" }, -- 균류인 유충
        { eventID = 809, role = "Mechanic" }, -- 버섯인 유충
    },

    [1753] = { -- 삼두정의 권좌
        -- 승천자 주라알
        { eventID = 223, role = "Other" },    -- 무효의 손바닥
        { eventID = 224, role = "Mechanic" }, -- 척살
        { eventID = 225, role = "Heal" },     -- 진흙 강타
        { eventID = 226, role = "Tank" },     -- 공허의 습격
        { eventID = 238, role = "Mechanic" }, -- 밀어닥치는 공허
        -- 사프리쉬
        { eventID = 234, role = "Other" },    -- 공허 폭탄
        { eventID = 235, role = "Mechanic" }, -- 위상 질주
        { eventID = 236, role = "Other" },    -- 섬뜩한 비명
        { eventID = 237, role = "Heal" },     -- 어둠의 암습
        { eventID = 243, role = "Heal" },     -- 과부하
        -- 총독 네자르
        { eventID = 244, role = "Other" },    -- 정신 분열
        { eventID = 245, role = "Heal" },     -- 대규모 공허 주입
        { eventID = 246, role = "Heal" },     -- 암영 촉수
        { eventID = 247, role = "Mechanic" }, -- 공허의 폭풍
        { eventID = 376, role = "Other" },    -- 심연의 관문
        -- 르우라
        { eventID = 248, role = "Heal" },     -- 절망의 음표
        { eventID = 249, role = "Heal" },     -- 절망의 진혼곡
        { eventID = 250, role = "Mechanic" }, -- 불협의 광선
        { eventID = 251, role = "Other" },    -- 파열
        { eventID = 252, role = "Other" },    -- 암울한 합창
        { eventID = 253, role = "Mechanic" }, -- 영원한 밤의 교향곡
        { eventID = 254, role = "Mechanic" }, -- 반발력
    },



    [2805] = { -- 윈드러너 첨탑
        -- 잿불여명
        { eventID = 239, role = "Tank" },     -- 불타는 부리
        { eventID = 241, role = "Heal" },     -- 불타는 상승 기류
        { eventID = 242, role = "Heal" },     -- 불타는 강풍
        { eventID = 736, role = "Other" },    -- 불타는 상승 기류
        -- 버려진 2인조
        { eventID = 25,  role = "Tank" },     -- 뼈 베기
        { eventID = 26,  role = "Heal" },     -- 어둠의 저주
        { eventID = 27,  role = "Heal" },     -- 쇠약의 절규
        { eventID = 28,  role = "Other" },    -- 흩어지는 분출
        { eventID = 29,  role = "Mechanic" }, -- 힘껏 당기기
        -- 지휘관 크롤루크
        { eventID = 210, role = "Tank" },     -- 광란
        { eventID = 211, role = "Mechanic" }, -- 위협의 외침
        { eventID = 212, role = "Heal" },     -- 무모한 도약
        { eventID = 213, role = "Mechanic" }, -- 위협의 외침
        { eventID = 214, role = "Heal" },     -- 무모한 도약
        { eventID = 215, role = "Mechanic" }, -- 재집결의 고함
        { eventID = 216, role = "Other" },    -- 칼날폭풍
        { eventID = 556, role = "Tank" },     -- 광란
        -- 잠 못 드는 심장
        { eventID = 21,  role = "Mechanic" }, -- 백발백중 바람작렬
        { eventID = 22,  role = "Heal" },     -- 화살 강풍
        { eventID = 23,  role = "Other" },    -- 화살의 비
        { eventID = 24,  role = "Tank" },     -- 폭풍의 베기
        { eventID = 538, role = "Heal" },     -- 돌풍 사격
    },

    [2811] = { -- 마법학자의 정원
        -- 비전골렘 쿠스토스
        { eventID = 281, role = "Mechanic" }, -- 연료 보급 프로토콜
        { eventID = 286, role = "Tank" },     -- 반발하는 격돌
        { eventID = 287, role = "Heal" },     -- 에테리얼 구속
        { eventID = 288, role = "Other" },    -- 비전 방출
        -- 사라넬 선래쉬
        { eventID = 93,  role = "Mechanic" }, -- 억제 지대
        { eventID = 94,  role = "Tank" },     -- 쾌속의 수호물
        { eventID = 95,  role = "Heal" },     -- 룬 징표
        { eventID = 96,  role = "Mechanic" }, -- 침묵의 물결
        -- 제멜루스
        { eventID = 97,  role = "Mechanic" }, -- 신경 연결
        { eventID = 98,  role = "Heal" },     -- 천공의 손아귀
        { eventID = 99,  role = "Other" },    -- 공허의 분비물
        { eventID = 100, role = "Heal" },     -- 우주의 독침
        { eventID = 635, role = "Mechanic" }, -- 3중 복제
        { eventID = 760, role = "Other" },    -- 3중 복제
        -- 디젠트리우스
        { eventID = 290, role = "Heal" },     -- 엔트로피 포식
        { eventID = 292, role = "Other" },    -- 불안정한 공허의 정수
        { eventID = 420, role = "Tank" },     -- 거대한 파편
    },

    [2874] = { -- 메아리치는 동굴
        -- 무로진과 네크락스
        { eventID = 150, role = "Tank" },     -- 측방의 창
        { eventID = 151, role = "Other" },    -- 악취 나는 깃털 폭풍
        { eventID = 152, role = "Mechanic" }, -- 빙결 덫
        { eventID = 153, role = "Heal" },     -- 탄막
        { eventID = 154, role = "Heal" },     -- 감염된 독
        { eventID = 155, role = "Mechanic" }, -- 썩어가는 강하
        -- 보르다자
        { eventID = 16,  role = "Tank" },     -- 영혼 흡수
        { eventID = 17,  role = "Other" },    -- 해체
        { eventID = 18,  role = "Other" },    -- 죽음의 은총
        { eventID = 19,  role = "Mechanic" }, -- 악령 왜곡
        { eventID = 20,  role = "Heal" },     -- 괴저의 수렴
        { eventID = 429, role = "Mechanic" }, -- 최후의 추적
        { eventID = 688, role = "Other" },    -- 최후의 추적
        -- 영혼의 그릇 락툴
        { eventID = 156, role = "Tank" },     -- 영혼파괴자
        { eventID = 157, role = "Heal" },     -- 영혼 분쇄하기
        { eventID = 158, role = "Mechanic" }, -- 영혼을 찢는 포효
    },

    [2912] = { -- 공허 첨탑
        -- 아베르지안
        { eventID = 194, role = "Mechanic" }, -- 어둠의 진격
        { eventID = 195, role = "Mechanic" }, -- 어둠의 진격
        { eventID = 196, role = "Heal" },     -- 어둠의 지각 변동
        { eventID = 197, role = "Mechanic" }, -- 암영 붕괴
        { eventID = 198, role = "Other" },    -- 망각의 분노
        { eventID = 199, role = "Other" },    -- 공허 추락
        { eventID = 200, role = "Other" },    -- 끝없는 행진
        { eventID = 201, role = "Other" },    -- 칠흑 보루
        { eventID = 209, role = "Other" },    -- 공허 추락
        { eventID = 361, role = "Other" },    -- 황폐화
        { eventID = 419, role = "Mechanic" }, -- 공허 징표
        { eventID = 492, role = "Tank" },     -- 약화됨
        -- 보라시우스
        { eventID = 59,  role = "Tank" },     -- 그림자발톱 격돌
        { eventID = 60,  role = "Tank" },     -- 그림자발톱 격돌
        { eventID = 61,  role = "Other" },    -- 공허의 숨결
        { eventID = 62,  role = "Heal" },     -- 기생충 배출
        { eventID = 63,  role = "Other" },    -- 거대한 투척
        { eventID = 133, role = "Heal" },     -- 태고의 포효
        { eventID = 557, role = "Other" },    -- 시선 고정
        { eventID = 749, role = "Other" },    -- 생성
        -- 몰락한 왕 살라다르
        { eventID = 139, role = "Mechanic" }, -- 공허의 수렴
        { eventID = 140, role = "Heal" },     -- 폭군의 지배
        { eventID = 141, role = "Other" },    -- 분열된 투영
        { eventID = 142, role = "Other" },    -- 부서지는 황혼
        { eventID = 143, role = "Heal" },     -- 뒤틀린 암연
        { eventID = 148, role = "Mechanic" }, -- 무질서의 해체
        { eventID = 633, role = "Other" },    -- 광폭화
        { eventID = 802, role = "Other" },    -- 맹세를 저버리다
        -- 바엘고어와 에조라크
        { eventID = 101, role = "Other" },    -- 공허 빔
        { eventID = 102, role = "Mechanic" }, -- 공허의 울부짖음
        { eventID = 103, role = "Mechanic" }, -- 안개
        { eventID = 104, role = "Other" },    -- 죽은 자의 숨결
        { eventID = 105, role = "Heal" },     -- 한밤의 불꽃
        { eventID = 219, role = "Other" },    -- 갈고리 턱
        { eventID = 220, role = "Tank" },     -- 락팽
        { eventID = 221, role = "Tank" },     -- 위어의 날개
        { eventID = 377, role = "Mechanic" }, -- 우주 침투: 안개
        { eventID = 378, role = "Other" },    -- 우주 침투: 공허 빔
        { eventID = 379, role = "Other" },    -- 우주 침투: 망자의 숨결
        { eventID = 380, role = "Mechanic" }, -- 우주 침투: 공허의 포효
        { eventID = 381, role = "Mechanic" }, -- 광역 장벽
        -- 빛에 눈이 먼 선봉대
        { eventID = 71,  role = "Mechanic" }, -- 평화로운 후광
        { eventID = 72,  role = "Other" },    -- 이벤트 72
        { eventID = 73,  role = "Other" },    -- 천둥 코끼리 돌격
        { eventID = 74,  role = "Mechanic" }, -- 거룩한 방패
        { eventID = 75,  role = "Heal" },     -- 티르의 분노
        { eventID = 76,  role = "Mechanic" }, -- 경건의 아우라
        { eventID = 77,  role = "Heal" },     -- 뜨거운 빛
        { eventID = 78,  role = "Tank" },     -- 심판
        { eventID = 79,  role = "Mechanic" }, -- 복수의 방패
        { eventID = 80,  role = "Mechanic" }, -- 거룩한 종
        { eventID = 81,  role = "Mechanic" }, -- 분노의 아우라
        { eventID = 82,  role = "Tank" },     -- 심판
        { eventID = 83,  role = "Mechanic" }, -- 신성한 폭풍
        { eventID = 84,  role = "Heal" },     -- 거룩한 죄
        { eventID = 85,  role = "Heal" },     -- 사형 선고
        { eventID = 358, role = "Mechanic" }, -- 열성적인 영혼
        { eventID = 359, role = "Mechanic" }, -- 열성적인 영혼
        { eventID = 360, role = "Mechanic" }, -- 열성적인 영혼
        { eventID = 365, role = "Mechanic" }, -- 복수의 방패
        { eventID = 373, role = "Heal" },     -- 뜨거운 빛
        { eventID = 374, role = "Other" },    -- 신성한 폭풍
        -- 우주의 왕관
        { eventID = 4,   role = "Heal" },     -- 무의 왕관
        { eventID = 5,   role = "Mechanic" }, -- 공허한 반발
        { eventID = 6,   role = "Mechanic" }, -- 은화살
        { eventID = 7,   role = "Other" },    -- 은화살 탄막
        { eventID = 8,   role = "Other" },    -- 특이점 폭발
        { eventID = 9,   role = "Heal" },     -- 공허추적자 스파이크
        { eventID = 10,  role = "Mechanic" }, -- 공허의 부름
        { eventID = 11,  role = "Heal" },     -- 레인저 캡틴의 마크
        { eventID = 12,  role = "Heal" },     -- 우주 장벽
        { eventID = 13,  role = "Mechanic" }, -- 최종 수호자
        { eventID = 14,  role = "Heal" },     -- 공허함의 파악
        { eventID = 15,  role = "Mechanic" }, -- 우주를 삼켜라
        { eventID = 64,  role = "Tank" },     -- 어둠의 손
        { eventID = 65,  role = "Mechanic" }, -- 폭식의 심연
        { eventID = 66,  role = "Heal" },     -- 간섭 진동
        { eventID = 131, role = "Heal" },     -- 레인저 캡틴의 마크
        { eventID = 132, role = "Heal" },     -- 공허함의 파악
        { eventID = 135, role = "Mechanic" }, -- 균열 환영
        { eventID = 136, role = "Mechanic" }, -- 우주 포털
        { eventID = 137, role = "Tank" },     -- 균열 베기
        { eventID = 169, role = "Other" },    -- 우주 에너지 과부하
    },

    [2913] = { -- 쿠엘다나스 진격로
        -- 오라의 아들 벨로란트
        { eventID = 128, role = "Mechanic" }, -- 벨로란의 불씨
        { eventID = 130, role = "Mechanic" }, -- 빛나는 메아리
        { eventID = 134, role = "Tank" },     -- 수호자 칙령
        { eventID = 138, role = "Heal" },     -- 영원한 소각
        { eventID = 161, role = "Mechanic" }, -- 주입된 깃털
        { eventID = 218, role = "Heal" },     -- 공허빛 합류
        { eventID = 272, role = "Mechanic" }, -- 죽음의 낙하
        { eventID = 273, role = "Other" },    -- 화염 부화
        { eventID = 384, role = "Mechanic" }, -- 성광의 깃털
        { eventID = 385, role = "Mechanic" }, -- 공허의 깃털
        { eventID = 417, role = "Other" },    -- 이벤트 417
        { eventID = 418, role = "Other" },    -- 이벤트 418
        { eventID = 482, role = "Mechanic" }, -- 성광의 깃털
        { eventID = 483, role = "Mechanic" }, -- 공허의 깃털
        { eventID = 494, role = "Heal" },     -- 성광의 급습
        { eventID = 495, role = "Heal" },     -- 공허 강하
        { eventID = 497, role = "Mechanic" }, -- 부활
        { eventID = 500, role = "Mechanic" }, -- 공허빛의 분노
        { eventID = 748, role = "Other" },    -- 부활
        -- 어둠의 강림
        { eventID = 255, role = "Mechanic" }, -- 죽음의 만가
        { eventID = 256, role = "Other" },    -- 하늘의 대검
        { eventID = 257, role = "Other" },    -- 수호 각기둥
        { eventID = 258, role = "Heal" },     -- 부서진 하늘
        { eventID = 259, role = "Heal" },     -- 개기일식
        { eventID = 260, role = "Mechanic" }, -- 가장 어두운 밤
        { eventID = 261, role = "Mechanic" }, -- 빛의 사이펀
        { eventID = 262, role = "Other" },    -- 어두운 별자리
        { eventID = 263, role = "Other" },    -- 암흑 대천사
        { eventID = 362, role = "Mechanic" }, -- 죽음의 레퀴엠
        { eventID = 363, role = "Heal" },     -- 연결 끊기
        { eventID = 364, role = "Tank" },     -- 하늘의 창
        { eventID = 433, role = "Mechanic" }, -- 어둠의 우물 깊이
        { eventID = 434, role = "Heal" },     -- 우주 핵분열
        { eventID = 435, role = "Heal" },     -- 핵심 수확
        { eventID = 436, role = "Other" },    -- 암흑 붕괴
        { eventID = 437, role = "Heal" },     -- 별조각
        { eventID = 632, role = "Heal" },     -- 충전
        { eventID = 636, role = "Other" },    -- 종단 각기둥
        { eventID = 644, role = "Mechanic" }, -- 말살 협주곡
        { eventID = 649, role = "Other" },    -- 암흑 퀘이사
        { eventID = 650, role = "Heal" },     -- 어두운 룬
        { eventID = 750, role = "Other" },    -- 불협의 자장가
    },

    [2915] = { -- 공결탑 제나스
        -- 수석 핵장인 카스레스
        { eventID = 106, role = "Heal" },     -- 핵심불꽃 폭발
        { eventID = 107, role = "Other" },    -- 역류 돌진
        { eventID = 108, role = "Other" },    -- 지맥 배열
        { eventID = 172, role = "Other" },    -- 용제 붕괴
        -- 핵감시관 니사라
        { eventID = 33,  role = "Heal" },     -- 일식의 발걸음
        { eventID = 34,  role = "Mechanic" }, -- 빛흉터 섬광
        { eventID = 35,  role = "Tank" },     -- 암영의 채찍
        { eventID = 36,  role = "Mechanic" }, -- 무위의 선봉대
        { eventID = 313, role = "Other" },    -- 무가치한 자는 포식당하리
        -- 로스락시온
        { eventID = 109, role = "Heal" },     -- 찬란한 분산
        { eventID = 110, role = "Mechanic" }, -- 천상의 기만
        { eventID = 111, role = "Tank" },     -- 이글거리는 분쇄
        { eventID = 112, role = "Other" },    -- 깜빡임
    },

    [2939] = { -- 꿈의 균열
        -- 꿈결을 벗어난 신 카이메루스
        { eventID = 48,  role = "Other" },    -- 대식가 강하
        { eventID = 49,  role = "Heal" },     -- 균열 발생
        { eventID = 50,  role = "Heal" },     -- 부식성 가래
        { eventID = 51,  role = "Other" },    -- 찢어지다
        { eventID = 53,  role = "Other" },    -- 부패와 파괴
        { eventID = 117, role = "Other" },    -- 끔찍한 전쟁의 함성
        { eventID = 118, role = "Heal" },     -- 불협화음의 포효
        { eventID = 119, role = "Mechanic" }, -- 장기를 포식
        { eventID = 126, role = "Other" },    -- 부패의 깃털
        { eventID = 149, role = "Mechanic" }, -- 엘린더스트의 격변
        { eventID = 170, role = "Other" },    -- 균열 대격변
        { eventID = 208, role = "Other" },    -- 부패한 산성액
        { eventID = 217, role = "Mechanic" }, -- 균열의 광기
        { eventID = 307, role = "Heal" },     -- 포식
        { eventID = 353, role = "Mechanic" }, -- 2페이즈
        { eventID = 431, role = "Mechanic" }, -- 엘린더스트의 격변
        { eventID = 458, role = "Other" },    -- 부패와 파괴
        { eventID = 555, role = "Other" },    -- 삼켜진 정수
    },
}

-- ==============================
-- 캐싱
-- ==============================
local C_EncounterEvents = C_EncounterEvents
local CreateColor = CreateColor
local CreateFrame = CreateFrame
local GetInstanceInfo = GetInstanceInfo
local IsInInstance = IsInInstance
local ipairs = ipairs

-- ==============================
-- 기능 1: 색상 적용/해제
-- ==============================
local current_events = nil -- 현재 적용된 이벤트 목록 (해제 시 사용)

local function clear_current()
    if not (C_EncounterEvents and C_EncounterEvents.SetEventColor) then return end
    if not current_events then return end
    -- SetEventColor가 ENCOUNTER_TIMELINE_STATE_UPDATED를 sync 발화 → tainted C_Timer chain 차단
    local et = EncounterTimeline
    if et then et:UnregisterEvent("ENCOUNTER_TIMELINE_STATE_UPDATED") end
    for _, entry in ipairs(current_events) do
        C_EncounterEvents.SetEventColor(entry.eventID, 0, nil)
        C_EncounterEvents.SetEventColor(entry.eventID, 1, nil)
    end
    if et then et:RegisterEvent("ENCOUNTER_TIMELINE_STATE_UPDATED") end
    current_events = nil
end

local function update_visual()
    clear_current()
    if not (dodoDB and dodoDB.enableEncounterTimelineColor ~= false) then return end

    local inInstance, instanceType = IsInInstance()
    if not inInstance or (instanceType ~= "party" and instanceType ~= "raid") then return end

    local mapID = select(8, GetInstanceInfo())
    local events = INSTANCE_EVENTS[mapID]
    if not events then return end

    local et = EncounterTimeline
    if et then et:UnregisterEvent("ENCOUNTER_TIMELINE_STATE_UPDATED") end
    for _, entry in ipairs(events) do
        local role = dodo.Colors.EncounterRole and dodo.Colors.EncounterRole[entry.role]
        local color = role and CreateColor(role.r, role.g, role.b)
        C_EncounterEvents.SetEventColor(entry.eventID, 0, color)
        C_EncounterEvents.SetEventColor(entry.eventID, 1, color)
    end
    if et then et:RegisterEvent("ENCOUNTER_TIMELINE_STATE_UPDATED") end
    current_events = events
end

-- ==============================
-- 이벤트 핸들러
-- ==============================
local initFrame = CreateFrame("Frame")

local function on_event(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == addonName then
        dodoDB = dodoDB or {}
    elseif event == "PLAYER_LOGIN" then
        if dodoDB.enableEncounterTimelineColor == nil then dodoDB.enableEncounterTimelineColor = true end
        self:UnregisterEvent("PLAYER_LOGIN")
    elseif event == "PLAYER_ENTERING_WORLD" then
        update_visual()
    end
end

initFrame:RegisterEvent("ADDON_LOADED")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
initFrame:SetScript("OnEvent", on_event)

-- ==============================
-- 설정 등록
-- ==============================
if dodo.RegisterEditModeModuleSetting then
    dodo.RegisterEditModeModuleSetting("편의기능", {
        {
            name = "보스 타임라인 색상 변경",
            get = function() return dodoDB and dodoDB.enableEncounterTimelineColor ~= false end,
            set = function(checked)
                if dodoDB then dodoDB.enableEncounterTimelineColor = checked end
                update_visual()
            end
        }
    })
end
