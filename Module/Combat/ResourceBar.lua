-- ==============================
-- Inspired
-- ==============================
-- dodo ResourceBar Module

-- ==============================
-- 설정 및 테이블
-- ==============================
---@diagnostic disable: lowercase-global, param-type-mismatch, redundant-parameter, undefined-field, undefined-global
local addonName, dodo = ...
dodoDB = dodoDB or {}

local Colors = dodo.Colors

local barConfigs = {
    { name = "ResourceBar1", width = 272, height = 10, y = -220, level = 3000, template = "ResourceBar1Template" },
    { name = "ResourceBar2", width = 272, height = 7, y = -4, level = 3001, template = "ResourceBar2Template" }
}

---@class ResourceBarPowerConfig
---@field powerType number 파워 타입 ID (마나=0, 기적=12, 기력=3 등)
---@field powerToken string 파워 토큰 문자열 ("ENERGY", "MANA", "FURY" 등)          
---@field isTickPower boolean|nil 연계점수나 버블처럼 틱 단위로 표시할지 여부       
---@field ticks number|nil 최대 틱 개수 (풍운 기=5, 흑마 영조=5 등)
---@type table<string, ResourceBarPowerConfig|table<number, ResourceBarPowerConfig>>
local bar1ClassConfig = {
    ["DEMONHUNTER"] = { powerType = 17, powerToken = "FURY" }, -- 악사 분노 (전 스펙)
    ["DRUID"] = {
        [1] = { powerType = 8,  powerToken = "LUNAR_POWER" }, -- 조화 달의 힘
        [2] = { powerType = 4,  powerToken = "COMBO_POINTS", isTickPower = true }, -- 야드 연계 점수
    },
    ["EVOKER"]  = { powerType = 19, powerToken = "ESSENCE", isTickPower = true }, -- ticks: UnitPowerMax (6)
    ["HUNTER"]  = { powerType = 2,  powerToken = "FOCUS" }, -- 사냥꾼 집중력 (전 스펙)
    ["MAGE"] = {
        [1] = { powerType = 0, powerToken = "MANA" }, -- 비법 마나
    },
    ["MONK"] = { [3] = { powerType = 12, powerToken = "CHI", isTickPower = true, ticks = 5 }}, -- 풍운 기
    ["PALADIN"] = { powerType = 9, powerToken = "HOLY_POWER", isTickPower = true, ticks = 5 }, -- 성기사 신성한 힘 (전 스펙)
    ["PRIEST"] = {
        [3] = { powerType = 13, powerToken = "INSANITY" }, -- 암흑 광기
    },
    ["ROGUE"]   = { powerType = 3, powerToken = "ENERGY" }, -- 도적 에너지
    ["WARLOCK"] = { powerType = 7, powerToken = "SOUL_SHARDS", isTickPower = true, ticks = 5 }, -- 흑마 영혼 조각
}

