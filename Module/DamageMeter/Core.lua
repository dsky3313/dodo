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
    
    update_all_states()
end

local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("ADDON_LOADED")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
initFrame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == addonName then
        hooksecurefunc(DamageMeter, "ShowNewSecondarySessionWindow", on_secondary_session_shown)
    elseif event == "PLAYER_LOGIN" then
        initialize()
    elseif event == "PLAYER_ENTERING_WORLD" then
        update_all_states()
        self:UnregisterEvent("PLAYER_ENTERING_WORLD")
    end
end)

-- ==============================
-- 설정 등록
-- ==============================
if dodo.RegisterEditModeModuleSetting then
    dodo.RegisterEditModeModuleSetting("전투", {
        {
            name = "피해량 측정기",
            get = function() return dodoDB and dodoDB.enableDamageMeter ~= false end,
            set = function(checked)
                if dodoDB then dodoDB.enableDamageMeter = checked end
                update_all_states()
            end
        }
    })
end

if dodo.RegisterEditModeSystemSetting then
    local systemID = Enum.EditModeSystem.DamageMeter
    if systemID then
        dodo.RegisterEditModeSystemSetting(systemID, {
            {
                name = "창 크기 동기화",
                get = function() return dodoDB and dodoDB.dmgMeterSyncSize ~= false end,
                set = function(checked)
                    if dodoDB then dodoDB.dmgMeterSyncSize = checked end
                    if dodo.UpdateDamageMeterSyncState then
                        dodo.UpdateDamageMeterSyncState()
                    end
                end,
                disabled = function() return dodoDB and dodoDB.enableDamageMeter == false end,
            },
            {
                name = "창 붙이기",
                get = function() return dodoDB and dodoDB.dmgMeterSnap ~= false end,
                set = function(checked)
                    if dodoDB then dodoDB.dmgMeterSnap = checked end
                    if dodo.UpdateDamageMeterSyncState then
                        dodo.UpdateDamageMeterSyncState()
                    end
                end,
                disabled = function() return dodoDB and dodoDB.enableDamageMeter == false end,
            },
            {
                name = "초기화 버튼 생성",
                get = function() return dodoDB and dodoDB.dmgMeterResetButton ~= false end,
                set = function(checked)
                    if dodoDB then dodoDB.dmgMeterResetButton = checked end
                    if dodo.UpdateDamageMeterResetState then
                        dodo.UpdateDamageMeterResetState()
                    end
                end,
                disabled = function() return dodoDB and dodoDB.enableDamageMeter == false end,
            }
        })
    end
end
