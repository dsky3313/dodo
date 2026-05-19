-- ==============================
-- Inspired
-- ==============================
-- 파티 구인 중 새로운 신청자 알림 위크오라 (https://www.inven.co.kr/board/wow/5297/7283)

-- ==============================
-- 설정 및 테이블
-- ==============================
---@diagnostic disable: lowercase-global, param-type-mismatch, redundant-parameter, undefined-field, undefined-global
local addonName, dodo = ...
local module = {}
dodo:RegisterModule("NewLFG", module)

dodo.newLFG_AlertSoundTable = {
    { label = "MurlocAggro", value = "416" },
    { label = "AuctionWindowOpen", value = "5274" },
    { label = "AuctionWindowClose", value = "5275" },
    { label = "PVPFlagTaken.Mono", value = "9378" },
    { label = "PVPFlagTakenHordeMono", value = "9379" },
    { label = "UI_QuestObjectivesComplete", value = "26905" },
    { label = "UI_RaidBossWhisperWarning", value = "11773" },
    { label = "RaidWarning", value = "8959" },
    { label = "HumanFemaleStandardNPCGreetings", value = "552141" },
}

-- ==============================
-- 캐싱
-- ==============================
-- 함수
local CreateFrame = CreateFrame
local GetInstanceInfo = GetInstanceInfo
local GetTime = GetTime
local InCombatLockdown = InCombatLockdown
local PlaySound = PlaySound
local PlaySoundFile = PlaySoundFile
local tonumber = tonumber
local UnitIsGroupLeader = UnitIsGroupLeader
local GetNumApplicants = C_LFGList.GetNumApplicants

-- 변수
local C_LFGList = C_LFGList
local C_Timer = C_Timer
local GroupFinderFrame = GroupFinderFrame
local GroupFinderFrameGroupButton3 = GroupFinderFrameGroupButton3
local PVEFrame_ShowFrame = PVEFrame_ShowFrame
local UIParent = UIParent

local function isIns()
    local _, instanceType, difficultyID = GetInstanceInfo()
    return (difficultyID == 8 or instanceType == "raid")
end

local alertTimer
local armedAt = 0
local lastApps = 0
local lastTrig = 0

-- ==============================
-- 디스플레이
-- ==============================
local newLFG_Alert = CreateFrame("Frame", "NewLFG_AlertFrame", UIParent)
newLFG_Alert:SetSize(400, 50)
newLFG_Alert:SetPoint("TOP", 50, -150)
newLFG_Alert:Hide()

newLFG_Alert.Text = newLFG_Alert:CreateFontString(nil, "OVERLAY", "GameFontNormalOutline")
newLFG_Alert.Text:SetPoint("CENTER")
local fontPath, _, fontFlags = newLFG_Alert.Text:GetFont()
newLFG_Alert.Text:SetFont(fontPath or "fonts/frizqt__.ttf", 22, fontFlags)
newLFG_Alert.Text:SetText("[ 신규 신청 ]\n\n|cffffff00파티창을 확인하세요!|r")

-- ==============================
-- 동작
-- ==============================
function NewLFG()
    if InCombatLockdown() then return end

    local isLeader = UnitIsGroupLeader("player") == true
    local useMemberAlert = dodo.DB.useNewLFGLeader
    if not useMemberAlert and not isLeader then return end

    if GroupFinderFrame and not GroupFinderFrame:IsVisible() then
        PVEFrame_ShowFrame("GroupFinderFrame")
        if GroupFinderFrameGroupButton3 then GroupFinderFrameGroupButton3:Click() end
    end

    if not newLFG_Alert:IsShown() then
        newLFG_Alert:Show()
    end
    
    if alertTimer then alertTimer:Cancel() end
    alertTimer = C_Timer.After(7, function() 
        if newLFG_Alert:IsShown() then newLFG_Alert:Hide() end 
    end)

    local soundID = (dodo.DB and dodo.DB.soundID) or "5274"
    local sID = tonumber(soundID) or 5274

    if sID > 100000 then
        PlaySoundFile(sID, "Master")
    else
        PlaySound(sID, "Master")
    end
end

-- ==============================
-- 이벤트
-- ==============================
local initNewLFG = CreateFrame("Frame")

-- 이벤트 등록/해제를 관리하여 성능 최적화
local function UpdateNewLFGRegistration()
    if not initNewLFG then return end
    
    local isEnabled = (dodo.DB and dodo.DB.useNewLFG ~= false)
    local inInstance = isIns()

    -- 기능이 켜져 있고 인스턴스가 아닐 때만 작동
    if isEnabled and not inInstance then
        initNewLFG:RegisterEvent("LFG_LIST_APPLICANT_LIST_UPDATED")
        initNewLFG:RegisterEvent("LFG_LIST_ACTIVE_ENTRY_UPDATE")
        
        -- 현재 상태 초기화
        lastApps = GetNumApplicants() or 0
        armedAt = GetTime() + 1.5
    else
        initNewLFG:UnregisterEvent("LFG_LIST_APPLICANT_LIST_UPDATED")
        initNewLFG:UnregisterEvent("LFG_LIST_ACTIVE_ENTRY_UPDATE")
        lastApps = 0
    end
end

initNewLFG:SetScript("OnEvent", function(self, event)
    local now = GetTime()
    local count = GetNumApplicants() or 0

    if event == "LFG_LIST_ACTIVE_ENTRY_UPDATE" then
        lastApps = count
        armedAt = now + 1.5
        return
    end

    if event == "LFG_LIST_APPLICANT_LIST_UPDATED" then
        if now >= armedAt and count > lastApps then
            if (now - lastTrig) > 1.0 then
                NewLFG()
                lastTrig = now
            end
        end
        lastApps = count
    end
end)

function module:OnEnable()
    local initializer = CreateFrame("Frame")
    initializer:RegisterEvent("PLAYER_ENTERING_WORLD")
    initializer:SetScript("OnEvent", function(self, event, arg1)
        if event == "PLAYER_ENTERING_WORLD" then
            UpdateNewLFGRegistration()
        end
    end)
    armedAt = GetTime() + 2
end

-- ==============================
-- 설정
-- ==============================
function module:CreateOptions()
    local settingParentNewLFG, _, initParentNewLFG = dodo.UI.CheckBoxDropDown(dodo.subCategoryParty, "useNewLFG", "soundID", "파티신청 알림",
    "새로운 파티신청 시 알림", dodo.newLFG_AlertSoundTable, false, dodo.newLFG_AlertSoundTable[2].value, NewLFG)
    local settingChildNewLFG, initChildNewLFG = dodo.UI.Checkbox(dodo.subCategoryParty, "useNewLFGLeader", "파티원 기능 활성화",
    "파티장원일 경우에도 활성화합니다. ", false, NewLFG)
    if settingParentNewLFG and settingChildNewLFG then
        settingParentNewLFG:SetValueChangedCallback(function(_, value)
            if value == false then
                settingChildNewLFG:SetValue(false) -- 부모가 꺼지면 자식도 끔
            end
        end)
        initChildNewLFG:SetParentInitializer(initParentNewLFG, function()
            return settingParentNewLFG:GetValue()
        end)
    end
end