---@class ResourceBarColor
---@class ResourceBar2ConfigItem
---@field barMode string 바 작동 모드 ("rune", "soulfragments", "ironfur", "duration", "power", "stagger", "stack")
---@field color ResourceBarColor 바의 색상 테이블 {r, g, b}
---@field spellID number|nil 추적할 주문 ID (무쇠가죽 등)
---@field maxStack number|nil 최대 중첩 제한수
---@field requiredSpell number|nil 이 주문을 배웠을 때만 표시 (필수 특성 제한용)    
---@field excludedSpell number|nil 이 주문을 배우지 않았을 때만 표시 (제외 특성 제한용)
---@field powerType number|nil 파워 타입 ID (비법 비전 충전물 등)
---@field powerToken string|nil 파워 토큰 명칭
---@field isTickPower boolean|nil 버블/틱 형태로 쪼개어 표시할지 여부
---@field ticks number|nil 최대 틱 개수
---@type table<string, table<number, ResourceBar2ConfigItem[]> | ResourceBar2ConfigItem[]>
local bar2ClassConfig = {
    ["DEATHKNIGHT"] = { [1] = {{barMode = "rune", color = { r = 1, g = 0, b = 0 }}},
                        [2] = {{barMode = "rune", color = { r = 0, g = 0.8, b = 1 }}},
    ["DRUID"] = { [3] = {r=0, g=0.82, b=1} },
                        [3] = {{barMode = "rune", color = { r = 0.3, g = 0.9, b = 0.3 }}} },
    ["DEMONHUNTER"] = { [2] = {{barMode = "soulfragments", maxStack = 5, color = { r = 0.8, g = 0.6, b = 1 }}} },
    ["DRUID"] = { [3] = {{spellID = 192081, barMode = "ironfur", color = { r = 0, g = 0.8, b = 1 }}} },
    ["EVOKER"] = { [3] = {{spellID = 395296, barMode = "duration", color = { r = 1, g = 0.5, b = 0.2 }}} },
    ["MAGE"] = { [1] = {{barMode = "power", powerType = 16, powerToken = "ARCANE_CHARGES", isTickPower = true, ticks = 4, color = { r = 0.6, g = 0.2, b = 0.9 }}} }, -- 비전 충전물
    ["MONK"] = { [1] = {{barMode = "stagger", color = { r = 0.0, g = 1.0, b = 0.5 }}} },
    ["ROGUE"] = { {barMode = "power", powerType = 4, powerToken = "COMBO_POINTS", isTickPower = true, color = { r = 1.0, g = 0.8, b = 0.0 }} }, -- 전 스펙
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
local C_SpecializationInfo = C_SpecializationInfo
local C_Spell = C_Spell
local C_SpellBook = C_SpellBook
local C_Timer = C_Timer
local C_UnitAuras = C_UnitAuras
local CreateFrame = CreateFrame
local GetRuneCooldown = GetRuneCooldown
local GetTime = GetTime
local hooksecurefunc = hooksecurefunc
local Mixin = Mixin
local PowerBarColor = PowerBarColor
local RAID_CLASS_COLORS = RAID_CLASS_COLORS
local UnitAffectingCombat = UnitAffectingCombat
local UnitClass = UnitClass
local UnitHealthMax = UnitHealthMax
local UnitPower = UnitPower
local UnitPowerMax = UnitPowerMax
local UnitPowerPercent = UnitPowerPercent
local UnitPowerType = UnitPowerType
local UnitStagger = UnitStagger
local ipairs = ipairs
local math = math
local pairs = pairs
local rawget = rawget
local table = table

local currentSpecBuffs = {}
local cachedPowerType = nil
local cachedSpecColor = { r = 1, g = 1, b = 1 }
local fallbackSpecColor = { r = 1, g = 1, b = 1 } -- static fallback to prevent spikesum garbage
local runeIndexes = { 1, 2, 3, 4, 5, 6 }
local staggerTicker = nil
local ironfurTicker = nil
local runeTicker = nil
local durationTicker = nil
local ironfurExpiries = {}
local ironfurDurations = {}
local goeExpiry = 0
local ironfurBaseDuration = 7
local hasGoeTalent = false

local function GetUpdateInterval()
    return UnitAffectingCombat("player") and 0.1 or 0.5
end

local function RestartDurationTicker()
    if durationTicker then
        durationTicker:Cancel()
        durationTicker = nil
    end
    if bar2Frame and bar2Frame.buffConfig and bar2Frame.buffConfig.barMode == "duration" then
        bar2Frame:Update()
    end
end

local function RestartRuneTicker()
    if runeTicker then
        runeTicker:Cancel()
        runeTicker = nil
    end
    if bar2Frame and bar2Frame.buffConfig and bar2Frame.buffConfig.barMode == "rune" then
        bar2Frame:UpdateRuneSystem()
    end
end

local function RestartIronfurTicker()
    if ironfurTicker then
        ironfurTicker:Cancel()
        ironfurTicker = nil
    end
    if bar2Frame and bar2Frame.buffConfig and bar2Frame.buffConfig.barMode == "ironfur" then
        if bar2Frame.UpdateIronfurSystemActual then
            bar2Frame:UpdateIronfurSystemActual()
        end
    end
end

local function RestartStaggerTicker()
    if staggerTicker then
        staggerTicker:Cancel()
        staggerTicker = nil
    end
    if bar2Frame and bar2Frame.buffConfig and bar2Frame.buffConfig.barMode == "stagger" then
        bar2Frame:UpdateStaggerSystem()
    end
end
local updateTicker = nil
local isArcaneOrHealer = false
local overridePowerConfig = nil

-- ==============================
-- 프레임 및 이벤트
-- ==============================
local bar1Frame
local bar2Frame
local combatFrame = CreateFrame("Frame")
local updater = CreateFrame("Frame")

-- ==============================
-- 기능 1: 유틸 및 헬퍼 함수
-- ==============================
local function GetBar2Size()
    local width = (dodo.DB and dodo.DB.resourceBarWidth) or (barConfigs and barConfigs[1] and barConfigs[1].width) or 272
    local height = (dodo.DB and dodo.DB.resourceBarHeight) or (barConfigs and barConfigs[1] and barConfigs[1].height) or 10
    local height2 = math.max(height - 3, 5)
    return width, height2
end

local UpdateIronfurSystem

local function duration_tick()
    if bar2Frame and bar2Frame.buffConfig and bar2Frame.buffConfig.barMode == "duration" then
        bar2Frame:Update()
    end
end

local function stagger_tick()
    if bar2Frame and bar2Frame.buffConfig and bar2Frame.buffConfig.barMode == "stagger" then
        bar2Frame:UpdateStaggerSystem()
    end
end

local function rune_tick()
    if bar2Frame and bar2Frame.buffConfig and bar2Frame.buffConfig.barMode == "rune" then
        bar2Frame:UpdateRuneSystem()
    end
end

local function RefreshIronfurTalents()
    ironfurBaseDuration = C_SpellBook.IsSpellKnown(393611) and 9 or 7
    hasGoeTalent = C_SpellBook.IsSpellKnown(155578)
end

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

local function CompareRuneOrder(a, b)
    local runeA = runeDataCache[a]
    local runeB = runeDataCache[b]
    if runeA.isReady and not runeB.isReady then
        return true
    elseif not runeA.isReady and runeB.isReady then
        return false
    end
    return runeA.remaining < runeB.remaining
end

local function CollectAndSortRuneData()
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

    table.sort(runeSortOrder, CompareRuneOrder)

    return hasRecharging
end

local function UpdateCurrentSpecConfig()
    local _, englishClass = UnitClass("player")
    local spec = C_SpecializationInfo.GetSpecialization()

    local specID = spec and C_SpecializationInfo.GetSpecializationInfo(spec)
    isArcaneOrHealer = (specID == 62) or (specID == 65) or (specID == 256) or (specID == 257) or (specID == 264) or (specID == 105) or (specID == 270) or (specID == 1468)

    overridePowerConfig = nil
    local classConf = bar1ClassConfig[englishClass]
    if classConf then
        if classConf.powerType then
            overridePowerConfig = classConf
        elseif spec and classConf[spec] then
            overridePowerConfig = classConf[spec]
        end
    end

    cachedSpecColor = (Colors and Colors.Spec and Colors.Spec[englishClass] and Colors.Spec[englishClass][spec]) or fallbackSpecColor

    local baseConfig = {}
    if bar2ClassConfig[englishClass] then
        local c2 = bar2ClassConfig[englishClass]
        if spec and c2[spec] then
            baseConfig = c2[spec]
        elseif c2[1] and c2[1].barMode then
            baseConfig = c2 -- 전 스펙 flat 구조
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

    local bar2 = _G["ResourceBar2"]
    if bar2 then
        bar2:SetViewerItem(nil)
        bar2:SetBuffConfig(nil)
        bar2.currentPriority = i
        if bar2.countStack then bar2.countStack:SetText("") end
        if bar2.countDuration then bar2.countDuration:SetText("") end
        bar2._lastDurationIntVal = nil
        bar2:SetValue(0)

        if staggerTicker then staggerTicker:Cancel(); staggerTicker = nil end
        if ironfurTicker then ironfurTicker:Cancel(); ironfurTicker = nil end
        if runeTicker then runeTicker:Cancel(); runeTicker = nil end
        if durationTicker then durationTicker:Cancel(); durationTicker = nil end
        
        RefreshIronfurTalents()

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

local function UpdateBar1Ticks(maxStack)
    if not bar1Frame then return end
    if not bar1Frame.ticks then bar1Frame.ticks = {} end

    for _, tick in ipairs(bar1Frame.ticks) do tick:Hide() end

    if not maxStack or maxStack <= 1 or maxStack > 10 then
        bar1Frame._lastMaxStack = nil
        return
    end

    if bar1Frame._lastMaxStack == maxStack then
        for i = 1, maxStack - 1 do
            if bar1Frame.ticks[i] then bar1Frame.ticks[i]:Show() end
        end
        return
    end
    bar1Frame._lastMaxStack = maxStack

    local barWidth = bar1Frame:GetWidth()
    local barHeight = bar1Frame:GetHeight()

    for i = 1, maxStack - 1 do
        if not bar1Frame.ticks[i] then
            local tick = bar1Frame:CreateTexture(nil, "OVERLAY")
            tick:SetColorTexture(0, 0, 0, 0.8)
            bar1Frame.ticks[i] = tick
        end

        local tick = bar1Frame.ticks[i]
        tick:ClearAllPoints()
        PixelUtil.SetSize(tick, 1, barHeight)
        local xOffset = (barWidth / maxStack) * i
        PixelUtil.SetPoint(tick, "LEFT", bar1Frame, "LEFT", xOffset, 0)
        tick:Show()
    end
end

local function UpdateBar1()
    if not bar1Frame or not bar1Frame:IsShown() then return end
    local pType, pToken = UnitPowerType("player")

    if overridePowerConfig then
        pType = overridePowerConfig.powerType
        pToken = overridePowerConfig.powerToken
    end

    if pType == 0 and not isArcaneOrHealer then
        bar1Frame:SetValue(0)
        if bar1Frame.countPower then bar1Frame.countPower:SetText("") end
        return
    end

    if pType ~= cachedPowerType then
        cachedPowerType = pType
        local c
        if pToken == "ESSENCE" then
            c = (RAID_CLASS_COLORS and RAID_CLASS_COLORS["EVOKER"]) or { r = 0.20, g = 0.58, b = 0.50 }
        else
            c = (Colors and Colors.Power and Colors.Power[pToken]) or PowerBarColor[pToken] or PowerBarColor[pType] or { r = 1, g = 1, b = 1 }
        end
        bar1Frame:SetStatusBarColor(c.r, c.g, c.b)
    end
    local current = UnitPower("player", pType)
    local max = UnitPowerMax("player", pType)
    if max and max > 0 then
        bar1Frame:SetMinMaxValues(0, max)
        
        local isTickPower = overridePowerConfig and overridePowerConfig.isTickPower
        if isTickPower then
            if pType == 19 then
                local partial = UnitPartialPower("player", 19) or 0
                bar1Frame:SetValue(current + (partial / 1000), Enum.StatusBarInterpolation.ExponentialEaseOut)
            else
                bar1Frame:SetValue(current, Enum.StatusBarInterpolation.ExponentialEaseOut)
            end
            if bar1Frame.countPower then
                bar1Frame.countPower:SetText(current)
            end
            UpdateBar1Ticks(overridePowerConfig.ticks or max)
        else
            bar1Frame:SetValue(current, Enum.StatusBarInterpolation.ExponentialEaseOut)
            if bar1Frame.countPower then
                if pType == 0 then
                    local pct = UnitPowerPercent("player", 0, false, CurveConstants and CurveConstants.ScaleTo100)
                    if pct then
                        bar1Frame.countPower:SetFormattedText("%d", pct)
                    else
                        bar1Frame.countPower:SetText("0")
                    end
                else
                    bar1Frame.countPower:SetText(current)
                end
            end
            UpdateBar1Ticks(nil)
        end
    end
end

local function OnCombatChange(inCombat)
    if updateTicker then updateTicker:Cancel(); updateTicker = nil end
    local isEnabled = (dodo.DB and dodo.DB.enableResourceBarModule ~= false)
    local useBar1 = (dodo.DB and dodo.DB.useResourceBar1 ~= false)
    if isEnabled and useBar1 then
        updateTicker = C_Timer.NewTicker(inCombat and 0.1 or 0.5, UpdateBar1)
    end
end

local function ToggleBar1CombatEvents(enable)
    if enable then
        combatFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
        combatFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
    else
        combatFrame:UnregisterAllEvents()
        if updateTicker then updateTicker:Cancel(); updateTicker = nil end
    end
end

combatFrame:SetScript("OnEvent", function(_, event)
    OnCombatChange(event == "PLAYER_REGEN_DISABLED")
end)

-- ==============================
-- 기능 2: ResourceBar2 Mixin & 동작
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

function UpdateIronfurSystem(f)
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
        ironfurTicker = C_Timer.NewTicker(GetUpdateInterval(), ironfur_tick)
    end
end

function ResourceBar2Mixin:UpdateIronfurSystemActual()
    UpdateIronfurSystem(self)
end

function ResourceBar2Mixin:OnEvent(event, ...)
    if event == "PLAYER_ENTERING_WORLD" or event == "PLAYER_SPECIALIZATION_CHANGED" or event == "PLAYER_TALENT_UPDATE" then
        UpdateCurrentSpecConfig()
        RefreshIronfurTalents()
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
            UpdateIronfurSystem(self)
        elseif spellID == 33917 then -- 짓이기기
            if hasGoeTalent then
                goeExpiry = GetTime() + 15
            end
        end
    end
end

function ResourceBar2Mixin:GetSpecColor()
    return cachedSpecColor
end

-- Removed Bar2DurationOnUpdate in favor of unified 0.1s/0.5s C_Timer ticker

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
    local width, height2 = GetBar2Size()
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

    local hasRecharging = CollectAndSortRuneData()
    local c = (self.buffConfig and self.buffConfig.color) or self:GetSpecColor()
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
            runeTicker = C_Timer.NewTicker(GetUpdateInterval(), rune_tick)
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
            local c = (self.buffConfig and self.buffConfig.color) or self:GetSpecColor()
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
        -- 12.0.0 인스턴스 제한 상황 (비밀 값)
        local sPct = C_PaperDollInfo.GetStaggerPercentage("player")
        
        -- 오라를 통해 색상 결정 (Light/Moderate/Heavy)
        if C_UnitAuras.GetPlayerAuraBySpellID(124273) then -- Heavy
            self:SetStatusBarColor(1, 0, 0)
        elseif C_UnitAuras.GetPlayerAuraBySpellID(124274) then -- Moderate
            self:SetStatusBarColor(1, 0.8, 0)
        else -- Light or None
            local c = (self.buffConfig and self.buffConfig.color) or self:GetSpecColor()
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
            staggerTicker = C_Timer.NewTicker(GetUpdateInterval(), stagger_tick)
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
        local c = (self.buffConfig and self.buffConfig.color) or self:GetSpecColor()
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

    local width, height2 = GetBar2Size()
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
    local c = (self.buffConfig and self.buffConfig.color) or self:GetSpecColor()
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
                durationTicker = C_Timer.NewTicker(GetUpdateInterval(), duration_tick)
            end
        elseif self.buffConfig and self.buffConfig.barMode == "ironfur" then
            if durationTicker then 
                durationTicker:Cancel()
                durationTicker = nil 
                self._lastDurationIntVal = nil
            end
            self:SetMinMaxValues(0, 1)
            UpdateIronfurSystem(self)
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
-- 기능 3: ResourceBar2 Updater
-- ==============================
local ResourceBar2UpdaterMixin = {}

function ResourceBar2UpdaterMixin:OnLoad()
    self.bar2Frame = bar2Frame
    local hook = function(_, item) self:HookViewerItem(item) end
    hooksecurefunc(BuffBarCooldownViewer, 'OnAcquireItemFrame', hook)
    hooksecurefunc(BuffIconCooldownViewer, 'OnAcquireItemFrame', hook)
    UpdateCurrentSpecConfig()
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

local function ToggleBar2Events(enable)
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

function dodoUpdateResourceBarOption()
    if not bar1Frame or not bar2Frame then return end

    local width = (dodo.DB and dodo.DB.resourceBarWidth) or (barConfigs and barConfigs[1] and barConfigs[1].width) or 272
    local height = (dodo.DB and dodo.DB.resourceBarHeight) or (barConfigs and barConfigs[1] and barConfigs[1].height) or 10
    local height2 = math.max(height - 3, 5)

    bar1Frame:SetSize(width, height)
    bar2Frame:SetSize(width, height2)

    local fontSize = (dodo.DB and dodo.DB.resourceBarFontSize) or 12
    if bar1Frame.countPower then
        local font, _, flags = bar1Frame.countPower:GetFont()
        if font then
            bar1Frame.countPower:SetFont(font, fontSize, flags)
        end
    end
    if bar2Frame.countStack then
        local font, _, flags = bar2Frame.countStack:GetFont()
        if font then
            bar2Frame.countStack:SetFont(font, fontSize, flags)
        end
    end
    if bar2Frame.countDuration then
        local font, _, flags = bar2Frame.countDuration:GetFont()
        if font then
            bar2Frame.countDuration:SetFont(font, fontSize, flags)
        end
    end

    if dodo.DB and dodo.DB.resourceBarX and dodo.DB.resourceBarY then
        bar1Frame:ClearAllPoints()
        bar1Frame:SetPoint(dodo.DB.resourceBarPoint or "CENTER", UIParent, dodo.DB.resourceBarPoint or "CENTER", dodo.DB.resourceBarX, dodo.DB.resourceBarY)
    else
        bar1Frame:ClearAllPoints()
        bar1Frame:SetPoint("CENTER", UIParent, "CENTER", 0, -220)
    end

    bar2Frame:ClearAllPoints()
    bar2Frame:SetPoint("TOP", bar1Frame, "BOTTOM", 0, -4)
end

local function UpdateResourceBarVisibility()
    dodoUpdateResourceBarOption()

    local isEnabled = (dodo.DB and dodo.DB.enableResourceBarModule ~= false)
    if not isEnabled then
        bar1Frame:Hide()
        bar2Frame:Hide()
        if staggerTicker then staggerTicker:Cancel(); staggerTicker = nil end
        ToggleBar1CombatEvents(false)
        ToggleBar2Events(false)
        return
    end

    if dodo.DB and dodo.DB.useResourceBar1 ~= false then
        bar1Frame:Show()
        UpdateBar1()
        ToggleBar1CombatEvents(true)
        OnCombatChange(UnitAffectingCombat("player"))
    else
        bar1Frame:Hide()
        ToggleBar1CombatEvents(false)
    end

    if dodo.DB and dodo.DB.useResourceBar2 ~= false then
        bar2Frame:Show()
        ToggleBar2Events(true)
        UpdateCurrentSpecConfig()
    else
        bar2Frame:Hide()
        ToggleBar2Events(false)
        if staggerTicker then staggerTicker:Cancel(); staggerTicker = nil end
        if durationTicker then durationTicker:Cancel(); durationTicker = nil end
    end
end

-- ==============================
-- 모듈 On/Off 활성화 상태 제어
-- ==============================
local function update_module_state()
    UpdateResourceBarVisibility()
end

dodo.UpdateResourceBarModuleState = update_module_state
dodo.UpdateResourceBarVisibility = UpdateResourceBarVisibility

-- ==============================
-- 초기화
-- ==============================
local function create_ui()
    if bar1Frame then return end

    bar1Frame = CreateFrame("StatusBar", "ResourceBar1", UIParent, barConfigs[1].template)
    bar1Frame:SetSize(barConfigs[1].width, barConfigs[1].height)
    bar1Frame:SetPoint("CENTER", UIParent, "CENTER", 0, barConfigs[1].y)

    bar2Frame = CreateFrame("StatusBar", "ResourceBar2", UIParent, barConfigs[2].template)
    Mixin(bar2Frame, ResourceBar2Mixin)
    bar2Frame:SetSize(barConfigs[2].width, barConfigs[2].height)
    bar2Frame:SetPoint("TOP", bar1Frame, "BOTTOM", 0, barConfigs[2].y)

    bar2Frame:SetScript("OnEvent", function(self, event, ...)
        self:OnEvent(event, ...)
        if event == "RUNE_POWER_UPDATE" and self.UpdateRuneSystem then
            self:UpdateRuneSystem()
        end
    end)

    Mixin(updater, ResourceBar2UpdaterMixin)
end

local function initialize()
    create_ui()
end

-- ==============================
-- 이벤트 및 자동 초기화
-- ==============================
local isInitialized = false
local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("ADDON_LOADED")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == addonName then
        dodoDB = dodoDB or {}
        dodo.DB = dodo.DB or dodoDB
    elseif event == "PLAYER_LOGIN" then
        dodo.DB = dodo.DB or dodoDB or {}
        initialize()
        dodoUpdateResourceBarOption()
        UpdateResourceBarVisibility()

        if isInitialized then return end
        isInitialized = true

        updater:OnLoad()

        updater:OnLoad()
    end
end)

