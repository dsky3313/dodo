-- ==============================
-- Inspired
-- ==============================
-- dodo ResourceBar Buff Tracker (Bar2) Module
-- ==============================

-- ==============================
-- 설정 및 테이블
-- ==============================
---@diagnostic disable: lowercase-global, param-type-mismatch, redundant-parameter, undefined-field, undefined-global
local addonName, dodo = ...
dodoDB = dodoDB or {}

local RB = dodo.ResourceBar
local Colors = dodo.Colors

---@class BuffColor
---@field r number Red
---@field g number Green
---@field b number Blue

---@class BuffConfigItem
---@field barMode string 바 작동 모드
---@field color BuffColor 바 색상 테이블
---@field spellID number 추적할 주문 ID
---@field maxStack number 최대 중첩수
---@field requiredSpell number 특성 필수 주문 ID
---@field excludedSpell number 제외할 주문 ID
---@field powerType number 파워 타입 ID
---@field powerToken string 파워 토큰 명칭
---@field isTickPower boolean 틱 단위 표시 여부
---@field ticks number 최대 틱 개수

---@type table<string, any>
local bar2ClassConfig = {
    ["DEATHKNIGHT"] = { [1] = {{barMode = "rune", color = { r = 1, g = 0, b = 0 }}},
                        [2] = {{barMode = "rune", color = { r = 0, g = 0.8, b = 1 }}},
                        [3] = {{barMode = "rune", color = { r = 0.3, g = 0.9, b = 0.3 }}} },
    ["DEMONHUNTER"] = { [2] = {{barMode = "soulfragments", maxStack = 5, color = { r = 0.8, g = 0.6, b = 1 }}} },
    ["DRUID"] = { [3] = {{spellID = 192081, barMode = "ironfur", color = { r = 0, g = 0.8, b = 1 }}} },
    ["EVOKER"] = { [3] = {{spellID = 395296, barMode = "duration", color = { r = 1, g = 0.5, b = 0.2 }}} },
    ["MAGE"] = { [1] = {{barMode = "power", powerType = 16, powerToken = "ARCANE_CHARGES", isTickPower = true, ticks = 4, color = { r = 0.6, g = 0.2, b = 0.9 }}} },
    ["MONK"] = { [1] = {{barMode = "stagger", color = { r = 0.0, g = 1.0, b = 0.5 }}} },
    ["ROGUE"] = { {barMode = "power", powerType = 4, powerToken = "COMBO_POINTS", isTickPower = true, color = { r = 1.0, g = 0.8, b = 0.0 }} },
    ["SHAMAN"] = { [3] = {{spellID = 51564,  barMode = "stack", maxStack = 3, color = { r = 0.0, g = 0.8, b = 1.0 }}}, },
    ["WARRIOR"] = { [1] = {{spellID = 167105, barMode = "duration", color = { r = 1, g = 0.5, b = 0.2 }}},
                    [2] = {{spellID = 12950,  barMode = "stack", maxStack = 4, requiredSpell = 12950, color = { r = 0, g = 0.8, b = 1 }},
                           {spellID = 184361, barMode = "duration", excludedSpell = 12950, color = { r = 0, g = 0.8, b = 1 }},},
                    [3] = {{spellID = 190456, barMode = "stack", maxStack = 100, color = { r = 1, g = 0.5, b = 0.2 }}}},
}

-- ==============================
-- 캐싱
-- ==============================
local C_CooldownViewer = C_CooldownViewer
local C_PaperDollInfo = C_PaperDollInfo
local C_SpecializationInfo = C_SpecializationInfo
local C_Spell = C_Spell
local C_SpellBook = C_SpellBook
local C_Timer = C_Timer
local C_UnitAuras = C_UnitAuras
local CreateFrame = CreateFrame
local Enum = Enum
local GetRuneCooldown = GetRuneCooldown
local GetTime = GetTime
local hooksecurefunc = hooksecurefunc
local ipairs = ipairs
local issecretvalue = issecretvalue
local math = math
local Mixin = Mixin
local pairs = pairs
local PowerBarColor = PowerBarColor
local RAID_CLASS_COLORS = RAID_CLASS_COLORS
local rawget = rawget
local table = table
local UnitAffectingCombat = UnitAffectingCombat
local UnitClass = UnitClass
local UnitHealthMax = UnitHealthMax
local UnitPower = UnitPower
local UnitPowerMax = UnitPowerMax
local UnitStagger = UnitStagger

