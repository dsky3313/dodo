-- ==============================
-- Inspired
-- ==============================
-- dodo ResourceBar - Demon Hunter Soul Fragments Mode
-- ==============================

local addonName, dodo = ...
local RB = dodo.ResourceBar
local Colors = dodo.Colors

local C_Spell = C_Spell
local CreateFrame = CreateFrame
local Enum = Enum
local ipairs = ipairs
local math = math

local function get_bar2_size()
    local db = dodo.DB or dodoDB
    local width = (db and db.resourceBarWidth) or RB.barConfigs[1].width or 272
    local height = (db and db.resourceBarHeight) or RB.barConfigs[1].height or 10
    local height2 = math.max(height - 3, 5)
    return width, height2
end

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
-- Soul Fragments Mode 인터페이스 정의
-- ==============================
local Mode = {}

function Mode:OnEnable(bar2Frame)
    bar2Frame:UnregisterEvent("RUNE_POWER_UPDATE")
    bar2Frame:UnregisterEvent("UNIT_POWER_UPDATE")
    bar2Frame:RegisterUnitEvent("UNIT_AURA", "player")
    self:Update(bar2Frame)
end

function Mode:OnDisable(bar2Frame)
    bar2Frame:UnregisterEvent("UNIT_AURA")
    if bar2Frame.ticks then
        for _, tick in ipairs(bar2Frame.ticks) do tick:Hide() end
    end
end

function Mode:Update(bar2Frame)
    if not bar2Frame:IsShown() then return end
    if bar2Frame.runebars then
        for _, rb in ipairs(bar2Frame.runebars) do rb:Hide() end
    end
    
    local width, height2 = get_bar2_size()
    bar2Frame:SetSize(width, height2)

    bar2Frame:SetMinMaxValues(0, 5)
    local count = C_Spell.GetSpellCastCount(228477) or 0
    if bar2Frame.countStack then bar2Frame.countStack:SetText(count) end
    if bar2Frame.countDuration then bar2Frame.countDuration:SetText("") end
    bar2Frame:SetValue(count, Enum.StatusBarInterpolation.ExponentialEaseOut)
    update_stack_ticks(bar2Frame, 5)
    
    local c = (bar2Frame.buffConfig and bar2Frame.buffConfig.color) or RB.cachedSpecColor
    bar2Frame:SetStatusBarColor(c.r, c.g, c.b)
    bar2Frame:Show()
end

function Mode:OnEvent(bar2Frame, event, ...)
    if event == "UNIT_AURA" then
        local unit = ...
        if unit == "player" then
            self:Update(bar2Frame)
        end
    end
end

RB:RegisterMode("soulfragments", Mode)
