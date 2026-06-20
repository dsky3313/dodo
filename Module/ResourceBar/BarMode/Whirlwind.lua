-- ==============================
-- Inspired
-- ==============================
-- asPowerBarWhirlwind.lua (Hybrid rewrite via CooldownViewer)

-- ==============================
-- 설정 및 테이블
-- ==============================
local addonName, dodo = ...
local RB = dodo.ResourceBar

local Config = {
    maxStack = 4,
    unhingedTalentID = 386628,
}

local use_stack = {
    [23881]  = true, -- 피의 갈증
    [85288]  = true, -- Raging Blow
    [280735] = true, -- Execute
    [202168] = true, -- Impending Victory
    [184367] = true, -- Rampage
    [335096] = true, -- Bloodbath
    [335097] = true, -- Crushing Blow
    [5308]   = true, -- Execute (Base)
}

-- ==============================
-- 캐싱
-- ==============================
local C_SpellBook = C_SpellBook
local C_Timer = C_Timer
local C_UnitAuras = C_UnitAuras
local Enum = Enum
local GetTime = GetTime
local ipairs = ipairs
local issecretvalue = issecretvalue
local math = math
local PixelUtil = PixelUtil

-- ==============================
-- 기능 1: 로컬 상태 및 설정
-- ==============================
local ww_stack_count = 0
local ww_consume_prevent_until = 0
local ww_has_unhinged_talent = false
local ww_processed_cast_guids = {}
local ww_timer_ticker = nil
local ww_is_active = false
local ww_last_consume_time = 0
local Mode = {}

-- ==============================
-- 기능 2: 상태 업데이트 및 감지
-- ==============================
local function handle_timer_tick()
    local bar2Frame = RB.bar2Frame
    if not bar2Frame then return end

    if bar2Frame.buffConfig and bar2Frame.buffConfig.barMode == "whirlwind" then
        Mode:Update(bar2Frame)
    end
end

local function process_player_spellcast(bar2Frame, unit, cast_guid, spell_id)
    if unit ~= "player" then return end

    if cast_guid and ww_processed_cast_guids[cast_guid] then return end
    if cast_guid then ww_processed_cast_guids[cast_guid] = true end

    -- Whirlwind generation (190414, 190411 or 1680)
    if spell_id == 190414 or spell_id == 190411 or spell_id == 1680 then
        ww_stack_count = Config.maxStack
        if bar2Frame.countStack then
            bar2Frame.countStack:SetText(tostring(ww_stack_count))
        end
        bar2Frame:SetValue(ww_stack_count, Enum.StatusBarInterpolation.ExponentialEaseOut)
        return
    end

    -- Unhinged check to prevent stack consumption during Bladestorm
    if ww_has_unhinged_talent and (
        spell_id == 50622 or
        spell_id == 46924 or
        spell_id == 227847 or
        spell_id == 184362 or
        spell_id == 446035
    ) then
        ww_consume_prevent_until = GetTime() + 2
    end

    -- Stack consumption logic
    if use_stack[spell_id] then
        -- Prevent stack consumption by automatic Bloodthirst (23881) or Bloodbath (335096) during Bladestorm
        if (GetTime() < ww_consume_prevent_until) and (spell_id == 23881 or spell_id == 335096) then return end
        if ww_stack_count <= 0 then return end

        -- Time guard: prevent multiple consumptions within 0.1s (e.g. multi-target cleaves)
        local now = GetTime()
        if now - ww_last_consume_time < 0.1 then return end
        ww_last_consume_time = now

        ww_stack_count = math.max(0, ww_stack_count - 1)

        if bar2Frame.countStack then
            bar2Frame.countStack:SetText(ww_stack_count > 0 and tostring(ww_stack_count) or "")
        end
        bar2Frame:SetValue(ww_stack_count, Enum.StatusBarInterpolation.ExponentialEaseOut)
    end
end

-- ==============================
-- 기능 3: UI 및 이벤트 핸들러 등록
-- ==============================

function Mode:OnEnable(bar2Frame)
    bar2Frame:UnregisterEvent("RUNE_POWER_UPDATE")
    bar2Frame:UnregisterEvent("UNIT_POWER_UPDATE")
    bar2Frame:UnregisterEvent("UNIT_AURA")
    
    bar2Frame:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")

    ww_stack_count = 0
    ww_is_active = false
    ww_consume_prevent_until = 0
    ww_last_consume_time = 0
    ww_has_unhinged_talent = C_SpellBook.IsSpellKnown(Config.unhingedTalentID) or false
    ww_processed_cast_guids = {}

    if not ww_timer_ticker then
        ww_timer_ticker = C_Timer.NewTicker(0.2, handle_timer_tick)
    end

    self:Update(bar2Frame)
end

function Mode:OnDisable(bar2Frame)
    bar2Frame:UnregisterEvent("UNIT_SPELLCAST_SUCCEEDED")

    if ww_timer_ticker then
        ww_timer_ticker:Cancel()
        ww_timer_ticker = nil
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

    local max_stack = Config.maxStack
    bar2Frame:SetMinMaxValues(0, max_stack)

    -- Update ticks (dirty check: 바 크기 변경 시에만 재배치)
    if not bar2Frame.ticks then bar2Frame.ticks = {} end
    local bar_width = bar2Frame:GetWidth()
    local bar_height = bar2Frame:GetHeight()
    if bar2Frame._lastBarWidth ~= bar_width or bar2Frame._lastBarHeight ~= bar_height then
        bar2Frame._lastBarWidth = bar_width
        bar2Frame._lastBarHeight = bar_height
        for _, tick in ipairs(bar2Frame.ticks) do tick:Hide() end
        for i = 1, max_stack - 1 do
            if not bar2Frame.ticks[i] then
                local tick = bar2Frame:CreateTexture(nil, "OVERLAY")
                tick:SetColorTexture(0, 0, 0, 0.8)
                bar2Frame.ticks[i] = tick
            end
            local tick = bar2Frame.ticks[i]
            tick:ClearAllPoints()
            PixelUtil.SetSize(tick, 1, bar_height)
            local x_offset = (bar_width / max_stack) * i
            PixelUtil.SetPoint(tick, "LEFT", bar2Frame, "LEFT", x_offset, 0)
            tick:Show()
        end
    end

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
        -- 버프 최초 획득 시에만 4스택으로 초기화
        if not ww_is_active then
            ww_stack_count = Config.maxStack
            ww_is_active = true
        end

        if bar2Frame.countStack then
            bar2Frame.countStack:SetText(tostring(ww_stack_count))
        end
        
        local durObj = C_UnitAuras.GetAuraDuration(unit, auraID)
        if durObj and bar2Frame.countDuration then
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
        
        bar2Frame:SetValue(ww_stack_count, Enum.StatusBarInterpolation.ExponentialEaseOut)
        bar2Frame:Show()
    else
        -- 실제 버프가 해제되었을 때
        ww_stack_count = 0
        ww_is_active = false
        bar2Frame._lastDurationIntVal = nil
        if bar2Frame.countStack then bar2Frame.countStack:SetText("") end
        if bar2Frame.countDuration then bar2Frame.countDuration:SetText("") end
        bar2Frame:SetValue(0, Enum.StatusBarInterpolation.ExponentialEaseOut)
    end
end

function Mode:OnEvent(bar2Frame, event, ...)
    if event == "UNIT_SPELLCAST_SUCCEEDED" then
        process_player_spellcast(bar2Frame, ...)
    end
end

RB:RegisterMode("whirlwind", Mode)
