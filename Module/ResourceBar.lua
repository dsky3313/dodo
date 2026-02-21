-- ==============================
-- 테이블
-- ==============================
------------ 룬 업데이트 관련 코드 최적화할 것
---@diagnostic disable: lowercase-global, undefined-field
---@diagnostic disable: redundant-parameter, param-type-mismatch
local addonName, dodo = ...
dodoDB = dodoDB or {}

local barConfigs = {
    { name = "ResourceBar1", width = 276, height = 10, y = -220, level = 3000, template = "ResourceBar1Template" },
    { name = "ResourceBar2", width = 276, height = 7, y = -4, level = 3001, template = "ResourceBar2Template" }
}

local ClassConfig = {
    ["DEATHKNIGHT"] = {
        [1] = { { barMode = "rune" } },
        [2] = { { barMode = "rune" } },
        [3] = { { barMode = "rune" } },
    },
    ["DEMONHUNTER"] = {
        [2] = { { spellName = "영혼 파편", barMode = "stack", maxStack = 6 } }
    },
    ["DRUID"] = {
        [3] = { { spellName = "무쇠가죽", barMode = "duration", duration = 7 } }
    },
    ["SHAMAN"] = {
        [3] = { { spellName = "응축되는 물", barMode = "stack", maxStack = 2 } }
    },
    ["WARRIOR"] = {
        [1] = { { spellName = "투신", barMode = "duration", duration = 20 } },
        [2] = { { spellName = "소용돌이 연마", barMode = "stack", maxStack = 4 } },
        [3] = { { spellName = "고통 감내", barMode = "stack", maxStack = 100 } },
    },
}

local SpecColors = {
    ["DEATHKNIGHT"] = { [1] = { r = 1, g = 0, b = 0 }, [2] = { r = 0, g = 0.8, b = 1 }, [3] = { r = 0.3, g = 0.9, b = 0.3 } },
    ["DEMONHUNTER"] = { [2] = { r = 0.86, g = 0.59, b = 0.98 } },
    ["DRUID"] = { [3] = { r = 1, g = 0.49, b = 0.04 } },
    ["SHAMAN"] = { [3] = { r = 0, g = 0.82, b = 1 } },
    ["WARRIOR"] = { [1] = { r = 1, g = 0.588, b = 0.196 }, [2] = { r = 0, g = 0.82, b = 1 }, [3] = { r = 1, g = 0.588, b = 0.196 } },
}

-- ✅ 캐시: 이전 값 저장
local cache = {
    powerType = nil,
    powerValue = nil,
    inCombat = false,
    updateTicker = nil,
}

local currentSpecBuffs = {}
local cachedPowerType = nil
local runeIndexes = { 1, 2, 3, 4, 5, 6 }

local curve = C_CurveUtil.CreateCurve()
curve:SetType(Enum.LuaCurveType.Linear); curve:AddPoint(0, 0); curve:AddPoint(1, 100)

-- 특성확인
local function UpdateCurrentSpecConfig()
    local _, englishClass = UnitClass("player")
    local spec = C_SpecializationInfo.GetSpecialization()
    currentSpecBuffs = (ClassConfig[englishClass] and ClassConfig[englishClass][spec]) or {}

    local bar2 = _G["ResourceBar2"]
    if bar2 then
        if englishClass == "DEATHKNIGHT" then
            bar2:SetBuffConfig({ barMode = "rune" })
        else
            bar2:SetBuffConfig(nil); bar2:SetViewerItem(nil)
        end
    end
end

-- ==============================
-- ResourceBar2 Mixin
-- ==============================
local ResourceBar2Mixin = {}

function ResourceBar2Mixin:SetViewerItem(viewerItem) self.viewerItem = viewerItem end
function ResourceBar2Mixin:SetBuffConfig(buffConfig) self.buffConfig = buffConfig end

function ResourceBar2Mixin:GetSpecColor()
    local _, englishClass = UnitClass("player")
    local spec = C_SpecializationInfo.GetSpecialization()
    return (SpecColors[englishClass] and SpecColors[englishClass][spec]) or { r = 1, g = 1, b = 1 }
end

