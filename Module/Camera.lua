-- ==============================
-- Inspired
-- ==============================
-- Camera Tilt Controls (https://www.curseforge.com/wow/addons/camera-tilt-controls)

-- ==============================
-- 설정 및 테이블
-- ==============================
---@diagnostic disable: lowercase-global, param-type-mismatch, redundant-parameter, undefined-field, undefined-global
local addonName, dodo = ...
local module = {}
dodo:RegisterModule("Camera", module)

local cameraTiltAngle = 1.0

local CAM_DYNAMIC_PITCH = "test_cameraDynamicPitch"
local CAM_FOV_PAD = "test_cameraDynamicPitchBaseFovPad"
local CAM_FOV_PAD_DOWN = "test_cameraDynamicPitchBaseFovPadDownScale"
local CAM_FOV_PAD_FLYING = "test_cameraDynamicPitchBaseFovPadFlying"
local CAM_KEEP_CENTERED = "CameraKeepCharacterCentered"

-- ==============================
-- 캐싱
-- ==============================
local C_Timer = C_Timer
local GetCVar = GetCVar
local SetCVar = SetCVar
local tostring = tostring
local UIParent = UIParent

local function SafeSetCVar(cvar, value)
    local cur = GetCVar(cvar)
    local newVal = tostring(value)
    if cur ~= newVal then
        SetCVar(cvar, newVal)
    end
end

-- ==============================
-- 기능 1: 카메라 시점 조절
-- ==============================
local function camera_tilt()
    if not dodo.DB then return end
    
    -- CVar 값 조정 중 경고 팝업이 발생하는 것을 차단하기 위해 임시로 이벤트 해제
    UIParent:UnregisterEvent("EXPERIMENTAL_CVAR_CONFIRMATION_NEEDED")
    
    local isEnabled = (dodo.DB.enableCameraModule ~= false)
    if isEnabled then
        local base = dodo.DB.cameraBase or cameraTiltAngle
        local baseDown = dodo.DB.cameraDown or cameraTiltAngle
        local baseFlying = dodo.DB.cameraFlying or cameraTiltAngle

        SafeSetCVar(CAM_DYNAMIC_PITCH, 1)
        SafeSetCVar(CAM_KEEP_CENTERED, 0)

        if GetCVar(CAM_DYNAMIC_PITCH) == "1" then
            SafeSetCVar(CAM_FOV_PAD, base)
            SafeSetCVar(CAM_FOV_PAD_DOWN, baseDown)
            SafeSetCVar(CAM_FOV_PAD_FLYING, baseFlying)
        end
    else
        SafeSetCVar(CAM_DYNAMIC_PITCH, 0)
    end
    
    -- CVar 조작 완료 후 0.1초 뒤 이벤트를 부드럽게 재등록하여 다른 시스템 영향 방지
    C_Timer.After(0.1, function()
        UIParent:RegisterEvent("EXPERIMENTAL_CVAR_CONFIRMATION_NEEDED")
    end)
end

dodo.Camera_Tilt = camera_tilt

-- ==============================
-- 모듈 On/Off 활성화 상태 제어
-- ==============================
local function update_module_state()
    camera_tilt()
end

dodo.UpdateCameraModuleState = update_module_state

-- ==============================
-- 초기화
-- ==============================
local function initialize()
    -- 1. DB 설정 초기값 세팅
    if dodo.DB then
        if dodo.DB.enableCameraModule == nil then
            dodo.DB.enableCameraModule = true
        end
        if dodo.DB.cameraBase == nil then
            dodo.DB.cameraBase = cameraTiltAngle
        end
        if dodo.DB.cameraDown == nil then
            dodo.DB.cameraDown = cameraTiltAngle
        end
        if dodo.DB.cameraFlying == nil then
            dodo.DB.cameraFlying = cameraTiltAngle
        end
    end
end

-- ==============================
-- 모듈 생명주기
-- ==============================
function module:OnEnable()
    initialize()
    camera_tilt()
    update_module_state()

    -- Editmode 설정창에 동적 설정 등록
    if dodo.RegisterEditModeSetting then
        dodo.RegisterEditModeSetting("인터페이스", {
            {
                name = "카메라 각도 조절",
                get = function() return dodo.DB and dodo.DB.enableCameraModule ~= false end,
                set = function(checked)
                    if dodo.DB then dodo.DB.enableCameraModule = checked end
                    camera_tilt()
                    -- 실시간 비활성화 갱신 처리
                    if dodoEditModePanel and dodoEditModePanel.UpdateDisabledStates then
                        dodoEditModePanel.UpdateDisabledStates()
                    end
                end
            },
            {
                type = "slider",
                get = function() return dodo.DB and dodo.DB.cameraBase or cameraTiltAngle end,
                set = function(val)
                    if dodo.DB then 
                        dodo.DB.cameraBase = val 
                        dodo.DB.cameraDown = val
                        dodo.DB.cameraFlying = val
                    end
                    camera_tilt()
                end,
                minVal = 0.3,
                maxVal = 1.0,
                step = 0.05,
                disabled = function()
                    return dodo.DB and dodo.DB.enableCameraModule == false
                end
            }
        })
    end
end