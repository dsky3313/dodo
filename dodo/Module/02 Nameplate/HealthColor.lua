-- ==============================
-- Inspired
-- ==============================
-- EnemyNameplateColors v1.2.0 (Zerkggz)

---@diagnostic disable: lowercase-global, param-type-mismatch, redundant-parameter, undefined-field, undefined-global
local addonName, dodo = ...
local NP = dodo.NamePlate

-- ==============================
-- 캐싱
-- ==============================
local C_NamePlate         = C_NamePlate
local CreateFrame         = CreateFrame
local hooksecurefunc      = hooksecurefunc
local ipairs              = ipairs
local pairs               = pairs
local strmatch            = strmatch
local UnitAffectingCombat = UnitAffectingCombat
local UnitExists          = UnitExists
local UnitIsFriend        = UnitIsFriend
local UnitIsPlayer        = UnitIsPlayer
local UnitIsTapDenied     = UnitIsTapDenied
local UnitIsUnit          = UnitIsUnit

-- ==============================
-- 색상 헬퍼
-- ==============================
local function db_color(key)
    local v = dodoDB and dodoDB[key]
    if type(v) == "string" then return CreateColorFromHexString(v) end
    return v
end

local unit_type_key = {
    boss     = "nameplateColorBoss",
    miniBoss = "nameplateColorMiniBoss",
    caster   = "nameplateColorCaster",
    standard = "nameplateColorStandard",
}

local function unit_type_color(unit_type)
    return db_color(unit_type_key[unit_type] or "nameplateColorStandard")
end

-- ==============================
-- 색상 결정 로직
-- ==============================
local function get_nameplate_color(unit)
    if not NP.in_instance           then return nil end
    if UnitIsFriend("player", unit) then return nil end
    if UnitIsPlayer(unit)           then return nil end
    if NP.neutral_cache[unit]       then return nil end
    if UnitIsTapDenied(unit)        then return nil end
    if not dodoDB                   then return nil end

    local db = dodoDB

    -- 포커스 색상 (최우선)
    if db.nameplateFocusColor and UnitExists("focus") and UnitIsUnit(unit, "focus") then
        return db_color("nameplateColorFocus")
    end

    local utype     = NP.get_unit_type(unit)
    local in_combat = UnitAffectingCombat("player")

    -- 비전투: 유닛 색상만
    if not in_combat then
        if db.nameplateHealthColor == false then return nil end
        if utype == "standard" then return nil end
        return unit_type_color(utype)
    end

    -- 전투 중
    local status = NP.get_threat_status(unit)

    if NP.is_player_tank() then
        if db.nameplateTankThreatEnabled ~= false then
            if NP.is_being_tanked_by_other(unit) then
                return db_color("nameplateColorTankOnOtherTank")
            elseif status and status >= 3 then
                return db_color("nameplateColorTankHasThreat")
            elseif status and status == 2 then
                return db_color("nameplateColorTankLosingThreat")
            elseif status ~= nil then
                return db_color("nameplateColorTankNoThreat")
            end
        end
    else
        if db.nameplateDpsThreatEnabled ~= false then
            if status and status >= 3 then
                return db_color("nameplateColorDpsHasThreat")
            elseif status and status >= 1 then
                return db_color("nameplateColorDpsGainingThreat")
            elseif status ~= nil and UnitAffectingCombat(unit) then
                return db_color("nameplateColorDpsNoThreat")
            end
        end
    end

    -- 위협 색상 미적용 시 유닛 색상 폴백
    if db.nameplateHealthColor ~= false then
        if UnitAffectingCombat(unit) or utype ~= "standard" then
            return unit_type_color(utype)
        end
    end
    return nil
end

-- ==============================
-- 네임플레이트 갱신
-- ==============================
local function update_nameplate(nameplate)
    if not nameplate or not nameplate.UnitFrame then return end
    local unit = nameplate.UnitFrame.unit
    if not unit then return end

    local color = get_nameplate_color(unit)
    if color and nameplate.UnitFrame.healthBar then
        nameplate.UnitFrame.healthBar:SetStatusBarColor(color.r, color.g, color.b)
    end
end

local function update_all_nameplates()
    for _, np in pairs(C_NamePlate.GetNamePlates()) do
        update_nameplate(np)
    end
end

NP.update_all_nameplates = update_all_nameplates

-- ==============================
-- CompactUnitFrame 후킹
-- ==============================
local function hook_health_color(frame)
    if not frame.unit or frame:IsForbidden() then return end
    if not strmatch(frame.unit, "^nameplate") then return end

    -- 중립(노란) 감지: Blizzard가 방금 세팅한 색으로 판별
    if frame.healthBar then
        local r, g, b = frame.healthBar:GetStatusBarColor()
        NP.neutral_cache[frame.unit] = (r > 0.9 and g > 0.7 and b < 0.2)
    end

    local color = get_nameplate_color(frame.unit)
    if color and frame.healthBar then
        frame.healthBar:SetStatusBarColor(color.r, color.g, color.b)
    end
end

hooksecurefunc("CompactUnitFrame_UpdateHealthColor", hook_health_color)

-- ==============================
-- 이벤트
-- ==============================
local event_frame = CreateFrame("Frame")

local function on_event(self, event, arg1)
    if event == "NAME_PLATE_UNIT_ADDED" then
        local np = C_NamePlate.GetNamePlateForUnit(arg1)
        if np then update_nameplate(np) end
    elseif event == "UNIT_THREAT_LIST_UPDATE" then
        -- 고빈도: 해당 플레이트만 갱신
        if arg1 and strmatch(arg1, "^nameplate") then
            local np = C_NamePlate.GetNamePlateForUnit(arg1)
            if np then update_nameplate(np) end
        else
            update_all_nameplates()
        end
    elseif event == "UNIT_THREAT_SITUATION_UPDATE"
        or event == "PLAYER_FOCUS_CHANGED"
        or event == "PLAYER_REGEN_ENABLED"
        or event == "PLAYER_REGEN_DISABLED" then
        update_all_nameplates()
    end
end

event_frame:SetScript("OnEvent", on_event)

local function register_events()
    event_frame:RegisterEvent("NAME_PLATE_UNIT_ADDED")
    event_frame:RegisterEvent("UNIT_THREAT_LIST_UPDATE")
    event_frame:RegisterEvent("UNIT_THREAT_SITUATION_UPDATE")
    event_frame:RegisterEvent("PLAYER_FOCUS_CHANGED")
    event_frame:RegisterEvent("PLAYER_REGEN_ENABLED")
    event_frame:RegisterEvent("PLAYER_REGEN_DISABLED")
end

local function unregister_events()
    event_frame:UnregisterAllEvents()
end

-- 마스터 토글 콜백 등록 (Core.lua가 호출)
NP.sub_enable[#NP.sub_enable   + 1] = register_events
NP.sub_disable[#NP.sub_disable + 1] = unregister_events
