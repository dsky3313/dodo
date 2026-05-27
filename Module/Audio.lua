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

-- 보스전 진입
dodo.soundEncounterStartTable = {
    { label = "돌격", value = "16971" },
}

-- 보스전 승리
dodo.soundEncounterVictoryTable = {
    { label = "PVP 얼라이언스", value = "38352" },
    { label = "퀘스트 추가", value = "618" },
    { label = "PVP 승리", value = "34091" },
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
local ipairs = ipairs
local tonumber = tonumber
local type = type

-- ==============================
-- 동작
-- ==============================
local lastSync = 0
local function audioSync(isManual)
    -- 옵션이 꺼져있거나, 방금 체크를 해제한 경우 리턴
    if (isManual == false) or (isManual == nil and (not dodoDB or dodoDB.useAudioSync == false)) then 
        return 
    end
    
    -- 자동 동기화(이벤트) 시 5초 이내 재실행 방지
    local now = GetTime()
    if isManual ~= true and now - lastSync < 5 then return end
    lastSync = now

    local cinemaShown = CinematicFrame and CinematicFrame:IsShown()
    local movieShown = MovieFrame and MovieFrame:IsShown()

    if not cinemaShown and not movieShown then
        -- 현재 설정이 이미 '0'이더라도 다시 설정하고 재시작해야 OS의 오디오 변경사항을 감지함
        SetCVar("Sound_OutputDriverIndex", "0")
        Sound_GameSystem_RestartSoundSystem()
        
        if isManual == true then
            UIErrorsFrame:AddMessage("|cffaaffaa[dodo]|r 오디오 동기화 완료", 1.0, 1.0, 1.0, 5.0)
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
        if GetCVar("Sound_EnableMusic") ~= "0" then
            SetCVar("Sound_EnableMusic", 0)
        end
        if dodoDB.useSoundEncounterStart ~= false then 
            EncounterSoundStart() 
        end
    elseif event == "ENCOUNTER_END" then
        if GetCVar("Sound_EnableMusic") ~= "1" then
            SetCVar("Sound_EnableMusic", 1)
        end
        local _, _, _, _, success = ...
        if success == 1 and dodoDB.useSoundEncounterVictory ~= false then
            EncounterSoundVictory()
        end
    end
end

-- ==============================
-- 이벤트 핸들러 (가비지 프리 정적 참조)
-- ==============================
local function on_event(self, event, ...)
    local arg1 = ...

    if event == "ADDON_LOADED" and arg1 == addonName then
        dodoDB = dodoDB or {}
        self:UnregisterEvent("ADDON_LOADED")
        self:RegisterEvent("VOICE_CHAT_OUTPUT_DEVICES_UPDATED")
        self:RegisterEvent("PLAYER_ENTERING_WORLD")
    elseif event == "VOICE_CHAT_OUTPUT_DEVICES_UPDATED" or event == "PLAYER_ENTERING_WORLD" then
        audioSync()
    elseif event == "ENCOUNTER_START" or event == "ENCOUNTER_END" then
        EncounterSound(event, ...)
    end
end

-- ==============================
-- 이벤트 등록
-- ==============================
local initAudioSync = CreateFrame("Frame")
initAudioSync:RegisterEvent("ADDON_LOADED")
initAudioSync:RegisterEvent("ENCOUNTER_START")
initAudioSync:RegisterEvent("ENCOUNTER_END")
initAudioSync:SetScript("OnEvent", on_event)

-- ==============================
-- 외부 노출 (Option.lua용)
-- ==============================
dodo.audioSync = audioSync
dodo.EncounterSoundStart = EncounterSoundStart
dodo.EncounterSoundVictory = EncounterSoundVictory

-- ==============================
-- 설정 동적 등록 (Option.lua 연동)
-- ==============================
local SettingsPanel = SettingsPanel
local CreateSettingsListSectionHeaderInitializer = CreateSettingsListSectionHeaderInitializer
local Checkbox = Checkbox
local CheckBoxDropDown = CheckBoxDropDown

dodo.OptionRegistrations = dodo.OptionRegistrations or {}
dodo.OptionRegistrations["sound"] = dodo.OptionRegistrations["sound"] or {}
table.insert(dodo.OptionRegistrations["sound"], function(category)
    local layoutSound = SettingsPanel:GetLayout(category)
    if not layoutSound then return end

    -- 출력 장치 동기화
    layoutSound:AddInitializer(CreateSettingsListSectionHeaderInitializer("출력장치"))
    Checkbox(category, "useAudioSync", "출력장치 동기화", "출력장치 동기화.", true, dodo.audioSync)

    -- 효과음
    layoutSound:AddInitializer(CreateSettingsListSectionHeaderInitializer("효과음"))
    CheckBoxDropDown(category, "useSoundEncounterStart", "useSoundEncounterStart_soundID", "보스전 시작", "전투 시작 사운드를 변경합니다.", dodo.soundEncounterStartTable, true, dodo.soundEncounterStartTable[1].value, dodo.EncounterSoundStart)
    CheckBoxDropDown(category, "useSoundEncounterVictory", "useSoundEncounterVictory_soundID", "보스전 승리", "전투 승리 사운드를 변경합니다.", dodo.soundEncounterVictoryTable, true, dodo.soundEncounterVictoryTable[1].value, dodo.EncounterSoundVictory)
end)
