------------------------------
-- 테이블
------------------------------
local addonName, dodo = ...
dodoDB = dodoDB or {}

local function isIns() -- 인스확인
    local _, instanceType, difficultyID = GetInstanceInfo()
    return (difficultyID == 8 or instanceType == "raid") -- 1 일반 / 8 쐐기 / raid 레이드
end

local initialized = false
local LFGListFrame

------------------------------
-- 디스플레이
------------------------------
local browseGroupsBtn = CreateFrame("Button", "browseGroupsBtn", UIParent, "UIPanelButtonTemplate")
browseGroupsBtn:SetSize(144, 22)
browseGroupsBtn:SetText("파티 탐색하기")
browseGroupsBtn:Hide()

local function anchorBrowseGroupBtn()
    browseGroupsBtn:SetParent(LFGListFrame)
    browseGroupsBtn:ClearAllPoints()
    browseGroupsBtn:SetPoint("TOP", LFGListFrame, "BOTTOM", -100, 26)
end

local returnGroupsBtn = CreateFrame("Button", "returnGroupsBtn", UIParent, "UIPanelButtonTemplate")
returnGroupsBtn:SetSize(144, 22)
returnGroupsBtn:SetText("파티로 돌아가기")
returnGroupsBtn:Hide()

local function anchorReturnGroupsBtn()
    returnGroupsBtn:SetParent(LFGListFrame)
    returnGroupsBtn:ClearAllPoints()
    returnGroupsBtn:SetPoint("TOP", LFGListFrame, "BOTTOM", -100, 26)
end

------------------------------
-- 동작
------------------------------
local function updateBtn()
    local isEnabled = (dodoDB.useBrowseGroup ~= false) -- 기본값 true

    if not LFGListFrame or isIns() or not isEnabled then
        browseGroupsBtn:Hide()
        returnGroupsBtn:Hide()
        return
    end

    local joinedGroup = C_LFGList.GetActiveEntryInfo() ~= nil
    local isLeader = UnitIsGroupLeader("player") == true
    local shownApp = LFGListFrame.ApplicationViewer and LFGListFrame.ApplicationViewer:IsShown()
    local shownSearch = LFGListFrame.SearchPanel and LFGListFrame.SearchPanel:IsShown()

    if shownApp and (not isLeader) and joinedGroup then -- 탐색하기 (파티 창 + 내가 파티장이 아닐 때)
        browseGroupsBtn:Show()
    else
        browseGroupsBtn:Hide()
    end

    if shownSearch and joinedGroup then -- 돌아가기 (파티목록 + 등록된 파티가 있을 때)
        returnGroupsBtn:Show()
    else
        returnGroupsBtn:Hide()
    end
end

local function initBtn()
    local isEnabled = (dodoDB.useBrowseGroup ~= false) -- 기본값 true
    LFGListFrame = _G.LFGListFrame

    if not LFGListFrame or initialized or not isEnabled then return end

    anchorBrowseGroupBtn()
    anchorReturnGroupsBtn()

    browseGroupsBtn:SetScript("OnClick", function() -- 파티 탐색하기
        if LFGListFrame.ApplicationViewer then
            local bgb = LFGListFrame.ApplicationViewer.BrowseGroupsButton
            if bgb and bgb:IsEnabled() then bgb:Click() end
        end
    end)

    local backBtn = LFGListFrame.SearchPanel and LFGListFrame.SearchPanel.BackButton -- 파티로 돌아가기
    if backBtn then
        returnGroupsBtn:SetFrameStrata(backBtn:GetFrameStrata())
        returnGroupsBtn:SetFrameLevel(backBtn:GetFrameLevel() + 10)
    end
    returnGroupsBtn:Hide()

    returnGroupsBtn:SetScript("OnClick", function()
        if not C_LFGList.GetActiveEntryInfo() then return end
        if LFGListFrame.ApplicationViewer then
            C_Timer.After(0, function()
                LFGListFrame_SetActivePanel(LFGListFrame, LFGListFrame.ApplicationViewer)
            end)
        end
    end)

    LFGListFrame.ApplicationViewer:HookScript("OnShow", updateBtn) -- hook
    LFGListFrame.SearchPanel:HookScript("OnShow", updateBtn)
    LFGListFrame:HookScript("OnHide", function()
        if browseGroupsBtn then browseGroupsBtn:Hide() end
        if returnGroupsBtn  then returnGroupsBtn:Hide()  end
    end)

    initialized = true
    updateBtn()
end

------------------------------
-- 이벤트
------------------------------
local initBrowseGroupBtn = CreateFrame("Frame")
initBrowseGroupBtn:RegisterEvent("ADDON_LOADED")
initBrowseGroupBtn:RegisterEvent("GROUP_ROSTER_UPDATE")
initBrowseGroupBtn:RegisterEvent("LFG_LIST_ACTIVE_ENTRY_UPDATE")

initBrowseGroupBtn:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == "Blizzard_GroupFinder" then
        initBtn()
    elseif event == "GROUP_ROSTER_UPDATE" or event == "LFG_LIST_ACTIVE_ENTRY_UPDATE" then
        if not initialized then initBtn() else updateBtn() end
    end
end)

if C_AddOns and C_AddOns.IsAddOnLoaded("Blizzard_GroupFinder") then
    initBtn()
end

dodo.BrowseGroup = updateBtn