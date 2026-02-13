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
    ["DEMONHUNTER"] = {
        [2] = {
            { spellName = L["영혼 파편"], barMode = "stack", maxStack = 6, color = { r = 0.86, g = 0.59, b = 0.98 } },
        }
    },
    ["DRUID"] = {
        [3] = {
            { spellName = L["무쇠가죽"], barMode = "duration", duration = 7, color = { r = 1, g = 0.49, b = 0.04 } },
        }
    },
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

---@diagnostic disable: param-type-mismatch
---@diagnostic disable: redundant-parameter

local currentSpecBuffs = {}
local cachedPowerType = nil

-- 공용 함수: 현재 특성의 버프 설정 업데이트
local function UpdateCurrentSpecConfig()
    local _, englishClass = UnitClass("player")
    local spec = C_SpecializationInfo.GetSpecialization()
    currentSpecBuffs = (ClassConfig[englishClass] and ClassConfig[englishClass][spec]) or {}
end

-- 마나 퍼센트 계산용
local curve = C_CurveUtil.CreateCurve()
curve:SetType(Enum.LuaCurveType.Linear)
curve:AddPoint(0, 0)
curve:AddPoint(1, 100)

-- ==============================
-- ResourceBar2 Mixin
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

-- ==============================
-- ResourceBar2UpdaterMixin
-- ==============================
local ResourceBar2UpdaterMixin = {}

function ResourceBar2UpdaterMixin:OnLoad()
    self.bar2Frame = _G["ResourceBar2"]

    -- 특성 변경 이벤트 등록
    local eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
    eventFrame:SetScript("OnEvent", function(self, event)
        if event == "PLAYER_SPECIALIZATION_CHANGED" then
            UpdateCurrentSpecConfig()
            if self.bar2Frame then
                self.bar2Frame:Update()
            end
        end
    end)

    -- CDM 훅
    local hook = function(_, item) self:HookViewerItem(item) end
    hooksecurefunc(BuffBarCooldownViewer, 'OnAcquireItemFrame', hook)
    hooksecurefunc(BuffIconCooldownViewer, 'OnAcquireItemFrame', hook)

    -- CDM 아이템 훅
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
            if self.bar2Frame and self.bar2Frame.SetViewerItem then
                self.bar2Frame:SetViewerItem(item)
                self.bar2Frame:SetBuffConfig(buffConfig)
                self.bar2Frame:Update()
            end
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

-- ==============================
-- 디스플레이
-- ==============================
local bar1Frame = CreateFrame("StatusBar", "ResourceBar1", UIParent, barConfigs[1].template)
bar1Frame:SetSize(barConfigs[1].width, barConfigs[1].height)
bar1Frame:SetPoint("CENTER", UIParent, "CENTER", 0, barConfigs[1].y)
bar1Frame:SetFrameLevel(barConfigs[1].level)

local bar2Frame = CreateFrame("StatusBar", "ResourceBar2", UIParent, barConfigs[2].template)
Mixin(bar2Frame, ResourceBar2Mixin)  -- ✅ Mixin 적용 (ResourceBar2Mixin을 정의한 후에만 가능)
bar2Frame:SetSize(barConfigs[2].width, barConfigs[2].height)
bar2Frame:SetPoint("TOP", bar1Frame, "BOTTOM", 0, barConfigs[2].y)
bar2Frame:SetFrameLevel(barConfigs[2].level)

-- ==============================
-- ResourceBar1
-- ==============================
local function UpdateBar1()
    if not bar1Frame then return end

    local powerType, powerToken = UnitPowerType("player")

    if powerType ~= cachedPowerType then
        cachedPowerType = powerType
        local color = PowerBarColor[powerToken] or PowerBarColor[powerType] or {r=1, g=1, b=1}
        bar1Frame:SetStatusBarColor(color.r, color.g, color.b)
    end

    local current = UnitPower("player", powerType)
    local max = UnitPowerMax("player", powerType)

    if max and max > 0 then
        bar1Frame:SetMinMaxValues(0, max)
        bar1Frame:SetValue(current, Enum.StatusBarInterpolation.ExponentialEaseOut)

        if bar1Frame.countPower then
            if powerType == 0 then
                local percentage = UnitPowerPercent("player", powerType, false, curve)
                bar1Frame.countPower:SetFormattedText("%d", percentage)
            else
                bar1Frame.countPower:SetText(current)
            end
        end
    end

    if bar2Frame and bar2Frame.Update then
        bar2Frame:Update()
    end
end

C_Timer.NewTicker(0.1, UpdateBar1)

-- ==============================
-- 설정 관련
-- ==============================
function dodo.ResourceBar1()
    -- dodoDB값이 nil이면 true, false면 false가 됨 (기본값 true 응용)
    local isEnabled = (dodoDB.useResourceBar1 ~= false)
    
    if bar1Frame then
        if isEnabled then bar1Frame:Show() else bar1Frame:Hide() end
    end
end

function dodo.ResourceBar2()
    local isEnabled = (dodoDB.useResourceBar2 ~= false)
    
    if bar2Frame then
        if isEnabled then bar2Frame:Show() else bar2Frame:Hide() end
    end
end

-- ==============================
-- 이벤트
-- ==============================
local updater = CreateFrame("Frame", "ResourceBar2Updater", UIParent)
Mixin(updater, ResourceBar2UpdaterMixin)

local initResourcebar = CreateFrame("Frame")
initResourcebar:RegisterEvent("PLAYER_LOGIN")
initResourcebar:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_LOGIN" then
        -- 1. 리소스바 업데이트 로직 로드 (기존 코드)
        updater:OnLoad()

        -- 2. [통합 초기화] DB 설정값에 따라 바 표시 여부 결정
        -- 내부에서 (dodoDB.값 ~= false) 로직이 작동하여 기본값을 true로 잡습니다.
        if type(dodo.ResourceBar1) == "function" then
            dodo.ResourceBar1()
        end
        if type(dodo.ResourceBar2) == "function" then
            dodo.ResourceBar2()
        end

        -- 3. 이벤트 해제
        self:UnregisterEvent("PLAYER_LOGIN")
    end
end)