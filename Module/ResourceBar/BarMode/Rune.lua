-- ==============================
-- Inspired
-- ==============================
-- dodo ResourceBar - Death Knight Rune Mode
-- ==============================

local addonName, dodo = ...
local RB = dodo.ResourceBar
local Colors = dodo.Colors

local GetRuneCooldown = GetRuneCooldown
local GetTime = GetTime
local C_Timer = C_Timer
local CreateFrame = CreateFrame
local Enum = Enum
local ipairs = ipairs
local math = math
local table = table

local runeTicker = nil

-- 죽음의 기사 룬 정렬 캐싱
local runeDataCache = {}
for i = 1, 6 do
    runeDataCache[i] = {
        runeIndex = i,
        startTime = 0,
        duration = 0,
        isReady = false,
        remaining = 0
    }
end
local runeSortOrder = { 1, 2, 3, 4, 5, 6 }

local function compare_rune_order(a, b)
    local runeA = runeDataCache[a]
    local runeB = runeDataCache[b]
    if runeA.isReady and not runeB.isReady then
        return true
    elseif not runeA.isReady and runeB.isReady then
        return false
    end
    return runeA.remaining < runeB.remaining
end

local function collect_and_sort_rune_data()
    local now = GetTime()
    local hasRecharging = false

    for i = 1, 6 do
        local startTime, duration, runeIsReady = GetRuneCooldown(i)
        local remaining = 0

        if not runeIsReady and startTime and duration and duration > 0 then
            remaining = (startTime + duration) - now
            if remaining < 0 then remaining = 0 end
            hasRecharging = true
        end

        local entry = runeDataCache[i]
        entry.runeIndex = i
        entry.startTime = startTime
        entry.duration = duration
        entry.isReady = runeIsReady
        entry.remaining = remaining
    end

    for i = 1, 6 do
        runeSortOrder[i] = i
    end

    table.sort(runeSortOrder, compare_rune_order)

    return hasRecharging
end

local function get_update_interval()
    return UnitAffectingCombat("player") and 0.1 or 0.5
end

local function rune_tick()
    local bar2Frame = RB.bar2Frame
    if bar2Frame and bar2Frame.buffConfig and bar2Frame.buffConfig.barMode == "rune" then
        local mode = RB.Modes["rune"]
        if mode then mode:Update(bar2Frame) end
    end
end

local function get_bar2_size()
    local db = dodo.DB or dodoDB
    local width = (db and db.resourceBarWidth) or RB.barConfigs[1].width or 272
    local height = (db and db.resourceBarHeight) or RB.barConfigs[1].height or 10
    local height2 = math.max(height - 3, 5)
    return width, height2
end

-- ==============================
-- Rune Mode 인터페이스 정의
-- ==============================
local Mode = {}

function Mode:OnEnable(bar2Frame)
    bar2Frame:RegisterEvent("RUNE_POWER_UPDATE")
    bar2Frame:UnregisterEvent("UNIT_POWER_UPDATE")
    bar2Frame:UnregisterEvent("UNIT_AURA")
    self:Update(bar2Frame)
end

function Mode:OnDisable(bar2Frame)
    if runeTicker then
        runeTicker:Cancel()
        runeTicker = nil
    end
    if bar2Frame.runebars then
        for _, rb in ipairs(bar2Frame.runebars) do
            rb:Hide()
        end
    end
end

function Mode:Update(bar2Frame)
    local width, height2 = get_bar2_size()
    bar2Frame:SetSize(width, height2)

    local barWidth = width - 2
    local runeWidth = barWidth / 6

    if not bar2Frame.runebars then
        bar2Frame.runebars = {}
        for i = 1, 6 do
            local rb = CreateFrame("StatusBar", nil, bar2Frame, "ResourceBar2Template")
            rb:SetSize(runeWidth, height2)
            rb:SetPoint("LEFT", bar2Frame, "LEFT", (i - 1) * runeWidth, 0)
            bar2Frame.runebars[i] = rb
        end
    else
        for i = 1, 6 do
            local rb = bar2Frame.runebars[i]
            rb:SetSize(runeWidth, height2)
            rb:SetPoint("LEFT", bar2Frame, "LEFT", (i - 1) * runeWidth, 0)
        end
    end
    if bar2Frame.countStack then bar2Frame.countStack:Hide() end
    if bar2Frame.countDuration then bar2Frame.countDuration:Hide() end
    bar2Frame:SetStatusBarColor(0, 0, 0, 0)

    local hasRecharging = collect_and_sort_rune_data()
    local c = (bar2Frame.buffConfig and bar2Frame.buffConfig.color) or RB.cachedSpecColor
    local now = GetTime()

    for i = 1, 6 do
        local runeIndex = runeSortOrder[i]
        local rune = runeDataCache[runeIndex]
        local rb = bar2Frame.runebars[i]
        rb:Show()

        if rune.isReady then
            rb:SetMinMaxValues(0, 1)
            rb:SetStatusBarColor(c.r, c.g, c.b)
            rb:SetValue(1)
        elseif rune.startTime and rune.duration and rune.duration > 0 then
            rb:SetMinMaxValues(0, rune.duration)
            rb:SetStatusBarColor(1, 1, 1)

            local elapsed = now - rune.startTime
            local progress = elapsed
            if progress < 0 then progress = 0 end
            if progress > rune.duration then progress = rune.duration end
            rb:SetValue(progress, Enum.StatusBarInterpolation.Immediate)
        else
            rb:SetMinMaxValues(0, 1)
            rb:SetStatusBarColor(c.r, c.g, c.b)
            rb:SetValue(0)
        end
    end

    if hasRecharging then
        if not runeTicker then
            runeTicker = C_Timer.NewTicker(get_update_interval(), rune_tick)
        end
    else
        if runeTicker then
            runeTicker:Cancel()
            runeTicker = nil
        end
    end
end

function Mode:OnEvent(bar2Frame, event, ...)
    if event == "RUNE_POWER_UPDATE" then
        self:Update(bar2Frame)
    end
end

RB:RegisterMode("rune", Mode)
