------------------------------
-- 테이블 (변경 금지)
------------------------------
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

local lastApps = 0
local armedAt = 0
local lastTrig = 0
local alertTimer

------------------------------
-- 디스플레이
------------------------------
local NewLFG_Alert = CreateFrame("Frame", "NewLFG_AlertFrame", UIParent)
NewLFG_Alert:SetSize(400, 50)
NewLFG_Alert:SetPoint("TOP", 50, -150)
NewLFG_Alert:Hide()

NewLFG_Alert.Text = NewLFG_Alert:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
NewLFG_Alert.Text:SetPoint("CENTER")
NewLFG_Alert.Text:SetText("|cffffff00[ 신규 신청 ]|r\n\n파티창을 확인하세요!")

------------------------------
-- 동작 (행동 대장)
------------------------------
function NewLFG()
    if not InCombatLockdown() then
        if GroupFinderFrame and not GroupFinderFrame:IsVisible() then
            PVEFrame_ShowFrame("GroupFinderFrame")
            if GroupFinderFrameGroupButton3 then
                GroupFinderFrameGroupButton3:Click()
            end
        end
    end

    local soundID = (hodoDB and hodoDB.NewLFG_AlertSoundTableID) or "5274"
    PlaySound(soundID, "Master")

    NewLFG_Alert:Show()
    -- 타이머 중첩 방지 (기존 예약 취소 후 재예약)
    if alertTimer then alertTimer:Cancel() end
    alertTimer = C_Timer.After(7, function() NewLFG_Alert:Hide() end)
end

------------------------------
-- 이벤트 (감시관)
------------------------------
local function OnLFGUpdate(self, event)
    -- [1] 인스턴스(던전/레이드) 체크: 성능 최적화
    local inInstance, instanceType = IsInInstance()
    if inInstance and instanceType ~= "none" then
        self:UnregisterAllEvents()
        self:RegisterEvent("PLAYER_ENTERING_WORLD") -- 밖으로 나갈 때 감지용
        lastApps = 0
        return
    end

    -- [2] DB 초기화 및 사용 여부 체크
    hodoDB = hodoDB or { useNewLFG = true }
    if not hodoDB.useNewLFG then return end

    -- [3] 파티장 체크
    if hodoDB.NewLFG_LeaderOnly and IsInGroup() and not UnitIsGroupLeader("player") then
        lastApps = 0
        return
    end

    -- [4] 모집글 활성화 여부에 따른 이벤트 제어
    local hasEntry = C_LFGList.HasActiveEntryInfo and C_LFGList.HasActiveEntryInfo()
    if not hasEntry then
        self:UnregisterEvent("LFG_LIST_APPLICANT_LIST_UPDATED")
        lastApps = 0
        return
    else
        self:RegisterEvent("LFG_LIST_APPLICANT_LIST_UPDATED")
    end

    -- [5] 신청자 비교 로직
    local now = GetTime()
    local apps = C_LFGList.GetApplicants()
    local count = (apps and #apps) or 0

    -- 접속/로딩 직후 뻥튀기 방지
    if now < armedAt then
        lastApps = count
        return
    end

    -- 상태 변경 시 데이터 동기화
    if event == "LFG_LIST_ACTIVE_ENTRY_UPDATE" or event == "PLAYER_ENTERING_WORLD" then
        lastApps = count
        armedAt = now + 1.5
        return
    end

    -- 신규 신청자 감지
    if count > lastApps then
        if (now - lastTrig) > 1.0 then -- 1초 스팸 방지
            NewLFG()
            lastTrig = now
        end
    end
    lastApps = count
end

------------------------------
-- 이벤트 등록 (수신기)
------------------------------
local initNewLFG = CreateFrame("Frame")
initNewLFG:RegisterEvent("LFG_LIST_APPLICANT_LIST_UPDATED")
initNewLFG:RegisterEvent("LFG_LIST_ACTIVE_ENTRY_UPDATE")
initNewLFG:RegisterEvent("PLAYER_ENTERING_WORLD")
initNewLFG:SetScript("OnEvent", OnLFGUpdate)

-- 시작 대기 시간 설정
armedAt = GetTime() + 2