function ResourceBar2Mixin:UpdateRuneSystem()
    if not self.runebars then
        self.runebars = {}
        local spacing = 2
        local runeWidth = (self:GetWidth() - (spacing * 5)) / 6
        for i = 1, 6 do
            local rb = CreateFrame("StatusBar", nil, self, "ResourceBar2Template")
            rb:SetSize(runeWidth, self:GetHeight())
            rb:SetPoint("LEFT", self, "LEFT", (i - 1) * (runeWidth + spacing), 0)
            self.runebars[i] = rb
        end
    end

    if self.countStack then self.countStack:Hide() end
    self:SetStatusBarColor(0, 0, 0, 0)

    table.sort(runeIndexes, function(a, b)
        local aS, _, aR = GetRuneCooldown(a); local bS, _, bR = GetRuneCooldown(b)
        if aR ~= bR then return aR end
        return (aS or 0) < (bS or 0)
    end)

    local c = self:GetSpecColor()
    for i, index in ipairs(runeIndexes) do
        local start, duration, ready = GetRuneCooldown(index)
        local rb = self.runebars[i]
        rb:Show()
        if ready then
            rb:SetStatusBarColor(c.r, c.g, c.b)
            rb:SetMinMaxValues(0, 1); rb:SetValue(1)
            rb:SetScript("OnUpdate", nil)
        else
            rb:SetStatusBarColor(1, 1, 1)
            rb:SetMinMaxValues(0, duration)
            rb:SetScript("OnUpdate", function(f)
                local elapsed = GetTime() - start
                f:SetValue(math.min(elapsed, duration))
            end)
        end
    end
end

function ResourceBar2Mixin:Update()
    if self.buffConfig and self.buffConfig.barMode == "rune" then
        self:UpdateRuneSystem(); self:Show(); return
    end

    if self.runebars then for _, rb in ipairs(self.runebars) do rb:Hide() end end
    if self.countStack then self.countStack:Show() end

    local maxValue = 100
    if self.buffConfig then
        if self.buffConfig.barMode == "duration" then maxValue = self.buffConfig.duration or 20
        elseif self.buffConfig.barMode == "stack" then maxValue = self.buffConfig.maxStack or 100 end
    end
    self:SetMinMaxValues(0, maxValue)

    local c = self:GetSpecColor()
    self:SetStatusBarColor(c.r, c.g, c.b)

    if not self.viewerItem or not self.viewerItem.auraInstanceID then
        if self.countStack then self.countStack:SetText("0") end
        self:SetValue(0, Enum.StatusBarInterpolation.ExponentialEaseOut)
        if self._hasDurationUpdate then self:SetScript("OnUpdate", nil); self._hasDurationUpdate = false end
        return
    end

    local unit, auraID = self.viewerItem.auraDataUnit, self.viewerItem.auraInstanceID
    local auraData = C_UnitAuras.GetAuraDataByAuraInstanceID(unit, auraID)

    if auraData then
        if self.buffConfig and self.buffConfig.barMode == "duration" then
            if not self._hasDurationUpdate then
                self:SetScript("OnUpdate", function(f)
                    local durObj = C_UnitAuras.GetAuraDuration(unit, auraID)
                    if durObj then
                        local rem = durObj:GetRemainingDuration()
                        f:SetValue(rem, Enum.StatusBarInterpolation.ExponentialEaseOut)
                        if f.countStack then f.countStack:SetFormattedText("%d", rem) end
                    end
                end)
                self._hasDurationUpdate = true
            end
        else
            if self._hasDurationUpdate then self:SetScript("OnUpdate", nil); self._hasDurationUpdate = false end
            local countBar = auraData.applications or 0
            if self.countStack then self.countStack:SetText(countBar) end
            self:SetValue(countBar, Enum.StatusBarInterpolation.ExponentialEaseOut)
        end
        self:Show()
    end
end

-- ==============================
-- ResourceBar1 & 캐시 로직 (최적화)
-- ==============================
local bar1Frame = CreateFrame("StatusBar", "ResourceBar1", UIParent, barConfigs[1].template)
bar1Frame:SetSize(barConfigs[1].width, barConfigs[1].height)
bar1Frame:SetPoint("CENTER", UIParent, "CENTER", 0, barConfigs[1].y)

