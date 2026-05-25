-- ==============================
-- Inspired
-- ==============================
-- Leatrix Plus (https://www.curseforge.com/wow/addons/leatrix-plus)

-- ==============================
-- 설정 및 테이블
-- ==============================
---@diagnostic disable: lowercase-global, param-type-mismatch, redundant-parameter, undefined-field, undefined-global
local addonName, dodo = ...
local module = {}
dodo:RegisterModule("Audio", module)

-- ==============================
-- 캐싱
-- ==============================
local CinematicFrame = CinematicFrame
local CreateFrame = CreateFrame
local GetCVar = GetCVar
local GetTime = GetTime
local MovieFrame = MovieFrame
local PlaySound = PlaySound
local SetCVar = SetCVar
local Sound_GameSystem_RestartSoundSystem = Sound_GameSystem_RestartSoundSystem
local tonumber = tonumber
local UIErrorsFrame = UIErrorsFrame

-- ==============================
-- 프레임 및 이벤트
-- ==============================
local main_frame = CreateFrame("Frame")

-- ==============================
-- 기능 1: 오디오 동기화
-- ==============================
local lastSync = 0
local function audio_sync(isManual)
    if (isManual == false) or (isManual == nil and (not dodo.DB or dodo.DB.useAudioSync == false)) then 
        return 
    end
    
    local now = GetTime()
    if isManual ~= true and now - lastSync < 5 then return end
    lastSync = now

    local cinemaShown = CinematicFrame and CinematicFrame:IsShown()
    local movieShown = MovieFrame and MovieFrame:IsShown()

    if not cinemaShown and not movieShown then
        SetCVar("Sound_OutputDriverIndex", "0")
        Sound_GameSystem_RestartSoundSystem()
        
        if isManual == true then
            UIErrorsFrame:AddMessage("|cffaaffaa[dodo]|r 오디오 동기화 완료", 1.0, 1.0, 1.0, 5.0)
        end
    end
end

dodo.Audio_Sync = audio_sync

-- ==============================
-- 기능 2: 보스전 효과음
-- ==============================
local function play_encounter_start()
    if not dodo.DB then return end
    local soundID = tonumber(dodo.DB.useSoundEncounterStart_soundID) or 16971
    PlaySound(soundID, "Master")
end

local function play_encounter_victory()
    if not dodo.DB then return end
    local soundID = tonumber(dodo.DB.useSoundEncounterVictory_soundID) or 38352
    PlaySound(soundID, "Master")
end

dodo.PlayEncounterStartSound = play_encounter_start
dodo.PlayEncounterVictorySound = play_encounter_victory

local function on_encounter_event(event, ...)
    if not dodo.DB then return end

    if event == "ENCOUNTER_START" then
        if GetCVar("Sound_EnableMusic") ~= "0" then
            SetCVar("Sound_EnableMusic", 0)
        end
        if dodo.DB.useSoundEncounterStart ~= false then 
            play_encounter_start() 
        end
    elseif event == "ENCOUNTER_END" then
        if GetCVar("Sound_EnableMusic") ~= "1" then
            SetCVar("Sound_EnableMusic", 1)
        end
        local _, _, _, _, success = ...
        if success == 1 and dodo.DB.useSoundEncounterVictory ~= false then
            play_encounter_victory()
        end
    end
end

-- ==============================
-- 초기화
-- ==============================
local function initialize()
    -- 1. DB 설정 초기값 세팅
    if dodo.DB then
        if dodo.DB.useAudioSync == nil then
            dodo.DB.useAudioSync = false
        end
        if dodo.DB.useSoundEncounterStart == nil then
            dodo.DB.useSoundEncounterStart = true
        end
        if dodo.DB.useSoundEncounterVictory == nil then
            dodo.DB.useSoundEncounterVictory = true
        end
    end
end

-- ==============================
-- 모듈 생명주기
-- ==============================
local isInitialized = false
function module:OnEnable()
    initialize()
    audio_sync()

    if isInitialized then return end
    isInitialized = true

    main_frame:SetScript("OnEvent", function(self, event, ...)
        if event == "VOICE_CHAT_OUTPUT_DEVICES_UPDATED" or event == "PLAYER_ENTERING_WORLD" then
            audio_sync()
        elseif event == "ENCOUNTER_START" or event == "ENCOUNTER_END" then
            on_encounter_event(event, ...)
        end
    end)

    main_frame:RegisterEvent("VOICE_CHAT_OUTPUT_DEVICES_UPDATED")
    main_frame:RegisterEvent("PLAYER_ENTERING_WORLD")
    main_frame:RegisterEvent("ENCOUNTER_START")
    main_frame:RegisterEvent("ENCOUNTER_END")

    -- Editmode 설정창에 동적 설정 등록
    if dodo.RegisterEditModeSetting then
        dodo.RegisterEditModeSetting("음성", {
            {
                name = "출력장치 동기화",
                get = function() return dodo.DB and dodo.DB.useAudioSync or false end,
                set = function(checked)
                    if dodo.DB then dodo.DB.useAudioSync = checked end
                    audio_sync()
                end
            },
            { isSpacer = true },
            {
                name = "보스전 시작 효과음",
                get = function() return dodo.DB and dodo.DB.useSoundEncounterStart ~= false end,
                set = function(checked)
                    if dodo.DB then dodo.DB.useSoundEncounterStart = checked end
                end
            },
            {
                type = "dropdown",
                get = function() return dodo.DB and dodo.DB.useSoundEncounterStart_soundID or "16971" end,
                set = function(val)
                    if dodo.DB then dodo.DB.useSoundEncounterStart_soundID = val end
                    play_encounter_start()
                end,
                values = {
                    { text = "돌격", value = "16971" },
                }
            },
            {
                name = "보스전 승리 효과음",
                get = function() return dodo.DB and dodo.DB.useSoundEncounterVictory ~= false end,
                set = function(checked)
                    if dodo.DB then dodo.DB.useSoundEncounterVictory = checked end
                end
            },
            {
                type = "dropdown",
                get = function() return dodo.DB and dodo.DB.useSoundEncounterVictory_soundID or "38352" end,
                set = function(val)
                    if dodo.DB then dodo.DB.useSoundEncounterVictory_soundID = val end
                    play_encounter_victory()
                end,
                values = {
                    { text = "PVP 얼라이언스", value = "38352" },
                    { text = "퀘스트 추가", value = "618" },
                    { text = "PVP 승리", value = "34091" },
                }
            },
        })
    end
end
