------------------------------
-- 테이블
------------------------------
local addonName, ns = ...

local function isIns() -- 인스확인
    local _, instanceType, difficultyID = GetInstanceInfo()
    return (difficultyID == 1 or instanceType == "raid") -- 1 일반 / 8 쐐기
end

NewLFG_AlertSoundTable = {
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
local apps = C_LFGList.GetApplicants()
local armedAt = 0
local lastApps = 0
local lastTrig = 0

------------------------------
-- 디스플레이
------------------------------
local NewLFG_Alert = CreateFrame("Frame", "NewLFG_AlertFrame", UIParent)
NewLFG_Alert:SetSize(400, 50)
NewLFG_Alert:SetPoint("TOP", 50, -150)
NewLFG_Alert:Hide()

NewLFG_Alert.Text = NewLFG_Alert:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge2Outline")
NewLFG_Alert.Text:SetPoint("CENTER")
NewLFG_Alert.Text:SetText("|cffffff00[ 신규 신청 ]|r\n\n파티창을 확인하세요!")

------------------------------
-- 동작 (행동 대장)
------------------------------
function NewLFG()
    if isIns() or InCombatLockdown() then return end

    if GroupFinderFrame and not GroupFinderFrame:IsVisible() then
        PVEFrame_ShowFrame("GroupFinderFrame")
        if GroupFinderFrameGroupButton3 then
            GroupFinderFrameGroupButton3:Click()
        end
    end

    local soundID = (hodoDB and hodoDB.soundID) or "5274"
    PlaySound(soundID, "Master")

    NewLFG_Alert:Show()
    if alertTimer then alertTimer:Cancel() end -- 타이머 중첩 방지
    alertTimer = C_Timer.After(7, function() NewLFG_Alert:Hide() end)
end

------------------------------
-- 이벤트
------------------------------
local initNewLFG = CreateFrame("Frame")
initNewLFG:RegisterEvent("PLAYER_ENTERING_WORLD")
initNewLFG:RegisterEvent("LFG_LIST_APPLICANT_LIST_UPDATED")
initNewLFG:RegisterEvent("LFG_LIST_ACTIVE_ENTRY_UPDATE")

initNewLFG:SetScript("OnEvent", function (self, event, arg1)
    if event == "PLAYER_ENTERING_WORLD" then
        C_Timer.After(0.5, function()
            if isIns() then
                self:UnregisterEvent("LFG_LIST_APPLICANT_LIST_UPDATED")
                self:UnregisterEvent("LFG_LIST_ACTIVE_ENTRY_UPDATE")
                lastApps = 0
            else
                self:RegisterEvent("LFG_LIST_APPLICANT_LIST_UPDATED")
                self:RegisterEvent("LFG_LIST_ACTIVE_ENTRY_UPDATE")
                -- 밖으로 나왔을 때 초기 카운트 설정
                local apps = C_LFGList.GetApplicants()
                lastApps = (apps and #apps) or 0
                armedAt = GetTime() + 1.5
            end
        end)
        return
    end

    if isIns() then return end

    local useNewLFG = (hodoDB and hodoDB.useNewLFG ~= false)
    if not useNewLFG then return end

    if hodoDB and hodoDB.NewLFG_LeaderOnly and IsInGroup() and not UnitIsGroupLeader("player") then
        lastApps = 0
        return
    end


    local now = GetTime() -- 신청자 체크 로직
    local apps = C_LFGList.GetApplicants()
    local count = (apps and #apps) or 0

    if event == "LFG_LIST_ACTIVE_ENTRY_UPDATE" then -- 파티 모집을 등록 및 변경 시, 스팸 방지
        lastApps = count
        armedAt = now + 1.5
        return
    end

    if now >= armedAt then -- 신청자 업데이트 감지
        if count > lastApps then
            if (now - lastTrig) > 1.0 then -- 1초 내부 쿨타임
                NewLFG() -- 알림 실행
                lastTrig = now
            end
        end
    end
    lastApps = count
end)
armedAt = GetTime() + 2 -- 시작 대기 시간 설정

ns.NewLFG = NewLFG