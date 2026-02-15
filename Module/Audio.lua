-- ==============================
-- 테이블
-- ==============================
---@diagnostic disable: lowercase-global, undefined-field, undefined-global
local addonName, dodo = ...
dodoDB = dodoDB or {}

-- ==============================
-- 동작
-- ==============================
local function audioSync()
    SetCVar("Sound_OutputDriverIndex", "0")
    Sound_GameSystem_RestartSoundSystem()
    print("|cff00ff00[dodo]|r 음성 출력장치 변경")
end

-- ==============================
-- 이벤트
-- ==============================
local initAudioSync = CreateFrame("Frame")
initAudioSync:RegisterEvent("VOICE_CHAT_OUTPUT_DEVICES_UPDATED")
initAudioSync:SetScript("OnEvent", function(self, event)
    local isEnabled = (dodoDB and dodoDB.useAudioSync ~= false)
    if not isEnabled then return end
    if not (CinematicFrame and CinematicFrame:IsShown()) and not (MovieFrame and MovieFrame:IsShown()) then audioSync() end
end)