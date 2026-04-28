-- ==============================
-- Inspired
-- ==============================
-- 11.2 파티 탐색하기 버튼 (BrowseGroupsButton) (https://wago.io/JaYwj48fu)

-- ==============================
-- 테이블
-- ==============================
---@diagnostic disable: lowercase-global, undefined-field
local addonName, dodo = ...
dodoDB = dodoDB or {}

local initialized = false
local LFGListFrame

-- ==============================
-- 디스플레이
-- ==============================
local browseGroupsBtn = CreateFrame("Button", "browseGroupsBtn", UIParent, "UIPanelButtonTemplate")
browseGroupsBtn:SetSize(144, 22)
browseGroupsBtn:SetText(GROUP_FINDER_BROWSE or "파티 탐색하기")
browseGroupsBtn:Hide()

local returnGroupsBtn = CreateFrame("Button", "returnGroupsBtn", UIParent, "UIPanelButtonTemplate")
returnGroupsBtn:SetSize(144, 22)
returnGroupsBtn:SetText(GROUP_FINDER_BACK_TO_GROUP or "파티로 돌아가기")
returnGroupsBtn:Hide()

-- ==============================
-- 동작
-- ==============================
local function updateBtn()
    local isEnabled = (dodoDB.useBrowseGroup ~= false)

    if not LFGListFrame or not isEnabled then
        browseGroupsBtn:Hide()
        returnGroupsBtn:Hide()
        return
    end

    local active = C_LFGList.GetActiveEntryInfo() ~= nil
    local isLeader = UnitIsGroupLeader("player")
    
    local shownApp = LFGListFrame.ApplicationViewer and LFGListFrame.ApplicationViewer:IsShown()
    local shownSearch = LFGListFrame.SearchPanel and LFGListFrame.SearchPanel:IsShown()

    -- 1. [파티 탐색하기]
    if shownApp and (not isLeader) and active then
        browseGroupsBtn:Show()
    else
        browseGroupsBtn:Hide()
    end

    -- 2. [파티로 돌아가기]
    if shownSearch and active then
        returnGroupsBtn:Show()
    else
        returnGroupsBtn:Hide()
    end
end

local function initBtn()
    LFGListFrame = _G.LFGListFrame
    if not LFGListFrame or initialized then return end
    
    browseGroupsBtn:SetParent(LFGListFrame)
    browseGroupsBtn:ClearAllPoints()
    browseGroupsBtn:SetPoint("TOP", LFGListFrame, "BOTTOM", -100, 26)

    returnGroupsBtn:SetParent(LFGListFrame)
    returnGroupsBtn:ClearAllPoints()
    returnGroupsBtn:SetPoint("TOP", LFGListFrame, "BOTTOM", -100, 26)

    local backBtn = LFGListFrame.SearchPanel and LFGListFrame.SearchPanel.BackButton
    if backBtn then
        local strata = backBtn:GetFrameStrata()
        -- 레이어를 확실히 높여서 가려지지 않게 함
        browseGroupsBtn:SetFrameStrata(strata); browseGroupsBtn:SetFrameLevel(500)
        returnGroupsBtn:SetFrameStrata(strata); returnGroupsBtn:SetFrameLevel(500)
    end

    -- 클릭: 파티 탐색하기
    browseGroupsBtn:SetScript("OnClick", function()
        local bgb = LFGListFrame.ApplicationViewer and LFGListFrame.ApplicationViewer.BrowseGroupsButton
        if bgb then
            -- 블리자드 버튼이 비활성화 상태가 아니라면 클릭 실행
            if bgb:IsEnabled() then
                bgb:Click()
            end
        end
    end)

    -- 클릭: 파티로 돌아가기
    returnGroupsBtn:SetScript("OnClick", function()
        C_Timer.After(0, function()
            LFGListFrame_SetActivePanel(LFGListFrame, LFGListFrame.ApplicationViewer)
        end)
    end)

    -- Hook
    LFGListFrame.ApplicationViewer:HookScript("OnShow", updateBtn)
    LFGListFrame.SearchPanel:HookScript("OnShow", updateBtn)
    LFGListFrame:HookScript("OnHide", function()
        browseGroupsBtn:Hide()
        returnGroupsBtn:Hide()
    end)

    initialized = true
    updateBtn()
end

-- ==============================
-- 이벤트
-- ==============================
local initBrowseGroupBtn = CreateFrame("Frame")
initBrowseGroupBtn:RegisterEvent("ADDON_LOADED")
initBrowseGroupBtn:RegisterEvent("GROUP_ROSTER_UPDATE")
initBrowseGroupBtn:RegisterEvent("LFG_LIST_ACTIVE_ENTRY_UPDATE")

initBrowseGroupBtn:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == "Blizzard_GroupFinder" then
        initBtn()
    elseif event == "GROUP_ROSTER_UPDATE" or event == "LFG_LIST_ACTIVE_ENTRY_UPDATE" then
        if not initialized then 
            if C_AddOns.IsAddOnLoaded("Blizzard_GroupFinder") then initBtn() end
        else 
            updateBtn() 
        end
    end
end)

if C_AddOns and C_AddOns.IsAddOnLoaded("Blizzard_GroupFinder") then
    initBtn()
end

dodo.BrowseGroup = updateBtn