------------------------------
-- 테이블
------------------------------
local addonName, ns = ...

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
    ["미지의 시장 타자베쉬: 경이의 거리"] = "거리",
    ["미지의 시장 타자베쉬: 소레아의 승부수"] = "승부수",

    ["부화장"] = "부화장",
    ["새벽인도자호"] = "새인호",
    ["신성한 불꽃의 수도원"] = "수도원",
    ["작전명: 수문"] = "수문",
    ["실타래의 도시"] = "실타래",
    ["아라카라: 메아리의 도시"] = "아라카라",
    ["생태지구 알다니"] = "알다니",
    ["잿불맥주 양조장"] = "양조장",
    ["어둠불꽃 동굴"] = "어불동",
}
local lfgDifficulty = LFGListFrame.EntryCreation.ActivityDropdown

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
local keyDropDown = CreateFrame("DropdownButton", "KeyDropDownBtn", lfgDifficulty, "WowStyle1DropdownTemplate")
keyDropDown:SetWidth(138)
keyDropDown:SetPoint("TOP", lfgDifficulty, "BOTTOM", 0, -7)

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
    local isEnabled = hodoDB.useMyKey ~= false -- 기본값 true
    if not isEnabled or isIns() then
        keyDropDown:Hide()
        return
    end

    local isTargetVisible = lfgDifficulty:IsVisible() and lfgDifficulty:GetHeight() > 1
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

-- 드롭다운 메뉴 내용물
keyDropDown:SetupMenu(function(dropdown, rootDescription)
    if InCombatLockdown() then return end
    local myName, myLevel = GetMyKeyInfo()
    if myName then
        local myTitle = string.format("+%d %s", myLevel, GetMyKeyShortName(myName))
        rootDescription:CreateButton("|cff00ff00[내 돌]|r " .. myTitle, function() ShowCopyWindow(myTitle) end)
    end
    if IsInGroup() and openRaidLib then
        local partyKeys = openRaidLib.GetAllKeystonesInfo()
        for name, data in pairs(partyKeys) do
            if name ~= UnitName("player") then
                local dName = C_ChallengeMode.GetMapUIInfo(data.challengeMapID)
                local pTitle = string.format("+%d %s", data.level, GetMyKeyShortName(dName))
                rootDescription:CreateButton(string.format("|cff00ccff[%s]|r %s", name:gsub("%-.+", ""), pTitle), function() ShowCopyWindow(pTitle) end)
            end
        end
    end
end)

ns.MyKey = MyKey

------------------------------
-- 이벤트
------------------------------
local initMyKey = CreateFrame("Frame")
initMyKey:RegisterEvent("ADDON_LOADED")
initMyKey:RegisterEvent("PLAYER_ENTERING_WORLD")
initMyKey:SetScript("OnEvent", function (self, event, arg1)
    if event == "PLAYER_ENTERING_WORLD" then
        C_Timer.After(0.5, function ()
            if isIns() then
                initMyKey:UnregisterEvent("BAG_UPDATE_DELAYED")
                initMyKey:UnregisterEvent("CHALLENGE_MODE_COMPLETED")
                initMyKey:UnregisterEvent("GROUP_ROSTER_UPDATE")
            else
                initMyKey:RegisterEvent("BAG_UPDATE_DELAYED")
                initMyKey:RegisterEvent("CHALLENGE_MODE_COMPLETED")
                initMyKey:RegisterEvent("GROUP_ROSTER_UPDATE")
                MyKey()
            end
        end)
    elseif event == "ADDON_LOADED" and arg1 == addonName then
        lfgDifficulty:HookScript("OnShow", MyKey)
        LFGListFrame.EntryCreation:HookScript("OnShow", MyKey)
    else
        if not isIns() then
            if event == "GROUP_ROSTER_UPDATE" and openRaidLib then
                openRaidLib.RequestKeystoneDataFromParty()
            end
            RefreshKeyInfo()
        end
    end
end)