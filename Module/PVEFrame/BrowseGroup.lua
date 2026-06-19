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
-- 캐싱
-- ==============================
local C_AddOns = C_AddOns
local C_Timer = C_Timer
local CreateFrame = CreateFrame
local GetActiveEntryInfo = C_LFGList.GetActiveEntryInfo
local InCombatLockdown = InCombatLockdown
local ipairs = ipairs
local issecretvalue = issecretvalue
local LFGListFrame_SetActivePanel = LFGListFrame_SetActivePanel
local type = type
local UnitIsGroupLeader = UnitIsGroupLeader
local UIParent = UIParent

-- ==============================
-- 기능 1: 로컬 상태 및 설정
-- ==============================
local is_initialized = false
local lfg_list_frame = nil
local init_browse_group_btn = CreateFrame("Frame")

-- ==============================
-- 기능 2: 상태 업데이트
-- ==============================
local browse_groups_btn = nil
local return_groups_btn = nil

local function update_btn()
    local is_enabled = (dodoDB.useBrowseGroup ~= false)
    if not is_enabled or not lfg_list_frame then
        if browse_groups_btn and browse_groups_btn:IsShown() then browse_groups_btn:Hide() end
        if return_groups_btn and return_groups_btn:IsShown() then return_groups_btn:Hide() end
        return
    end

    local entry_info = GetActiveEntryInfo()
    local is_entry_secret = issecretvalue(entry_info)
    local active = (not is_entry_secret and entry_info ~= nil) or is_entry_secret
    local is_leader = UnitIsGroupLeader("player")
    
    local viewer = lfg_list_frame.ApplicationViewer
    local search = lfg_list_frame.SearchPanel
    local shown_app = viewer and viewer:IsShown()
    local shown_search = search and search:IsShown()

    -- 파티 탐색하기
    if shown_app and (not is_leader) and active then
        if browse_groups_btn and not browse_groups_btn:IsShown() then browse_groups_btn:Show() end
    else
        if browse_groups_btn and browse_groups_btn:IsShown() then browse_groups_btn:Hide() end
    end

    -- 파티로 돌아가기
    if shown_search and active then
        if return_groups_btn and not return_groups_btn:IsShown() then return_groups_btn:Show() end
    else
        if return_groups_btn and return_groups_btn:IsShown() then return_groups_btn:Hide() end
    end
end

local function on_browse_click()
    if not lfg_list_frame then return end
    local viewer = lfg_list_frame.ApplicationViewer
    local bgb = viewer and viewer.BrowseGroupsButton
    if bgb then
        if bgb:IsEnabled() then
            bgb:Click()
        end
    end
end

local function on_return_timer_tick()
    if lfg_list_frame and lfg_list_frame.ApplicationViewer then
        LFGListFrame_SetActivePanel(lfg_list_frame, lfg_list_frame.ApplicationViewer)
    end
end

local function on_return_click()
    C_Timer.After(0, on_return_timer_tick)
end

local function on_lfg_hide()
    if browse_groups_btn then browse_groups_btn:Hide() end
    if return_groups_btn then return_groups_btn:Hide() end
end

