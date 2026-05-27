-- ==============================
-- Inspired
-- ==============================
-- 11.2 파티 탐색하기 버튼 (BrowseGroupsButton) (https://wago.io/JaYwj48fu)

-- ==============================
-- 설정 및 테이블
-- ==============================
---@diagnostic disable: lowercase-global, param-type-mismatch, redundant-parameter, undefined-field, undefined-global
local addonName, dodo = ...
dodoDB = dodoDB or {}

-- ==============================
-- 캐싱 (가나다 순 정렬)
-- ==============================
local C_AddOns = C_AddOns
local C_Timer = C_Timer
local CreateFrame = CreateFrame
local GetActiveEntryInfo = C_LFGList.GetActiveEntryInfo
local InCombatLockdown = InCombatLockdown
local LFGListFrame_SetActivePanel = LFGListFrame_SetActivePanel
local UnitIsGroupLeader = UnitIsGroupLeader
local ipairs = ipairs
local issecretvalue = issecretvalue
local type = type

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

-- ==============================
-- 버튼 클릭 및 스크립트 정적 핸들러 (가비지 프리)
-- ==============================
local function on_browse_click()
    local bgb = LFGListFrame.ApplicationViewer and LFGListFrame.ApplicationViewer.BrowseGroupsButton
    if bgb then
        if bgb:IsEnabled() then
            bgb:Click()
        end
    end
end

local function on_return_timer_tick()
    if LFGListFrame and LFGListFrame.ApplicationViewer then
        LFGListFrame_SetActivePanel(LFGListFrame, LFGListFrame.ApplicationViewer)
    end
end

local function on_return_click()
    C_Timer.After(0, on_return_timer_tick)
end

local function on_lfg_hide()
    browseGroupsBtn:Hide()
    returnGroupsBtn:Hide()
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
    browseGroupsBtn:SetScript("OnClick", on_browse_click)

    -- 클릭: 파티로 돌아가기
    returnGroupsBtn:SetScript("OnClick", on_return_click)

    LFGListFrame.ApplicationViewer:HookScript("OnShow", updateBtn)
    LFGListFrame.SearchPanel:HookScript("OnShow", updateBtn)
    LFGListFrame:HookScript("OnHide", on_lfg_hide)

    initialized = true
    updateBtn()
end

-- ==============================
-- 이벤트 핸들러 (가비지 프리 정적 참조)
-- ==============================
local function on_event(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == "Blizzard_GroupFinder" then
        initBtn()
    elseif event == "PARTY_LEADER_CHANGED" or event == "LFG_LIST_ACTIVE_ENTRY_UPDATE" then
        if not initialized then 
            if C_AddOns.IsAddOnLoaded("Blizzard_GroupFinder") then initBtn() end
        else 
            updateBtn() 
        end
    end
end

-- ==============================
-- 이벤트 등록
-- ==============================
local initBrowseGroupBtn = CreateFrame("Frame")
initBrowseGroupBtn:RegisterEvent("ADDON_LOADED")
initBrowseGroupBtn:RegisterEvent("PARTY_LEADER_CHANGED")
initBrowseGroupBtn:RegisterEvent("LFG_LIST_ACTIVE_ENTRY_UPDATE")
initBrowseGroupBtn:SetScript("OnEvent", on_event)

if C_AddOns and C_AddOns.IsAddOnLoaded("Blizzard_GroupFinder") then
    initBtn()
end

dodo.BrowseGroup = updateBtn

-- ==============================
-- 설정 동적 등록 (Option.lua 연동)
-- ==============================
local SettingsPanel = SettingsPanel
local CreateSettingsListSectionHeaderInitializer = CreateSettingsListSectionHeaderInitializer
local Checkbox = Checkbox

dodo.OptionRegistrations = dodo.OptionRegistrations or {}
dodo.OptionRegistrations["party"] = dodo.OptionRegistrations["party"] or {}
table.insert(dodo.OptionRegistrations["party"], function(category)
    local layoutParty = SettingsPanel:GetLayout(category)
    if not layoutParty then return end

    layoutParty:AddInitializer(CreateSettingsListSectionHeaderInitializer("파티"))
    Checkbox(category, "useBrowseGroup", "파티 탐색하기 버튼", "파티원일 경우에도 '파티 탐색하기' 버튼을 표시합니다.", true, dodo.BrowseGroup)
end)