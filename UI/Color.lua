-- ========================================================================
-- dodo UI Color Palette
-- Description: 단일 1차원 플랫 팔레트 관리 구조 (용도별 복잡한 분류 통합).
-- ========================================================================

---@diagnostic disable: lowercase-global, param-type-mismatch, redundant-parameter, undefined-field, undefined-global
local addonName, dodo = ...
dodoDB = dodoDB or {}
dodo.Colors = dodo.Colors or {}

-- ==============================
-- 기능 1: 색상 테이블
-- ==============================
dodo.Colors = {
    Gold         = { r = 1.0, g = 0.82, b = 0.0, hex = "ffffd100" },
    Gray         = { r = 0.63, g = 0.63, b = 0.63, hex = "ffa0a0a0" },
    Green        = { r = 0.0, g = 1.0, b = 0.0, hex = "ff00ff00" },
    Orange       = { r = 1.0, g = 0.66, b = 0.0, hex = "ffffaa00" },
    Red          = { r = 1.0, g = 0.0, b = 0.0, hex = "ffff0000" },
    White        = { r = 1.0, g = 1.0, b = 1.0, hex = "ffffffff" },

    SoftRed      = { r = 1.0, g = 0.7, b = 0.7, hex = "ffffb2b2" },
    SoftGreen    = { r = 0.7, g = 1.0, b = 0.7, hex = "ffb2ffb2" },
    LemonYellow  = { r = 1.0, g = 1.0, b = 0.7, hex = "ffffffb2" },

    ForestGreen  = { r = 0.2, g = 0.6, b = 0.1, hex = "ff339919" },
    DeepRed      = { r = 0.7, g = 0.2, b = 0.1, hex = "ffb23319" },

    Blue         = { r = 0.0, g = 0.0, b = 1.0, hex = "ff0000ff" },
    FrostBlue    = { r = 0.58, g = 0.8, b = 0.97, hex = "ff94ccf7" },
    UnholyGreen  = { r = 0.68, g = 0.92, b = 0.26, hex = "ffadeb42" },
    ChiJade      = { r = 0.71, g = 1.0, b = 0.92, hex = "ffb5ffeb" },
    ShardPurple  = { r = 0.5, g = 0.32, b = 0.55, hex = "ff80518c" },
    EssenceTeal  = { r = 0.39, g = 0.68, b = 0.81, hex = "ff63adcf" }
}










-- Colors.Gold         = { r = 1.0, g = 0.82, b = 0.0 }   -- dodo 메인 골드 (Primary / HealthNeutral / HolyGold)
-- Colors.Green        = { r = 0.1, g = 1.0, b = 0.1 }   -- 활성 밝은 그린 (Success)
-- Colors.Orange       = { r = 1.0, g = 0.5, b = 0.0 }   -- 경고 오렌지 (Warning / FocusOrange)
-- Colors.Red          = { r = 1.0, g = 0.1, b = 0.1 }   -- 위험/에러 레드 (Danger / Bleed / Threat)
-- Colors.Gray         = { r = 0.6, g = 0.6, b = 0.6 }   -- 비활성/선점/접속끊김 그레이 (Muted / Disconnected / Tapped)
-- Colors.White        = { r = 1.0, g = 1.0, b = 1.0 }   -- 순백색 (White)
-- Colors.SkyBlue      = { r = 0.6, g = 0.7, b = 1.0 }   -- 아군 플레이어 하늘색 (NamePlayerFriendly / oUF RunicPower)
-- Colors.SoftRed      = { r = 1.0, g = 0.7, b = 0.7 }   -- 적군 파스텔 레드 (NamePlayerHostile / NameNpcHostile)
-- Colors.SoftGreen    = { r = 0.7, g = 1.0, b = 0.7 }   -- 아군 NPC 연그린 (NameNpcFriendly)
-- Colors.LemonYellow  = { r = 1.0, g = 0.97, b = 0.7 }  -- 중립 NPC 연노랑 (NameNpcNeutral)
-- Colors.ForestGreen  = { r = 0.2, g = 0.6, b = 0.1 }   -- 아군 체력바 숲색 (HealthFriendly)
-- -- Colors.DeepRed      = { r = 0.7, g = 0.2, b = 0.1 }   -- 적군 체력바 딥레드 (HealthHostile / oUF Blood)
-- -- Colors.Blue         = { r = 0.0, g = 0.0, b = 1.0 }   -- 마나 블루 (oUF Mana)
-- -- Colors.FrostBlue    = { r = 0.58, g = 0.8, b = 0.97 }  -- 냉기 룬 라이트블루 (oUF Frost)
-- -- Colors.UnholyGreen  = { r = 0.68, g = 0.92, b = 0.26 } -- 부정 룬 밝은연두 (oUF Unholy)
-- -- Colors.ChiJade      = { r = 0.71, g = 1.0, b = 0.92 }  -- 수도사 기 비취색 (oUF Chi)
-- -- Colors.ShardPurple  = { r = 0.5, g = 0.32, b = 0.55 }  -- 조각 흑마 퍼플 (oUF SoulShards)
-- -- Colors.EssenceTeal  = { r = 0.39, g = 0.68, b = 0.81 }  -- 기원사 정수 에메랄드 (oUF Essence)

-- -- ==============================
-- -- 기능 2: 1:1 매핑 헥스 코드 팔레트 (정적 헥스)
-- -- ==============================


-- -- ==============================
-- -- 기능 3: 디스펠 속성용 2차 매핑 (정적 참조)
-- -- ==============================
-- Colors.Dispel = {
--     Magic   = { r = 0.2, g = 0.6, b = 1.0 },
--     Curse   = { r = 0.6, g = 0.0, b = 1.0 },
--     Disease = { r = 0.6, g = 0.4, b = 0.1 },
--     Poison  = { r = 0.0, g = 0.6, b = 0.0 },
--     Bleed   = Colors.Red,
--     Enrage  = { r = 0.95, g = 0.37, b = 0.96 },
--     None    = Colors.DeepRed
-- }

-- -- ==============================
-- -- 기능 4: 용도별 편리성 에일리어스 (참조 포인터 별칭)
-- -- ==============================
-- -- 기존 네스팅 조회 호환 및 명시적 직관용 매핑
-- Colors.Primary = Colors.Gold
-- Colors.Success = Colors.Green
-- Colors.Warning = Colors.Orange
-- Colors.Danger  = Colors.Red
-- Colors.Muted   = Colors.Gray

-- Colors.Name = {
--     PlayerFriendly = Colors.SkyBlue,
--     PlayerHostile  = Colors.SoftRed,
--     NpcFriendly    = Colors.SoftGreen,
--     NpcNeutral     = Colors.LemonYellow,
--     NpcHostile     = Colors.SoftRed
-- }

-- Colors.Health = {
--     Friendly    = Colors.ForestGreen,
--     Neutral     = Colors.Gold,
--     Hostile     = Colors.DeepRed
-- }

-- Colors.Power = {
--     Mana        = Colors.Blue,
--     Rage        = Colors.Red,
--     Focus       = Colors.Orange,
--     Energy      = { r = 1.0, g = 1.0, b = 0.0 }, -- 순정 노랑
--     RunicPower  = { r = 0.0, g = 0.82, b = 1.0 }, -- 순정 하늘
--     Chi         = Colors.ChiJade,
--     HolyPower   = Colors.Gold,
--     SoulShards  = Colors.ShardPurple,
--     Essence     = Colors.EssenceTeal
-- }