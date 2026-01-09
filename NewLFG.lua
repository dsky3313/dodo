------------------------------
-- 테이블
------------------------------
NewLFG_AlertSoundTable = {
    { CheckboxDropdownText = "MurlocAggro", CheckboxDropdownTextValue = "416" },
    { CheckboxDropdownText = "AuctionWindowOpen", CheckboxDropdownTextValue = "5274" },
    { CheckboxDropdownText = "AuctionWindowClose", CheckboxDropdownTextValue = "5275" },
    { CheckboxDropdownText = "PVPFlagTaken.Mono", CheckboxDropdownTextValue = "9378" },
    { CheckboxDropdownText = "PVPFlagTakenHordeMono", CheckboxDropdownTextValue = "9379" },
    { CheckboxDropdownText = "UI_QuestObjectivesComplete", CheckboxDropdownTextValue = "26905" },
    { CheckboxDropdownText = "UI_RaidBossWhisperWarning", CheckboxDropdownTextValue = "37666" },
    { CheckboxDropdownText = "RaidWarning", CheckboxDropdownTextValue = "8959" },
}




local lastApps = 0
local armedAt = 0
local lastTrig = 0

------------------------------
-- NewLFG UI
------------------------------
local NewLFG_Alert = CreateFrame("Frame", "NewLFG_AlertFrame", UIParent)
NewLFG_Alert:SetSize(400, 50)
NewLFG_Alert:SetPoint("TOP", 50, -150)
NewLFG_Alert:Hide()

NewLFG_Alert.Text = NewLFG_Alert:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
NewLFG_Alert.Text:SetPoint("CENTER")
NewLFG_Alert.Text:SetText("|cffffff00[ 신규 신청 ]|r\n\n파티창을 확인하세요!")

------------------------------
-- NewLFG func
------------------------------
function NewLFG()
    if not InCombatLockdown() then
        if not GroupFinderFrame:IsVisible() then
            PVEFrame_ShowFrame("GroupFinderFrame")
            GroupFinderFrameGroupButton3:Click()
        end
    end

    local NewLFG_AlertSoundTableID = hodoDB and hodoDB.NewLFG_AlertSoundTableID or "5274" -- 소리 재생
    PlaySound(NewLFG_AlertSoundTableID, "Master")

    NewLFG_Alert:Show() -- 메시지 
    C_Timer.After(7, function() NewLFG_Alert:Hide() end)
end

local function OnLFGUpdate(self, event)
    if not hodoDB or not hodoDB.useNewLFG then return end
    
    if hodoDB.NewLFG_LeaderOnly then
        if IsInGroup() and not UnitIsGroupLeader("player") then
            lastApps = 0
            return
        end
    end

    if not (C_LFGList.HasActiveEntryInfo and C_LFGList.HasActiveEntryInfo()) then
        lastApps = 0
        return
    end

    local now = GetTime()
    if now < armedAt then
        local a = C_LFGList.GetApplicants()
        lastApps = (a and #a) or 0
        return
    end

    if event == "LFG_LIST_ACTIVE_ENTRY_UPDATE" or event == "PLAYER_ENTERING_WORLD" then
        local a = C_LFGList.GetApplicants()
        lastApps = (a and #a) or 0
        armedAt = now + 1.5
        return
    end

    local apps = C_LFGList.GetApplicants()
    local count = (apps and #apps) or 0
    
    if count > lastApps then
        if (now - lastTrig) > 1.0 then 
            NewLFG()
            lastTrig = now
        end
    end
    
    lastApps = count
end

------------------------------
-- 이벤트 등록 및 스크립트 연결
------------------------------
local initNewLFG = CreateFrame("Frame")
initNewLFG:RegisterEvent("LFG_LIST_APPLICANT_LIST_UPDATED")
initNewLFG:RegisterEvent("LFG_LIST_ACTIVE_ENTRY_UPDATE")
initNewLFG:RegisterEvent("PLAYER_ENTERING_WORLD")
initNewLFG:SetScript("OnEvent", OnLFGUpdate)
armedAt = GetTime() + 2

------------------------------
-- 테스트 명령어 (/11)
------------------------------
SLASH_HODOTEST1 = "/11"
SlashCmdList["HODOTEST"] = function()
    print("|cff00ccff[Hodo]|r 파티 신청 알림 테스트를 실행합니다.")
    NewLFG()
end