-- ==============================
-- Inspired
-- ==============================
-- Camera Tilt Controls (https://www.curseforge.com/wow/addons/camera-tilt-controls)

-- ==============================
-- 설정 및 테이블
-- ==============================
---@diagnostic disable: lowercase-global, param-type-mismatch, redundant-parameter, undefined-field, undefined-global
local addonName, dodo = ...
dodoDB = dodoDB or {}

local cameraTiltAngle = 0.55

-- ==============================
-- 캐싱
-- ==============================
local GetCVar = GetCVar
local SetCVar = SetCVar
local tostring = tostring

local function SafeSetCVar(cvar, value)
    local cur = GetCVar(cvar)
    local newVal = tostring(value)
    if cur ~= newVal then
        SetCVar(cvar, newVal)
    end
end

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
    local base = dodoDB.cameraBase or cameraTiltAngle
    local baseDown = dodoDB.cameraDown or cameraTiltAngle
    local baseFlying = dodoDB.cameraFlying or cameraTiltAngle

    if GetCVar(CAM_DYNAMIC_PITCH) ~= "1" then
        UIParent:UnregisterEvent("EXPERIMENTAL_CVAR_CONFIRMATION_NEEDED")
        SafeSetCVar(CAM_DYNAMIC_PITCH, 1)
        SafeSetCVar(CAM_KEEP_CENTERED, 0)
    end

    if GetCVar(CAM_DYNAMIC_PITCH) == "1" then
        SafeSetCVar(CAM_FOV_PAD, base)
        SafeSetCVar(CAM_FOV_PAD_DOWN, baseDown)
        SafeSetCVar(CAM_FOV_PAD_FLYING, baseFlying)
    end
end

-- ==============================
-- 초기화 및 등록
-- ==============================
local initCamera = CreateFrame("Frame")
initCamera:RegisterEvent("ADDON_LOADED")
initCamera:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == addonName then
        dodoDB = dodoDB or {}
        self:RegisterEvent("PLAYER_LOGIN")
        self:UnregisterEvent("ADDON_LOADED")
    elseif event == "PLAYER_LOGIN" then
        cameraTilt()
        self:UnregisterAllEvents()
        self:SetScript("OnEvent", nil)
    end
end)

-- 외부 노출 (Option.lua용)
dodo.CameraTilt = cameraTilt