-- ==============================
-- 로컬 타이머 및 스펙 상태
-- ==============================
local currentSpecBuffs = {}
local staggerTicker = nil
local ironfurTicker = nil
local runeTicker = nil
local durationTicker = nil

local ironfurExpiries = {}
local ironfurDurations = {}
local goeExpiry = 0
local ironfurBaseDuration = 7
local hasGoeTalent = false
local runeIndexes = { 1, 2, 3, 4, 5, 6 }

local function get_update_interval()
    return UnitAffectingCombat("player") and 0.1 or 0.5
end

-- ==============================
-- 티커 재시작 유틸
-- ==============================
local function restart_duration_ticker()
    if durationTicker then durationTicker:Cancel(); durationTicker = nil end
    local bar2Frame = RB.bar2Frame
    if bar2Frame and bar2Frame.buffConfig and bar2Frame.buffConfig.barMode == "duration" then
        bar2Frame:Update()
    end
end

local function restart_rune_ticker()
    if runeTicker then runeTicker:Cancel(); runeTicker = nil end
    local bar2Frame = RB.bar2Frame
    if bar2Frame and bar2Frame.buffConfig and bar2Frame.buffConfig.barMode == "rune" then
        bar2Frame:UpdateRuneSystem()
    end
end

local function restart_ironfur_ticker()
    if ironfurTicker then ironfurTicker:Cancel(); ironfurTicker = nil end
    local bar2Frame = RB.bar2Frame
    if bar2Frame and bar2Frame.buffConfig and bar2Frame.buffConfig.barMode == "ironfur" then
        if bar2Frame.UpdateIronfurSystemActual then
            bar2Frame:UpdateIronfurSystemActual()
        end
    end
end

local function restart_stagger_ticker()
    if staggerTicker then staggerTicker:Cancel(); staggerTicker = nil end
    local bar2Frame = RB.bar2Frame
    if bar2Frame and bar2Frame.buffConfig and bar2Frame.buffConfig.barMode == "stagger" then
        bar2Frame:UpdateStaggerSystem()
    end
end

-- ==============================
-- 틱 핸들러 (클로저 제거용 정적 바인딩)
-- ==============================
local function duration_tick()
    local bar2Frame = RB.bar2Frame
    if bar2Frame and bar2Frame.buffConfig and bar2Frame.buffConfig.barMode == "duration" then
        bar2Frame:Update()
    end
end

local function stagger_tick()
    local bar2Frame = RB.bar2Frame
    if bar2Frame and bar2Frame.buffConfig and bar2Frame.buffConfig.barMode == "stagger" then
        bar2Frame:UpdateStaggerSystem()
    end
end

local function rune_tick()
    local bar2Frame = RB.bar2Frame
    if bar2Frame and bar2Frame.buffConfig and bar2Frame.buffConfig.barMode == "rune" then
        bar2Frame:UpdateRuneSystem()
    end
end

local function ironfur_tick()
    local bar2Frame = RB.bar2Frame
    if bar2Frame and bar2Frame.buffConfig and bar2Frame.buffConfig.barMode == "ironfur" then
        if bar2Frame.UpdateIronfurSystemActual then
            bar2Frame:UpdateIronfurSystemActual()
        end
    end
end

local function refresh_ironfur_talents()
    ironfurBaseDuration = C_SpellBook.IsSpellKnown(393611) and 9 or 7
    hasGoeTalent = C_SpellBook.IsSpellKnown(155578)
end

-- ==============================
-- 죽음의 기사 룬 정렬 캐싱
-- ==============================
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

-- ==============================
-- 공통 리사이징 헬퍼
-- ==============================
local function get_bar2_size()
    local db = dodo.DB or dodoDB
    local width = (db and db.resourceBarWidth) or RB.barConfigs[1].width or 272
    local height = (db and db.resourceBarHeight) or RB.barConfigs[1].height or 10
    local height2 = math.max(height - 3, 5)
    return width, height2
end

