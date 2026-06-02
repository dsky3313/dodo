-- ==============================
-- Inspired
-- ==============================
-- dodo ResourceBar - Duration Buff Tracker Mode
-- ==============================

local addonName, dodo = ...
local RB = dodo.ResourceBar
local Colors = dodo.Colors

local C_Timer = C_Timer
local C_UnitAuras = C_UnitAuras
local issecretvalue = issecretvalue
local math = math
local ipairs = ipairs
local UnitAffectingCombat = UnitAffectingCombat

local durationTicker = nil

local function get_update_interval()
    return UnitAffectingCombat("player") and 0.1 or 0.5
end

local function duration_tick()
    local bar2Frame = RB.bar2Frame
    if bar2Frame and bar2Frame.buffConfig and bar2Frame.buffConfig.barMode == "duration" then
        local mode = RB.Modes["duration"]
        if mode then mode:Update(bar2Frame) end
    end
end

-- ==============================
-- Duration Mode 인터페이스 정의
-- ==============================
local Mode = {}

function Mode:OnEnable(bar2Frame)
    bar2Frame:UnregisterEvent("RUNE_POWER_UPDATE")
    bar2Frame:UnregisterEvent("UNIT_POWER_UPDATE")
    bar2Frame:UnregisterEvent("UNIT_AURA")
    self:Update(bar2Frame)
end

function Mode:OnDisable(bar2Frame)
    if durationTicker then
        durationTicker:Cancel()
        durationTicker = nil
    end
    if bar2Frame.ticks then
        for _, tick in ipairs(bar2Frame.ticks) do tick:Hide() end
    end
end

function Mode:Update(bar2Frame)
    if bar2Frame.runebars then
        for _, rb in ipairs(bar2Frame.runebars) do rb:Hide() end
    end
    if bar2Frame.countStack then bar2Frame.countStack:Show() end
    if bar2Frame.countDuration then bar2Frame.countDuration:Show() end

    local maxValue = bar2Frame.buffConfig and bar2Frame.buffConfig.duration or 20
    bar2Frame:SetMinMaxValues(0, maxValue)
    
    if bar2Frame.ticks then
        for _, tick in ipairs(bar2Frame.ticks) do tick:Hide() end
    end

    local c = (bar2Frame.buffConfig and bar2Frame.buffConfig.color) or RB.cachedSpecColor
    bar2Frame:SetStatusBarColor(c.r, c.g, c.b, 1)

    if not bar2Frame.viewerItem or not bar2Frame.viewerItem.auraInstanceID or not bar2Frame.viewerItem.auraDataUnit then
        if bar2Frame.countStack then bar2Frame.countStack:SetText("") end
        if bar2Frame.countDuration then bar2Frame.countDuration:SetText("0") end
        bar2Frame:SetValue(0, Enum.StatusBarInterpolation.ExponentialEaseOut)
        local tex = bar2Frame:GetStatusBarTexture()
        if tex then tex:SetAlpha(0) end
        if durationTicker then 
            durationTicker:Cancel()
            durationTicker = nil 
            bar2Frame._lastDurationIntVal = nil
        end
        return
    end

    local tex = bar2Frame:GetStatusBarTexture()
    if tex then tex:SetAlpha(1) end

    local unit, auraID = bar2Frame.viewerItem.auraDataUnit, bar2Frame.viewerItem.auraInstanceID
    local auraData = C_UnitAuras.GetAuraDataByAuraInstanceID(unit, auraID)
    if auraData then
        local durObj = C_UnitAuras.GetAuraDuration(unit, auraID)
        if durObj then
            bar2Frame:SetTimerDuration(durObj, Enum.StatusBarInterpolation.ExponentialEaseOut, Enum.StatusBarTimerDirection.RemainingTime)
            local rem = durObj:GetRemainingDuration()
            if issecretvalue(rem) then
                bar2Frame.countDuration:SetFormattedText("%.0f", rem)
                bar2Frame._lastDurationIntVal = nil
            else
                local intVal = math.floor(rem)
                if intVal ~= bar2Frame._lastDurationIntVal then
                    bar2Frame.countDuration:SetFormattedText("%.0f", intVal)
                    bar2Frame._lastDurationIntVal = intVal
                end
            end
        end
        if bar2Frame.countStack then bar2Frame.countStack:SetText("") end
        if not durationTicker then
            durationTicker = C_Timer.NewTicker(get_update_interval(), duration_tick)
        end
        bar2Frame:Show()
    end
end

function Mode:OnEvent(bar2Frame, event, ...)
    -- CooldownViewer 훅에 의해 직접 Update가 시전되므로 여기선 특수 이벤트 처리 없음
end

RB:RegisterMode("duration", Mode)