-- ==============================
-- 외부 노출 및 설정 동적 등록 (Option.lua 연동)
-- ==============================
local SettingsPanel = SettingsPanel
local CreateSettingsListSectionHeaderInitializer = CreateSettingsListSectionHeaderInitializer
local Checkbox = Checkbox
local Slider = Slider

dodo.OptionRegistrations = dodo.OptionRegistrations or {}
dodo.OptionRegistrations["combat"] = dodo.OptionRegistrations["combat"] or {}
table.insert(dodo.OptionRegistrations["combat"], function(category)
    local layout = SettingsPanel:GetLayout(category)
    if not layout then return end

    layout:AddInitializer(CreateSettingsListSectionHeaderInitializer("자원바 표시"))
    Checkbox(category, "enableResourceBarModule", "자원바 활성화", "개인 자원바 및 버프 추적바 기능을 활성화합니다.", true, dodo.UpdateResourceBarModuleState)
    Checkbox(category, "useResourceBar1", "플레이어 자원바", "플레이어 마나/분노 표시 바를 활성화합니다.", true, dodo.UpdateResourceBarVisibility)
    Checkbox(category, "useResourceBar2", "버프 추적 바", "특성에 따른 버프 추적 바를 활성화합니다.", true, dodo.UpdateResourceBarVisibility)

    layout:AddInitializer(CreateSettingsListSectionHeaderInitializer("자원바 크기 설정"))
    Slider(category, "resourceBarWidth", "바 가로 크기", "자원바와 버프 추적바의 가로 너비를 조절합니다.", 200, 300, 2, 268, "Integer", dodoUpdateResourceBarOption)
    Slider(category, "resourceBarHeight", "바 세로 크기", "자원바의 세로 두께를 조절합니다. (버프바는 자동 비례 조절됩니다.)", 6, 20, 1, 10, "Integer", dodoUpdateResourceBarOption)
    Slider(category, "resourceBarFontSize", "수치 글자 크기", "자원바/버프바의 수치 텍스트 글꼴 크기를 조절합니다.", 8, 18, 1, 12, "Integer", dodoUpdateResourceBarOption)
end)