-- ==============================
-- 수호 드루이드 무쇠가죽(Ironfur) 핵심 로직
-- ==============================
local function update_ironfur_system(f)
    local now = GetTime()
    while #ironfurExpiries > 0 and ironfurExpiries[1] <= now do
        table.remove(ironfurExpiries, 1)
        table.remove(ironfurDurations, 1)
    end

    local stackCount = #ironfurExpiries
    if stackCount == 0 then
        f:SetValue(0)
        if f.countStack then f.countStack:SetText("") end
        if f.countDuration then f.countDuration:SetText("") end
        f._lastDurationIntVal = nil
        if f.ironfurTicks then for _, t in ipairs(f.ironfurTicks) do t:Hide() end end
        if ironfurTicker then
            ironfurTicker:Cancel()
            ironfurTicker = nil
        end
        f._hasIronfurUpdate = false
        return
    end

    local longestIdx = 1
    local maxRem = 0
    for i = 1, stackCount do
        local rem = ironfurExpiries[i] - now
        if rem > maxRem then
            maxRem = rem
            longestIdx = i
        end
    end

    local fillPct = math.max(0, maxRem / ironfurDurations[longestIdx])
    f:SetValue(fillPct, Enum.StatusBarInterpolation.Immediate)
    if f.countStack then f.countStack:SetText(stackCount) end

    local intVal = math.floor(maxRem)
    if f.countDuration and intVal ~= f._lastDurationIntVal then
        f.countDuration:SetFormattedText("%.0f", intVal)
        f._lastDurationIntVal = intVal
    end

    f:UpdateIronfurTicks(stackCount, longestIdx, fillPct, f:GetWidth(), f:GetHeight())

    if not ironfurTicker then
        ironfurTicker = C_Timer.NewTicker(get_update_interval(), ironfur_tick)
    end
end

-- ==============================
-- ResourceBar2 Mixin & 동작
-- ==============================
local ResourceBar2Mixin = {}

function ResourceBar2Mixin:SetViewerItem(viewerItem) self.viewerItem = viewerItem end
function ResourceBar2Mixin:SetBuffConfig(buffConfig) self.buffConfig = buffConfig end

function ResourceBar2Mixin:UpdateIronfurTicks(stackCount, longestIdx, fillPct, barWidth, barHeight)
    if not self.ironfurTicks then self.ironfurTicks = {} end
    local now = GetTime()

    for i = 1, stackCount do
        local tick = self.ironfurTicks[i]
        if not tick then
            tick = self:CreateTexture(nil, "OVERLAY")
            tick:SetAtlas("cast-empowered-pipflare")
            self.ironfurTicks[i] = tick
        end

        local pct
        if i == longestIdx then
            pct = fillPct
        else
            pct = math.max(0, math.min(1, (ironfurExpiries[i] - now) / ironfurDurations[i]))
        end

        tick:SetSize(barHeight * 0.6, barHeight * 1.6)
        tick:ClearAllPoints()
        tick:SetPoint("CENTER", self, "LEFT", pct * barWidth, 0)
        tick:Show()
    end

    for i = stackCount + 1, #self.ironfurTicks do
        self.ironfurTicks[i]:Hide()
    end
end

function ResourceBar2Mixin:UpdateIronfurSystemActual()
    update_ironfur_system(self)
end

function ResourceBar2Mixin:OnEvent(event, ...)
    if event == "PLAYER_ENTERING_WORLD" or event == "PLAYER_SPECIALIZATION_CHANGED" or event == "PLAYER_TALENT_UPDATE" then
        RB.UpdateSpecConfig()
        refresh_ironfur_talents()
    elseif event == "PLAYER_REGEN_DISABLED" or event == "PLAYER_REGEN_ENABLED" then
        if self.buffConfig and self.buffConfig.barMode == "stagger" then
            self:UpdateStaggerSystem()
        end
    elseif event == "UNIT_POWER_UPDATE" then
        if self.buffConfig and self.buffConfig.barMode == "power" then
            self:Update()
        end
    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        local unit, _, spellID = ...
        if spellID == 192081 then -- 무쇠가죽
            local now = GetTime()
            local bonus = (hasGoeTalent and now < goeExpiry) and 3 or 0
            if bonus > 0 then goeExpiry = 0 end 
            local duration = ironfurBaseDuration + bonus
            local n = #ironfurExpiries + 1
            ironfurExpiries[n] = now + duration
            ironfurDurations[n] = duration
            update_ironfur_system(self)
        elseif spellID == 33917 then -- 짓이기기
            if hasGoeTalent then
                goeExpiry = GetTime() + 15
            end
        end
    end
end

