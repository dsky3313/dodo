-- ==============================
-- Inspired
-- ==============================
-- dodo ResourceBar - Power Bar Mode (Bar2)

-- ==============================
-- 설정 및 테이블
-- ==============================
local addonName, dodo = ...
local RB = dodo.ResourceBar

-- ==============================
-- 캐싱
-- ==============================
local CreateFrame = CreateFrame
local Enum = Enum
local ipairs = ipairs
local PowerBarColor = PowerBarColor
local UnitPower = UnitPower
local UnitPowerMax = UnitPowerMax

-- ==============================
-- 기능 1: 로컬 상태 및 설정
-- ==============================
-- (상태 변수 없음)

-- ==============================
-- 기능 2: 상태 업데이트
-- ==============================
local function update_stack_ticks(bar2Frame, maxStack)
    if not bar2Frame.ticks then bar2Frame.ticks = {} end

    for _, tick in ipairs(bar2Frame.ticks) do tick:Hide() end

    if not maxStack or maxStack <= 1 or maxStack > 10 then
        bar2Frame._lastMaxStack = nil
        return
    end

    if bar2Frame._lastMaxStack == maxStack then
        for i = 1, maxStack - 1 do
            if bar2Frame.ticks[i] then bar2Frame.ticks[i]:Show() end
        end
        return
    end
    bar2Frame._lastMaxStack = maxStack

    local barWidth = bar2Frame:GetWidth()
    local barHeight = bar2Frame:GetHeight()

    for i = 1, maxStack - 1 do
        if not bar2Frame.ticks[i] then
            local tick = bar2Frame:CreateTexture(nil, "OVERLAY")
            tick:SetColorTexture(0, 0, 0, 0.8)
            bar2Frame.ticks[i] = tick
        end

        local tick = bar2Frame.ticks[i]
        tick:ClearAllPoints()
        PixelUtil.SetSize(tick, 1, barHeight)
        local xOffset = (barWidth / maxStack) * i
        PixelUtil.SetPoint(tick, "LEFT", bar2Frame, "LEFT", xOffset, 0)
        tick:Show()
    end
end

-- ==============================
-- 기능 3: UI 및 이벤트 핸들러 등록
-- ==============================
local Mode = {}

function Mode:OnEnable(bar2Frame)
    bar2Frame:UnregisterEvent("RUNE_POWER_UPDATE")
    bar2Frame:UnregisterEvent("UNIT_AURA")
    bar2Frame:RegisterUnitEvent("UNIT_POWER_UPDATE", "player")
    self:Update(bar2Frame)
end

function Mode:OnDisable(bar2Frame)
    bar2Frame:UnregisterEvent("UNIT_POWER_UPDATE")
    if bar2Frame.ticks then
        for _, tick in ipairs(bar2Frame.ticks) do tick:Hide() end
    end
end

function Mode:Update(bar2Frame)
    if not bar2Frame:IsShown() then return end
    if bar2Frame.runebars then
        for _, rb in ipairs(bar2Frame.runebars) do rb:Hide() end
    end
    
    local pType  = bar2Frame.buffConfig and bar2Frame.buffConfig.powerType
    local pToken = bar2Frame.buffConfig and bar2Frame.buffConfig.powerToken
    if not pType or not pToken then return end

    local maxVal = bar2Frame.buffConfig.ticks or UnitPowerMax("player", pType) or 1
    local current = UnitPower("player", pType)
    local c = (bar2Frame.buffConfig and bar2Frame.buffConfig.color) or PowerBarColor[pToken] or PowerBarColor[pType] or { r = 1, g = 1, b = 1 }
    
    bar2Frame:SetMinMaxValues(0, maxVal)
    bar2Frame:SetStatusBarColor(c.r, c.g, c.b)
    
    if bar2Frame.countStack then bar2Frame.countStack:SetText(current) end
    if bar2Frame.countDuration then bar2Frame.countDuration:SetText("") end
    bar2Frame:SetValue(current, Enum.StatusBarInterpolation.ExponentialEaseOut)
    
    if bar2Frame.buffConfig.isTickPower then
        update_stack_ticks(bar2Frame, maxVal)
    else
        if bar2Frame.ticks then
            for _, t in ipairs(bar2Frame.ticks) do t:Hide() end
        end
    end
    bar2Frame:Show()
end

function Mode:OnEvent(bar2Frame, event, ...)
    if event == "UNIT_POWER_UPDATE" then
        self:Update(bar2Frame)
    end
end

RB:RegisterMode("power", Mode)
