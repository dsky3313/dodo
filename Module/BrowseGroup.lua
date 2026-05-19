-- ==============================
-- Inspired
-- ==============================
-- 11.2 파티 탐색하기 버튼 (BrowseGroupsButton) (https://wago.io/JaYwj48fu)

-- ==============================
-- 설정 및 테이블
-- ==============================
---@diagnostic disable: lowercase-global, param-type-mismatch, redundant-parameter, undefined-field, undefined-global
local addonName, dodo = ...
local module = {}
dodo:RegisterModule("BrowseGroup", module)

-- ==============================
-- 캐싱
-- ==============================
local CreateFrame = CreateFrame
local UnitIsGroupLeader = UnitIsGroupLeader
local issecretvalue = issecretvalue
local GetActiveEntryInfo = C_LFGList.GetActiveEntryInfo

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
    local isEnabled = (dodo.DB.useBrowseGroup ~= false)
    if not isEnabled or not LFGListFrame then
        if browseGroupsBtn:IsShown() then browseGroupsBtn:Hide() end
        if returnGroupsBtn:IsShown() then returnGroupsBtn:Hide() end
        return
    end

    local entryInfo = GetActiveEntryInfo()
    local isEntrySecret = issecretvalue(entryInfo)
    local active = (not isEntrySecret and entryInfo ~= nil) or isEntrySecret
    local isLeader = UnitIsGroupLeader("player")
    
    local shownApp = LFGListFrame.ApplicationViewer and LFGListFrame.ApplicationViewer:IsShown()
    local shownSearch = LFGListFrame.SearchPanel and LFGListFrame.SearchPanel:IsShown()

    -- 파티 탐색하기
    if shownApp and (not isLeader) and active then
        if not browseGroupsBtn:IsShown() then browseGroupsBtn:Show() end
    else
        if browseGroupsBtn:IsShown() then browseGroupsBtn:Hide() end
    end

    -- 파티로 돌아가기
    if shownSearch and active then
        if not returnGroupsBtn:IsShown() then returnGroupsBtn:Show() end
    else
        if returnGroupsBtn:IsShown() then returnGroupsBtn:Hide() end
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
        browseGroupsBtn:SetFrameStrata(strata); browseGroupsBtn:SetFrameLevel(500)
        returnGroupsBtn:SetFrameStrata(strata); returnGroupsBtn:SetFrameLevel(500)
    end

    -- 클릭: 파티 탐색하기
    browseGroupsBtn:SetScript("OnClick", function()
        local bgb = LFGListFrame.ApplicationViewer and LFGListFrame.ApplicationViewer.BrowseGroupsButton
        if bgb then
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
-- ==============================
-- 초기화 & 옵션 UI
-- ==============================
function module:OnEnable()
    local initBrowseGroupBtn = CreateFrame("Frame")
    initBrowseGroupBtn:RegisterEvent("ADDON_LOADED")
    initBrowseGroupBtn:RegisterEvent("PARTY_LEADER_CHANGED")
    initBrowseGroupBtn:RegisterEvent("LFG_LIST_ACTIVE_ENTRY_UPDATE")

    initBrowseGroupBtn:SetScript("OnEvent", function(self, event, arg1)
        if event == "ADDON_LOADED" and arg1 == "Blizzard_GroupFinder" then
            initBtn()
        elseif event == "PARTY_LEADER_CHANGED" or event == "LFG_LIST_ACTIVE_ENTRY_UPDATE" then
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
end

-- ==============================
-- 설정
-- ==============================
function module:CreateOptions()
    dodo.UI.Checkbox(dodo.subCategoryParty, "useBrowseGroup", "파티 탐색하기 버튼", "파티원일 경우에도 '파티 탐색하기' 버튼을 표시합니다.", false, updateBtn)
end