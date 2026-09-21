-- ==============================
-- 퀘스트 자동 수락, 자동 완료, 퀘스트 아이템 단축키
-- ==============================
-- Inspired by EllesmereUIQuestTracker_QoL.lua
---@diagnostic disable: lowercase-global, param-type-mismatch, redundant-parameter, undefined-field, undefined-global
local dodo = _G.dodo
dodoDB = dodoDB or {}
if dodoDB.questItemHotkey == nil then dodoDB.questItemHotkey = "CTRL-G" end

local C_GossipInfo            = C_GossipInfo
local C_QuestLog              = C_QuestLog
local C_Timer                 = C_Timer
local AcceptQuest             = AcceptQuest
local CreateFrame             = CreateFrame
local GetNumQuestChoices      = GetNumQuestChoices
local GetQuestLogSpecialItemInfo = GetQuestLogSpecialItemInfo
local GetQuestReward          = GetQuestReward
local GetTime                 = GetTime
local InCombatLockdown        = InCombatLockdown
local IsShiftKeyDown          = IsShiftKeyDown
local UIParent                = UIParent

-- ==============================
-- 자동 수락 / 자동 완료
-- ==============================
local prevent_npc_guid = nil
local auto_frame = CreateFrame("Frame")
auto_frame:RegisterEvent("QUEST_DETAIL")
auto_frame:RegisterEvent("QUEST_COMPLETE")
auto_frame:RegisterEvent("GOSSIP_SHOW")
auto_frame:SetScript("OnEvent", function(_, event)
    if event == "GOSSIP_SHOW" then
        if not C_GossipInfo then return end

        if dodoDB.autoTurnIn and C_GossipInfo.GetActiveQuests then
            for _, quest in ipairs(C_GossipInfo.GetActiveQuests() or {}) do
                if quest.questID and quest.isComplete then
                    C_GossipInfo.SelectActiveQuest(quest.questID)
                    return
                end
            end
        end

        if dodoDB.autoAccept and C_GossipInfo.GetAvailableQuests then
            if dodoDB.autoAcceptShiftSkip ~= false and IsShiftKeyDown() then return end
            local available = C_GossipInfo.GetAvailableQuests()
            if available and #available > 0 then
                local npc_guid = UnitGUID("npc")
                -- 퀘스트 여러 개면 이 NPC는 수동 선택
                if #available > 1 then prevent_npc_guid = npc_guid end
                if prevent_npc_guid ~= npc_guid and available[1].questID then
                    C_GossipInfo.SelectAvailableQuest(available[1].questID)
                end
            end
        end
        return
    end

    if event == "QUEST_DETAIL" then
        if not dodoDB.autoAccept then return end
        if dodoDB.autoAcceptShiftSkip ~= false and IsShiftKeyDown() then return end
        AcceptQuest()

    elseif event == "QUEST_COMPLETE" then
        if not dodoDB.autoTurnIn then return end
        if dodoDB.autoTurnInShiftSkip ~= false and IsShiftKeyDown() then return end
        local n = GetNumQuestChoices()
        -- 보상 선택이 없을 때만 자동 완료 (선택지 있으면 수동)
        if n <= 1 then GetQuestReward(n) end
    end
end)

-- ==============================
-- 퀘스트 아이템 단축키
-- ==============================
-- SecureActionButton(type="item") + SetOverrideBindingClick.
-- SetBinding 방식은 영구 저장되어 키를 빼앗음 → OverrideBinding 사용.
-- AnyDown + AnyUp 둘 다 등록 필수: cast-on-key-down 옵션 시
-- down phase만 등록하면 액션이 실행되지 않음.
local qi_btn = CreateFrame("Button", "dodo_QuestItemHotkeyBtn", UIParent, "SecureActionButtonTemplate")
qi_btn:SetSize(32, 32)
qi_btn:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
qi_btn:SetAlpha(0)
qi_btn:EnableMouse(false)
qi_btn:RegisterForClicks("AnyDown", "AnyUp")

local function init_secure_attrs()
    qi_btn:SetAttribute("type", "item")
end
if InCombatLockdown() then
    local f = CreateFrame("Frame")
    f:RegisterEvent("PLAYER_REGEN_ENABLED")
    f:SetScript("OnEvent", function(self)
        self:UnregisterAllEvents()
        init_secure_attrs()
    end)
else
    init_secure_attrs()
end

local _bound_key        = nil
local _binding_dirty    = true
local _self_write_until = 0
local _cached_name      = nil
local _scan_dirty       = true
local _scan_pending     = false

local function scan_for_quest_item()
    local num = C_QuestLog.GetNumQuestLogEntries() or 0
    local fallback = nil
    for i = 1, num do
        local info = C_QuestLog.GetInfo(i)
        if info and not info.isHeader and info.questID then
            local idx = C_QuestLog.GetLogIndexForQuestID
                and C_QuestLog.GetLogIndexForQuestID(info.questID) or i
            local link = GetQuestLogSpecialItemInfo(idx)
            if link then
                local name = link:match("%[(.-)%]")
                if name then
                    local wt = C_QuestLog.GetQuestWatchType
                        and C_QuestLog.GetQuestWatchType(info.questID)
                    if wt ~= nil then return name end
                    fallback = fallback or name
                end
            end
        end
    end
    return fallback
