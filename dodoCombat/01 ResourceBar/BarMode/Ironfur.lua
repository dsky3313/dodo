-- ==============================
-- Inspired
-- ==============================
-- dodo ResourceBar - Ironfur Buff Tracker Mode

-- ==============================
-- 설정 및 테이블
-- ==============================
local dodo = _G.dodo
local RB = dodo.ResourceBar

-- ==============================
-- 캐싱
-- ==============================
local C_SpellBook = C_SpellBook
local C_Timer = C_Timer
local Enum = Enum
local GetTime = GetTime
local ipairs = ipairs
local math_floor = math.floor
local math_max   = math.max
local math_min   = math.min
local UnitAffectingCombat = UnitAffectingCombat

-- ==============================
-- 기능 1: 로컬 상태 및 설정
-- ==============================
local ironfurTicker = nil
local ironfurExpiries = {}
local ironfurDurations = {}
local ironfur_head = 1
local goeExpiry = 0
local ironfurBaseDuration = 7
local hasGoeTalent = false

-- ==============================
-- 기능 2: 상태 업데이트
-- ==============================
local function get_update_interval()
    return UnitAffectingCombat("player") and 0.1 or 0.5
end

local function ironfur_tick()
    local bar2Frame = RB.bar2Frame
    if bar2Frame and bar2Frame.buffConfig and bar2Frame.buffConfig.barMode == "ironfur" then
        local mode = RB.Modes["ironfur"]
        if mode then mode:Update(bar2Frame) end
    end
end

local function refresh_ironfur_talents()
    ironfurBaseDuration = C_SpellBook.IsSpellKnown(393611) and 9 or 7
    hasGoeTalent = C_SpellBook.IsSpellKnown(155578)
end

local function update_ironfur_ticks(bar2Frame, stackCount, longestIdx, fillPct, barWidth, barHeight)
    if not bar2Frame.ironfurTicks then bar2Frame.ironfurTicks = {} end
    local now = GetTime()

    for slot = 1, stackCount do
        local i = ironfur_head - 1 + slot
        local tick = bar2Frame.ironfurTicks[slot]
        if not tick then
            tick = bar2Frame:CreateTexture(nil, "OVERLAY")
            tick:SetAtlas("cast-empowered-pipflare")
            bar2Frame.ironfurTicks[slot] = tick
        end

        local pct
        if i == longestIdx then
            pct = fillPct
        else
            pct = math_max(0, math_min(1, (ironfurExpiries[i] - now) / ironfurDurations[i]))
        end

        tick:SetSize(barHeight * 0.5, barHeight * 1.6)
        tick:ClearAllPoints()
        tick:SetPoint("CENTER", bar2Frame, "LEFT", pct * barWidth, 0)
        tick:Show()
    end

    for i = stackCount + 1, #bar2Frame.ironfurTicks do
        bar2Frame.ironfurTicks[i]:Hide()
    end
end

-- ==============================
-- 기능 3: UI 및 이벤트 핸들러 등록
-- ==============================
local Mode = {}

function Mode:OnEnable(bar2Frame)
    ironfurExpiries = {}
    ironfurDurations = {}
    ironfur_head = 1
    bar2Frame:UnregisterEvent("RUNE_POWER_UPDATE")
    bar2Frame:UnregisterEvent("UNIT_POWER_UPDATE")
    bar2Frame:UnregisterEvent("UNIT_AURA")
    bar2Frame:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
    refresh_ironfur_talents()
    -- 12.1: Ironfur aura 전체 secret → applications/expirationTime 비교 불가.
    -- 기존 스택 시드 불가, SPELLCAST 이벤트로만 추적.
    self:Update(bar2Frame)
end

function Mode:OnDisable(bar2Frame)
    ironfurExpiries = {}
    ironfurDurations = {}
    ironfur_head = 1
    if ironfurTicker then
        ironfurTicker:Cancel()
        ironfurTicker = nil
    end
    bar2Frame:UnregisterEvent("UNIT_SPELLCAST_SUCCEEDED")
    if bar2Frame.ironfurTicks then
        for _, tick in ipairs(bar2Frame.ironfurTicks) do tick:Hide() end
    end
end

function Mode:Update(bar2Frame)
    if not bar2Frame:IsShown() then return end
    if bar2Frame.runebars then
        for _, rb in ipairs(bar2Frame.runebars) do rb:Hide() end
    end
    if bar2Frame.countStack then bar2Frame.countStack:Show() end
    if bar2Frame.countDuration then bar2Frame.countDuration:Show() end

    local now = GetTime()
    while ironfur_head <= #ironfurExpiries and ironfurExpiries[ironfur_head] <= now do
        ironfur_head = ironfur_head + 1
    end

    local stackCount = #ironfurExpiries - ironfur_head + 1
    if stackCount == 0 then
        bar2Frame:SetValue(0)
        if bar2Frame.countStack then bar2Frame.countStack:SetText("") end
        if bar2Frame.countDuration then bar2Frame.countDuration:SetText("") end
        bar2Frame._lastDurationIntVal = nil
        if bar2Frame.ironfurTicks then
            for _, t in ipairs(bar2Frame.ironfurTicks) do t:Hide() end
        end
        local tex = bar2Frame:GetStatusBarTexture()
        if tex then tex:SetAlpha(0) end
        if ironfurTicker then
            ironfurTicker:Cancel()
            ironfurTicker = nil
        end
        return
    end

    bar2Frame:SetMinMaxValues(0, 1)
    local c = (bar2Frame.buffConfig and bar2Frame.buffConfig.color) or RB.cachedSpecColor
    bar2Frame:SetStatusBarColor(c.r, c.g, c.b, 1)
    local tex = bar2Frame:GetStatusBarTexture()
    if tex then tex:SetAlpha(1) end

    local longestIdx = ironfur_head
    local maxRem = 0
    for i = ironfur_head, #ironfurExpiries do
        local rem = ironfurExpiries[i] - now
        if rem > maxRem then
            maxRem = rem
            longestIdx = i
        end
    end

    local fillPct = math_max(0, maxRem / ironfurDurations[longestIdx])
    bar2Frame:SetValue(fillPct, Enum.StatusBarInterpolation.Immediate)
    if bar2Frame.countStack then bar2Frame.countStack:SetText(stackCount) end

    local intVal = math_floor(maxRem)
    if bar2Frame.countDuration and intVal ~= bar2Frame._lastDurationIntVal then
        bar2Frame.countDuration:SetFormattedText("%.0f", intVal)
        bar2Frame._lastDurationIntVal = intVal
    end

    update_ironfur_ticks(bar2Frame, stackCount, longestIdx, fillPct, bar2Frame:GetWidth(), bar2Frame:GetHeight())

    if not ironfurTicker then
        ironfurTicker = C_Timer.NewTicker(get_update_interval(), ironfur_tick)
    end
end

function Mode:OnEvent(bar2Frame, event, ...)
    if event == "UNIT_SPELLCAST_SUCCEEDED" then
        local unit, _, spellID = ...
        if spellID == 192081 then -- 무쇠가죽
            local now = GetTime()
            local bonus = (hasGoeTalent and now < goeExpiry) and 3 or 0
            if bonus > 0 then goeExpiry = 0 end 
            local duration = ironfurBaseDuration + bonus
            local n = #ironfurExpiries + 1
            ironfurExpiries[n] = now + duration
            ironfurDurations[n] = duration
            self:Update(bar2Frame)
        elseif spellID == 33917 then -- 짓이기기
            if hasGoeTalent then
                goeExpiry = GetTime() + 15
            end
        end
    end
end

RB:RegisterMode("ironfur", Mode)