function ResourceBar2Mixin:UpdateStackTicks(maxStack)
    if not self.ticks then self.ticks = {} end

    for _, tick in ipairs(self.ticks) do tick:Hide() end

    if not maxStack or maxStack <= 1 or maxStack > 10 then
        self._lastMaxStack = nil
        return
    end

    if self._lastMaxStack == maxStack then
        for i = 1, maxStack - 1 do
            if self.ticks[i] then self.ticks[i]:Show() end
        end
        return
    end
    self._lastMaxStack = maxStack

    local barWidth = self:GetWidth()
    local barHeight = self:GetHeight()

    for i = 1, maxStack - 1 do
        if not self.ticks[i] then
            local tick = self:CreateTexture(nil, "OVERLAY")
            tick:SetColorTexture(0, 0, 0, 0.8)
            self.ticks[i] = tick
        end

        local tick = self.ticks[i]
        tick:ClearAllPoints()
        PixelUtil.SetSize(tick, 1, barHeight)
        local xOffset = (barWidth / maxStack) * i
        PixelUtil.SetPoint(tick, "LEFT", self, "LEFT", xOffset, 0)
        tick:Show()
    end
end

function ResourceBar2Mixin:UpdateRuneSystem()
    local width, height2 = get_bar2_size()
    self:SetSize(width, height2)

    local barWidth = width - 2
    local runeWidth = barWidth / 6

    if not self.runebars then
        self.runebars = {}
        for i = 1, 6 do
            local rb = CreateFrame("StatusBar", nil, self, "ResourceBar2Template")
            rb:SetSize(runeWidth, height2)
            rb:SetPoint("LEFT", self, "LEFT", (i - 1) * runeWidth, 0)
            self.runebars[i] = rb
        end
    else
        for i = 1, 6 do
            local rb = self.runebars[i]
            rb:SetSize(runeWidth, height2)
            rb:SetPoint("LEFT", self, "LEFT", (i - 1) * runeWidth, 0)
        end
    end
    if self.countStack then self.countStack:Hide() end
    if self.countDuration then self.countDuration:Hide() end
    self:SetStatusBarColor(0, 0, 0, 0)

    local hasRecharging = collect_and_sort_rune_data()
    local c = (self.buffConfig and self.buffConfig.color) or RB.cachedSpecColor
    local now = GetTime()

    for i = 1, 6 do
        local runeIndex = runeSortOrder[i]
        local rune = runeDataCache[runeIndex]
        local rb = self.runebars[i]
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

function ResourceBar2Mixin:UpdateStaggerSystem()
    if not self:IsShown() then return end
    if self.runebars then for _, rb in ipairs(self.runebars) do rb:Hide() end end
    if self.countStack then self.countStack:Show() end
    if self.countDuration then self.countDuration:Hide() end
    if self.Cooldown then
        self.Cooldown:Clear()
        self.Cooldown:Hide()
    end

    local stagger = UnitStagger("player") or 0
    local maxHealth = UnitHealthMax("player") or 1
    self:SetMinMaxValues(0, maxHealth)
    self:SetValue(stagger, Enum.StatusBarInterpolation.ExponentialEaseOut)

    local pct = 0
    local isSecret = issecretvalue(stagger) or issecretvalue(maxHealth)
    
    if not isSecret then
        pct = (stagger / maxHealth) * 100
        if pct >= 60 then
            self:SetStatusBarColor(1, 0, 0)
        elseif pct >= 30 then
            self:SetStatusBarColor(1, 0.8, 0)
        else
            local c = (self.buffConfig and self.buffConfig.color) or RB.cachedSpecColor
            self:SetStatusBarColor(c.r, c.g, c.b)
        end
        if self.countStack then
            if stagger == 0 then
                self.countStack:SetText("0")
            else
                self.countStack:SetFormattedText("%.0f", pct)
            end
        end
    else
        -- 12.0.0 인스턴스 비밀값 검출 우회
        local sPct = C_PaperDollInfo.GetStaggerPercentage("player")
        
        -- 오라 디버프에 따른 색상 분기
        if C_UnitAuras.GetPlayerAuraBySpellID(124273) then
            self:SetStatusBarColor(1, 0, 0)
        elseif C_UnitAuras.GetPlayerAuraBySpellID(124274) then
            self:SetStatusBarColor(1, 0.8, 0)
        else
            local c = (self.buffConfig and self.buffConfig.color) or RB.cachedSpecColor
            self:SetStatusBarColor(c.r, c.g, c.b)
        end
        
        if self.countStack then
            if sPct == 0 then
                self.countStack:SetText("0")
            else
                self.countStack:SetText(sPct)
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

