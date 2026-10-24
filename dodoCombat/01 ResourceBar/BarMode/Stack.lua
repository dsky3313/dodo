-- ==============================
-- Inspired
-- ==============================
-- dodo ResourceBar - Stack Buff Tracker Mode

-- ==============================
-- 설정 및 테이블
-- ==============================
local dodo = _G.dodo
local RB = dodo.ResourceBar

-- ==============================
-- 캐싱
-- ==============================
local C_UnitAuras = C_UnitAuras
local Enum = Enum
local GetTime = GetTime
local ipairs = ipairs
local issecretvalue = issecretvalue

-- ==============================
-- 기능 1: 로컬 상태 및 설정
-- ==============================
-- 남은시간 tick (tickDuration 설정된 버프만, 예: 고통 감내)
-- aura 만료시간 secret → 시전 시점 기준으로 추정
local tickEndTime = 0
local SHIELD_SLAM = 23922   -- 방패 밀쳐내기
local VO_PROC = 386478      -- 격렬한 분출: 방패 밀쳐내기로 고통 감내 갱신
local tickTicker

-- ==============================
-- 기능 2: 상태 업데이트
-- ==============================
local function update_duration_tick()
    local bar2Frame = RB.bar2Frame
    local cfg = bar2Frame and bar2Frame.buffConfig
    local remain = tickEndTime - GetTime()
    if not cfg or not cfg.tickDuration or remain <= 0 then
        if bar2Frame and bar2Frame.durationTick then bar2Frame.durationTick:Hide() end
        tickTicker:Stop()
        return
    end

    local tick = bar2Frame.durationTick
    if not tick then
        tick = bar2Frame:CreateTexture(nil, "OVERLAY")
        tick:SetAtlas("cast-empowered-pipflare")
        bar2Frame.durationTick = tick
    end

    local pct = remain / cfg.tickDuration
    if pct > 1 then pct = 1 end
    local barHeight = bar2Frame:GetHeight()
    tick:SetSize(barHeight * 0.5, barHeight * 1.6)
    tick:ClearAllPoints()
    tick:SetPoint("CENTER", bar2Frame, "LEFT", pct * bar2Frame:GetWidth(), 0)
    tick:Show()
end

-- 30Hz 루프 티커 (dodo/Data/Tick.lua)
tickTicker = dodo.LoopTicker(update_duration_tick, 1 / 30)

local function start_duration_tick(duration)
    tickEndTime = GetTime() + duration
    if not tickTicker:IsPlaying() then tickTicker:Play() end
    update_duration_tick()
end

local function update_stack_ticks(bar2Frame, maxStack)
    if not bar2Frame.ticks then bar2Frame.ticks = {} end

    for _, tick in ipairs(bar2Frame.ticks) do tick:Hide() end

    if not maxStack or maxStack <= 1 or maxStack > 20 then
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
    bar2Frame:UnregisterEvent("UNIT_POWER_UPDATE")
    bar2Frame:UnregisterEvent("UNIT_AURA")
    local cfg = bar2Frame.buffConfig
    if cfg and cfg.tickDuration then
        bar2Frame:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
        -- 버프 새로 활성 = 방금 시전 (SPELLCAST가 CDM 활성보다 먼저 와서 놓친 경우 대비)
        if tickEndTime <= GetTime() then start_duration_tick(cfg.tickDuration) end
    end
    self:Update(bar2Frame)
end

function Mode:OnDisable(bar2Frame)
    if bar2Frame.ticks then
        for _, tick in ipairs(bar2Frame.ticks) do tick:Hide() end
    end
    bar2Frame:UnregisterEvent("UNIT_SPELLCAST_SUCCEEDED")
    tickEndTime = 0
    tickTicker:Stop()
    if bar2Frame.durationTick then bar2Frame.durationTick:Hide() end
end

function Mode:Update(bar2Frame)
    if not bar2Frame:IsShown() then return end
    if bar2Frame.runebars then
        for _, rb in ipairs(bar2Frame.runebars) do rb:Hide() end
    end
    if bar2Frame.countStack then bar2Frame.countStack:Show() end
    if bar2Frame.countDuration then bar2Frame.countDuration:Show() end

    local maxValue = bar2Frame.buffConfig and bar2Frame.buffConfig.maxStack or 100
    if maxValue ~= bar2Frame._cachedMax then
        bar2Frame._cachedMax = maxValue
        bar2Frame:SetMinMaxValues(0, maxValue)
    end
    update_stack_ticks(bar2Frame, maxValue)

    local c = (bar2Frame.buffConfig and bar2Frame.buffConfig.color) or RB.cachedSpecColor
    bar2Frame:SetStatusBarColor(c.r, c.g, c.b, 1)

    if not bar2Frame.viewerItem or not bar2Frame.viewerItem.auraDataCached then
        if bar2Frame.countStack then bar2Frame.countStack:SetText("") end
        if bar2Frame.countDuration then bar2Frame.countDuration:SetText("") end
        bar2Frame:SetValue(0, RB.smoothInterp)
        local tex = bar2Frame:GetStatusBarTexture()
        if tex then tex:SetAlpha(0) end
        return
    end

    local tex = bar2Frame:GetStatusBarTexture()
    if tex then tex:SetAlpha(1) end

    local auraData = bar2Frame.viewerItem.auraDataCached
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
        bar2Frame:SetValue(countBar, RB.smoothInterp)
        bar2Frame:Show()
    end
end

function Mode:OnEvent(bar2Frame, event, ...)
    -- 스택은 CooldownViewer 훅에서 Update, 여기선 남은시간 tick 리셋만 처리
    if event == "UNIT_SPELLCAST_SUCCEEDED" then
        local cfg = bar2Frame.buffConfig
        if not cfg or not cfg.tickDuration then return end
        local _, _, spellID = ...
        if spellID == cfg.spellID then
            start_duration_tick(cfg.tickDuration)
        elseif spellID == SHIELD_SLAM and C_UnitAuras.GetPlayerAuraBySpellID(VO_PROC) then
            start_duration_tick(cfg.tickDuration)
        end
    end
end

RB:RegisterMode("stack", Mode)