end

local function apply_binding()
    if InCombatLockdown() then return end
    local key = dodoDB.questItemHotkey
    if key == "" then key = nil end
    -- 퀘스트 아이템이 있을 때만 바인딩 (없으면 키를 빼앗지 않음)
    local want = (key and qi_btn:GetAttribute("item")) and key or nil
    if not _binding_dirty and want == _bound_key then return end
    _binding_dirty = false
    _self_write_until = GetTime() + 0.5
    ClearOverrideBindings(qi_btn)
    if want then
        SetOverrideBindingClick(qi_btn, true, want, "dodo_QuestItemHotkeyBtn", "LeftButton")
    end
    _bound_key = want
end

local function update_quest_item_attr()
    if InCombatLockdown() then return end
    if not dodoDB.questItemHotkey then return end
    if not _scan_dirty then return end
    _scan_dirty = false
    local found = scan_for_quest_item()
    if found ~= _cached_name then
        _cached_name = found
        qi_btn:SetAttribute("item", found)
        apply_binding()
    end
end

local function apply_quest_item_hotkey()
    if InCombatLockdown() then return end
    _scan_dirty    = true
    _binding_dirty = true
    update_quest_item_attr()
    apply_binding()
end
dodo.ApplyQuestItemHotkey = apply_quest_item_hotkey

local function flush_scan()
    _scan_pending = false
    update_quest_item_attr()
end

local qi_frame = CreateFrame("Frame")
qi_frame:RegisterEvent("QUEST_LOG_UPDATE")
qi_frame:RegisterEvent("QUEST_ACCEPTED")
qi_frame:RegisterEvent("QUEST_REMOVED")
qi_frame:RegisterEvent("QUEST_TURNED_IN")
qi_frame:RegisterEvent("UPDATE_BINDINGS")
qi_frame:RegisterEvent("PLAYER_REGEN_ENABLED")
qi_frame:SetScript("OnEvent", function(_, event)
    if InCombatLockdown() then return end
    if event == "PLAYER_REGEN_ENABLED" then
        apply_quest_item_hotkey()
        return
    end
    if event == "UPDATE_BINDINGS" then
        -- 우리가 직접 쓴 echo는 무시 (자기강화루프 방지)
        if GetTime() < _self_write_until then return end
        _binding_dirty = true
        apply_binding()
        return
    end
    if not dodoDB.questItemHotkey then return end
    _scan_dirty = true
    if not _scan_pending then
        _scan_pending = true
        C_Timer.After(0.3, flush_scan)
    end
end)

C_Timer.After(1.5, function()
    if not InCombatLockdown() then apply_quest_item_hotkey() end
end)

-- ==============================
-- 퀘스트 헤더 설정 아이콘
-- ==============================
-- QuestObjectiveTracker.Header 구조:
--   Text (LEFT x=7, width=200) | ... | MinimizeButton (RIGHT x=1, 16x16)
-- MinimizeButton 왼쪽에 DropdownButton(UIPanelIconDropdownButtonTemplate) 추가.
-- 클릭하면 자동수락/자동완료 토글 + 설정창 열기 메뉴 표시.
local function add_quest_header_settings_icon()
    local header = QuestObjectiveTracker and QuestObjectiveTracker.Header
    if not header or header.dodoSettingsBtn then return end

    local btn = CreateFrame("DropdownButton", "dodo_QuestTrackerSettingsDropdown", header, "UIPanelIconDropdownButtonTemplate")
    btn:SetSize(16, 16)
    btn:SetPoint("RIGHT", header.MinimizeButton, "LEFT", -4, 0)

    btn:SetupMenu(function(_, rootDescription)
        rootDescription:SetTag("MENU_DODO_QUEST_SETTINGS")

        rootDescription:CreateCheckbox(
            "퀘스트 자동 수락",
            function() return dodoDB.autoAccept end,
            function() dodoDB.autoAccept = not dodoDB.autoAccept end
        )
        rootDescription:CreateCheckbox(
            "퀘스트 자동 완료",
            function() return dodoDB.autoTurnIn end,
            function() dodoDB.autoTurnIn = not dodoDB.autoTurnIn end
        )

        rootDescription:CreateDivider()

        rootDescription:CreateButton("dodo 설정 열기", function()
            if Settings and Settings.OpenToCategory then
                local cat = Settings.GetCategory and Settings.GetCategory("dodo")
                if cat then Settings.OpenToCategory(cat) end
            end
        end)
    end)

    btn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("dodo 퀘스트 설정", 1, 1, 1)
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    header.dodoSettingsBtn = btn
end

local init_f = CreateFrame("Frame")
init_f:RegisterEvent("PLAYER_LOGIN")
init_f:SetScript("OnEvent", function(self)
    self:UnregisterAllEvents()
    add_quest_header_settings_icon()
end)
