------------------------------
-- 테이블
------------------------------
local addonName, dodo = ...
dodoDB = dodoDB or {}

local function isIns() -- 인스확인
    local _, instanceType, difficultyID = GetInstanceInfo()
    return (difficultyID == 1 or instanceType == "raid") -- 1 일반 / 8 쐐기
end

newLFG_AlertSoundTable = {
    { label = "MurlocAggro", value = "416" },
    { label = "AuctionWindowOpen", value = "5274" },
    { label = "AuctionWindowClose", value = "5275" },
    { label = "PVPFlagTaken.Mono", value = "9378" },
    { label = "PVPFlagTakenHordeMono", value = "9379" },
    { label = "UI_QuestObjectivesComplete", value = "26905" },
    { label = "UI_RaidBossWhisperWarning", value = "37666" },
    { label = "RaidWarning", value = "8959" },
}

local alertTimer
local armedAt = 0
local lastApps = 0
local lastTrig = 0

------------------------------
-- 디스플레이
------------------------------
local newLFG_Alert = CreateFrame("Frame", "NewLFG_AlertFrame", UIParent)
newLFG_Alert:SetSize(400, 50)
newLFG_Alert:SetPoint("TOP", 50, -150)
newLFG_Alert:Hide()

newLFG_Alert.Text = newLFG_Alert:CreateFontString(nil, "OVERLAY", "GameFontNormalOutline")
newLFG_Alert.Text:SetPoint("CENTER")
local fontPath, _, fontFlags = newLFG_Alert.Text:GetFont()
newLFG_Alert.Text:SetFont(fontPath, 22, fontFlags)
newLFG_Alert.Text:SetText("[ 신규 신청 ]\n\n|cffffff00파티창을 확인하세요!|r")


------------------------------
-- 동작
------------------------------
function NewLFG()
    if isIns() or InCombatLockdown() then return end

    local isLeader = UnitIsGroupLeader("player") == true
    local useMemberAlert = dodoDB.useNewLFGLeade

    if not useMemberAlert and not isLeader then
        return
    end

    if GroupFinderFrame and not GroupFinderFrame:IsVisible() then
        PVEFrame_ShowFrame("GroupFinderFrame")
        if GroupFinderFrameGroupButton3 then
            GroupFinderFrameGroupButton3:Click()
        end
    end

    newLFG_Alert:Show()
    if alertTimer then alertTimer:Cancel() end
    alertTimer = C_Timer.After(7, function() newLFG_Alert:Hide() end)

    local soundID = (dodoDB and dodoDB.soundID) or "5274"
    PlaySound(tonumber(soundID), "Master")
end

------------------------------
-- 이벤트
------------------------------
local initNewLFG = CreateFrame("Frame")
initNewLFG:RegisterEvent("PLAYER_ENTERING_WORLD")
initNewLFG:RegisterEvent("LFG_LIST_APPLICANT_LIST_UPDATED")
initNewLFG:RegisterEvent("LFG_LIST_ACTIVE_ENTRY_UPDATE")

initNewLFG:SetScript("OnEvent", function (self, event)
    if event == "PLAYER_ENTERING_WORLD" then -- 지역 이동
        C_Timer.After(0.5, function()
            if isIns() then
                self:UnregisterEvent("LFG_LIST_APPLICANT_LIST_UPDATED")
                lastApps = 0
            else
                self:RegisterEvent("LFG_LIST_APPLICANT_LIST_UPDATED")
                local apps = C_LFGList.GetApplicants()
                lastApps = (apps and #apps) or 0
                armedAt = GetTime() + 1.5
            end
        end)
        return
    end

    if isIns() or (dodoDB and dodoDB.useNewLFG == false) then return end

    local now = GetTime() -- 신청자 확인
    local apps = C_LFGList.GetApplicants()
    local count = (apps and #apps) or 0

    if event == "LFG_LIST_ACTIVE_ENTRY_UPDATE" then -- 모집글 변경
        lastApps = count
        armedAt = now + 1.5
        return
    end

    if now >= armedAt and count > lastApps then
        if (now - lastTrig) > 1.0 then 
            NewLFG()
            lastTrig = now
        end
    end
    lastApps = count
end)

armedAt = GetTime() + 2 -- 시작 대기 시간 설정

dodo.NewLFG = NewLFG