-- ==============================
-- 기능 3: UI 생성
-- ==============================
local function init_btn()
    lfg_list_frame = _G.LFGListFrame
    if not lfg_list_frame or is_initialized then return end

    if not browse_groups_btn then
        browse_groups_btn = CreateFrame("Button", "browseGroupsBtn", lfg_list_frame, "UIPanelButtonTemplate")
        browse_groups_btn:SetSize(144, 22)
        browse_groups_btn:SetText(GROUP_FINDER_BROWSE or "파티 탐색하기")
        browse_groups_btn:Hide()
    end

    if not return_groups_btn then
        return_groups_btn = CreateFrame("Button", "returnGroupsBtn", lfg_list_frame, "UIPanelButtonTemplate")
        return_groups_btn:SetSize(144, 22)
        return_groups_btn:SetText(GROUP_FINDER_BACK_TO_GROUP or "파티로 돌아가기")
        return_groups_btn:Hide()
    end
    
    browse_groups_btn:SetParent(lfg_list_frame)
    browse_groups_btn:ClearAllPoints()
    browse_groups_btn:SetPoint("TOP", lfg_list_frame, "BOTTOM", -100, 26)

    return_groups_btn:SetParent(lfg_list_frame)
    return_groups_btn:ClearAllPoints()
    return_groups_btn:SetPoint("TOP", lfg_list_frame, "BOTTOM", -100, 26)

    local search = lfg_list_frame.SearchPanel
    local viewer = lfg_list_frame.ApplicationViewer

    local back_btn = search and search.BackButton
    if back_btn then
        local strata = back_btn:GetFrameStrata()
        browse_groups_btn:SetFrameStrata(strata); browse_groups_btn:SetFrameLevel(500)
        return_groups_btn:SetFrameStrata(strata); return_groups_btn:SetFrameLevel(500)
    end

    -- 클릭: 파티 탐색하기
    browse_groups_btn:SetScript("OnClick", on_browse_click)

    -- 클릭: 파티로 돌아가기
    return_groups_btn:SetScript("OnClick", on_return_click)

    if viewer then viewer:HookScript("OnShow", update_btn) end
    if search then search:HookScript("OnShow", update_btn) end
    lfg_list_frame:HookScript("OnHide", on_lfg_hide)

    is_initialized = true
    update_btn()
end

-- ==============================
-- 이벤트 핸들러
-- ==============================
local function toggle_events()
    local is_enabled = (dodoDB and dodoDB.useBrowseGroup ~= false)
    if is_enabled then
        if init_browse_group_btn then
            init_browse_group_btn:RegisterEvent("PARTY_LEADER_CHANGED")
            init_browse_group_btn:RegisterEvent("LFG_LIST_ACTIVE_ENTRY_UPDATE")
        end
        if C_AddOns and C_AddOns.IsAddOnLoaded("Blizzard_GroupFinder") then
            init_btn()
        end
        update_btn()
    else
        if init_browse_group_btn then
            init_browse_group_btn:UnregisterEvent("PARTY_LEADER_CHANGED")
            init_browse_group_btn:UnregisterEvent("LFG_LIST_ACTIVE_ENTRY_UPDATE")
        end
        if browse_groups_btn and browse_groups_btn:IsShown() then browse_groups_btn:Hide() end
        if return_groups_btn and return_groups_btn:IsShown() then return_groups_btn:Hide() end
    end
end

local function on_event(self, event, arg1)
    if event == "ADDON_LOADED" then
        if arg1 == addonName then
            toggle_events()
        elseif arg1 == "Blizzard_GroupFinder" then
            if dodoDB and dodoDB.useBrowseGroup ~= false then
                init_btn()
            end
            self:UnregisterEvent("ADDON_LOADED")
        end
    elseif event == "PARTY_LEADER_CHANGED" or event == "LFG_LIST_ACTIVE_ENTRY_UPDATE" then
        if not is_initialized then 
            if C_AddOns and C_AddOns.IsAddOnLoaded("Blizzard_GroupFinder") then init_btn() end
        else 
            update_btn() 
        end
    end
end

init_browse_group_btn:RegisterEvent("ADDON_LOADED")
init_browse_group_btn:SetScript("OnEvent", on_event)

dodo.BrowseGroup = toggle_events

-- ==============================
-- 설정 등록
-- ==============================
local Checkbox = Checkbox

dodo.OptionRegistrations = dodo.OptionRegistrations or {}
dodo.OptionRegistrations["인터페이스.파티모집창"] = dodo.OptionRegistrations["인터페이스.파티모집창"] or {}
table.insert(dodo.OptionRegistrations["인터페이스.파티모집창"], function(category)
    Checkbox(category, "useBrowseGroup", "파티 탐색하기 버튼", "파티 탐색하기 / 파티로 돌아가기 버튼을 표시합니다.", true, dodo.BrowseGroup)
end)