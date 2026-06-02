-- ==============================
-- Inspired
-- ==============================
-- dodo ResourceBar - Stack Buff Tracker Mode
-- ==============================

local addonName, dodo = ...
local RB = dodo.ResourceBar
local Colors = dodo.Colors

local C_UnitAuras = C_UnitAuras
local CreateFrame = CreateFrame
local Enum = Enum
local ipairs = ipairs
local issecretvalue = issecretvalue

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
-- Stack Mode 인터페이스 정의
-- ==============================
local Mode = {}

function Mode:OnEnable(bar2Frame)
    bar2Frame:UnregisterEvent("RUNE_POWER_UPDATE")
    bar2Frame:UnregisterEvent("UNIT_POWER_UPDATE")
    bar2Frame:UnregisterEvent("UNIT_AURA")
    self:Update(bar2Frame)
end

function Mode:OnDisable(bar2Frame)
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

    local maxValue = bar2Frame.buffConfig and bar2Frame.buffConfig.maxStack or 100
    bar2Frame:SetMinMaxValues(0, maxValue)
    update_stack_ticks(bar2Frame, maxValue)

    local c = (bar2Frame.buffConfig and bar2Frame.buffConfig.color) or RB.cachedSpecColor
    bar2Frame:SetStatusBarColor(c.r, c.g, c.b, 1)

    if not bar2Frame.viewerItem or not bar2Frame.viewerItem.auraInstanceID or not bar2Frame.viewerItem.auraDataUnit then
        if bar2Frame.countStack then bar2Frame.countStack:SetText("") end
        if bar2Frame.countDuration then bar2Frame.countDuration:SetText("") end
        bar2Frame:SetValue(0, Enum.StatusBarInterpolation.ExponentialEaseOut)
        local tex = bar2Frame:GetStatusBarTexture()
        if tex then tex:SetAlpha(0) end
        return
    end

    local tex = bar2Frame:GetStatusBarTexture()
    if tex then tex:SetAlpha(1) end

    local unit, auraID = bar2Frame.viewerItem.auraDataUnit, bar2Frame.viewerItem.auraInstanceID
    local auraData = C_UnitAuras.GetAuraDataByAuraInstanceID(unit, auraID)
    if auraData then
        local countBar = auraData.applications or 0
        if bar2Frame.countStack then 
            if issecretvalue(countBar) then
                bar2Frame.countStack:SetText(countBar)
            else
                bar2Frame.countStack:SetText(countBar > 0 and countBar or "") 
            end
        end
        if bar2Frame.countDuration then bar2Frame.countDuration:SetText("") end
        bar2Frame:SetValue(countBar, Enum.StatusBarInterpolation.ExponentialEaseOut)
        bar2Frame:Show()
    end
end

function Mode:OnEvent(bar2Frame, event, ...)
    -- CooldownViewer 훅에 의해 직접 Update가 시전되므로 여기선 특수 이벤트 처리 없음
end

RB:RegisterMode("stack", Mode)
