-- ==============================
-- 테이블
-- ==============================
---@diagnostic disable: lowercase-global, undefined-field, undefined-global
local addonName, dodo = ...
dodoDB = dodoDB or {}

local CreateFrame = CreateFrame
local SetCVar = SetCVar
local NAMEPLATE_CLASS_COLOR = "nameplateUseClassColorForFriendlyPlayerUnitNames"
local NAMEPLATE_ONLY_NAME = "nameplateShowOnlyNameForFriendlyPlayerUnits"












-- ==============================
-- 동작
-- ==============================
local function nameplateFriendly()
    if not dodoDB then return end
    local isEnabled = (dodoDB.useNameplateFriendly ~= false)

    if isEnabled then
        SetCVar(NAMEPLATE_CLASS_COLOR, 1)
        SetCVar(NAMEPLATE_ONLY_NAME, 1)
    else
        SetCVar(NAMEPLATE_CLASS_COLOR, 0)
        SetCVar(NAMEPLATE_ONLY_NAME, 0)
    end
end

-- ==============================
-- 이벤트
-- ==============================
local initNameplate = CreateFrame("Frame")
initNameplate:RegisterEvent("ADDON_LOADED")
initNameplate:SetScript("OnEvent", function(self, event, arg1)
    if arg1 == addonName then
        dodoDB = dodoDB or {}
        self:RegisterEvent("PLAYER_ENTERING_WORLD")
    elseif event == "PLAYER_ENTERING_WORLD" then
        if nameplateFriendly then nameplateFriendly() end
        self:UnregisterAllEvents()
        self:SetScript("OnEvent", nil)
    end
end)

dodo.nameplateFriendly = nameplateFriendly



-- encounterWarningsEnabled 1
-- damageMeterEnabled 1
-- damageMeterResetOnNewInstance 1

-- /console cameraDistanceMaxZoomFactor 2.6
-- /console cameraIndirectVisibility 1
-- /console cameraIndirectOffset 10
