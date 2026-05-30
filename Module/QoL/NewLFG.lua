-- ==============================
-- Inspired
-- ==============================
-- 파티 구인 중 새로운 신청자 알림 위크오라 (https://www.inven.co.kr/board/wow/5297/7283)

-- ==============================
-- 설정 및 테이블
-- ==============================
---@diagnostic disable: lowercase-global, param-type-mismatch, redundant-parameter, undefined-field, undefined-global
local addonName, dodo = ...
dodoDB = dodoDB or {}

-- 2dodo 규격을 위해 text 필드 추가 (label 병행 제공하여 OptionUI.lua 하위 호환 보장)
dodo.newLFG_AlertSoundTable = {
    { text = "MurlocAggro", label = "MurlocAggro", value = "416" },
    { text = "AuctionWindowOpen", label = "AuctionWindowOpen", value = "5274" },
    { text = "AuctionWindowClose", label = "AuctionWindowClose", value = "5275" },
    { text = "PVPFlagTaken.Mono", label = "PVPFlagTaken.Mono", value = "9378" },
    { text = "PVPFlagTakenHordeMono", label = "PVPFlagTakenHordeMono", value = "9379" },
    { text = "UI_QuestObjectivesComplete", label = "UI_QuestObjectivesComplete", value = "26905" },
    { text = "UI_RaidBossWhisperWarning", label = "UI_RaidBossWhisperWarning", value = "11773" },
    { text = "RaidWarning", label = "RaidWarning", value = "8959" },
    { text = "HumanFemaleStandardNPCGreetings", label = "HumanFemaleStandardNPCGreetings", value = "552141" },
}

-- ==============================
-- 캐싱
-- ==============================
local _G = _G
local C_LFGList = C_LFGList
local C_Timer = C_Timer
local CreateFrame = CreateFrame
local GetInstanceInfo = GetInstanceInfo
local GetNumApplicants = C_LFGList.GetNumApplicants
local GetTime = GetTime
local GroupFinderFrame = GroupFinderFrame
local GroupFinderFrameGroupButton3 = GroupFinderFrameGroupButton3
local InCombatLockdown = InCombatLockdown
local ipairs = ipairs
local PlaySound = PlaySound
local PlaySoundFile = PlaySoundFile
local PVEFrame_ShowFrame = PVEFrame_ShowFrame
local table = table
local tonumber = tonumber
local type = type
local UnitIsGroupLeader = UnitIsGroupLeader
local UIParent = UIParent

-- ==============================
-- 기능 1: 로컬 상태 및 설정
-- ==============================
local alert_timer = nil
local armed_at = 0
local last_apps = 0
local last_trig = 0

local function is_in_instance()
    local _, instance_type, difficulty_id = GetInstanceInfo()
    return (difficulty_id == 8 or instance_type == "raid")
end

-- 알림 프레임 물리 격리 및 로컬 캡슐화
local alert_frame = CreateFrame("Frame", "NewLFG_AlertFrame", UIParent)
alert_frame:SetSize(400, 50)
alert_frame:SetPoint("TOP", 50, -150)
alert_frame:Hide()

alert_frame.Text = alert_frame:CreateFontString(nil, "OVERLAY", "GameFontNormalOutline")
alert_frame.Text:SetPoint("CENTER")
local font_path, _, font_flags = alert_frame.Text:GetFont()
alert_frame.Text:SetFont(font_path or "fonts/frizqt__.ttf", 22, font_flags)
alert_frame.Text:SetText("[ 신규 신청 ]\n\n|cffffff00파티창을 확인하세요!|r")

-- ==============================
-- 기능 2: 상태 업데이트
-- ==============================
local function on_alert_timer_tick()
    if alert_frame:IsShown() then alert_frame:Hide() end
end

local function play_lfg_alert()
    if InCombatLockdown() then return end

    local is_leader = UnitIsGroupLeader("player") == true
    local use_member_alert = dodoDB.useNewLFGLeader
    if not use_member_alert and not is_leader then return end

    local gff = GroupFinderFrame or _G["GroupFinderFrame"]
    if gff and not gff:IsVisible() then
        PVEFrame_ShowFrame("GroupFinderFrame")
        local btn3 = GroupFinderFrameGroupButton3 or _G["GroupFinderFrameGroupButton3"]
        if btn3 then btn3:Click() end
    end

    if not alert_frame:IsShown() then
        alert_frame:Show()
    end
    
    if alert_timer then alert_timer:Cancel() end
    alert_timer = C_Timer.After(7, on_alert_timer_tick)

    local sound_id = (dodoDB and dodoDB.soundID) or "5274"
    local s_id = tonumber(sound_id) or 5274

    if s_id > 100000 then
        PlaySoundFile(s_id, "Master")
    else
        PlaySound(s_id, "Master")
    end
end

-- ==============================
-- 이벤트 핸들러 (단일 프레임 최적화)
-- ==============================
local init_frame = CreateFrame("Frame")

local function update_registration()
    if not init_frame then return end
    
    local is_enabled = (dodoDB and dodoDB.useNewLFG ~= false)
    local in_instance = is_in_instance()

    -- 기능이 켜져 있고 인스턴스가 아닐 때만 작동
    if is_enabled and not in_instance then
        init_frame:RegisterEvent("LFG_LIST_APPLICANT_LIST_UPDATED")
        init_frame:RegisterEvent("LFG_LIST_ACTIVE_ENTRY_UPDATE")
        
        -- 현재 상태 초기화
        last_apps = GetNumApplicants() or 0
        armed_at = GetTime() + 1.5
    else
        init_frame:UnregisterEvent("LFG_LIST_APPLICANT_LIST_UPDATED")
        init_frame:UnregisterEvent("LFG_LIST_ACTIVE_ENTRY_UPDATE")
        last_apps = 0
        
        -- 비활성화 시 화면에 떠있는 알림 및 타이머 즉시 정리 (자원 소모 0 보장)
        if alert_frame then alert_frame:Hide() end
        if alert_timer then
            alert_timer:Cancel()
            alert_timer = nil
        end
    end
end

local function on_event(self, event, arg1)
    local now = GetTime()
    
    if event == "ADDON_LOADED" and arg1 == addonName then
        update_registration()
        self:RegisterEvent("PLAYER_ENTERING_WORLD")
    elseif event == "PLAYER_ENTERING_WORLD" then
        update_registration()
    elseif event == "LFG_LIST_ACTIVE_ENTRY_UPDATE" then
        last_apps = GetNumApplicants() or 0
        armed_at = now + 1.5
    elseif event == "LFG_LIST_APPLICANT_LIST_UPDATED" then
        local count = GetNumApplicants() or 0
        if now >= armed_at and count > last_apps then
            if (now - last_trig) > 1.0 then
                play_lfg_alert()
                last_trig = now
            end
        end
        last_apps = count
    end
end

init_frame:RegisterEvent("ADDON_LOADED")
init_frame:SetScript("OnEvent", on_event)

armed_at = GetTime() + 2

-- ==============================
-- 외부 노출 (Option.lua용)
-- ==============================
dodo.UpdateNewLFG = update_registration
dodo.NewLFG = play_lfg_alert

-- ==============================
-- 외부 노출 및 설정 동적 등록 (Option.lua 연동)
-- ==============================
local setting_parent = nil
local setting_child = nil

local function on_parent_changed(_, value)
    if value == false then
        if setting_child then
            setting_child:SetValue(false)
        end
    end
end

local function is_parent_active()
    if setting_parent then
        return setting_parent:GetValue()
    end
    return true
end

local SettingsPanel = SettingsPanel
local Checkbox = Checkbox
local CheckBoxDropDown = CheckBoxDropDown

dodo.OptionRegistrations = dodo.OptionRegistrations or {}
dodo.OptionRegistrations["party"] = dodo.OptionRegistrations["party"] or {}
table.insert(dodo.OptionRegistrations["party"], function(category)
    local layout = SettingsPanel:GetLayout(category)
    if not layout then return end

    local init_parent_lfg
    setting_parent, _, init_parent_lfg = CheckBoxDropDown(
        category, 
        "useNewLFG", 
        "soundID", 
        "파티신청 알림",
        "새로운 파티신청 시 알림", 
        dodo.newLFG_AlertSoundTable, 
        true, 
        dodo.newLFG_AlertSoundTable[2].value, 
        play_lfg_alert
    )

    local init_child_lfg
    setting_child, init_child_lfg = Checkbox(
        category, 
        "useNewLFGLeader", 
        "파티원 기능 활성화",
        "파티장원일 경우에도 활성화합니다. ", 
        true, 
        play_lfg_alert
    )

    if setting_parent and setting_child then
        setting_parent:SetValueChangedCallback(on_parent_changed)
        init_child_lfg:SetParentInitializer(init_parent_lfg, is_parent_active)
    end
end)