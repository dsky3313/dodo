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

local CAMERA_TILT_ANGLE = 0.55

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
local function safe_set_cvar(cvar, value)
    local cur = GetCVar(cvar)
    local newVal = tostring(value)
    if cur ~= newVal then
        SetCVar(cvar, newVal)
    end
end

local function camera_tilt()
    local is_enabled = (dodoDB and dodoDB.useCameraTilt ~= false)
    if is_enabled then
        local angle = dodoDB.cameraAngle or CAMERA_TILT_ANGLE

        if GetCVar(CAM_DYNAMIC_PITCH) ~= "1" then
            UIParent:UnregisterEvent("EXPERIMENTAL_CVAR_CONFIRMATION_NEEDED")
            safe_set_cvar(CAM_DYNAMIC_PITCH, 1)
            safe_set_cvar(CAM_KEEP_CENTERED, 0)
        end

        if GetCVar(CAM_DYNAMIC_PITCH) == "1" then
            safe_set_cvar(CAM_FOV_PAD, angle)
            safe_set_cvar(CAM_FOV_PAD_DOWN, angle)
            safe_set_cvar(CAM_FOV_PAD_FLYING, angle)
        end
    else
        -- 비활성화 시 기본값 복원 (자원 소모 0화 및 시스템 복구)
        safe_set_cvar(CAM_DYNAMIC_PITCH, 0)
        safe_set_cvar(CAM_KEEP_CENTERED, 1)
        safe_set_cvar(CAM_FOV_PAD, 0)
        safe_set_cvar(CAM_FOV_PAD_DOWN, 0)
        safe_set_cvar(CAM_FOV_PAD_FLYING, 0)
    end
end

-- ==============================
-- 이벤트 핸들러
-- ==============================
local function on_event(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == addonName then
        dodoDB = dodoDB or {}
        self:RegisterEvent("PLAYER_LOGIN")
        self:UnregisterEvent("ADDON_LOADED")
    elseif event == "PLAYER_LOGIN" then
        camera_tilt()
        self:UnregisterAllEvents()
        self:SetScript("OnEvent", nil)
    end
end

-- ==============================
-- 초기화 및 등록
-- ==============================
local init_camera = CreateFrame("Frame")
init_camera:RegisterEvent("ADDON_LOADED")
init_camera:SetScript("OnEvent", on_event)

-- 외부 노출 (호환성 유지)
dodo.CameraTilt = camera_tilt

-- ==============================
-- 설정 등록
-- ==============================
if dodo.RegisterEditModeModuleSetting then
    dodo.RegisterEditModeModuleSetting("일반", {
        {
            name = "카메라 시점 조절",
            get = function() return dodoDB and dodoDB.useCameraTilt ~= false end,
            set = function(checked)
                if dodoDB then dodoDB.useCameraTilt = checked end
                camera_tilt()
            end
        },
        {
            name = "시점 높이 조절",
            type = "slider",
            get = function() return dodoDB.cameraAngle or CAMERA_TILT_ANGLE end,
            set = function(val)
                if dodoDB then dodoDB.cameraAngle = val end
                camera_tilt()
            end,
            minVal = 0.3,
            maxVal = 1.0,
            step = 0.05,
            disabled = function() return dodoDB and dodoDB.useCameraTilt == false end,
        }
    })
end