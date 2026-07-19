-- ==============================
-- Inspired
-- ==============================
-- dodo PersonalResource

-- ==============================
-- 설정 및 테이블
-- ==============================
---@diagnostic disable: lowercase-global, param-type-mismatch, redundant-parameter, undefined-field, undefined-global
local addonName, dodo = ...
dodoDB = dodoDB or {}

dodo.PersonalResource = dodo.PersonalResource or {}

-- ==============================
-- 캐싱
-- ==============================
local CreateFrame = CreateFrame

-- ==============================
-- 이벤트 핸들러
-- ==============================
local initFrame = CreateFrame("Frame")

local function on_event(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == addonName then
        dodoDB = dodoDB or {}
        dodo.DB = dodo.DB or dodoDB
    elseif event == "PLAYER_LOGIN" then
        dodo.DB = dodo.DB or dodoDB or {}
        local PR = dodo.PersonalResource
        if PR and PR.ApplyFontSize then PR.ApplyFontSize() end
        self:UnregisterEvent("PLAYER_LOGIN")
    end
end

initFrame:RegisterEvent("ADDON_LOADED")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:SetScript("OnEvent", on_event)
