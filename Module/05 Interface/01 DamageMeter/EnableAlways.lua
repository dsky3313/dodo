-- ==============================
-- Inspired
-- ==============================
-- dodo

-- ==============================
-- 설정 및 테이블
-- ==============================
---@diagnostic disable: lowercase-global, param-type-mismatch, redundant-parameter, undefined-field, undefined-global
local addonName, dodo = ...

-- ==============================
-- 캐싱
-- ==============================
local C_CVar = C_CVar
local C_Timer = C_Timer
local CreateFrame = CreateFrame
local SetCVar = SetCVar

-- ==============================
-- 초기화
-- ==============================
local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function(self)
    if dodoDB.enableDamageMeterAlways ~= false then
        C_Timer.After(1, function()
            if C_CVar.GetCVarBool("damageMeterEnabled") == false then
                SetCVar("damageMeterEnabled", "1")
                print("|cff00ccff[dodo]|r 피해량 측정기를 활성화했습니다.")
            end
        end)
    end
    self:UnregisterEvent("PLAYER_LOGIN")
end)