-- ✅ 1단계: UpdateBar1 함수 정의 (먼저 정의해야 함!)
local function UpdateBar1()
    if not bar1Frame then return end
    local pType, pToken = UnitPowerType("player")

    -- 색상 변경만 감지
    if pType ~= cachedPowerType then
        cachedPowerType = pType
        local c = PowerBarColor[pToken] or PowerBarColor[pType] or { r = 1, g = 1, b = 1 }
        bar1Frame:SetStatusBarColor(c.r, c.g, c.b)
    end

    local current = UnitPower("player", pType)
    local max = UnitPowerMax("player", pType)

    if max and max > 0 then
        bar1Frame:SetMinMaxValues(0, max)
        bar1Frame:SetValue(current, Enum.StatusBarInterpolation.ExponentialEaseOut)
        if bar1Frame.countPower then
            if pType == 0 then 
                bar1Frame.countPower:SetFormattedText("%d%%", UnitPowerPercent("player", 0, false, curve))
            else 
                bar1Frame.countPower:SetText(current) 
            end
        end
    end
    
    if _G["ResourceBar2"] and _G["ResourceBar2"].Update then 
        _G["ResourceBar2"]:Update() 
    end
end

-- ✅ 2단계: UpdateTicker 변수 선언
local updateTicker = nil

-- ✅ 3단계: OnCombatChange 함수 정의 (UpdateBar1을 호출)
local function OnCombatChange(inCombat)
    if updateTicker then
        updateTicker:Cancel()
    end
    
    -- 전투중: 0.1초, 비전투: 0.5초
    local interval = inCombat and 0.1 or 0.5
    updateTicker = C_Timer.NewTicker(interval, function()
        UpdateBar1()
    end)
end

-- ✅ 4단계: 전투 이벤트 등록
local combatFrame = CreateFrame("Frame")
combatFrame:RegisterEvent("PLAYER_REGEN_DISABLED")  -- 전투 시작
combatFrame:RegisterEvent("PLAYER_REGEN_ENABLED")   -- 전투 종료
combatFrame:SetScript("OnEvent", function(self, event)
    OnCombatChange(event == "PLAYER_REGEN_DISABLED")
end)

-- ✅ 5단계: 초기 틱 시작 (비전투 0.5초)
OnCombatChange(false)

-- ==============================
-- ResourceBar2Updater
-- ==============================
local ResourceBar2UpdaterMixin = {}
function ResourceBar2UpdaterMixin:OnLoad()
    self.bar2Frame = _G["ResourceBar2"]
    local f = CreateFrame("Frame")
    f:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
    f:SetScript("OnEvent", function() UpdateCurrentSpecConfig() end)
    
    local hook = function(_, item) self:HookViewerItem(item) end
    hooksecurefunc(BuffBarCooldownViewer, 'OnAcquireItemFrame', hook)
    hooksecurefunc(BuffIconCooldownViewer, 'OnAcquireItemFrame', hook)
    UpdateCurrentSpecConfig()
end

function ResourceBar2UpdaterMixin:UpdateFromItem(item)
    if not item or not item.cooldownID then return end
    local cdInfo = C_CooldownViewer.GetCooldownViewerCooldownInfo(item.cooldownID)
    if not cdInfo or not cdInfo.spellID then return end
    local sName = C_Spell.GetSpellName(cdInfo.spellID)

    for _, config in ipairs(currentSpecBuffs) do
        if sName == config.spellName then
            self.bar2Frame:SetViewerItem(item)
            self.bar2Frame:SetBuffConfig(config)
            self.bar2Frame:Update()
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
-- 설정 관련
-- ==============================
function dodo.ResourceBarToggle(barNum, enabled)
    local frame = (barNum == 1) and bar1Frame or _G["ResourceBar2"]
    if frame then
        if enabled then frame:Show() else frame:Hide() end
    end
end

-- ==============================
-- 실행 및 이벤트
-- ==============================
local bar2Frame = CreateFrame("StatusBar", "ResourceBar2", UIParent, barConfigs[2].template)
Mixin(bar2Frame, ResourceBar2Mixin)
bar2Frame:SetSize(barConfigs[2].width, barConfigs[2].height)
bar2Frame:SetPoint("TOP", bar1Frame, "BOTTOM", 0, barConfigs[2].y)

local updater = CreateFrame("Frame"); Mixin(updater, ResourceBar2UpdaterMixin)
local init = CreateFrame("Frame"); init:RegisterEvent("PLAYER_LOGIN")
init:SetScript("OnEvent", function(self)
    updater:OnLoad()
    if dodoDB.useResourceBar1 ~= false then bar1Frame:Show() else bar1Frame:Hide() end
    if dodoDB.useResourceBar2 ~= false then bar2Frame:Show() else bar2Frame:Hide() end
    self:UnregisterEvent("PLAYER_LOGIN")
end)