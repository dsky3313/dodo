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

local bar2ClassConfig = {
    ["DEATHKNIGHT"] = {
        [1] = { { barMode = "rune", color = Colors.Spec.DEATHKNIGHT[1] } },
        [2] = { { barMode = "rune", color = Colors.Spec.DEATHKNIGHT[2] } },
        [3] = { { barMode = "rune", color = Colors.Spec.DEATHKNIGHT[3] } },
    },
    ["DEMONHUNTER"] = {
        [2] = { { barMode = "soulfragments", maxStack  = 5, color = Colors.Spec.DEMONHUNTER[2] } },
    },
    ["DRUID"]       = {
        [3] = { { barMode = "ironfur",       spellID   = 192081, color = Colors.Spec.DRUID[3] } },
    },
    ["EVOKER"]      = {
        [3] = { { barMode = "duration",      spellID = 395296, color = Colors.Spec.WARRIOR[1] } },
    },
    ["MAGE"]        = {
        [1] = { { barMode = "power", powerType = 16, powerToken = "ARCANE_CHARGES", isTickPower = true, ticks = 4, color = Colors.Class.DEMONHUNTER } },
    },
    ["MONK"]        = {
        [1] = { { barMode = "stagger", color = Colors.Spec.MONK[1] } },
    },
    ["ROGUE"]       = {
        { barMode = "power",                 powerType = 4,      powerToken = "COMBO_POINTS",   isTickPower = true, color = Colors.Primary.Gold },
    },
    ["SHAMAN"]      = {
        [3] = { { barMode = "stack",         spellID   = 51564,  maxStack   = 3, color = Colors.Spec.SHAMAN[3] } },
    },
    ["WARRIOR"]     = {
        [1] = { { barMode = "duration",      spellID = 167105, color = Colors.Spec.WARRIOR[1] } },
        [2] = {
            { barMode = "whirlwind",         spellID   = 12950,  maxStack   = 4,            requiredSpell = 12950, color = Colors.Spec.WARRIOR[2] },
            { barMode = "duration",          spellID   = 184361, excludedSpell = 12950, color = Colors.Spec.WARRIOR[2] },
        },
        [3] = { { barMode = "stack",         spellID   = 190456, maxStack   = 100, color = Colors.Spec.WARRIOR[3] } },
    },
}

-- ==============================
-- 캐싱
-- ==============================
local C_CooldownViewer = C_CooldownViewer
local C_SpecializationInfo = C_SpecializationInfo
local C_Spell = C_Spell
local C_SpellBook = C_SpellBook
local hooksecurefunc = hooksecurefunc
local ipairs = ipairs
local math = math
local Mixin = Mixin
local rawget = rawget
local table = table
local UnitClass = UnitClass

-- ==============================
-- 로컬 상태 변수
-- ==============================
local currentSpecBuffs = {}
local activeMode = nil

-- ==============================
-- ResourceBar2 Mixin & 동작 (다형성 위임 프레임워크)
-- ==============================
local ResourceBar2Mixin = {}

function ResourceBar2Mixin:SetViewerItem(viewerItem) self.viewerItem = viewerItem end

function ResourceBar2Mixin:SetBuffConfig(buffConfig)
    local prevModeName = self.buffConfig and self.buffConfig.barMode
    local newModeName = buffConfig and buffConfig.barMode

    self.buffConfig = buffConfig

    if prevModeName ~= newModeName then
        if prevModeName and RB.Modes[prevModeName] then
            RB.Modes[prevModeName]:OnDisable(self)
        end
        activeMode = newModeName and RB.Modes[newModeName] or nil
        if activeMode then
            activeMode:OnEnable(self)
        end
    end
end

function ResourceBar2Mixin:Update()
    if not self:IsShown() then return end
    if activeMode then
        activeMode:Update(self)
    else
        if self.runebars then
            for _, rb in ipairs(self.runebars) do rb:Hide() end
        end
        if self.countStack then self.countStack:SetText("") end
        
        local hasNormalBuffTracker = false
        for _, config in ipairs(currentSpecBuffs) do
            if config.barMode == "duration" or config.barMode == "stack" or config.barMode == "ironfur" or config.barMode == "whirlwind" then
                hasNormalBuffTracker = true
                break
            end
        end
        
        if hasNormalBuffTracker then
            if self.countDuration then self.countDuration:SetText("0") end
        else
            if self.countDuration then self.countDuration:SetText("") end
        end
        self:SetValue(0)
        local tex = self:GetStatusBarTexture()
        if tex then tex:SetAlpha(0) end
    end
end

function ResourceBar2Mixin:OnEvent(event, ...)
    if event == "PLAYER_ENTERING_WORLD" or event == "PLAYER_SPECIALIZATION_CHANGED" or event == "PLAYER_TALENT_UPDATE" then
        RB.UpdateSpecConfig()
    elseif activeMode and activeMode.OnEvent then
        activeMode:OnEvent(self, event, ...)
    end
