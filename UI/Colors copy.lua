-- ========================================================================
-- dodo UI Color Palette
-- Description: 중앙 집중식 공용 정적 색상 테이블 (동적 생성 연산 배제).
-- ========================================================================

---@diagnostic disable: lowercase-global, param-type-mismatch, redundant-parameter, undefined-field, undefined-global
local addonName, dodo = ...
dodo.Colors = dodo.Colors or {}

local Colors = dodo.Colors

---@class dodoColorRGB
---@field r number Red
---@field g number Green
---@field b number Blue

-- ==============================
-- 기능 1: dodo 브랜드 및 상태 색상 (정적 RGB)
-- ==============================
---@type dodoColorRGB
Colors.Primary = { r = 1.0, g = 0.82, b = 0.0 }   -- dodo 골드

---@type dodoColorRGB
Colors.Success = { r = 0.1, g = 1.0, b = 0.1 }   -- 활성 그린

---@type dodoColorRGB
Colors.Warning = { r = 1.0, g = 0.5, b = 0.0 }   -- 경고 오렌지

---@type dodoColorRGB
Colors.Danger  = { r = 1.0, g = 0.1, b = 0.1 }   -- 위험 레드

---@type dodoColorRGB
Colors.Muted   = { r = 0.6, g = 0.6, b = 0.6 }   -- 비활성 그레이

---@type dodoColorRGB
Colors.White   = { r = 1.0, g = 1.0, b = 1.0 }

-- ==============================
-- 기능 2: Kui 스타일 아군/적군 네임플레이트 텍스트 색상 (정적 RGB)
-- ==============================
Colors.Name = {
    PlayerFriendly = { r = 0.6, g = 0.7, b = 1.0 },   -- 아군 플레이어 (하늘빛 블루)
    PlayerHostile  = { r = 1.0, g = 0.7, b = 0.7 },   -- 적군 플레이어 (파스텔 레드)
    NpcFriendly    = { r = 0.7, g = 1.0, b = 0.7 },   -- 아군 NPC (연그린)
    NpcNeutral     = { r = 1.0, g = 0.97, b = 0.7 },  -- 중립 NPC (연노랑)
    NpcHostile     = { r = 1.0, g = 0.7, b = 0.7 }    -- 적군 NPC (파스텔 레드)
}

-- ==============================
-- 기능 3: Kui 스타일 체력바 색상 (정적 RGB)
-- ==============================
Colors.Health = {
    Friendly    = { r = 0.2, g = 0.6, b = 0.1 },   -- 아군/우호적 (그린)
    Neutral     = { r = 1.0, g = 0.8, b = 0.0 },   -- 중립적 (황금빛 노랑)
    Hostile     = { r = 0.7, g = 0.2, b = 0.1 }    -- 적군/몹 (딥 레드)
}

-- ==============================
-- 기능 4: oUF 기반 직업별 자원(Power) 색상 (정적 RGB)
-- ==============================
Colors.Power = {
    Mana        = { r = 0.0, g = 0.0, b = 1.0 },      -- 마나 (블랙블루)
    Rage        = { r = 1.0, g = 0.0, b = 0.0 },      -- 분노 (레드)
    Focus       = { r = 1.0, g = 0.5, b = 0.25 },     -- 집중 (오렌지)
    Energy      = { r = 1.0, g = 1.0, b = 0.0 },      -- 기력 (옐로우)
    RunicPower  = { r = 0.0, g = 0.82, b = 1.0 },     -- 룬 마력 (하늘색)
    Chi         = { r = 0.71, g = 1.0, b = 0.92 },    -- 수도사 기 (비취색)
    HolyPower   = { r = 0.95, g = 0.9, b = 0.6 },     -- 신성한 힘 (옅은 골드)
    SoulShards  = { r = 0.5, g = 0.32, b = 0.55 },    -- 영혼의 조각 (퍼플)
    Essence     = { r = 0.39, g = 0.68, b = 0.81 }    -- 기원사 정수 (에메랄드 블루)
}

-- ==============================
-- 기능 5: oUF 기반 룬(Rune) 및 유닛 특수 상태 색상 (정적 RGB)
-- ==============================
Colors.Rune = {
    Blood       = { r = 0.97, g = 0.25, b = 0.22 },   -- 혈기 룬
    Frost       = { r = 0.58, g = 0.8, b = 0.97 },    -- 냉기 룬
    Unholy      = { r = 0.68, g = 0.92, b = 0.26 }    -- 부정 룬
}

Colors.Unit = {
    Disconnected = { r = 0.6, g = 0.6, b = 0.6 },     -- 오프라인 (그레이)
    Tapped       = { r = 0.6, g = 0.6, b = 0.6 }      -- 선점된 대상 (그레이)
}

-- ==============================
-- 기능 6: 디스펠 속성별 색상 (정적 RGB)
-- ==============================
Colors.Dispel = {
    Magic   = { r = 0.2, g = 0.6, b = 1.0 },
    Curse   = { r = 0.6, g = 0.0, b = 1.0 },
    Disease = { r = 0.6, g = 0.4, b = 0.1 },
    Poison  = { r = 0.0, g = 0.6, b = 0.0 },
    Bleed   = { r = 1.0, g = 0.1, b = 0.1 },
    Enrage  = { r = 0.95, g = 0.37, b = 0.96 },
    None    = { r = 0.8, g = 0.0, b = 0.0 }
}

-- ==============================
-- 기능 7: 채팅창 및 FontString용 Hex 코드 (정적 헥스)
-- ==============================
Colors.Hex = {
    -- 기본 브랜드 헥스
    Primary = "ffffd100",
    Success = "ff00ff00",
    Warning = "ffffaa00",
    Danger  = "ffff0000",
    Muted   = "ffa0a0a0",
    White   = "ffffffff",
    
    -- Kui 스타일 이름 헥스
    NamePlayerFriendly = "ff99b2ff",
    NamePlayerHostile  = "ffffb2b2",
    NameNpcFriendly    = "ffb2ffb2",
    NameNpcNeutral     = "ffffffb2",
    
    -- Kui 스타일 체력바 헥스
    HealthFriendly = "ff339919",
    HealthNeutral  = "ffffcc00",
    HealthHostile  = "ffb23319",

    -- oUF 자원 주요 헥스
    PowerMana      = "ff0000ff",
    PowerRage      = "ffff0000",
    PowerEnergy    = "ffffff00",
    PowerRunic     = "ff00d1ff"
}