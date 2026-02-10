-- ==============================
-- 테이블
-- ==============================
local addonName, dodo = ...
dodoDB = dodoDB or {}
local L = LibStub("AceLocale-3.0"):GetLocale(addonName)

local barConfigs = {
    { name = "ResourceBar1", width = 276, height = 10, y = -220, level = 3000, template = "ResourceBar1Template" },
    { name = "ResourceBar2", width = 270, height = 8, y = -5, level = 2999, template = "ResourceBar2Template" }
}

local ClassConfig = {
    ["SHAMAN"] = {
        [3] = {
            { spellName = L["응축되는 물"], barMode = "stack", maxStack = 2, color = { r = 0, g = 0.82, b = 1 } },
        }
    },
    ["WARRIOR"] = {
        [1] = {
            { spellName = L["투신"], barMode = "duration", duration = 20, color = { r = 1.0, g = 0.588, b = 0.196 } },
        },
        [2] = {
            { spellName = L["소용돌이 연마"], barMode = "stack", maxStack = 4, color = { r = 0, g = 0.82, b = 1 } },
        },
        [3] = {
            { spellName = L["고통 감내"], barMode = "stack", maxStack = 100, color = { r = 1, g = 0.588, b = 0.196 } },
        },
    },
}

local currentSpecBuffs = {}
local cachedPowerType = nil

local curve = C_CurveUtil.CreateCurve()
curve:SetType(Enum.LuaCurveType.Linear)
curve:AddPoint(0, 0)
curve:AddPoint(1, 100)

local function UpdateCurrentSpecConfig()
    local _, englishClass = UnitClass("player")
    local spec = C_SpecializationInfo.GetSpecialization()
    currentSpecBuffs = (ClassConfig[englishClass] and ClassConfig[englishClass][spec]) or {}
end

---@diagnostic disable: param-type-mismatch
---@diagnostic disable: redundant-parameter

-- ==============================
-- 디스플레이
-- ==============================
local bar1Frame = CreateFrame("StatusBar", "ResourceBar1", UIParent, barConfigs[1].template)
bar1Frame:SetSize(barConfigs[1].width, barConfigs[1].height)
bar1Frame:SetPoint("CENTER", UIParent, "CENTER", 0, barConfigs[1].y)
bar1Frame:SetFrameLevel(barConfigs[1].level)

local bar2Frame = CreateFrame("StatusBar", "ResourceBar2", UIParent, barConfigs[2].template)
bar2Frame:SetSize(barConfigs[2].width, barConfigs[2].height)
bar2Frame:SetPoint("TOP", bar1Frame, "BOTTOM", 0, barConfigs[2].y)
bar2Frame:SetFrameLevel(barConfigs[2].level)

-- ==============================
-- ResourceBar1
-- ==============================
local ResourceBar1Mixin = {}

function ResourceBar1Mixin:Update()
    if not bar1Frame then return end

    local powerType, powerToken = UnitPowerType("player")

    -- powerType 색상 업데이트
    if powerType ~= cachedPowerType then
        cachedPowerType = powerType
        local color = PowerBarColor[powerToken] or PowerBarColor[powerType] or {r=1, g=1, b=1}
        self:SetStatusBarColor(color.r, color.g, color.b)
    end

    local current = UnitPower("player", powerType)
    local max = UnitPowerMax("player", powerType)

    if max and max > 0 then
        self:SetMinMaxValues(0, max)
        self:SetValue(current, Enum.StatusBarInterpolation.ExponentialEaseOut)

        if self.countPower then
            if powerType == 0 then
                local percentage = UnitPowerPercent("player", powerType, false, curve)
                self.countPower:SetFormattedText("%d", percentage)
            else
                self.countPower:SetText(current)
            end
        end
    end
end

Mixin(bar1Frame, ResourceBar1Mixin)
C_Timer.NewTicker(0.1, function() bar1Frame:Update() end)

-- ==============================
-- ResourceBar2
-- ==============================
local ResourceBar2Mixin = {}

function ResourceBar2Mixin:SetViewerItem(viewerItem)
    self.viewerItem = viewerItem
end

function ResourceBar2Mixin:SetBuffConfig(buffConfig)
    self.buffConfig = buffConfig
end

