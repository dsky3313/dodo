------------------------------
-- 테이블 및 설정
------------------------------
local addonName, dodo = ...;
dodoDB = dodoDB or {}

local barConfigs = {
    { name = "ResourceBar1", width = 276, height = 12, y = -10, level = 3000, template = "ResourceBar1Template" },
    { name = "ResourceBar2", width = 270, height = 10, y = -5, level = 2999, template = "ResourceBar2Template" }
}

local ClassConfig = {
    ["WARRIOR"] = {
        [1] = { spellName = "투신", barMode = "Cooldown", duration = 20 },
        [2] = { spellName = "소용돌이", barMode = "Stack", maxStack = 4 },
        [3] = { spellName = "고통 감내", barMode = "Stack", maxStack = 100 },
    },
}

local ResourceBar2Mixin = {}

function ResourceBar2Mixin:SetViewerItem(viewerItem)
    self.viewerItem = viewerItem
end

function ResourceBar2Mixin:Update()
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

        local count = C_UnitAuras.GetAuraApplicationDisplayCount(unit, auraInstanceID)
        self.Stacks:SetText(count)

        self:Show()
    end
end

---@diagnostic disable: redundant-parameter

------------------------------
-- 디스플레이 (XML 템플릿 적용)
------------------------------
local bar1Frame = CreateFrame("StatusBar", "ResourceBar1", UIParent, barConfigs[1].template)
bar1Frame:SetSize(barConfigs[1].width, barConfigs[1].height)
bar1Frame:SetPoint("CENTER", UIParent, "CENTER", 0, barConfigs[1].y)
bar1Frame:SetFrameLevel(barConfigs[1].level)

local bar2Frame = CreateFrame("StatusBar", "ResourceBar2", UIParent, barConfigs[2].template)
Mixin(bar2Frame, ResourceBar2Mixin) 
bar2Frame:SetSize(barConfigs[2].width, barConfigs[2].height)
bar2Frame:SetPoint("TOP", bar1Frame, "BOTTOM", 0, barConfigs[2].y)
bar2Frame:SetFrameLevel(barConfigs[2].level)

Mixin(bar2Frame, ResourceBar2Mixin)

------------------------------
-- 동작 함수
------------------------------
local function UpdateBar1()
    if not bar1Frame then return end

    local powerType, powerToken = UnitPowerType("player")
    local current = UnitPower("player", powerType)
    local max = UnitPowerMax("player", powerType)

    if max and max > 0 then
        bar1Frame:SetMinMaxValues(0, max)
        bar1Frame:SetValue(current, Enum.StatusBarInterpolation.ExponentialEaseOut) -- 부드러운 애니메이션
        if bar1Frame.Stacks then bar1Frame.Stacks:SetText(tostring(current)) end
    end

    local color = PowerBarColor[powerToken] or PowerBarColor[powerType] or {r=1, g=1, b=1} -- 자원 색상
    bar1Frame:SetStatusBarColor(color.r, color.g, color.b)
end
C_Timer.NewTicker(0.1, UpdateBar1)



local ResourceBar2UpdaterMixin = {}

function ResourceBar2UpdaterMixin:OnLoad()
    self.bar2Frame = _G["ResourceBar2"]
    
    local hook = function(_, item) self:HookViewerItem(item) end
    hooksecurefunc(BuffBarCooldownViewer, 'OnAcquireItemFrame', hook)
    hooksecurefunc(BuffIconCooldownViewer, 'OnAcquireItemFrame', hook)
    
    for _, viewer in ipairs({BuffBarCooldownViewer, BuffIconCooldownViewer}) do
        for _, itemFrame in ipairs(viewer:GetItemFrames()) do
            if itemFrame.cooldownID then self:HookViewerItem(itemFrame) end
        end
    end
end

function ResourceBar2UpdaterMixin:UpdateFromItem(item)
    local _, englishClass = UnitClass("player")
    local spec = C_SpecializationInfo.GetSpecialization()
    local config = ClassConfig[englishClass] and ClassConfig[englishClass][spec]
    if not config or not config.spellName then return end

    if not item or not item.cooldownID then return end
    local cdInfo = C_CooldownViewer.GetCooldownViewerCooldownInfo(item.cooldownID)
    if not cdInfo or not cdInfo.spellID then return end

    if C_Spell.GetSpellName(cdInfo.spellID) == config.spellName then
        if self.bar2Frame and self.bar2Frame.SetViewerItem then
            self.bar2Frame:SetViewerItem(item)
            self.bar2Frame:Update()
        end
    end
end

function ResourceBar2UpdaterMixin:HookViewerItem(item)
    if not item.__CDMBAHooked then
        hooksecurefunc(item, 'RefreshData', function() self:UpdateFromItem(item) end)
        item.__CDMBAHooked = true
    end
    self:UpdateFromItem(item)
end

-- 최종 실행
if ResourceBar2Updater then
    Mixin(ResourceBar2Updater, ResourceBar2UpdaterMixin)
    ResourceBar2Updater:OnLoad()
end