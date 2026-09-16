-- ==============================
-- Inspired
-- ==============================
-- dodo ResourceBar - Duration Buff Tracker Mode

-- ==============================
-- 설정 및 테이블
-- ==============================
local dodo = _G.dodo
local RB = dodo.ResourceBar

-- ==============================
-- 캐싱
-- ==============================
local C_Spell = C_Spell
local C_Timer = C_Timer
local GetTime = GetTime
local ipairs = ipairs
local math_max = math.max
local string_format = string.format
local UnitAffectingCombat = UnitAffectingCombat

-- ==============================
-- 기능 1: 로컬 상태 및 설정
-- ==============================
local durationTicker = nil

-- ==============================
-- 기능 2: 상태 업데이트
-- ==============================
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

local function stop_ticker_and_hide(bar2Frame)
    if bar2Frame.countStack then bar2Frame.countStack:SetText("") end
    if bar2Frame.countDuration then bar2Frame.countDuration:SetText("0") end
    bar2Frame:SetValue(0, RB.smoothInterp)
    local tex = bar2Frame:GetStatusBarTexture()
    if tex then tex:SetAlpha(0) end
    if durationTicker then
        durationTicker:Cancel()
        durationTicker = nil
    end
    bar2Frame._castTime = nil
    bar2Frame._knownDuration = nil
end

-- ==============================
-- 기능 3: UI 및 이벤트 핸들러 등록
-- ==============================
local Mode = {}

function Mode:OnEnable(bar2Frame)
    bar2Frame:UnregisterEvent("RUNE_POWER_UPDATE")
    bar2Frame:UnregisterEvent("UNIT_POWER_UPDATE")
    bar2Frame:UnregisterEvent("UNIT_AURA")
    bar2Frame:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
    self:Update(bar2Frame)
end

function Mode:OnDisable(bar2Frame)
    bar2Frame:UnregisterEvent("UNIT_SPELLCAST_SUCCEEDED")
    if durationTicker then
        durationTicker:Cancel()
        durationTicker = nil
    end
    if bar2Frame.ticks then
        for _, tick in ipairs(bar2Frame.ticks) do tick:Hide() end
    end
end

function Mode:Update(bar2Frame)
    if not bar2Frame:IsShown() then return end
    if bar2Frame.runebars then
        for _, rb in ipairs(bar2Frame.runebars) do rb:Hide() end
    end
    if bar2Frame.countStack then bar2Frame.countStack:Show() end
    if bar2Frame.countDuration then bar2Frame.countDuration:Show() end

    if bar2Frame.ticks then
        for _, tick in ipairs(bar2Frame.ticks) do tick:Hide() end
    end

    local c = (bar2Frame.buffConfig and bar2Frame.buffConfig.color) or RB.cachedSpecColor
    bar2Frame:SetStatusBarColor(c.r, c.g, c.b, 1)

    local item = bar2Frame.viewerItem
    if not item or not item.auraDataCached then
        stop_ticker_and_hide(bar2Frame)
        return
    end

    local tex = bar2Frame:GetStatusBarTexture()
    if tex then tex:SetAlpha(1) end

    local knownDur = (bar2Frame.buffConfig and bar2Frame.buffConfig.duration) or 20

    -- auraData 수치 필드는 타겟 디버프에서 전부 secret → UNIT_SPELLCAST_SUCCEEDED로 기록한 시각 사용
    -- 리로드 등으로 castTime 없으면 현재 시각 기준으로 추정 (약간 오차 있음)
    if not bar2Frame._castTime then
        bar2Frame._castTime = GetTime()
        bar2Frame._knownDuration = knownDur
    end

    local maxValue = bar2Frame._knownDuration or knownDur
    local rem = bar2Frame._castTime + maxValue - GetTime()

    if bar2Frame._cachedMax ~= maxValue then
        bar2Frame._cachedMax = maxValue
        bar2Frame:SetMinMaxValues(0, maxValue)
    end

    if rem > 0 then
        bar2Frame:SetValue(rem, RB.smoothInterp)
    else
        stop_ticker_and_hide(bar2Frame)
        return
    end

    -- 텍스트: CDM FontString은 secret이어도 SetText에는 전달 가능
    local remText
    if item.Cooldown and item.Cooldown.GetCountdownFontString then
        local cfs = item.Cooldown:GetCountdownFontString()
        remText = cfs and cfs:GetText()
    elseif item.Bar and item.Bar.Duration then
        remText = item.Bar.Duration:GetText()
    end
    if remText then
        bar2Frame.countDuration:SetText(remText)
    else
        bar2Frame.countDuration:SetText(string_format("%.0f", math_max(0, rem)))
    end

    if bar2Frame.countStack then bar2Frame.countStack:SetText("") end
    if not durationTicker then
        durationTicker = C_Timer.NewTicker(get_update_interval(), duration_tick)
    end
    bar2Frame:Show()
end

function Mode:OnEvent(bar2Frame, event, ...)
    if event == "UNIT_SPELLCAST_SUCCEEDED" then
        local unit, _, spellID = ...
        if unit == "player" then
            local config = bar2Frame.buffConfig
            if config and config.spellID then
                local baseID = C_Spell.GetBaseSpell(spellID)
                if spellID == config.spellID or baseID == config.spellID then
                    bar2Frame._castTime = GetTime()
                    bar2Frame._knownDuration = config.duration or 20
                end
            end
        end
    end
end

RB:RegisterMode("duration", Mode)
