------------------------------
-- 테이블
------------------------------
local addonName, dodo = ...

local openRaidLib = LibStub:GetLibrary("LibOpenRaid-1.0", true)

local function isIns() -- 인스확인
    local _, instanceType, difficultyID = GetInstanceInfo()
    return (difficultyID == 8 or instanceType == "raid") -- 1 일반 / 8 쐐기
end

local dungeonName = {
    ["그림 바톨"] = "그림바톨",
    ["보랄러스 공성전"] = "보랄",
    ["죽음의 상흔"] = "죽상",
    ["티르너 사이드의 안개"] = "티르너",
    ["속죄의 전당"] = "속죄",
    ["타자베쉬: 경이의 거리"] = "거리",
    ["타자베쉬: 소레아의 승부수"] = "승부수",

    ["부화장"] = "부화장",
    ["새벽인도자호"] = "새인호",
    ["신성한 불꽃의 수도원"] = "수도원",
    ["작전명: 수문"] = "수문",
    ["실타래의 도시"] = "실타래",
    ["메아리의 도시 아라카라"] = "아라카라",
    ["생태지구 알다니"] = "알다니",
    ["잿불맥주 양조장"] = "양조장",
    ["어둠불꽃 동굴"] = "어불동",
}
local lfgPlaysStyle = LFGListEntryCreationPlayStyleDropdown

local function GetMyKeyShortName(fullName) return dungeonName[fullName] or fullName end

local function GetMyKeyInfo()
    local keyMapID = C_MythicPlus.GetOwnedKeystoneChallengeMapID()
    local keyLevel = C_MythicPlus.GetOwnedKeystoneLevel()
    if keyMapID and keyLevel then
        return C_ChallengeMode.GetMapUIInfo(keyMapID), keyLevel
    end
    return nil, nil
end

------------------------------
-- 디스플레이
------------------------------
-- 드롭다운
local keyDropDown = CreateFrame("DropdownButton", "KeyDropDownBtn", lfgPlaysStyle, "WowStyle1DropdownTemplate")
keyDropDown:SetWidth(110)
keyDropDown:SetPoint("RIGHT", lfgPlaysStyle, "LEFT", -8, 0)

-- 알림창
local copyKeyFrame = CreateFrame("Frame", nil, UIParent)
copyKeyFrame:SetSize(320, 100)
copyKeyFrame:SetPoint("TOP", UIParent, "TOP", 0, -150)
copyKeyFrame:EnableMouse(true)

copyKeyFrame.Border = CreateFrame("Frame", "copyKeyFrameBorder", copyKeyFrame, "DialogBorderTemplate")
copyKeyFrame.Header = CreateFrame("Frame", "copyKeyFrameHeader", copyKeyFrame, "DialogHeaderTemplate")
copyKeyFrame.Header:SetSize(120, 40)
copyKeyFrame.Header.Text:SetWidth(120)
copyKeyFrame.Header.Text:SetText("돌 정보 복사")

copyKeyFrame.text = copyKeyFrame:CreateFontString("copyKeyFrameText", "OVERLAY", "GameFontHighlight")
copyKeyFrame.text:SetPoint("TOP", 0, -36)
copyKeyFrame.text:SetText("Ctrl+C로 복사하세요")

copyKeyFrame.editBox = CreateFrame("EditBox", "copyKeyFrameEditbox", copyKeyFrame, "InputBoxInstructionsTemplate")
copyKeyFrame.editBox.Instructions:SetText("쐐기돌 던전명")
copyKeyFrame.editBox:SetSize(260, 20)
copyKeyFrame.editBox:SetPoint("BOTTOM", 0, 24)
copyKeyFrame.editBox:SetAutoFocus(false)

copyKeyFrame:Hide()

------------------------------
-- 동작
------------------------------
local function ShowCopyWindow(text) -- 복사창 띄우기
    copyKeyFrame:Show()
    copyKeyFrame.editBox:SetText(text)
    copyKeyFrame.editBox:SetFocus()
    copyKeyFrame.editBox:HighlightText()
end

local function RefreshKeyInfo() -- 돌 새로고침
    if InCombatLockdown() or not keyDropDown:IsVisible() then return end
    local name, level = GetMyKeyInfo()
    keyDropDown:SetText(name and string.format("+%d %s", level, GetMyKeyShortName(name)) or "보유 돌 없음")
end