function ResourceBar2Mixin:Update()
    local maxValue = 100
    if self.buffConfig then
        if self.buffConfig.barMode == "duration" then
            maxValue = self.buffConfig.duration or 20
        elseif self.buffConfig.barMode == "stack" then
            maxValue = self.buffConfig.maxStack or 100
        end
    end
    self:SetMinMaxValues(0, maxValue)

    local color = self.buffConfig and self.buffConfig.color or { r = 1.0, g = 0.588, b = 0.196 }
    self:SetStatusBarColor(color.r, color.g, color.b)

    if not self.viewerItem or not self.viewerItem.auraInstanceID then
        if self.countStack then self.countStack:SetText("0") end
        self:SetValue(0, Enum.StatusBarInterpolation.ExponentialEaseOut)

        if self._hasDurationUpdate then
            self:SetScript("OnUpdate", nil)
            self._hasDurationUpdate = false
        end
        return
    end

    local unit = self.viewerItem.auraDataUnit
    local auraInstanceID = self.viewerItem.auraInstanceID

    if unit and auraInstanceID then
        local duration = C_UnitAuras.GetAuraDuration(unit, auraInstanceID)
        if duration then
            self.Cooldown:SetCooldownFromDurationObject(duration, true)
            self.Cooldown:Show()
        else
            self.Cooldown:Hide()
        end

        local auraData = C_UnitAuras.GetAuraDataByAuraInstanceID(unit, auraInstanceID)
        if auraData then
            if self.buffConfig and self.buffConfig.barMode == "duration" then
                if not self._hasDurationUpdate then
                    self:SetScript("OnUpdate", function(self, elapsed)
                        if not self.viewerItem or not self.viewerItem.auraInstanceID then
                            self:SetScript("OnUpdate", nil)
                            self._hasDurationUpdate = false
                            return
                        end

                        local unit = self.viewerItem.auraDataUnit
                        local auraInstanceID = self.viewerItem.auraInstanceID

                        pcall(function()
                            local durObj = C_UnitAuras.GetAuraDuration(unit, auraInstanceID)
                            if durObj then
                                local remaining = durObj:GetRemainingDuration()
                                self:SetValue(remaining, Enum.StatusBarInterpolation.ExponentialEaseOut)

                                if self.countStack then
                                    self.countStack:SetFormattedText("%d", remaining)
                                end
                            end
                        end)
                    end)
                    self._hasDurationUpdate = true
                end
            else
                if self._hasDurationUpdate then
                    self:SetScript("OnUpdate", nil)
                    self._hasDurationUpdate = false
                end

                local countBar = auraData.applications or 0
                self.countStack:SetText(countBar)
                self:SetValue(countBar, Enum.StatusBarInterpolation.ExponentialEaseOut)
            end

            self:Show()
        end
    end
end

Mixin(bar2Frame, ResourceBar2Mixin)

-- ==============================
-- ResourceBar2 CDM 연동
-- ==============================
local ResourceBar2UpdaterMixin = {}

function ResourceBar2UpdaterMixin:OnLoad()
    local eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
    eventFrame:SetScript("OnEvent", function(self, event)
        if event == "PLAYER_SPECIALIZATION_CHANGED" then
            UpdateCurrentSpecConfig()
            bar2Frame:Update()
        end
    end)

    local hook = function(_, item) self:HookViewerItem(item) end
    hooksecurefunc(BuffBarCooldownViewer, 'OnAcquireItemFrame', hook)
    hooksecurefunc(BuffIconCooldownViewer, 'OnAcquireItemFrame', hook)

    for _, viewer in ipairs({BuffBarCooldownViewer, BuffIconCooldownViewer}) do
        for _, itemFrame in ipairs(viewer:GetItemFrames()) do
            if itemFrame.cooldownID then
                self:HookViewerItem(itemFrame)
            end
        end
    end

    UpdateCurrentSpecConfig()
end

function ResourceBar2UpdaterMixin:UpdateFromItem(item)
    if not item or not item.cooldownID then return end

    local cdInfo = C_CooldownViewer.GetCooldownViewerCooldownInfo(item.cooldownID)
    if not cdInfo or not cdInfo.spellID then return end

    local spellName = C_Spell.GetSpellName(cdInfo.spellID)

    for _, buffConfig in ipairs(currentSpecBuffs) do
        if spellName == buffConfig.spellName then
            bar2Frame:SetViewerItem(item)
            bar2Frame:SetBuffConfig(buffConfig)
            bar2Frame:Update()
            return
        end
    end
end

function ResourceBar2UpdaterMixin:HookViewerItem(item)
    if not item.cdmHooked then
        hooksecurefunc(item, 'RefreshData', function()
            self:UpdateFromItem(item)
        end)
        item.cdmHooked = true
    end
    self:UpdateFromItem(item)
end

local updater = CreateFrame("Frame", "ResourceBar2Updater", UIParent)
Mixin(updater, ResourceBar2UpdaterMixin)
updater:OnLoad()