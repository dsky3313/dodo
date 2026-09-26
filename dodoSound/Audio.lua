-- ==============================
-- Inspired
-- ==============================
-- Leatrix Plus (https://www.curseforge.com/wow/addons/leatrix-plus)

-- ==============================
-- 설정 및 테이블
-- ==============================
---@diagnostic disable: lowercase-global, param-type-mismatch, redundant-parameter, undefined-field, undefined-global
local dodo = _G.dodo
dodoDB = dodoDB or {}

-- ==============================
-- 캐싱
-- ==============================
local CinematicFrame = CinematicFrame
local CreateFrame = CreateFrame
local GetTime = GetTime
local MovieFrame = MovieFrame
local PlaySound = PlaySound
local print = print
local Sound_GameSystem_RestartSoundSystem = Sound_GameSystem_RestartSoundSystem
local tonumber = tonumber

-- ==============================
-- 기능 1: 로컬 상태 및 설정
-- ==============================
local last_sync = 0
local audio_frame = nil

local colors         = dodo.Colors
local soft_green_hex = (colors and colors.SoftGreen and colors.SoftGreen.hex) or "ff64ff64"

-- ==============================
-- 기능 2: 상태 업데이트 및 오디오 동작
-- ==============================
local function sync_audio(isManual)
    if (isManual == false) or (isManual == nil and dodoDB.useAudioSync == false) then
        return
    end

    local now = GetTime()
    if isManual ~= true and now - last_sync < 5 then return end
    last_sync = now

    local cinemaShown = CinematicFrame and CinematicFrame:IsShown()
    local movieShown = MovieFrame and MovieFrame:IsShown()

    if not cinemaShown and not movieShown then
        C_CVar.SetCVar("Sound_OutputDriverIndex", "0")
        Sound_GameSystem_RestartSoundSystem()

        if isManual == true then
            print("[|c" .. soft_green_hex .. "dodo|r] 오디오 동기화 완료")
        end
    end
end

--- 보스전 진입 사운드
local function play_encounter_start_sound()
    local soundID = tonumber(dodoDB.useSoundEncounterStart_soundID) or 16971
    PlaySound(soundID, "Master")
end

--- 보스전 승리 사운드
local function play_encounter_victory_sound()
    local soundID = tonumber(dodoDB.useSoundEncounterVictory_soundID) or 38352
    PlaySound(soundID, "Master")
end

local function on_encounter_state_changed(event, ...)
    if event == "ENCOUNTER_START" then
        if C_CVar.GetCVar("Sound_EnableMusic") ~= "0" then
            C_CVar.SetCVar("Sound_EnableMusic", 0)
        end
        if dodoDB.useSoundEncounterStart ~= false then
            play_encounter_start_sound()
        end
    elseif event == "ENCOUNTER_END" then
        if C_CVar.GetCVar("Sound_EnableMusic") ~= "1" then
            C_CVar.SetCVar("Sound_EnableMusic", 1)
        end
        local _, _, _, _, success = ...
        if success == 1 and dodoDB.useSoundEncounterVictory ~= false then
            play_encounter_victory_sound()
        end
    end
end

-- ==============================
-- 기능 3: UI 생성
-- ==============================
local function update_event_registration()
    if not audio_frame then return end

    local useSync = dodoDB.useAudioSync ~= false
    local useBossStart = dodoDB.useSoundEncounterStart ~= false
    local useBossVictory = dodoDB.useSoundEncounterVictory ~= false

    -- 출력 장치 동기화 이벤트
    if useSync then
        audio_frame:RegisterEvent("VOICE_CHAT_OUTPUT_DEVICES_UPDATED")
        audio_frame:RegisterEvent("PLAYER_ENTERING_WORLD")
    else
        audio_frame:UnregisterEvent("VOICE_CHAT_OUTPUT_DEVICES_UPDATED")
        audio_frame:UnregisterEvent("PLAYER_ENTERING_WORLD")
    end

    -- 보스전 이벤트
    if useBossStart or useBossVictory then
        audio_frame:RegisterEvent("ENCOUNTER_START")
        audio_frame:RegisterEvent("ENCOUNTER_END")
    else
        audio_frame:UnregisterEvent("ENCOUNTER_START")
        audio_frame:UnregisterEvent("ENCOUNTER_END")
    end
end

local function on_event(self, event, ...)
    if event == "PLAYER_LOGIN" then
        update_event_registration()
        self:UnregisterEvent("PLAYER_LOGIN")
    elseif event == "VOICE_CHAT_OUTPUT_DEVICES_UPDATED" or event == "PLAYER_ENTERING_WORLD" then
        sync_audio()
    elseif event == "ENCOUNTER_START" or event == "ENCOUNTER_END" then
        on_encounter_state_changed(event, ...)
    end
end

audio_frame = CreateFrame("Frame")
audio_frame:RegisterEvent("PLAYER_LOGIN")
audio_frame:SetScript("OnEvent", on_event)

-- 공개 API (99 Options.lua 콜백에서 호출)
dodo.AudioUpdateEventRegistration = update_event_registration
dodo.AudioSyncNow                 = sync_audio
dodo.AudioPlayEncounterStart      = play_encounter_start_sound
dodo.AudioPlayEncounterVictory    = play_encounter_victory_sound