end

-- 레거시 하위 호환용 인터페이스 보장
function ResourceBar2Mixin:UpdateStaggerSystem()
    if activeMode and activeMode.Update then
        activeMode:Update(self)
    end
end

function ResourceBar2Mixin:UpdateRuneSystem()
    if activeMode and activeMode.Update then
        activeMode:Update(self)
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
            local itemUnit = item.auraDataUnit or rawget(item, "auraDataUnit")
            local itemAura = item.auraInstanceID or rawget(item, "auraInstanceID")
            local hasAuraData = itemUnit ~= nil and itemAura ~= nil

            -- [무적 방어막] 블리자드 UI에서 auraData가 유실되어 들어왔을 때, 런타임 버프 엔진에서 직접 찾아 수동 복구 주입
            if not hasAuraData then
                local unit = (cdInfo.selfAura) and "player" or "target"
                local spellName = C_Spell.GetSpellName(config.spellID)
                if spellName then
                    local aura = C_UnitAuras.GetAuraDataBySpellName(unit, spellName, "HELPFUL")
                    if not aura then
                        aura = C_UnitAuras.GetAuraDataBySpellName(unit, spellName, "HARMFUL")
                    end
                    if not aura and unit == "player" then
                        aura = C_UnitAuras.GetPlayerAuraBySpellID(config.spellID)
                    end
                    
                    if aura then
                        item.auraDataUnit = unit
                        item.auraInstanceID = aura.auraInstanceID
                        hasAuraData = true
                    end
                end
            end

            if self.bar2Frame.buffConfig and self.bar2Frame.currentPriority and i > self.bar2Frame.currentPriority then
                local curItem = self.bar2Frame.viewerItem
                local curItemUnit = curItem and (curItem.auraDataUnit or rawget(curItem, "auraDataUnit"))
                local curItemAura = curItem and (curItem.auraInstanceID or rawget(curItem, "auraInstanceID"))
                if curItem and curItemUnit and curItemAura then
                    local curAura = C_UnitAuras.GetAuraDataByAuraInstanceID(curItemUnit, curItemAura)
                    if curAura then return end
                end
            end

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
        
        -- 현재 활성화된 모드 기동 보장
        if activeMode and activeMode.OnEnable then
            activeMode:OnEnable(bar2Frame)
        end
    else
        bar2Frame:UnregisterAllEvents()
        if activeMode and activeMode.OnDisable then
            activeMode:OnDisable(bar2Frame)
        end
    end
end

RB.ToggleTrackingEvents = toggle_bar2_events

local function cancel_tickers()
    -- 다형성 위임 구조이므로 개별 모듈이 OnDisable 시점에 100% 스스로 타이머를 비움
    if activeMode and activeMode.OnDisable then
        activeMode:OnDisable(RB.bar2Frame)
    end
end

RB.CancelTickers = cancel_tickers

-- ==============================
-- 스펙 변경 대응 설정 갱신
-- ==============================
local function update_tracking_spec(englishClass, spec)
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

        local powerModeConfig = nil
        for _, config in ipairs(currentSpecBuffs) do
            if config.barMode == "power" then powerModeConfig = config; break end
        end

        if englishClass == "DEATHKNIGHT" then
            local runeConfig = nil
            if spec and bar2ClassConfig["DEATHKNIGHT"] and bar2ClassConfig["DEATHKNIGHT"][spec] then
                runeConfig = bar2ClassConfig["DEATHKNIGHT"][spec][1]
            end
            runeConfig = runeConfig or { barMode = "rune", color = { r = 1, g = 0, b = 0 } }
            bar2:SetBuffConfig(runeConfig)
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
            
            local activeConfig = nil
            for _, config in ipairs(currentSpecBuffs) do
                if config.barMode == "soulfragments" or config.barMode == "ironfur" then
                    activeConfig = config
                    break
                end
            end
            if activeConfig then
                bar2:SetBuffConfig(activeConfig)
            end
        end
        
        bar2:Update()
    end
end

RB.UpdateTrackingSpec = update_tracking_spec

-- ==============================
-- OnLoad 이벤트
-- ==============================
local function on_load_tracking()
    if not RB.bar2Frame then return end

    Mixin(RB.bar2Frame, ResourceBar2Mixin)
    RB.bar2Frame:SetScript("OnEvent", function(self, event, ...)
        self:OnEvent(event, ...)
        if event == "RUNE_POWER_UPDATE" and activeMode and activeMode.Update then
            activeMode:Update(self)
        end
    end)

    Mixin(updater, ResourceBar2UpdaterMixin)
    updater:OnLoad()
    
    local _, englishClass = UnitClass("player")
    update_tracking_spec(englishClass, C_SpecializationInfo.GetSpecialization())
end

RB.OnLoadTracking = on_load_tracking
