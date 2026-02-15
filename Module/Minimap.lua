-- ==============================
-- 테이블
-- ==============================
---@diagnostic disable: lowercase-global, undefined-field, undefined-global
local addonName, dodo = ...
dodoDB = dodoDB or {}

local function isIns() -- 인스확인
    local _, instanceType, difficultyID = GetInstanceInfo()
    return (difficultyID == 8 or instanceType == "raid") -- 1 일반 / 8 쐐기 / raid 레이드
end

-- ==============================
-- 동작
-- ==============================
local frame = CreateFrame("Frame")
frame:RegisterEvent("MINIMAP_UPDATE_ZOOM")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:SetScript("OnEvent", function(self, event)
    if isIns() then return end

    if event == "MINIMAP_UPDATE_ZOOM" then
        C_Timer.After(10, function()
            if Minimap:GetZoom() ~= 0 then
                Minimap:SetZoom(0)
                PlaySound(113, "Master")
            end
        end)
    end
end)