---@diagnostic disable: lowercase-global, undefined-field, undefined-global
local dodo = _G.dodo

-- ==============================
-- 트래킹 대상 (specID별, 확장 포인트)
-- ==============================
-- type: "cooldown" (쿨다운 준비알림, 차지 지원) | "aura" (버프 스택+지속시간 표시)
-- group: "interrupt" | "dispel" | "cd" | "cc" ... (99 Options.lua의 dodo.CST_ROW_BY_GROUP / CST_GROUP_ORDER 참고, 배치 열·순서 결정)
-- enabled: false = 기본 꺼짐 (설정창 주문 목록에서 켤 수 있음), 생략 = 기본 켜짐
dodo.CST_SPELLS_BY_SPEC = {
    -- 전사
    [71] = { -- 무기
        { spellID = 6552, type = "cooldown", group = "interrupt" }, -- 차단
        { spellID = 107570, type = "cooldown", group = "cc" }, -- 폭망
        { spellID = 46968, type = "cooldown", group = "cc" }, -- 충파
        { spellID = 5246, type = "cooldown", group = "cc", enabled = false }, -- 공포
    },
    [72] = { -- 분노
        { spellID = 6552, type = "cooldown", group = "interrupt" }, -- 차단
        { spellID = 107570, type = "cooldown", group = "cc" }, -- 폭망
        { spellID = 46968, type = "cooldown", group = "cc" }, -- 충파
        { spellID = 5246, type = "cooldown", group = "cc", enabled = false }, -- 공포
    },
    [73] = { -- 방어
        { spellID = 6552, type = "cooldown", group = "interrupt" }, -- 차단
        { spellID = 386071, type = "cooldown", group = "interrupt" }, -- 훼방
        { spellID = 107570, type = "cooldown", group = "cc" }, -- 폭망
        { spellID = 46968, type = "cooldown", group = "cc" }, -- 충파
        { spellID = 5246, type = "cooldown", group = "cc", enabled = false }, -- 공포
    },
    -- 성기사
    [65] = {},   -- 신성
    [66] = {},   -- 보호
    [70] = {},   -- 징벌
    -- 사냥꾼
    [253] = {},  -- 야수
    [254] = {},  -- 사격
    [255] = {},  -- 생존
    -- 도적
    [259] = {},  -- 암살
    [260] = {},  -- 무법
    [261] = {},  -- 잠행
    -- 사제
    [256] = {},  -- 수양
    [257] = {},  -- 신성
    [258] = {},  -- 암흑
    -- 죽음의 기사
    [250] = {},  -- 혈기
    [251] = {},  -- 냉기
    [252] = {},  -- 부정
    -- 주술사
    [262] = {},  -- 정기
    [263] = {},  -- 고양
    -- 마법사
    [62] = {},   -- 비전
    [63] = {},   -- 화염
    [64] = {},   -- 냉기
    -- 흑마법사
    [265] = {},  -- 고통
    [266] = {},  -- 악마
    [267] = {},  -- 파괴
    -- 수도사
    [268] = {},  -- 양조
    [270] = {},  -- 운무
    [269] = {},  -- 풍운
    -- 드루이드
    [102] = {},  -- 조화
    [103] = {},  -- 야성
    [104] = {},  -- 수호
    [105] = {},  -- 회복
    -- 악마사냥꾼
    [577] = {},  -- 파멸
    [581] = {},  -- 복수
    [1480] = {}, -- 포식
    -- 기원사
    [1467] = {}, -- 황폐
    [1468] = {}, -- 보존
    [1473] = {}, -- 증강

    [264] = { -- 복원 주술사
        { spellID = 57994, type = "cooldown", group = "interrupt" }, -- 차단
        { spellID = 77130, type = "cooldown", group = "dispel" },    -- 해제
        -- glowCDMSpellID: 블리자드 CDM 추적 버프에는 버프 ID(53390)가 아닌 특성 ID(51564)로 등록됨
        { spellID = 61295, type = "cooldown", group = "cd", glowAuraSpellID = 53390, glowCDMSpellID = 51564 }, -- 성난해일 (굽이치는 물결)
        { spellID = 192058, type = "cooldown", group = "cc", enabled = false  }, -- 축전
    }
}
