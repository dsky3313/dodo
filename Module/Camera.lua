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

local CAM_DYNAMIC_PITCH    = "test_cameraDynamicPitch"
local CAM_FOV_PAD          = "test_cameraDynamicPitchBaseFovPad"
local CAM_FOV_PAD_DOWN     = "test_cameraDynamicPitchBaseFovPadDownScale"
local CAM_FOV_PAD_FLYING   = "test_cameraDynamicPitchBaseFovPadFlying"
local CAM_KEEP_CENTERED    = "CameraKeepCharacterCentered"

-- ==============================
-- 캐싱
-- ==============================
local C_Timer = C_Timer
local GetCVar = GetCVar
local SetCVar = SetCVar
local UIParent = UIParent
local tostring = tostring

local function SafeSetCVar(cvar, value)
    local cur = GetCVar(cvar)
    local newVal = tostring(value)
    if cur ~= newVal then
        SetCVar(cvar, newVal)
    end
end

-- ==============================
-- 기능 1: 카메라 시점 조절 (성능 최적화 완료)
-- ==============================
local hasApplied = false
local lastBase, lastDown, lastFlying, lastEnabled

-- CVar 조작 완료 후 이벤트 재등록 (가비지 프리: 정적 함수로 분리)
local function register_cvar_event()
    UIParent:RegisterEvent("EXPERIMENTAL_CVAR_CONFIRMATION_NEEDED")
end

local function camera_tilt()
    if not dodo.DB then return end

    local isEnabled = (dodo.DB.enableCameraModule ~= false)
    local base      = dodo.DB.cameraBase    or cameraTiltAngle
    local baseDown  = dodo.DB.cameraDown    or cameraTiltAngle
    local baseFlying = dodo.DB.cameraFlying or cameraTiltAngle

    -- 상태가 완벽히 이전과 동일하다면 엔진 API 호출 전면 차단
    if hasApplied and lastEnabled == isEnabled and lastBase == base and lastDown == baseDown and lastFlying == baseFlying then
        return
    end

    -- CVar 값 조정 중 경고 팝업이 발생하는 것을 차단하기 위해 임시로 이벤트 해제
    UIParent:UnregisterEvent("EXPERIMENTAL_CVAR_CONFIRMATION_NEEDED")

    if isEnabled then
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

    lastEnabled  = isEnabled
    lastBase     = base
    lastDown     = baseDown
    lastFlying   = baseFlying
    hasApplied   = true

    -- CVar 조작 완료 후 0.1초 뒤 이벤트를 부드럽게 재등록하여 다른 시스템 영향 방지
    C_Timer.After(0.1, register_cvar_event)
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
local isInitialized = false
function module:OnEnable()
    initialize()
    update_module_state()

    -- [최적화] 중복 실행 방지 가드
    if isInitialized then return end
    isInitialized = true

    -- 로딩 부하 분산을 위해 0.5초 뒤 지연 실행 (가비지 프리: 정적 함수 참조)
    C_Timer.After(0.5, camera_tilt)

    -- Editmode 설정창에 동적 설정 등록
    if dodo.RegisterEditModeSetting then
        dodo.RegisterEditModeSetting("인터페이스", {
            {
                name = "카메라 각도 조절",
                get = function()
                    if dodo.DB and dodo.DB.enableCameraModule ~= nil then
                        return dodo.DB.enableCameraModule
                    end
                    return true -- 기본 활성화
                end,
                set = function(checked)
                    if dodo.DB then dodo.DB.enableCameraModule = checked end
                    if dodo.UpdateCameraModuleState then dodo.UpdateCameraModuleState() end
                end
            },
            {
                name = "카메라 시점 각도",
                type = "slider",
                get = function() return dodo.DB and dodo.DB.cameraBase or cameraTiltAngle end,
                set = function(val)
                    if dodo.DB then
                        dodo.DB.cameraBase   = val
                        dodo.DB.cameraDown   = val
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