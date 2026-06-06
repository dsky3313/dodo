-- ==============================
-- Inspired
-- ==============================
-- dodo

-- ==============================
-- 설정 및 테이블
-- ==============================
---@diagnostic disable: lowercase-global, param-type-mismatch, redundant-parameter, undefined-field, undefined-global
local addonName, dodo = ...
dodoDB = dodoDB or {}

local RB = dodo.ResourceBar
local Colors = dodo.Colors

---@class PowerConfig
---@field powerType number 파워 타입 ID
---@field powerToken string 파워 토큰 문자열
---@field isTickPower boolean 틱 단위 표시 여부
---@field ticks number 최대 틱 개수

---@type table<string, any>
local bar1ClassConfig = {
    ["DEMONHUNTER"] = { powerType = 17, powerToken = "FURY" }, -- 악사 분노 (전 스펙)
    ["DRUID"] = {
        [1] = { powerType = 8,  powerToken = "LUNAR_POWER" }, -- 조화 달의 힘
        [2] = { powerType = 4,  powerToken = "COMBO_POINTS", isTickPower = true }, -- 야드 연계 점수
    },
    ["EVOKER"]  = { powerType = 19, powerToken = "ESSENCE", isTickPower = true }, -- 정수
    ["HUNTER"]  = { powerType = 2,  powerToken = "FOCUS" }, -- 사냥꾼 집중력 (전 스펙)
    ["MAGE"] = {
        [1] = { powerType = 0, powerToken = "MANA" }, -- 비법 마나
    },
    ["MONK"] = { [3] = { powerType = 12, powerToken = "CHI", isTickPower = true, ticks = 5 }}, -- 풍운 기
    ["PALADIN"] = { powerType = 9, powerToken = "HOLY_POWER", isTickPower = true, ticks = 5 }, -- 성기사 신성한 힘 (전 스펙)
    ["PRIEST"] = {
        [3] = { powerType = 13, powerToken = "INSANITY" }, -- 암흑 광기
    },
    ["ROGUE"]   = { powerType = 3, powerToken = "ENERGY" }, -- 도적 에너지
    ["WARLOCK"] = { powerType = 7, powerToken = "SOUL_SHARDS", isTickPower = true, ticks = 5 }, -- 흑마 영혼 조각
}

-- ==============================
-- 캐싱
-- ==============================
local C_Timer = C_Timer
local CreateFrame = CreateFrame
local Enum = Enum
local InCombatLockdown = InCombatLockdown
local ipairs = ipairs
local PowerBarColor = PowerBarColor
local RAID_CLASS_COLORS = RAID_CLASS_COLORS
local UnitAffectingCombat = UnitAffectingCombat
local UnitClass = UnitClass
local UnitPartialPower = UnitPartialPower
local UnitPower = UnitPower
local UnitPowerMax = UnitPowerMax
local UnitPowerPercent = UnitPowerPercent
local UnitPowerType = UnitPowerType

-- ==============================
-- 상태 변수
-- ==============================
local cachedPowerType = nil
local overridePowerConfig = nil
local updateTicker = nil
local combat_frame = CreateFrame("Frame")

-- ==============================
-- 기능 1: 틱 구분 눈금 그리기 (바 내부 격자)
-- ==============================
local function update_bar1_ticks(maxStack)
    local bar1Frame = RB.bar1Frame
    if not bar1Frame then return end
    if not bar1Frame.ticks then bar1Frame.ticks = {} end

    for _, tick in ipairs(bar1Frame.ticks) do tick:Hide() end

    if not maxStack or maxStack <= 1 or maxStack > 10 then
        bar1Frame._lastMaxStack = nil
        return
    end

    if bar1Frame._lastMaxStack == maxStack then
        for i = 1, maxStack - 1 do
            if bar1Frame.ticks[i] then bar1Frame.ticks[i]:Show() end
        end
        return
    end
    bar1Frame._lastMaxStack = maxStack

    local barWidth = bar1Frame:GetWidth()
    local barHeight = bar1Frame:GetHeight()

    for i = 1, maxStack - 1 do
        if not bar1Frame.ticks[i] then
            local tick = bar1Frame:CreateTexture(nil, "OVERLAY")
            tick:SetColorTexture(0, 0, 0, 0.8)
            bar1Frame.ticks[i] = tick
        end

        local tick = bar1Frame.ticks[i]
        tick:ClearAllPoints()
        PixelUtil.SetSize(tick, 1, barHeight)
        local xOffset = (barWidth / maxStack) * i
        PixelUtil.SetPoint(tick, "LEFT", bar1Frame, "LEFT", xOffset, 0)
        tick:Show()
    end
end

