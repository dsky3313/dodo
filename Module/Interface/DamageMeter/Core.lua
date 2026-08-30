-- ==============================
-- Inspired
-- ==============================
-- DamageMeterTools 暴雪傷害統計增強 (https://www.curseforge.com/wow/addons/damagemetertools)
-- Damage Meter Anchored (https://www.curseforge.com/wow/addons/damage-meter-anchored)

-- ==============================
-- 설정 및 테이블
-- ==============================
---@diagnostic disable: lowercase-global, param-type-mismatch, redundant-parameter, undefined-field, undefined-global
local addonName, dodo = ...
dodoDB = dodoDB or {}

-- ==============================
-- 캐싱
-- ==============================
local CreateFrame = CreateFrame
local hooksecurefunc = hooksecurefunc
local DamageMeter = DamageMeter

-- ==============================
-- 전체 상태 제어 및 초기화
-- ==============================
local function update_all_states()
    if dodo.UpdateDamageMeterSyncState then
        dodo.UpdateDamageMeterSyncState()
    end
    if dodo.UpdateDamageMeterResetState then
        dodo.UpdateDamageMeterResetState()
    end
end

local function on_secondary_session_shown()
    update_all_states()
end

local function initialize()
    if dodoDB.enableDamageMeter == nil then dodoDB.enableDamageMeter = true end
    if dodoDB.dmgMeterSyncSize == nil then dodoDB.dmgMeterSyncSize = true end
    if dodoDB.dmgMeterSnap == nil then dodoDB.dmgMeterSnap = true end
    if dodoDB.dmgMeterResetButton == nil then dodoDB.dmgMeterResetButton = true end
    if dodoDB.enableDamageMeterAlways == nil then dodoDB.enableDamageMeterAlways = true end
    
    update_all_states()
end

local initFrame = CreateFrame("Frame")

local function on_event(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == addonName then
        hooksecurefunc(DamageMeter, "ShowNewSecondarySessionWindow", on_secondary_session_shown)
    elseif event == "PLAYER_LOGIN" then
        initialize()
    elseif event == "PLAYER_ENTERING_WORLD" then
        update_all_states()
        self:UnregisterEvent("PLAYER_ENTERING_WORLD")
    end
end

initFrame:RegisterEvent("ADDON_LOADED")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
initFrame:SetScript("OnEvent", on_event)

-- ==============================
-- 설정 등록
-- ==============================
dodo.RegisterOption("인터페이스.피해량 전투기", function(category)
    dodo.UI:SettingsCheckbox(category, "enableDamageMeterAlways", "항상 활성화",      "", true, nil)
    dodo.UI:SettingsCheckbox(category, "dmgMeterSyncSize",        "창 크기 동기화",   "", true, dodo.UpdateDamageMeterSyncState)
    dodo.UI:SettingsCheckbox(category, "dmgMeterSnap",            "창 붙이기",        "", true, dodo.UpdateDamageMeterSyncState)
    dodo.UI:SettingsCheckbox(category, "dmgMeterResetButton",     "초기화 버튼 생성", "", true, dodo.UpdateDamageMeterResetState)
end, 3000)
