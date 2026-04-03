-- ==============================
-- 테이블
-- ==============================
---@diagnostic disable: lowercase-global, undefined-field, undefined-global
local addonName, dodo = ...
dodoDB = dodoDB or {}

local CreateFrame = CreateFrame
local GetCVar = GetCVar
local SetCVar = SetCVar
local CAM_DYNAMIC_PITCH = "test_cameraDynamicPitch"
local CAM_FOV_PAD = "test_cameraDynamicPitchBaseFovPad"
local CAM_FOV_PAD_DOWN = "test_cameraDynamicPitchBaseFovPadDownScale"
local CAM_FOV_PAD_FLYING = "test_cameraDynamicPitchBaseFovPadFlying"
local CAM_KEEP_CENTERED = "CameraKeepCharacterCentered"
local UIParent = UIParent

-- ==============================
-- 동작
-- ==============================
local function cameraTilt()
    if not dodoDB then return end

    local base = dodoDB.cameraBase or 0.65
    local baseDown = dodoDB.cameraDown or 0.65
    local baseFlying = dodoDB.cameraFlying or 0.65

    if GetCVar(CAM_DYNAMIC_PITCH) ~= "1" then
        UIParent:UnregisterEvent("EXPERIMENTAL_CVAR_CONFIRMATION_NEEDED")
        SetCVar(CAM_DYNAMIC_PITCH, 1)
        SetCVar(CAM_KEEP_CENTERED, 0)
    end

    if GetCVar(CAM_DYNAMIC_PITCH) == "1" then
        SetCVar(CAM_FOV_PAD, base)
        SetCVar(CAM_FOV_PAD_DOWN, baseDown)
        SetCVar(CAM_FOV_PAD_FLYING, baseFlying)
    end
end

-- ==============================
-- 이벤트
-- ==============================
local initCamera = CreateFrame("Frame")
initCamera:RegisterEvent("ADDON_LOADED")
initCamera:SetScript("OnEvent", function(self, event, arg1)
    if arg1 == addonName then
        dodoDB = dodoDB or {}
        self:RegisterEvent("PLAYER_LOGIN")
    elseif event == "PLAYER_LOGIN" then
        if cameraTilt then cameraTilt() end
        self:UnregisterAllEvents()
        self:SetScript("OnEvent", nil)
    end
end)

dodo.CameraTilt = cameraTilt
