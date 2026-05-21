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
local GetActiveEntryInfo = C_LFGList.GetActiveEntryInfo
local IsAddOnLoaded = C_AddOns.IsAddOnLoaded
local UnitIsGroupLeader = UnitIsGroupLeader
local issecretvalue = issecretvalue

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
-- 프레임 및 이벤트
-- ==============================
local eventFrame = CreateFrame("Frame")

-- ==============================
-- 기능 1: 파티 탐색하기 버튼 상태 업데이트
-- ==============================
local function update_buttons()
    local isEnabled = (dodo.DB and dodo.DB.useBrowseGroup ~= false)
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

local function init_buttons()
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

    LFGListFrame.ApplicationViewer:HookScript("OnShow", update_buttons)
    LFGListFrame.SearchPanel:HookScript("OnShow", update_buttons)
    LFGListFrame:HookScript("OnHide", function()
        browseGroupsBtn:Hide()
        returnGroupsBtn:Hide()
    end)

    initialized = true
    update_buttons()
end

-- ==============================
-- 모듈 생명주기
-- ==============================
function module:OnEnable()
    -- 최적화된 이벤트 감지 설정
    eventFrame:RegisterEvent("ADDON_LOADED")
    eventFrame:RegisterEvent("PARTY_LEADER_CHANGED")
    eventFrame:RegisterEvent("LFG_LIST_ACTIVE_ENTRY_UPDATE")

    eventFrame:SetScript("OnEvent", function(self, event, arg1)
        if event == "ADDON_LOADED" then
            if arg1 == "Blizzard_GroupFinder" then
                init_buttons()
                eventFrame:UnregisterEvent("ADDON_LOADED") -- 로드 완료 시 이벤트 해제로 성능 향상
            end
        elseif event == "PARTY_LEADER_CHANGED" or event == "LFG_LIST_ACTIVE_ENTRY_UPDATE" then
            if initialized then 
                update_buttons() 
            elseif IsAddOnLoaded("Blizzard_GroupFinder") then
                init_buttons()
                eventFrame:UnregisterEvent("ADDON_LOADED")
            end
        end
    end)

    if IsAddOnLoaded("Blizzard_GroupFinder") then
        init_buttons()
        eventFrame:UnregisterEvent("ADDON_LOADED")
    end

    -- dodoEditModePanel 내부에 2열 그리드로 세부 설정 주입
    if dodo.RegisterEditModeSetting then
        dodo.RegisterEditModeSetting("인터페이스", {
            {
                name = "파티 탐색하기 버튼",
                get = function() return dodo.DB and dodo.DB.useBrowseGroup ~= false end,
                set = function(checked)
                    if dodo.DB then dodo.DB.useBrowseGroup = checked end
                    update_buttons()
                end
            }
        })
    end
end