function ResourceBar2Mixin:Update()
    if not self:IsShown() then return end
    if self.buffConfig and self.buffConfig.barMode == "rune" then
        self:UpdateRuneSystem(); self:Show(); return
    end
    if self.buffConfig and self.buffConfig.barMode == "stagger" then
        self:UpdateStaggerSystem(); self:Show(); return
    end
    if self.buffConfig and self.buffConfig.barMode == "soulfragments" then
        self:SetMinMaxValues(0, 5)
        local count = C_Spell.GetSpellCastCount(228477) or 0
        if self.countStack then self.countStack:SetText(count) end
        if self.countDuration then self.countDuration:SetText("") end
        self:SetValue(count, Enum.StatusBarInterpolation.ExponentialEaseOut)
        self:UpdateStackTicks(5)
        local c = (self.buffConfig and self.buffConfig.color) or RB.cachedSpecColor
        self:SetStatusBarColor(c.r, c.g, c.b)
        self:Show()
        return
    end
    if self.buffConfig and self.buffConfig.barMode == "power" then
        local pType  = self.buffConfig.powerType
        local pToken = self.buffConfig.powerToken
        local maxVal = self.buffConfig.ticks or UnitPowerMax("player", pType) or 1
        local current = UnitPower("player", pType)
        local c = (self.buffConfig and self.buffConfig.color) or (Colors and Colors.Power and Colors.Power[pToken]) or PowerBarColor[pToken] or PowerBarColor[pType] or { r = 1, g = 1, b = 1 }
        self:SetMinMaxValues(0, maxVal)
        self:SetStatusBarColor(c.r, c.g, c.b)
        if self.countStack then self.countStack:SetText(current) end
        if self.countDuration then self.countDuration:SetText("") end
        self:SetValue(current, Enum.StatusBarInterpolation.ExponentialEaseOut)
        if self.buffConfig.isTickPower then
            self:UpdateStackTicks(maxVal)
        else
            if self.ticks then for _, t in ipairs(self.ticks) do t:Hide() end end
        end
        self:Show()
        return
    end

    local width, height2 = get_bar2_size()
    self:SetSize(width, height2)
    if self.runebars then for _, rb in ipairs(self.runebars) do rb:Hide() end end
    if self.countStack then self.countStack:Show() end
    if self.countDuration then self.countDuration:Show() end

    local maxValue = 100
    if self.buffConfig then
        if self.buffConfig.barMode == "duration" then
            maxValue = self.buffConfig.duration or 20
            if self.ticks then for _, tick in ipairs(self.ticks) do tick:Hide() end end
        elseif self.buffConfig.barMode == "stack" then
            maxValue = self.buffConfig.maxStack or 100
            self:UpdateStackTicks(maxValue)
        end
    end

    self:SetMinMaxValues(0, maxValue)
    local c = (self.buffConfig and self.buffConfig.color) or RB.cachedSpecColor
    self:SetStatusBarColor(c.r, c.g, c.b)

    if not self.viewerItem or not self.viewerItem.auraInstanceID or not self.viewerItem.auraDataUnit then
        if self.countStack then self.countStack:SetText("") end
        if self.countDuration then self.countDuration:SetText("0") end
        self:SetValue(0, Enum.StatusBarInterpolation.ExponentialEaseOut)
        if durationTicker then 
            durationTicker:Cancel()
            durationTicker = nil 
            self._lastDurationIntVal = nil
        end
        return
    end

    local unit, auraID = self.viewerItem.auraDataUnit, self.viewerItem.auraInstanceID
    local auraData = C_UnitAuras.GetAuraDataByAuraInstanceID(unit, auraID)
    if auraData then
        if self.buffConfig and self.buffConfig.barMode == "duration" then
            local durObj = C_UnitAuras.GetAuraDuration(unit, auraID)
            if durObj then
                self:SetTimerDuration(durObj, Enum.StatusBarInterpolation.ExponentialEaseOut, Enum.StatusBarTimerDirection.RemainingTime)
                local rem = durObj:GetRemainingDuration()
                if issecretvalue(rem) then
                    self.countDuration:SetFormattedText("%.0f", rem)
                    self._lastDurationIntVal = nil
                else
                    local intVal = math.floor(rem)
                    if intVal ~= self._lastDurationIntVal then
                        self.countDuration:SetFormattedText("%.0f", intVal)
                        self._lastDurationIntVal = intVal
                    end
                end
            end
            if self.countStack then self.countStack:SetText("") end
            if not durationTicker then
                durationTicker = C_Timer.NewTicker(get_update_interval(), duration_tick)
            end
        elseif self.buffConfig and self.buffConfig.barMode == "ironfur" then
            if durationTicker then 
                durationTicker:Cancel()
                durationTicker = nil 
                self._lastDurationIntVal = nil
            end
            self:SetMinMaxValues(0, 1)
            update_ironfur_system(self)
        else
            if durationTicker then 
                durationTicker:Cancel()
                durationTicker = nil 
                self._lastDurationIntVal = nil
            end
            local countBar = auraData.applications or 0
            if self.countStack then 
                if issecretvalue(countBar) then
                    self.countStack:SetText(countBar)
                else
                    self.countStack:SetText(countBar > 0 and countBar or "") 
                end
            end
            if self.countDuration then self.countDuration:SetText("") end
            self:SetValue(countBar, Enum.StatusBarInterpolation.ExponentialEaseOut)
        end
        self:Show()
    end
