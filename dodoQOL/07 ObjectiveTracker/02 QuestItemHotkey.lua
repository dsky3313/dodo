-- ==============================
-- 퀘스트 아이템 단축키
-- ==============================
-- Inspired by EllesmereUIQuestTracker_QoL.lua
---@diagnostic disable: lowercase-global, param-type-mismatch, redundant-parameter, undefined-field, undefined-global
local dodo = _G.dodo
dodoDB = dodoDB or {}

local C_QuestLog                 = C_QuestLog
local C_Timer                    = C_Timer
local ClearOverrideBindings      = ClearOverrideBindings
local CreateFrame                = CreateFrame
local GetQuestLogSpecialItemInfo = GetQuestLogSpecialItemInfo
local GetTime                    = GetTime
local InCombatLockdown           = InCombatLockdown
local SetOverrideBindingClick    = SetOverrideBindingClick
local UIParent                   = UIParent

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

-- ==============================
-- 이벤트 핸들러
-- ==============================
local function on_login_timer()
    if not InCombatLockdown() then apply_quest_item_hotkey() end
end

local qi_frame = CreateFrame("Frame")
qi_frame:RegisterEvent("PLAYER_LOGIN")
qi_frame:RegisterEvent("QUEST_LOG_UPDATE")
qi_frame:RegisterEvent("QUEST_ACCEPTED")
qi_frame:RegisterEvent("QUEST_REMOVED")
qi_frame:RegisterEvent("QUEST_TURNED_IN")
qi_frame:RegisterEvent("UPDATE_BINDINGS")
qi_frame:RegisterEvent("PLAYER_REGEN_ENABLED")
qi_frame:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_LOGIN" then
        self:UnregisterEvent("PLAYER_LOGIN")
        C_Timer.After(1.5, on_login_timer)
        return
    end
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
