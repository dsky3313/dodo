------------------------------
-- 테이블
------------------------------
local ADDON_NAME, NS = ...
local openRaidLib = LibStub:GetLibrary("LibOpenRaid-1.0", true)

local DungeonAbbr = {
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

local function GetMyKeyShortName(fullName) return DungeonAbbr[fullName] or fullName end

local function GetMyKeyInfo()
    local mapID = C_MythicPlus.GetOwnedKeystoneChallengeMapID()
    local level = C_MythicPlus.GetOwnedKeystoneLevel()
    if mapID and level then
        return C_ChallengeMode.GetMapUIInfo(mapID), level
    end
    return nil, nil
end

------------------------------
-- MyKey UI
------------------------------
local LFG_Title = LFGListFrame.EntryCreation.ActivityDropdown
local KeyDropDown = CreateFrame("DropdownButton", "HodoKeyCopyBtn", LFG_Title, "WowStyle1DropdownTemplate")

KeyDropDown:SetSize(175, 25)
KeyDropDown:SetPoint("TOPLEFT", LFG_Title, "BOTTOMLEFT", 0, -7)
KeyDropDown:SetPoint("TOPRIGHT", LFG_Title, "BOTTOMRIGHT", 0, -7)

local function UpdateButtonVisibility()
    if not hodoDB or hodoDB.useMyKey == false then
        KeyDropDown:Hide()
        return
    end
    
    local isTargetVisible = LFG_Title:IsVisible() and LFG_Title:GetHeight() > 1
    KeyDropDown:SetShown(isTargetVisible)
end

LFG_Title:HookScript("OnShow", UpdateButtonVisibility)
LFG_Title:HookScript("OnHide", UpdateButtonVisibility)
LFG_Title:HookScript("OnSizeChanged", function(self, width, height) UpdateButtonVisibility() end)


-- 복사창
local function CreateCopyDialog()
    local frame = CreateFrame("Frame", "HodoCopyDialog", UIParent)
    frame:SetSize(350, 110); frame:SetPoint("CENTER", 0, 150); frame:SetFrameStrata("DIALOG")
    frame:SetToplevel(true); frame:EnableMouse(true); frame:Hide()
    NineSliceUtil.ApplyLayoutByName(frame, "Dialog")
    frame.Bg = frame:CreateTexture(nil, "BACKGROUND"); frame.Bg:SetAllPoints(); frame.Bg:SetAtlas("UI-DialogBox-Background-Dark"); frame.Bg:SetAlpha(0.8)
    frame.text = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight"); frame.text:SetPoint("TOP", 0, -25); frame.text:SetText("Ctrl+C로 복사하면 자동으로 닫힙니다")
    frame.editBox = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
    frame.editBox:SetSize(260, 30); frame.editBox:SetPoint("CENTER", 0, -5); frame.editBox:SetAutoFocus(false)
    frame.editBox:SetScript("OnKeyDown", function(self, key)
        if key == "C" and IsControlKeyDown() then
            C_Timer.After(0.1, function() frame:Hide(); local nameBox = LFGListFrame.EntryCreation.Name; if nameBox and nameBox:IsVisible() then nameBox:SetFocus(); nameBox:HighlightText() end end)
        end
    end)
    frame.editBox:SetScript("OnEscapePressed", function() frame:Hide() end)
    return frame
end

local CopyDialog = CreateCopyDialog()
local function ShowCopyWindow(text)
    CopyDialog:Show(); CopyDialog.editBox:SetText(text); CopyDialog.editBox:SetFocus(); CopyDialog.editBox:HighlightText()
end

KeyDropDown:SetupMenu(function(dropdown, rootDescription)
    if InCombatLockdown() then return end
    local myName, myLevel = GetMyKeyInfo()
    if myName then
        local myTitle = string.format("+%d %s", myLevel, GetMyKeyShortName(myName))
        rootDescription:CreateButton("|cff00ff00[내 돌]|r " .. myTitle, function() ShowCopyWindow(myTitle) end)
    end
    if IsInGroup() and openRaidLib then
        local allKeys = openRaidLib.GetAllKeystonesInfo()
        for name, data in pairs(allKeys) do
            if name ~= UnitName("player") then
                local pName = name:gsub("%-.+", "")
                local dName = C_ChallengeMode.GetMapUIInfo(data.challengeMapID)
                local pTitle = string.format("+%d %s", data.level, GetMyKeyShortName(dName))
                rootDescription:CreateButton(string.format("|cff00ccff[%s]|r %s", pName, pTitle), function() ShowCopyWindow(pTitle) end)
            end
        end
    end
end)


------------------------------
-- 이벤트
------------------------------
local function Refresh()
    if InCombatLockdown() or not KeyDropDown:IsVisible() then return end
    local name, level = GetMyKeyInfo()
    KeyDropDown:SetText(name and string.format("+%d %s", level, GetMyKeyShortName(name)) or "보유 돌 없음")
end

function MykeyUpdate()
    UpdateButtonVisibility()
    Refresh()
end

local EventFrame = CreateFrame("Frame")
EventFrame:RegisterAllEvents() -- 필요한 이벤트 자동 등록
EventFrame:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_REGEN_ENABLED" then Refresh() return end
    if openRaidLib then openRaidLib.RequestKeystoneDataFromParty() end
    Refresh()
end)

LFGListFrame.EntryCreation:HookScript("OnShow", function()
    if InCombatLockdown() then
        KeyDropDown:Disable(); KeyDropDown:SetAlpha(0.5)
    else
        KeyDropDown:Enable(); KeyDropDown:SetAlpha(1)
        MykeyUpdate()
    end
end)