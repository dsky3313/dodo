-- ==============================
-- Inspired
-- ==============================
-- Leatrix Plus (https://www.curseforge.com/wow/addons/leatrix-plus)

-- ==============================
-- 설정 및 테이블
-- ==============================
---@diagnostic disable: lowercase-global, param-type-mismatch, redundant-parameter, undefined-field, undefined-global
local addonName, dodo = ...
dodoDB = dodoDB or {}

---@class AudioSoundItem
---@field text string 표시될 사운드 한글 이름
---@field value string 실제 재생될 사운드 ID 문자열

-- 모듈 내부 정적 상태 변수 (물리 격리)
---@type AudioSoundItem[]
local soundEncounterStartTable = {
    { text = "돌격", value = "16971" },
}

---@type AudioSoundItem[]
local soundEncounterVictoryTable = {
    { text = "PVP 얼라이언스", value = "38352" },
    { text = "퀘스트 추가", value = "618" },
    { text = "PVP 승리", value = "34091" },
}

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
local UIErrorsFrame = UIErrorsFrame
local string_format = string.format
local tonumber = tonumber

-- ==============================
-- 기능 1: 로컬 상태 및 설정
-- ==============================
local lastSync = 0
local audioFrame = nil

-- dodo.Colors에서 피드백용 정적 헥스 코드 직접 가져오기 (치환 연산 배제)
local colors = dodo.Colors
local softGreenHex = (colors and colors.SoftGreen and colors.SoftGreen.hex) or "ffb2ffb2"
local softRedHex = (colors and colors.SoftRed and colors.SoftRed.hex) or "ffffb2b2"

-- ==============================
-- 기능 2: 상태 업데이트 및 오디오 동작
-- ==============================
---@param isManual boolean|nil 수동 실행 여부
---@return nil
local function sync_audio(isManual)
    if (isManual == false) or (isManual == nil and (not dodoDB or dodoDB.useAudioSync == false)) then
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
            print("|c" .. softGreenHex .. "[dodo]|r 오디오 동기화 완료")
        end
    end
end

--- 보스전 진입 사운드
local function play_encounter_start_sound()
    if not dodoDB then return end
    local soundID = tonumber(dodoDB.useSoundEncounterStart_soundID) or 16971
    PlaySound(soundID, "Master")
end

--- 보스전 승리 사운드
local function play_encounter_victory_sound()
    if not dodoDB then return end
    local soundID = tonumber(dodoDB.useSoundEncounterVictory_soundID) or 38352
    PlaySound(soundID, "Master")
end

--- 보스전 상태 변경 대응 핸들러
local function on_encounter_state_changed(event, ...)
    if not dodoDB then return end

    if event == "ENCOUNTER_START" then
        if GetCVar("Sound_EnableMusic") ~= "0" then
            SetCVar("Sound_EnableMusic", 0)
        end
        if dodoDB.useSoundEncounterStart ~= false then
            play_encounter_start_sound()
        end
    elseif event == "ENCOUNTER_END" then
        if GetCVar("Sound_EnableMusic") ~= "1" then
            SetCVar("Sound_EnableMusic", 1)
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
local function on_event(self, event, ...)
    local arg1 = ...

    if event == "ADDON_LOADED" and arg1 == addonName then
        dodoDB = dodoDB or {}
        self:UnregisterEvent("ADDON_LOADED")
        self:RegisterEvent("VOICE_CHAT_OUTPUT_DEVICES_UPDATED")
        self:RegisterEvent("PLAYER_ENTERING_WORLD")
    elseif event == "VOICE_CHAT_OUTPUT_DEVICES_UPDATED" or event == "PLAYER_ENTERING_WORLD" then
        sync_audio()
    elseif event == "ENCOUNTER_START" or event == "ENCOUNTER_END" then
        on_encounter_state_changed(event, ...)
    end
end

audioFrame = CreateFrame("Frame")
audioFrame:RegisterEvent("ADDON_LOADED")
audioFrame:RegisterEvent("ENCOUNTER_START")
audioFrame:RegisterEvent("ENCOUNTER_END")
audioFrame:SetScript("OnEvent", on_event)

-- ==============================
-- 설정 등록
-- ==============================
-- 1. dodoEditModePanel (모듈 편집창) 등록
if dodo.RegisterEditModeSetting then
    dodo.RegisterEditModeSetting("음성", {
        -- 1. 출력장치 동기화
        {
            name = "출력장치 동기화",
            get = function() return dodoDB.useAudioSync ~= false end,
            set = function(val)
                dodoDB.useAudioSync = val
                if val then
                    sync_audio(true)
                else
                    print("|c" .. softRedHex .. "[dodo]|r 오디오 동기화 비활성화")
                end
            end,
        },

        -- 2. 보스전 시작 효과음
        {
            name = "보스전 시작",
            get = function() return dodoDB.useSoundEncounterStart ~= false end,
            set = function(val) dodoDB.useSoundEncounterStart = val end,
        },
        {
            type = "dropdown",
            get = function() return dodoDB.useSoundEncounterStart_soundID or "16971" end,
            set = function(val) dodoDB.useSoundEncounterStart_soundID = val; play_encounter_start_sound() end,
            values = soundEncounterStartTable,
        },

        -- 3. 보스전 승리 효과음
        {
            name = "보스전 승리",
            get = function() return dodoDB.useSoundEncounterVictory ~= false end,
            set = function(val) dodoDB.useSoundEncounterVictory = val end,
        },
        {
            type = "dropdown",
            get = function() return dodoDB.useSoundEncounterVictory_soundID or "38352" end,
            set = function(val) dodoDB.useSoundEncounterVictory_soundID = val; play_encounter_victory_sound() end,
            values = soundEncounterVictoryTable,
        }
    })
end