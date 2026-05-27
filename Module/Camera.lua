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
local CreateFrame = CreateFrame
local GetCVar = GetCVar
local SetCVar = SetCVar
local tostring = tostring
local UIParent = UIParent

local CAM_DYNAMIC_PITCH = "test_cameraDynamicPitch"
local CAM_FOV_PAD = "test_cameraDynamicPitchBaseFovPad"
local CAM_FOV_PAD_DOWN = "test_cameraDynamicPitchBaseFovPadDownScale"
local CAM_FOV_PAD_FLYING = "test_cameraDynamicPitchBaseFovPadFlying"
local CAM_KEEP_CENTERED = "CameraKeepCharacterCentered"

-- ==============================
-- 동작
-- ==============================
local function SafeSetCVar(cvar, value)
    local cur = GetCVar(cvar)
    local newVal = tostring(value)
    if cur ~= newVal then
        SetCVar(cvar, newVal)
    end
end

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
-- 이벤트 핸들러 (가비지 프리 정적 참조)
-- ==============================
local function on_event(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == addonName then
        dodoDB = dodoDB or {}
        self:RegisterEvent("PLAYER_LOGIN")
        self:UnregisterEvent("ADDON_LOADED")
    elseif event == "PLAYER_LOGIN" then
        cameraTilt()
        self:UnregisterAllEvents()
        self:SetScript("OnEvent", nil)
    end
end

-- ==============================
-- 초기화 및 등록
-- ==============================
local initCamera = CreateFrame("Frame")
initCamera:RegisterEvent("ADDON_LOADED")
initCamera:SetScript("OnEvent", on_event)

-- 외부 노출 (Option.lua용)
dodo.CameraTilt = cameraTilt

-- ==============================
-- 설정 동적 등록 (Option.lua 연동)
-- ==============================
local SettingsPanel = SettingsPanel
local CreateSettingsListSectionHeaderInitializer = CreateSettingsListSectionHeaderInitializer
local Slider = Slider

dodo.OptionRegistrations = dodo.OptionRegistrations or {}
dodo.OptionRegistrations["general"] = dodo.OptionRegistrations["general"] or {}
table.insert(dodo.OptionRegistrations["general"], function(category)
    local layoutGeneral = SettingsPanel:GetLayout(category)
    if not layoutGeneral then return end

    layoutGeneral:AddInitializer(CreateSettingsListSectionHeaderInitializer("카메라 시점"))
    Slider(category, "cameraBase", "기본 시점", "기본시점 각도를 조절합니다. \n\n|cffaaffaa추천 : 0.55|r", 0.3, 1.0, 0.05, 0.1, "Decimal2", dodo.CameraTilt)
    Slider(category, "cameraDown", "탑다운 뷰", "수직으로 내렸을 때 각도를 조절합니다. \n\n|cffaaffaa추천 : 0.55|r", 0.3, 1.0, 0.05, 0.1, "Decimal2", dodo.CameraTilt)
    Slider(category, "cameraFlying", "하늘비행 탈것 시점", "하늘비행 탈것 탑승 시 각도를 조절합니다. \n\n|cffaaffaa추천 : 0.55|r", 0.3, 1.0, 0.05, 0.1, "Decimal2", dodo.CameraTilt)
end)