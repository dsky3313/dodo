-- ==============================
-- 테이블
-- ==============================
---@diagnostic disable: lowercase-global, undefined-field, undefined-global
local addonName, dodo = ...
dodoDB = dodoDB or {}

-- 보스전 진입 (ENCOUNTER_START)
soundEncounterStartTable = {
    { label = "돌격", value = "16971" },
}

-- 보스전 승리 (ENCOUNTER_END 성공 시)
soundEncounterVictoryTable = {
    { label = "PVP 얼라이언스", value = "38352" },
    { label = "퀘스트 추가", value = "618" },
    { label = "PVP 승리", value = "34091" },
}

local CreateFrame = CreateFrame
local PlaySound = PlaySound
local SetCVar = SetCVar
local Sound_GameSystem_RestartSoundSystem = Sound_GameSystem_RestartSoundSystem
local tonumber = tonumber
local CinematicFrame = CinematicFrame
local MovieFrame = MovieFrame

-- ==============================
-- 동작
-- ==============================
local function audioSync()
    if not dodoDB then return end
    local isEnabled = (dodoDB.useAudioSync ~= false)
    local cinemaShown = CinematicFrame and CinematicFrame:IsShown()
    local movieShown = MovieFrame and MovieFrame:IsShown()

    if not cinemaShown and not movieShown then
        if isEnabled then
            SetCVar("Sound_OutputDriverIndex", "0")
            Sound_GameSystem_RestartSoundSystem()
        end
    end
end

-- 옵션창 콜백 or 보스전 시작 이벤트
local function EncounterSoundStart()
    if not dodoDB then return end
    local soundID = tonumber(dodoDB.useSoundEncounterStart_soundID) or 16971
    PlaySound(soundID, "Master") -- 미리듣기: 체크박스 상태 무관하게 재생
end

-- 옵션창 콜백 or 보스전 승리 이벤트
local function EncounterSoundVictory()
    if not dodoDB then return end
    local soundID = tonumber(dodoDB.useSoundEncounterVictory_soundID) or 38352
    PlaySound(soundID, "Master") -- 미리듣기: 체크박스 상태 무관하게 재생
end

-- 이벤트에서 호출하는 래퍼 (배경음 제어 + isEnabled 체크 포함)
local function EncounterSound(event, ...)
    if not dodoDB then return end

    if event == "ENCOUNTER_START" then
        local isEnabled = (dodoDB.useSoundEncounterStart ~= false)
        SetCVar("Sound_EnableMusic", 0)
        if isEnabled then EncounterSoundStart() end
    elseif event == "ENCOUNTER_END" then
        SetCVar("Sound_EnableMusic", 1)
        local _, _, _, _, success = ...
        if success == 1 then
            local isEnabled = (dodoDB.useSoundEncounterVictory ~= false)
            if isEnabled then EncounterSoundVictory() end
        end
    end
end

-- ==============================
-- 이벤트
-- ==============================
local initAudioSync = CreateFrame("Frame")
initAudioSync:RegisterEvent("ADDON_LOADED")
initAudioSync:RegisterEvent("ENCOUNTER_START")
initAudioSync:RegisterEvent("ENCOUNTER_END")

initAudioSync:SetScript("OnEvent", function(self, event, ...)
    local arg1 = ...

    if event == "ADDON_LOADED" and arg1 == addonName then
        dodoDB = dodoDB or {}
        self:UnregisterEvent("ADDON_LOADED")
        self:RegisterEvent("VOICE_CHAT_OUTPUT_DEVICES_UPDATED")
    elseif event == "VOICE_CHAT_OUTPUT_DEVICES_UPDATED" then
        audioSync()
    elseif event == "ENCOUNTER_START" or event == "ENCOUNTER_END" then
        EncounterSound(event, ...)
    end
end)

dodo.audioSync = audioSync
dodo.EncounterSoundStart = EncounterSoundStart
dodo.EncounterSoundVictory = EncounterSoundVictory
