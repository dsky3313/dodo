-- ==============================
-- 테이블
-- ==============================
---@diagnostic disable: lowercase-global, param-type-mismatch, redundant-parameter, undefined-field, undefined-global
local addonName, dodo = ...

local CreateFrame = CreateFrame
local SetCVar = SetCVar
local NAMEPLATE_CLASS_COLOR = "nameplateUseClassColorForFriendlyPlayerUnitNames"
local NAMEPLATE_ONLY_NAME = "nameplateShowOnlyNameForFriendlyPlayerUnits"

-- ==============================
-- 동작
-- ==============================
local function nameplateFriendly()
    if not dodo.DB then return end
    local isEnabled = (dodo.DB.useNameplateFriendly ~= false)

    if isEnabled then
        SetCVar(NAMEPLATE_CLASS_COLOR, 1)
        SetCVar(NAMEPLATE_ONLY_NAME, 1)
    else
        SetCVar(NAMEPLATE_CLASS_COLOR, 0)
        SetCVar(NAMEPLATE_ONLY_NAME, 0)
    end
end

-- ==============================
-- 모듈 & 이벤트
-- ==============================
local module = {}
dodo:RegisterModule("CVar", module)

function module:OnEnable()
    nameplateFriendly()
end

-- ==============================
-- 설정
-- ==============================
function module:CreateOptions()
    if not dodo.mainCategory then return end
    if self.optionsCreated then return end

    local Settings = Settings
    local SettingsPanel = SettingsPanel

    local mainCategory = dodo.mainCategory
    local layoutMain = SettingsPanel:GetLayout(mainCategory)

    layoutMain:AddInitializer(CreateSettingsListSectionHeaderInitializer("이름표"))
    dodo.UI.Checkbox(mainCategory, "useNameplateFriendly", "아군 이름표 자동 설정", "아군 이름표에 클래스 색상을 적용하고 이름만 표시합니다.", false, nameplateFriendly)

    self.optionsCreated = true
end

if SettingsPanel then
    SettingsPanel:HookScript("OnShow", function()
        module:CreateOptions()
    end)
end

-- encounterWarningsEnabled 1
-- damageMeterEnabled 1
-- damageMeterResetOnNewInstance 1

-- /console cameraDistanceMaxZoomFactor 2.6
-- /console cameraIndirectVisibility 1
-- /console cameraIndirectOffset 10