end

-- ==============================
-- Buff Tracker Cooldown Hook Updater
-- ==============================
local ResourceBar2UpdaterMixin = {}
local updater = CreateFrame("Frame")

function ResourceBar2UpdaterMixin:OnLoad()
    self.bar2Frame = RB.bar2Frame
    local hook = function(_, item) self:HookViewerItem(item) end
    hooksecurefunc(BuffBarCooldownViewer, 'OnAcquireItemFrame', hook)
    hooksecurefunc(BuffIconCooldownViewer, 'OnAcquireItemFrame', hook)
end

function ResourceBar2UpdaterMixin:UpdateFromItem(item)
    if not item or not item.cooldownID then return end

    local cdInfo = C_CooldownViewer.GetCooldownViewerCooldownInfo(item.cooldownID)
    if not cdInfo or not cdInfo.spellID then return end

    local spellID = C_Spell.GetBaseSpell(cdInfo.spellID)

    for i, config in ipairs(currentSpecBuffs) do
        if spellID == config.spellID then
            if self.bar2Frame.buffConfig and self.bar2Frame.currentPriority and i > self.bar2Frame.currentPriority then
                local curItem = self.bar2Frame.viewerItem
                if curItem and rawget(curItem, "auraDataUnit") and rawget(curItem, "auraInstanceID") then
                    local curAura = C_UnitAuras.GetAuraDataByAuraInstanceID(curItem.auraDataUnit, curItem.auraInstanceID)
                    if curAura then return end
                end
            end

            local hasAuraData = rawget(item, "auraDataUnit") ~= nil and rawget(item, "auraInstanceID") ~= nil

            if hasAuraData then
                self.bar2Frame:SetViewerItem(item)
                self.bar2Frame:SetBuffConfig(config)
                self.bar2Frame.currentPriority = i
                self.bar2Frame:Update()
            else
                if self.bar2Frame.viewerItem == item then
                    self.bar2Frame:SetViewerItem(nil)
                    self.bar2Frame:SetBuffConfig(nil)
                    self.bar2Frame.currentPriority = nil
                    self.bar2Frame:Update()
                end
            end
            return
        end
    end
end

function ResourceBar2UpdaterMixin:HookViewerItem(item)
    if not item.cdmHooked then
        hooksecurefunc(item, 'RefreshData', function() self:UpdateFromItem(item) end)
        item.cdmHooked = true
    end
    self:UpdateFromItem(item)
end

-- ==============================
-- 이벤트 및 리소스 관리 (자원소모 0 보장)
-- ==============================
local function toggle_bar2_events(enable)
    local bar2Frame = RB.bar2Frame
    if not bar2Frame then return end

    if enable then
        bar2Frame:RegisterEvent("PLAYER_ENTERING_WORLD")
        bar2Frame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
        bar2Frame:RegisterEvent("PLAYER_TALENT_UPDATE")
        bar2Frame:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
        bar2Frame:RegisterEvent("PLAYER_REGEN_DISABLED")
        bar2Frame:RegisterEvent("PLAYER_REGEN_ENABLED")
        
        local _, class = UnitClass("player")
        if class == "DEATHKNIGHT" then
            bar2Frame:RegisterEvent("RUNE_POWER_UPDATE")
        end
    else
        bar2Frame:UnregisterAllEvents()
    end
