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
    { text = "멀록", value = "416" },
    { text = "경매장 1", value = "5274" },
    { text = "경매장 2", value = "5275" },
    { text = "PVP 1", value = "9378" },
    { text = "PVP 2", value = "9379" },
    { text = "퀘스트", value = "26905" },
    { text = "공격대 1", value = "8959" },
    { text = "공격대 2", value = "11773" },
    { text = "인간여성", value = "552141" },
}

-- ==============================
-- 캐싱
-- ==============================
local C_LFGList = C_LFGList
local C_Timer = C_Timer
local CreateFrame = CreateFrame
local GetInstanceInfo = GetInstanceInfo
local GetTime = GetTime
local GroupFinderFrame = GroupFinderFrame
local GroupFinderFrameGroupButton3 = GroupFinderFrameGroupButton3
local InCombatLockdown = InCombatLockdown
local PlaySound = PlaySound
local PlaySoundFile = PlaySoundFile
local PVEFrame_ShowFrame = PVEFrame_ShowFrame
local tonumber = tonumber
local UIParent = UIParent
local UnitIsGroupLeader = UnitIsGroupLeader
local GetNumApplicants = C_LFGList.GetNumApplicants

-- ==============================
-- 상태 변수
-- ==============================
local alertTimer
local armedAt = 0
local lastApps = 0
local lastTrig = 0

local function isIns()
    local _, instanceType, difficultyID = GetInstanceInfo()
    return (difficultyID == 8 or instanceType == "raid")
end

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
-- 기능 1: 신청 알림
-- ==============================
local function play_newLFG_alert()
    if InCombatLockdown() then return end

    local isLeader = UnitIsGroupLeader("player") == true
    -- [임시 비활성화] 파티원일 때 알림 기능 비활성화 (방장 전용)
    -- local useMemberAlert = dodo.DB and dodo.DB.useNewLFGLeader
    -- if not useMemberAlert and not isLeader then return end
    if not isLeader then return end

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
NewLFG = play_newLFG_alert -- 전역 역호환성 유지용 바인딩

-- ==============================
-- 이벤트 및 알림 제어
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
    
    if event == "PLAYER_ENTERING_WORLD" then
        UpdateNewLFGRegistration()
        return
    end

    local count = GetNumApplicants() or 0

    if event == "LFG_LIST_ACTIVE_ENTRY_UPDATE" then
        lastApps = count
        armedAt = now + 1.5
        return
    end

    if event == "LFG_LIST_APPLICANT_LIST_UPDATED" then
        if now >= armedAt and count > lastApps then
            if (now - lastTrig) > 1.0 then
                play_newLFG_alert()
                lastTrig = now
            end
        end
        lastApps = count
    end
end)

-- ==============================
-- 모듈 생명주기
-- ==============================
function module:OnEnable()
    -- DB 설정 초기값 세팅 (파티원일 때도 알림 기본 비활성화)
    if dodo.DB then
        if dodo.DB.useNewLFGLeader == nil then
            dodo.DB.useNewLFGLeader = false
        end
    end

    -- 일회성 프레임 대신 단일 initNewLFG 프레임을 활용해 메모리 & 이벤트 감지 성능 최적화
    initNewLFG:RegisterEvent("PLAYER_ENTERING_WORLD")
    UpdateNewLFGRegistration()
    armedAt = GetTime() + 2

    -- dodoEditModePanel 내부에 2열 그리드로 세부 설정 주입
    if dodo.RegisterEditModeSetting then
        dodo.RegisterEditModeSetting("음성", {
            {
                name = "파티신청 알림",
                get = function() return dodo.DB and dodo.DB.useNewLFG ~= false end,
                set = function(checked)
                    if dodo.DB then dodo.DB.useNewLFG = checked end
                    UpdateNewLFGRegistration()
                end
            },
            {
                type = "dropdown",
                get = function() return dodo.DB and dodo.DB.soundID or "5274" end,
                set = function(val)
                    if dodo.DB then dodo.DB.soundID = val end
                    -- 테스트 음성 출력 (방장/파티 조건 없이 소리만)
                    local sID = tonumber(val) or 5274
                    if sID > 100000 then
                        PlaySoundFile(sID, "Master")
                    else
                        PlaySound(sID, "Master")
                    end
                end,
                values = dodo.newLFG_AlertSoundTable
            },
            -- [임시 비활성화]
            -- {
            --     name = "파티원일 때도 알림",
            --     get = function() return dodo.DB and dodo.DB.useNewLFGLeader or false end,
            --     set = function(checked)
            --         if dodo.DB then dodo.DB.useNewLFGLeader = checked end
            --     end
            -- },
            { isSpacer = true }
        })
    end
end