-- ==============================
-- 기능 2: 자원 업데이트 로직
-- ==============================
local function update_bar1()
    local bar1Frame = RB.bar1Frame
    if not bar1Frame or not bar1Frame:IsShown() then return end

    local pType, pToken = UnitPowerType("player")

    if overridePowerConfig then
        pType = overridePowerConfig.powerType
        pToken = overridePowerConfig.powerToken
    end

    -- 비법/힐러가 아닌데 마나(0)인 경우 숨김 처리
    if pType == 0 and not RB.isArcaneOrHealer then
        bar1Frame:SetValue(0)
        if bar1Frame.countPower then bar1Frame.countPower:SetText("") end
        return
    end

    -- 색상 갱신
    if pType ~= cachedPowerType then
        cachedPowerType = pType
        local c
        
        -- dodo.Colors.Power의 타이틀케이스 키 매핑
        local token = pToken
        if token == "RUNIC_POWER" then token = "RunicPower"
        elseif token == "HOLY_POWER" then token = "HolyPower"
        elseif token == "SOUL_SHARDS" then token = "SoulShards"
        elseif token then
            token = token:sub(1, 1):upper() .. token:sub(2):lower()
        end
        
        local dodoRes = Colors and Colors.Power and token and Colors.Power[token]
        
        c = dodoRes or PowerBarColor[pToken] or PowerBarColor[pType] or { r = 1, g = 1, b = 1 }
        
        local r = c.r or c[1] or 1
        local g = c.g or c[2] or 1
        local b = c.b or c[3] or 1
        
        bar1Frame:SetStatusBarColor(r, g, b)
    end

    local current = UnitPower("player", pType)
    local max = UnitPowerMax("player", pType)
    if max and max > 0 then
        bar1Frame:SetMinMaxValues(0, max)
        
        local isTickPower = overridePowerConfig and overridePowerConfig.isTickPower
        if isTickPower then
            if pType == 19 then -- 기원사 정수 소수점 연산
                local partial = UnitPartialPower("player", 19) or 0
                bar1Frame:SetValue(current + (partial / 1000), Enum.StatusBarInterpolation.ExponentialEaseOut)
            else
                bar1Frame:SetValue(current, Enum.StatusBarInterpolation.ExponentialEaseOut)
            end
            if bar1Frame.countPower then
                bar1Frame.countPower:SetText(current)
            end
            update_bar1_ticks(overridePowerConfig.ticks or max)
        else
            bar1Frame:SetValue(current, Enum.StatusBarInterpolation.ExponentialEaseOut)
            if bar1Frame.countPower then
                if pType == 0 then
                    local pct = UnitPowerPercent("player", 0, false, CurveConstants and CurveConstants.ScaleTo100)
                    if pct then
                        bar1Frame.countPower:SetFormattedText("%d", pct)
                    else
                        bar1Frame.countPower:SetText("0")
                    end
                else
                    bar1Frame.countPower:SetText(current)
                end
            end
            update_bar1_ticks(nil)
        end
    end
end

RB.UpdateBar1 = update_bar1

-- ==============================
-- 기능 3: 전투 상태에 따른 틱 인터벌 조정 (가비지 프리 보장)
-- ==============================
local function on_combat_change(inCombat)
    if updateTicker then updateTicker:Cancel(); updateTicker = nil end
    
    local db = dodo.DB or dodoDB
    local isEnabled = (db and db.enableResourceBarModule ~= false)
    local useBar1 = (db and db.useResourceBar1 ~= false)
    
    if isEnabled and useBar1 then
        updateTicker = C_Timer.NewTicker(inCombat and 0.1 or 0.5, update_bar1)
    end
end

local function toggle_bar1_combat_events(enable)
    if enable then
        combat_frame:RegisterEvent("PLAYER_REGEN_DISABLED")
        combat_frame:RegisterEvent("PLAYER_REGEN_ENABLED")
        on_combat_change(UnitAffectingCombat("player"))
    else
        combat_frame:UnregisterAllEvents()
        if updateTicker then updateTicker:Cancel(); updateTicker = nil end
    end
end

RB.TogglePowerEvents = toggle_bar1_combat_events

combat_frame:SetScript("OnEvent", function(_, event)
    on_combat_change(event == "PLAYER_REGEN_DISABLED")
end)

-- ==============================
-- 스펙 변경 대응 설정 갱신
-- ==============================
local function update_power_spec(englishClass, spec)
    overridePowerConfig = nil
    local classConf = bar1ClassConfig[englishClass]
    if classConf then
        if classConf.powerType then
            overridePowerConfig = classConf
        elseif spec and classConf[spec] then
            overridePowerConfig = classConf[spec]
        end
    end
    cachedPowerType = nil -- 다음 업데이트 때 색상 강제 갱신 유도
end

RB.UpdatePowerSpec = update_power_spec

-- ==============================
-- OnLoad 이벤트
-- ==============================
local function on_load_power()
    local _, englishClass = UnitClass("player")
    update_power_spec(englishClass, C_SpecializationInfo.GetSpecialization())
end

RB.OnLoadPower = on_load_power