end

RB.ToggleBuffEvents = toggle_bar2_events

local function cancel_tickers()
    if staggerTicker then staggerTicker:Cancel(); staggerTicker = nil end
    if ironfurTicker then ironfurTicker:Cancel(); ironfurTicker = nil end
    if runeTicker then runeTicker:Cancel(); runeTicker = nil end
    if durationTicker then durationTicker:Cancel(); durationTicker = nil end
end

RB.CancelTickers = cancel_tickers

-- ==============================
-- 스펙 변경 대응 설정 갱신
-- ==============================
local function update_buff_spec(englishClass, spec)
    local baseConfig = {}
    if bar2ClassConfig[englishClass] then
        local c2 = bar2ClassConfig[englishClass]
        if spec and c2[spec] then
            baseConfig = c2[spec]
        elseif c2[1] and c2[1].barMode then
            baseConfig = c2
        end
    end
    
    currentSpecBuffs = {}
    for _, config in ipairs(baseConfig) do
        local ok = true
        if config.requiredSpell and not C_SpellBook.IsSpellKnown(config.requiredSpell) then
            ok = false
        end
        if config.excludedSpell and C_SpellBook.IsSpellKnown(config.excludedSpell) then
            ok = false
        end
        if ok then
            table.insert(currentSpecBuffs, config)
        end
    end

    local bar2 = RB.bar2Frame
    if bar2 then
        bar2:SetViewerItem(nil)
        bar2:SetBuffConfig(nil)
        bar2.currentPriority = nil
        if bar2.countStack then bar2.countStack:SetText("") end
        if bar2.countDuration then bar2.countDuration:SetText("") end
        bar2._lastDurationIntVal = nil
        bar2:SetValue(0)

        cancel_tickers()
        refresh_ironfur_talents()

        local powerModeConfig = nil
        for _, config in ipairs(currentSpecBuffs) do
            if config.barMode == "power" then powerModeConfig = config; break end
        end

        if englishClass == "DEATHKNIGHT" then
            bar2:SetBuffConfig({ barMode = "rune" })
            bar2:RegisterEvent("RUNE_POWER_UPDATE")
            bar2:UnregisterEvent("UNIT_POWER_UPDATE")
        elseif englishClass == "MONK" and spec == 1 then
            local staggerConfig = nil
            for _, config in ipairs(currentSpecBuffs) do
                if config.barMode == "stagger" then staggerConfig = config; break end
            end
            staggerConfig = staggerConfig or { barMode = "stagger", color = { r = 0.0, g = 1.0, b = 0.5 } }
            bar2:SetBuffConfig(staggerConfig)
            bar2:UnregisterEvent("RUNE_POWER_UPDATE")
            bar2:UnregisterEvent("UNIT_POWER_UPDATE")
            bar2:UpdateStaggerSystem()
        elseif powerModeConfig then
            bar2:SetBuffConfig(powerModeConfig)
            bar2:RegisterUnitEvent("UNIT_POWER_UPDATE", "player")
            bar2:UnregisterEvent("RUNE_POWER_UPDATE")
        else
            bar2:UnregisterEvent("RUNE_POWER_UPDATE")
            bar2:UnregisterEvent("UNIT_POWER_UPDATE")
        end
        bar2:Update()
    end
end

RB.UpdateBuffSpec = update_buff_spec

-- ==============================
-- OnLoad 이벤트
-- ==============================
local function on_load_buff()
    if not RB.bar2Frame then return end

    Mixin(RB.bar2Frame, ResourceBar2Mixin)
    RB.bar2Frame:SetScript("OnEvent", function(self, event, ...)
        self:OnEvent(event, ...)
        if event == "RUNE_POWER_UPDATE" and self.UpdateRuneSystem then
            self:UpdateRuneSystem()
        end
    end)

    Mixin(updater, ResourceBar2UpdaterMixin)
    updater:OnLoad()
    
    local _, englishClass = UnitClass("player")
    update_buff_spec(englishClass, C_SpecializationInfo.GetSpecialization())
end

RB.OnLoadBuff = on_load_buff
