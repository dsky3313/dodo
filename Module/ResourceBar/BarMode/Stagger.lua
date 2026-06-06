-- ==============================
-- Inspired
-- ==============================
-- dodo ResourceBar - Monk Stagger Mode

-- ==============================
-- 설정 및 테이블
-- ==============================
local addonName, dodo = ...
local RB = dodo.ResourceBar
local Colors = dodo.Colors

-- ==============================
-- 캐싱
-- ==============================
local C_PaperDollInfo = C_PaperDollInfo
local C_Timer = C_Timer
local C_UnitAuras = C_UnitAuras
local Enum = Enum
local issecretvalue = issecretvalue
local math = math
local UnitAffectingCombat = UnitAffectingCombat
local UnitHealthMax = UnitHealthMax
local UnitStagger = UnitStagger

-- ==============================
-- 기능 1: 로컬 상태 및 설정
-- ==============================
local staggerTicker = nil

-- ==============================
-- 기능 2: 상태 업데이트
-- ==============================
local function get_update_interval()
    return UnitAffectingCombat("player") and 0.1 or 0.5
end

local function stagger_tick()
    local bar2Frame = RB.bar2Frame
    if bar2Frame and bar2Frame.buffConfig and bar2Frame.buffConfig.barMode == "stagger" then
        local mode = RB.Modes["stagger"]
        if mode then mode:Update(bar2Frame) end
    end
end

-- ==============================
-- 기능 3: UI 및 이벤트 핸들러 등록
-- ==============================
local Mode = {}

function Mode:OnEnable(bar2Frame)
    bar2Frame:UnregisterEvent("RUNE_POWER_UPDATE")
    bar2Frame:UnregisterEvent("UNIT_POWER_UPDATE")
    bar2Frame:UnregisterEvent("UNIT_AURA")
    bar2Frame:RegisterEvent("PLAYER_REGEN_DISABLED")
    bar2Frame:RegisterEvent("PLAYER_REGEN_ENABLED")
    self:Update(bar2Frame)
end

function Mode:OnDisable(bar2Frame)
    if staggerTicker then
        staggerTicker:Cancel()
        staggerTicker = nil
    end
    bar2Frame:UnregisterEvent("PLAYER_REGEN_DISABLED")
    bar2Frame:UnregisterEvent("PLAYER_REGEN_ENABLED")
end

function Mode:Update(bar2Frame)
    if not bar2Frame:IsShown() then return end
    if bar2Frame.runebars then
        for _, rb in ipairs(bar2Frame.runebars) do rb:Hide() end
    end
    if bar2Frame.countStack then bar2Frame.countStack:Show() end
    if bar2Frame.countDuration then bar2Frame.countDuration:Hide() end
    if bar2Frame.Cooldown then
        bar2Frame.Cooldown:Clear()
        bar2Frame.Cooldown:Hide()
    end

    local stagger = UnitStagger("player") or 0
    local maxHealth = UnitHealthMax("player") or 1
    bar2Frame:SetMinMaxValues(0, maxHealth)
    bar2Frame:SetValue(stagger, Enum.StatusBarInterpolation.ExponentialEaseOut)

    local pct = 0
    local isSecret = issecretvalue(stagger) or issecretvalue(maxHealth)
    
    if not isSecret then
        pct = (stagger / maxHealth) * 100
        if pct >= 60 then
            local c = Colors and Colors.Spec and Colors.Spec.MONK and Colors.Spec.MONK[1] and Colors.Spec.MONK[1].Stagger and Colors.Spec.MONK[1].Stagger[3] or { r = 1, g = 0, b = 0 }
            bar2Frame:SetStatusBarColor(c.r, c.g, c.b)
        elseif pct >= 30 then
            local c = Colors and Colors.Spec and Colors.Spec.MONK and Colors.Spec.MONK[1] and Colors.Spec.MONK[1].Stagger and Colors.Spec.MONK[1].Stagger[2] or { r = 1, g = 0.8, b = 0 }
            bar2Frame:SetStatusBarColor(c.r, c.g, c.b)
        else
            local specColor = Colors and Colors.Spec and Colors.Spec.MONK and Colors.Spec.MONK[1]
            local c = specColor and specColor.Stagger and specColor.Stagger[1] or specColor or (bar2Frame.buffConfig and bar2Frame.buffConfig.color) or RB.cachedSpecColor
            bar2Frame:SetStatusBarColor(c.r, c.g, c.b)
        end
        if bar2Frame.countStack then
            if stagger == 0 then
                bar2Frame.countStack:SetText("0")
            else
                bar2Frame.countStack:SetFormattedText("%.0f", pct)
            end
        end
    else
        -- 12.0.0 인스턴스 비밀값 검출 우회
        local sPct = C_PaperDollInfo.GetStaggerPercentage("player")
        
        -- 오라 디버프에 따른 색상 분기
        if C_UnitAuras.GetPlayerAuraBySpellID(124273) then
            local c = Colors and Colors.Spec and Colors.Spec.MONK and Colors.Spec.MONK[1] and Colors.Spec.MONK[1].Stagger and Colors.Spec.MONK[1].Stagger[3] or { r = 1, g = 0, b = 0 }
            bar2Frame:SetStatusBarColor(c.r, c.g, c.b)
        elseif C_UnitAuras.GetPlayerAuraBySpellID(124274) then
            local c = Colors and Colors.Spec and Colors.Spec.MONK and Colors.Spec.MONK[1] and Colors.Spec.MONK[1].Stagger and Colors.Spec.MONK[1].Stagger[2] or { r = 1, g = 0.8, b = 0 }
            bar2Frame:SetStatusBarColor(c.r, c.g, c.b)
        else
            local specColor = Colors and Colors.Spec and Colors.Spec.MONK and Colors.Spec.MONK[1]
            local c = specColor and specColor.Stagger and specColor.Stagger[1] or specColor or (bar2Frame.buffConfig and bar2Frame.buffConfig.color) or RB.cachedSpecColor
            bar2Frame:SetStatusBarColor(c.r, c.g, c.b)
        end
        
        if bar2Frame.countStack then
            if sPct == 0 then
                bar2Frame.countStack:SetText("0")
            else
                bar2Frame.countStack:SetText(sPct)
            end
        end
    end

    local inCombat = UnitAffectingCombat("player")
    local hasStagger = stagger > 0
    
    if (inCombat or hasStagger) then
        if not staggerTicker then
            staggerTicker = C_Timer.NewTicker(get_update_interval(), stagger_tick)
        end
    else
        if staggerTicker then
            staggerTicker:Cancel()
            staggerTicker = nil
        end
    end
end

function Mode:OnEvent(bar2Frame, event, ...)
    if event == "PLAYER_REGEN_DISABLED" or event == "PLAYER_REGEN_ENABLED" then
        self:Update(bar2Frame)
    end
end

RB:RegisterMode("stagger", Mode)