local function MyKey()
    local isEnabled = dodoDB.usePartyClass ~= false -- 기본값 true
    if not isEnabled or isIns() then
        keyDropDown:Hide()
        return
    end

    local isTargetVisible = lfgPlaysStyle:IsVisible() and lfgPlaysStyle:GetHeight() > 1
    keyDropDown:SetShown(isTargetVisible)
    if isTargetVisible then
        RefreshKeyInfo()
        C_Timer.After(0.1, RefreshKeyInfo)
    end
end

-- 복사창닫기
copyKeyFrame:SetScript("OnMouseDown", function() copyKeyFrame:Hide() end)
copyKeyFrame.editBox:SetScript("OnEscapePressed", function() copyKeyFrame:Hide() end)
copyKeyFrame.editBox:SetScript("OnEditFocusLost", function() copyKeyFrame:Hide() end)
copyKeyFrame.editBox:SetScript("OnKeyDown", function(self, key)
    if key == "C" and IsControlKeyDown() then
        C_Timer.After(0.1, function()
            copyKeyFrame:Hide()
            local keyNameBox = LFGListFrame.EntryCreation.Name
            if keyNameBox and keyNameBox:IsVisible() then
                keyNameBox:SetFocus()
                keyNameBox:HighlightText()
            end
        end)
    end
end)

-- 드롭다운 메뉴
keyDropDown:SetupMenu(function(dropdown, rootDescription)
    if InCombatLockdown() then return end

    if IsInGroup() and openRaidLib then
        openRaidLib.RequestKeystoneDataFromParty()
    end

    local myName, myLevel = GetMyKeyInfo()
    if myName then
        local myTitle = string.format("+%d %s", myLevel, GetMyKeyShortName(myName))
        rootDescription:CreateButton("|cff00ff00[내 돌]|r " .. myTitle, function() ShowCopyWindow(myTitle) end)
    end

    if IsInGroup() and openRaidLib then
        local partyKeys = openRaidLib.GetAllKeystonesInfo()
        local hasPartyKey = false

        for name, data in pairs(partyKeys) do
            if name ~= UnitName("player") and data.challengeMapID then
                if UnitInParty(name) or UnitInRaid(name) then
                    local dName = C_ChallengeMode.GetMapUIInfo(data.challengeMapID)
                    if dName then
                        hasPartyKey = true
                        local pTitle = string.format("+%d %s", data.level, GetMyKeyShortName(dName))
                        local cleanName = name:gsub("%-.+", "") -- 화면 표시용 서버명 제거
                        rootDescription:CreateButton(string.format("|cff00ccff[%s]|r %s", cleanName, pTitle), function() ShowCopyWindow(pTitle) end)
                    end
                end
            end
        end

        if not hasPartyKey and GetNumGroupMembers() > 1 then
            rootDescription:CreateButton("|cffaaaaaa(파티원 정보 로딩 중...)|r", function() end)
        end
    end
end)

------------------------------
-- 이벤트
------------------------------
local initMyKey = CreateFrame("Frame")
initMyKey:RegisterEvent("ADDON_LOADED")
initMyKey:RegisterEvent("PLAYER_ENTERING_WORLD")
initMyKey:SetScript("OnEvent", function (self, event, arg1)
    if event == "PLAYER_ENTERING_WORLD" then
        C_Timer.After(1.0, function () -- 0.5초에서 1초로 약간 여유를 둠
            if isIns() then
                self:UnregisterEvent("BAG_UPDATE_DELAYED")
                self:UnregisterEvent("CHALLENGE_MODE_COMPLETED")
                self:UnregisterEvent("GROUP_ROSTER_UPDATE")
            else
                self:RegisterEvent("BAG_UPDATE_DELAYED")
                self:RegisterEvent("CHALLENGE_MODE_COMPLETED")
                self:RegisterEvent("GROUP_ROSTER_UPDATE")
                MyKey()
            end
        end)
    elseif event == "ADDON_LOADED" and arg1 == addonName then
        if lfgPlaysStyle then
            lfgPlaysStyle:HookScript("OnShow", MyKey)
        end
        if LFGListFrame.EntryCreation then
            LFGListFrame.EntryCreation:HookScript("OnShow", MyKey)
        end
    else
        -- 필드에서의 데이터 갱신
        if not isIns() then
            if event == "GROUP_ROSTER_UPDATE" then
                if openRaidLib then
                    openRaidLib.RequestKeystoneDataFromParty()
                end
                -- 데이터가 도달할 시간을 위해 약간 지연 후 갱신
                C_Timer.After(1.0, RefreshKeyInfo)
            else
                RefreshKeyInfo()
            end
        end
    end
end)

dodo.MyKey = MyKey