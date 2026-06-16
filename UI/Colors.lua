-- ========================================================================
-- dodo UI Color Palette
-- Description: 단일 1차원 플랫 팔레트 관리 구조 (용도별 복잡한 분류 통합).
-- ========================================================================

---@diagnostic disable: lowercase-global, param-type-mismatch, redundant-parameter, undefined-field, undefined-global
local addonName, dodo = ...
dodoDB = dodoDB or {}
_G.dodoAPI = dodo -- dodo_Test 등 의존 addon에서 dodo.* 공유 API 접근용
dodo.Colors = dodo.Colors or {}

-- ==============================
-- 기능 1: 색상 테이블
-- ==============================
dodo.Colors = {
	Primary = {
    Blue         = { r = 0.00, g = 0.00, b = 1.00, hex = "ff0000ff" },
    Gold         = { r = 1.00, g = 0.82, b = 0.00, hex = "ffffd100" },
    Gray         = { r = 0.63, g = 0.63, b = 0.63, hex = "ffa0a0a0" },
    Green        = { r = 0.00, g = 1.00, b = 0.00, hex = "ff00ff00" },
    Orange       = { r = 1.00, g = 0.66, b = 0.00, hex = "ffffaa00" },
    Red          = { r = 1.00, g = 0.00, b = 0.00, hex = "ffff0000" },
    White        = { r = 1.00, g = 1.00, b = 1.00, hex = "ffffffff" },
    },

	Class = { -- From oUF
    DEATHKNIGHT  = { r = 0.77, g = 0.12, b = 0.23, hex = "ffc41f3b" },
    DEMONHUNTER  = { r = 0.64, g = 0.19, b = 0.79, hex = "ffa330c9" },
    DRUID        = { r = 1.00, g = 0.49, b = 0.04, hex = "ffff7d0a" },
    EVOKER       = { r = 0.20, g = 0.58, b = 0.50, hex = "ff33937f" },
    HUNTER       = { r = 0.67, g = 0.83, b = 0.45, hex = "ffabd473" },
    MAGE         = { r = 0.25, g = 0.78, b = 0.92, hex = "ff3fc7eb" },
    MONK         = { r = 0.00, g = 1.00, b = 0.60, hex = "ff00ff96" },
    PALADIN      = { r = 0.96, g = 0.55, b = 0.73, hex = "fff58cba" },
    PRIEST       = { r = 1.00, g = 1.00, b = 1.00, hex = "ffffffff" },
    ROGUE        = { r = 1.00, g = 0.96, b = 0.41, hex = "ffffff69" },
    SHAMAN       = { r = 0.00, g = 0.44, b = 0.87, hex = "ff0070de" },
    WARLOCK      = { r = 0.53, g = 0.53, b = 0.93, hex = "ff8787ed" },
    WARRIOR      = { r = 0.78, g = 0.61, b = 0.43, hex = "ffc79c6e" },
    },

    Power = { -- From oUF
    Mana         = { r = 0.00, g = 0.00, b = 1.00, hex = "ff0000ff" },
    Rage         = { r = 1.00, g = 0.00, b = 0.00, hex = "ffff0000" },
    Focus        = { r = 1.00, g = 0.50, b = 0.25, hex = "ffff8040" },
    Energy       = { r = 1.00, g = 1.00, b = 0.00, hex = "ffffff00" },
    RunicPower   = { r = 0.00, g = 0.82, b = 1.00, hex = "ff00d1ff" },
    Chi          = { r = 0.71, g = 1.00, b = 0.92, hex = "ffb5ffeb" },
    HolyPower    = { r = 0.95, g = 0.90, b = 0.60, hex = "fff2e699" },
    SoulShards   = { r = 0.50, g = 0.32, b = 0.55, hex = "ff80518c" },
    Essence      = { r = 0.49, g = 0.91, b = 1.00, hex = "FF7CE7FF" },
    RuneBlood    = { r = 0.97, g = 0.25, b = 0.22, hex = "fff74139" },
    RuneFrost    = { r = 0.58, g = 0.80, b = 0.97, hex = "ff94cbf7" },
    RuneUnholy   = { r = 0.68, g = 0.92, b = 0.26, hex = "ffadeb42" },
    },
    
    Spec = {
        DEATHKNIGHT = {
            [1] = { r = 0.97, g = 0.25, b = 0.22, hex = "fff74139" }, -- 혈죽
            [2] = { r = 0.58, g = 0.80, b = 0.97, hex = "ff94cbf7" }, -- 냉죽
            [3] = { r = 0.68, g = 0.92, b = 0.26, hex = "ffadeb42" }, -- 부죽
        },
        DEMONHUNTER = { [2] = { r = 0.86, g = 0.59, b = 0.98, hex = "ffdb96fa" } }, -- 악탱
        DRUID       = { [3] = { r = 0.00, g = 0.82, b = 1.00, hex = "ff00d1ff" } }, -- 수드
        MONK        = {
            [1] = {
                r = 0.00, g = 1.00, b = 0.59, hex = "ff00ff96", -- 양조
                Stagger = {
                    [2] = { r = 1.00, g = 0.82, b = 0.00, hex = "ffffd100" }, -- 시간차 보통
                    [3] = { r = 1.00, g = 0.00, b = 0.00, hex = "ffff0000" }, -- 시간차 높음
                },
            },
        },
        SHAMAN      = { [3] = { r = 0.00, g = 0.82, b = 1.00, hex = "ff00d1ff" } }, -- 복술
        WARRIOR     = {
            [1] = { r = 1.00, g = 0.59, b = 0.20, hex = "ffff9633" }, -- 무기
            [2] = { r = 0.00, g = 0.82, b = 1.00, hex = "ff00d1ff" }, -- 분노
            [3] = { r = 1.00, g = 0.59, b = 0.20, hex = "ffff9633" }, -- 방어
        },
    },


    Reaction = { -- From oUF
    Reaction1    = { r = 0.80, g = 0.30, b = 0.22, hex = "ffcc4c38" },
    Reaction2    = { r = 0.80, g = 0.30, b = 0.22, hex = "ffcc4c38" },
    Reaction3    = { r = 0.80, g = 0.30, b = 0.22, hex = "ffcc4c38" },
    Reaction4    = { r = 0.85, g = 0.77, b = 0.36, hex = "ffd9c45c" },
    Reaction5    = { r = 0.10, g = 0.60, b = 0.10, hex = "ff1a991a" },
    Reaction6    = { r = 0.10, g = 0.60, b = 0.10, hex = "ff1a991a" },
    Reaction7    = { r = 0.10, g = 0.60, b = 0.10, hex = "ff1a991a" },
    Reaction8    = { r = 0.10, g = 0.60, b = 0.10, hex = "ff1a991a" },
    },

    Debuff = {
        [0]  = { r = 0.80, g = 0.80, b = 0.80, hex = "ffcccccc" }, -- 일반 디버프
        [1]  = { r = 0.32, g = 0.66, b = 1.00, hex = "FF52A8FF" }, -- Magic
        [2]  = { r = 0.67, g = 0.16, b = 1.00, hex = "FFAA29FF" }, -- Curse
        [3]  = { r = 0.70, g = 0.47, b = 0.00, hex = "FFB37700" }, -- Disease
        [4]  = { r = 0.00, g = 1.00, b = 0.00, hex = "FF00FF00" }, -- Poison
        [9]  = { r = 1.00, g = 0.29, b = 0.17, hex = "FFFF4B2C" }, -- Bleed / Enrage
        [11] = { r = 1.00, g = 0.16, b = 0.16, hex = "FFFF2828" }, -- Bleed
    },

    ETC = {
    SoftRed      = { r = 1.00, g = 0.70, b = 0.70, hex = "ffffb2b2" },
    SoftGreen    = { r = 0.70, g = 1.00, b = 0.70, hex = "ffb2ffb2" },
    LemonYellow  = { r = 1.00, g = 1.00, b = 0.70, hex = "ffffffb2" },
    ChiJade      = { r = 0.71, g = 1.00, b = 0.92, hex = "ffb5ffeb" },
    ShardPurple  = { r = 0.50, g = 0.32, b = 0.55, hex = "ff80518c" },
    HealthColorActive   = { r = 0.20, g = 0.80, b = 0.20, hex = "ff33cc33" },
    HealthColorExpiring = { r = 0.80, g = 0.20, b = 0.20, hex = "ffcc3333" },
    },

    EncounterRole = { -- 보스 인카운터 타임라인 색상 (EXBoss 기본 색상)
    Tank     = { r = 0xC6/255, g = 0x9B/255, b = 0x6C/255, hex = "ffc69b6c" },
    Heal     = { r = 0x5F/255, g = 0xFF/255, b = 0x9D/255, hex = "ff5fff9d" },
    Other    = { r = 0xA5/255, g = 0xAF/255, b = 0xA2/255, hex = "ffa5afa2" },
    Mechanic = { r = 0xDA/255, g = 0x5B/255, b = 0xFF/255, hex = "ffda5bff" },
    }
}

-- 하위 호환성 유지: Primary 및 ETC 색상들을 상위 dodo.Colors에 매핑
if dodo.Colors.Primary then
    for k, v in pairs(dodo.Colors.Primary) do
        dodo.Colors[k] = v
    end
end
if dodo.Colors.ETC then
    for k, v in pairs(dodo.Colors.ETC) do
        dodo.Colors[k] = v
    end
end

local mt = {
    __index = function(t, key)
        if oUF and oUF.colors then
            -- 1) oUF 직업 색상 테이블 참조 직접 등록
            if oUF.colors.class then
                for class, color in pairs(oUF.colors.class) do
                    dodo.Colors[class] = color
                end
                -- 죽음의 기사(DEATHKNIGHT) 'DK' 단축 에일리어스 매핑
                if oUF.colors.class.DEATHKNIGHT then
                    dodo.Colors.DK = oUF.colors.class.DEATHKNIGHT
                end
            end
            -- 2) oUF 우호도 색상 테이블 참조 직접 등록 (Reaction1 ~ Reaction8 형태로 평평화)
            if oUF.colors.reaction then
                for reaction, color in pairs(oUF.colors.reaction) do
                    dodo.Colors["Reaction" .. reaction] = color
                end
            end
        else
            -- 폴백: 블리자드 순정 색상 테이블 참조 직접 등록
            for class, color in pairs(RAID_CLASS_COLORS) do
                dodo.Colors[class] = color
            end
            if RAID_CLASS_COLORS.DEATHKNIGHT then
                dodo.Colors.DK = RAID_CLASS_COLORS.DEATHKNIGHT
            end
            for reaction, color in pairs(FACTION_BAR_COLORS) do
                dodo.Colors["Reaction" .. reaction] = color
            end
        end
        return nil
    end
}
setmetatable(dodo.Colors, mt)
