-- ==============================
-- Inspired
-- ==============================
-- ActionBarAuras (https://github.com/xod-wow/ActionBarAuras)

-- ==============================
-- 설정 및 테이블
-- ==============================
---@diagnostic disable: lowercase-global, param-type-mismatch, redundant-parameter, undefined-field, undefined-global
local addonName, dodo = ...
dodoDB = dodoDB or {}

local BAR_INDEX_MAP = dodo.BAR_INDEX_MAP

local CDM_DB_KEYS = {
    ["MainActionBar"]       = "useActionbarCDMBar1",
    ["MultiBarBottomLeft"]  = "useActionbarCDMBar2",
    ["MultiBarBottomRight"] = "useActionbarCDMBar3",
    ["MultiBarRight"]       = "useActionbarCDMBar4",
    ["MultiBarLeft"]        = "useActionbarCDMBar5",
    ["MultiBar5"]           = "useActionbarCDMBar6",
    ["MultiBar6"]           = "useActionbarCDMBar7",
    ["MultiBar7"]           = "useActionbarCDMBar8",
}

local CDM_DEFAULTS = {
    ["MainActionBar"]       = true,
    ["MultiBarBottomLeft"]  = true,
    ["MultiBarBottomRight"] = false,
    ["MultiBarRight"]       = false,
    ["MultiBarLeft"]        = false,
    ["MultiBar5"]           = false,
    ["MultiBar6"]           = false,
    ["MultiBar7"]           = false,
    ["StanceBar"]           = false,
    ["PetActionBar"]        = false,
}

local CustomCDMConfigs = { -- 물약 지속시간 (스펠ID - 아이템ID)
    [1236616] = { matchIDs = { 241308, 241309 }, duration = 30, type = 3 }, -- 빛의 잠재력
    [1236994] = { matchIDs = { 241288, 241289 }, duration = 30, type = 3 }, -- 무모함의 물약
}

local CDMMapping_defaults = { -- [specID] = { buffSpellID = actionBarSpellID }
    [71] = { -- 무기전사 (Arms)
        [386633] = 12294, -- 집행자의 정밀함 - 필사의 일격
    },
    [72] = { -- 분노전사 (Fury)
        [184361] = 1464,   -- 격노 - 광란
        [12950]  = 190411, -- 소용돌이 연마 - 소용돌이
    },
    [73] = { -- 방어전사 (Protection)
        [195181] = 195182, -- 뼈의 보호막 - 골수분쇄
    },
}

-- ==============================
-- 캐싱
-- ==============================
local C_CooldownViewer = C_CooldownViewer
local C_Item = C_Item
local C_Spell = C_Spell
local C_Timer = C_Timer
local GetSpecialization = GetSpecialization
local GetSpecializationInfo = GetSpecializationInfo
local CreateFrame = CreateFrame
local Enum = Enum
local GetActionInfo = GetActionInfo
local GetTime = GetTime
local hooksecurefunc = hooksecurefunc
local InCombatLockdown = InCombatLockdown
local ipairs = ipairs
local issecretvalue = issecretvalue
local Item = Item
local Mixin = Mixin
local pairs = pairs
local PixelUtil = PixelUtil
local type = type
local wipe = wipe

local custom_cdmauras    = dodo.customCDMAuras
local custom_cdmspell_map = dodo.customCDMSpellMap

-- ==============================
-- 헬퍼
-- ==============================
local function is_bar_cdm_enabled(barName)
    if not barName then return false end
    local dbKey = CDM_DB_KEYS[barName]
    if not dbKey then return CDM_DEFAULTS[barName] or false end
    if not dodoDB then return CDM_DEFAULTS[barName] or false end
    local val = dodoDB[dbKey]
    if val == nil then return CDM_DEFAULTS[barName] or false end
    return val
end

local function get_cdm_map()
    if not dodoDB then return nil end
    local specIndex = GetSpecialization()
    if not specIndex then return nil end
    local specID = GetSpecializationInfo(specIndex)
    if not specID then return nil end
    dodoDB.cdmMapping = dodoDB.cdmMapping or {}
    if not dodoDB.cdmMapping[specID] then
        dodoDB.cdmMapping[specID] = {}
        local defaults = CDMMapping_defaults[specID]
        if defaults then
            for k, v in pairs(defaults) do
                dodoDB.cdmMapping[specID][k] = v
            end
        end
    end
    return dodoDB.cdmMapping[specID]
end

local function get_action_spell_id(actionID)
    local actionType, id, actionSubType = GetActionInfo(actionID)
    if (actionType == "spell" or actionSubType == "spell") and id then
        return id
    elseif actionType == "item" then
        local _, spellID = C_Item.GetItemSpell(id)
        return spellID
    end
end

-- ==============================
-- AuraContainer 방식 — LinkedSpells
-- ==============================

-- [스펠명] = {[spellID]=true, ...}  CDM linkedSpellIDs 기반
local linked_spell_ids = {}

local function scan_linked_spells()
    wipe(linked_spell_ids)
    for c = Enum.CooldownViewerCategoryMeta.MinValue, Enum.CooldownViewerCategoryMeta.MaxValue do
        local set = C_CooldownViewer.GetCooldownViewerCategorySet(c, true)
        if set then
            for _, cooldownID in ipairs(set) do
                local info = C_CooldownViewer.GetCooldownViewerCooldownInfo(cooldownID)
                if info and info.spellID then
                    local name = C_Spell.GetSpellName(info.spellID)
                    if name then
                        if not linked_spell_ids[name] then linked_spell_ids[name] = {} end
                        linked_spell_ids[name][info.spellID] = true
                        for _, sid in ipairs(info.linkedSpellIDs) do
                            linked_spell_ids[name][sid] = true
                        end
                    end
                end
            end
        end
    end
end

-- 버튼 스펠 ID → 연관 버프 스펠 목록 (CDM linked + cdmMapping 수동 매핑 통합)
local function get_linked_spell_ids(spellID)
    local result = {}
    local name = C_Spell.GetSpellName(spellID)
    if name and linked_spell_ids[name] then
        Mixin(result, linked_spell_ids[name])
    end
    local cdmMap = get_cdm_map()
    if cdmMap then
        for buffID, skillID in pairs(cdmMap) do
            if skillID == spellID then
                result[buffID] = true
            end
        end
    end
    return result
end

-- ==============================
-- AuraContainer 슬롯 초기화
-- ==============================
local _duration_formatter
local function get_duration_formatter()
    if _duration_formatter then return _duration_formatter end
    if not (C_StringUtil and C_StringUtil.CreateNumericRuleFormatter and Enum.NumericRuleFormatRounding) then
        return nil
    end
    local Up   = Enum.NumericRuleFormatRounding.Up
    local Down = Enum.NumericRuleFormatRounding.Down
    local formatter = C_StringUtil.CreateNumericRuleFormatter()
    local ok = pcall(formatter.SetBreakpoints, formatter, {
        { threshold = 0,    format = "%d",  step = 1, rounding = Up,   components = { { div = 1 } } },
        { threshold = 60,   format = "%dm", step = 1, rounding = Up,   components = { { div = 60 } } },
        { threshold = 61,   format = "%dm", step = 1, rounding = Down, components = { { div = 60 } } },
        { threshold = 3600, format = "%dh", step = 1, rounding = Down, components = { { div = 3600 } } },
    })
    if ok then _duration_formatter = formatter end
    return _duration_formatter
end

local function initialize_aura_slot(f)
    f:SetDurationText(f.durationText, { textFormatter = get_duration_formatter() })
    f:SetApplicationCount(f.stacksText)
    f:EnableMouse(false)
    f.durationText:SetTextColor(0, 1, 0, 1)
    f.stacksText:SetTextColor(1, 1, 0, 1)
end


-- ==============================
-- AuraContainer 생성 & 필터 업데이트
-- ==============================
local function create_button_containers(btn)
    local name = btn:GetName()
    if not name then return end

    if not btn.cdmContainer then
        local c = CreateFrame("AuraContainer", name .. "CDMContainer", btn, "CustomAuraContainerTemplate")
        c:SetPoint("TOPLEFT")
        c:SetUnit("player")
        local as = c:AddAuraSlot("CDM", "HELPFUL|PLAYER", {
            sortMethod      = AuraContainerSortMethod.ExpirationOnly,
            sortDirection   = AuraContainerSortDirection.Reverse,
            templateNames   = { "CDMOverlayAuraTemplate" },
            initializeFrame = initialize_aura_slot,
        })
        as:SetSize(btn:GetSize())
        as:SetPoint("CENTER", btn)
        if btn.cooldown then as:SetFrameLevel(btn.cooldown:GetFrameLevel() + 1) end
        btn.cdmContainer = c
    end

    if not btn.cdmContainerDebuff then
        local cd = CreateFrame("AuraContainer", name .. "CDMDebuffContainer", btn, "CustomAuraContainerTemplate")
        cd:SetPoint("TOPLEFT")
        cd:SetUnit("target")
        local as = cd:AddAuraSlot("CDM", "HARMFUL|PLAYER", {
            sortMethod      = AuraContainerSortMethod.ExpirationOnly,
            sortDirection   = AuraContainerSortDirection.Reverse,
            templateNames   = { "CDMOverlayAuraTemplate" },
            initializeFrame = initialize_aura_slot,
        })
        as:SetSize(btn:GetSize())
        as:SetPoint("CENTER", btn)
        if btn.cooldown then as:SetFrameLevel(btn.cooldown:GetFrameLevel() + 1) end
        btn.cdmContainerDebuff = cd
    end
end

local function create_aura_containers()
    for btn in pairs(dodo.registeredButtons) do
        create_button_containers(btn)
    end
end

local function build_candidate_filters(btn, isHelpful)
    local spellID = btn.action and get_action_spell_id(btn.action)
    if not spellID then return nil end

    local filters = { includeSpellIDs = {} }
    if isHelpful then filters.isHelpful = true else filters.isHarmful = true end

    filters.includeSpellIDs[spellID] = true
    Mixin(filters.includeSpellIDs, get_linked_spell_ids(spellID))
    local baseSpellID = C_Spell.GetBaseSpell(spellID)
    if baseSpellID ~= spellID then
        filters.includeSpellIDs[baseSpellID] = true
        Mixin(filters.includeSpellIDs, get_linked_spell_ids(baseSpellID))
    end
    return filters
end

local function update_buff_filter(btn)
    local c = btn.cdmContainer
    if not c then return end
    local barName = dodo.get_bar_name_by_button(btn)
    if not barName or not is_bar_cdm_enabled(barName) or not btn:IsVisible() then
        c:SetEnabled(false)
        return
    end
    local filters = build_candidate_filters(btn, true)
    if not filters then c:SetEnabled(false); return end
    c:SetAuraSlotFilterString("CDM", "HELPFUL|PLAYER")
    c:SetAuraSlotCandidateFilters("CDM", filters)
    c:SetEnabled(true)
end

local function update_debuff_filter(btn)
    local cd = btn.cdmContainerDebuff
    if not cd then return end
    local barName = dodo.get_bar_name_by_button(btn)
    if not barName or not is_bar_cdm_enabled(barName) or not btn:IsVisible() then
        cd:SetEnabled(false)
        return
    end
    if UnitCanAssist("player", "target", true, true) then
        cd:SetEnabled(false)
        return
    end
    local filters = build_candidate_filters(btn, false)
    if not filters then cd:SetEnabled(false); return end
    cd:SetAuraSlotFilterString("CDM", "HARMFUL|PLAYER")
    cd:SetAuraSlotCandidateFilters("CDM", filters)
    cd:SetEnabled(true)
end

local function update_button_filter(btn)
    update_buff_filter(btn)
    update_debuff_filter(btn)
end

local function update_overlay_filters()
    if not dodoDB or dodoDB.enableActionbar == false then
        for btn in pairs(dodo.registeredButtons) do
            if btn.cdmContainer then btn.cdmContainer:SetEnabled(false) end
            if btn.cdmContainerDebuff then btn.cdmContainerDebuff:SetEnabled(false) end
        end
        return
    end
    for btn in pairs(dodo.registeredButtons) do
        update_button_filter(btn)
    end
end

-- ==============================
-- 물약 커스텀 CDM (AuraContainer 감지 불가 → 기존 방식 유지)
-- ==============================
local active_cdm_overlays = {}

local function customize_cooldown_text(cooldown)
    if not cooldown or cooldown.__textHooked then return end
    local region = cooldown:GetCountdownFontString()
    if region then
        local parent = cooldown:GetParent()
        region:SetParent(parent)
        region:ClearAllPoints()
        region:SetPoint("TOPLEFT", parent, "TOPLEFT", 5, -5)
        region:SetTextColor(0, 1, 0, 1)

        hooksecurefunc(region, "SetTextColor", function(self, r, g, b)
            if r ~= 0 or g ~= 1 or b ~= 0 then
                self:SetTextColor(0, 1, 0, 1)
            end
        end)
        hooksecurefunc(region, "SetPoint", function(self, point, relativeTo, relativePoint, x, y)
            if relativeTo ~= parent or point ~= "TOPLEFT" or x ~= 5 or y ~= -5 then
                self:SetParent(parent)
                self:ClearAllPoints()
                self:SetPoint("TOPLEFT", parent, "TOPLEFT", 5, -5)
            end
        end)
        cooldown.__textHooked = true
    end
end

CDMOverlayMixin = {}

function CDMOverlayMixin:OnLoad()
    local parent = self:GetParent()
    self:SetSize(parent:GetSize())
    self.InnerGlow:SetVertexColor(0, 1, 0, 1)
    self.Count:SetTextColor(1, 1, 0)
    if parent.cooldown then
        self:SetFrameLevel(parent.cooldown:GetFrameLevel() + 1)
    end
    self.Cooldown:SetPoint("TOPLEFT", parent.icon, "LEFT", 5, 0)
    self.Cooldown:SetPoint("BOTTOMRIGHT", parent.icon, "BOTTOM", 0, 3)
    self.Cooldown:SetDrawSwipe(false)
    self.Cooldown:SetUseAuraDisplayTime(true)
    self.Cooldown:SetCountdownFont("NumberFontNormal")
    self.Cooldown:SetCountdownAbbrevThreshold(60)
    self.Cooldown:SetScript("OnCooldownDone", function() self:StopCustomCDM() end)
    self:Hide()
end

function CDMOverlayMixin:StartCustomCDM(spellID, duration, startTime)
    self.customCDMSpellID = spellID
    self.customCDMEndTime = startTime + duration
    active_cdm_overlays[self] = true
    self.InnerGlow:Show()
    self.Cooldown:SetCooldown(startTime, duration)
    self.Cooldown:Show()
    self:Show()
    customize_cooldown_text(self.Cooldown)
end

function CDMOverlayMixin:StopCustomCDM()
    active_cdm_overlays[self] = nil
    self.customCDMSpellID = nil
    self.customCDMEndTime = nil
    self.Cooldown:Clear()
    self.Cooldown:Hide()
    self.InnerGlow:Hide()
    self.Count:Hide()
    self.TimerCooldown:Hide()
    self:Hide()
end

local _matched_buf = {}
local function get_matching_buttons(targetSpellID, configKey)
    wipe(_matched_buf)
    local itemConfig = CustomCDMConfigs[configKey]
    for btn in pairs(dodo.registeredButtons) do
        if btn.action then
            local actionType, id = GetActionInfo(btn.action)
            if actionType == "spell" then
                local baseSpellID = C_Spell.GetBaseSpell(id)
                local isMatch = false
                if itemConfig and itemConfig.matchIDs then
                    for _, tID in ipairs(itemConfig.matchIDs) do
                        if baseSpellID == tID or id == tID then isMatch = true; break end
                    end
                end
                if isMatch or baseSpellID == targetSpellID or id == targetSpellID or id == configKey or baseSpellID == configKey then
                    _matched_buf[#_matched_buf + 1] = btn
                end
            elseif actionType == "item" then
                local isMatch = false
                if itemConfig and itemConfig.matchIDs then
                    for _, tID in ipairs(itemConfig.matchIDs) do
                        if id == tID then isMatch = true; break end
                    end
                end
                if isMatch or id == configKey then
                    _matched_buf[#_matched_buf + 1] = btn
                else
                    local _, btnSpellID = C_Item.GetItemSpell(id)
                    if btnSpellID and btnSpellID == targetSpellID then
                        _matched_buf[#_matched_buf + 1] = btn
                    end
                end
            end
        end
    end
    return _matched_buf
end

local function init_custom_cdm_spells()
    for key, itemConfig in pairs(CustomCDMConfigs) do
        custom_cdmspell_map[key] = key
        if itemConfig.matchIDs then
            for _, tID in ipairs(itemConfig.matchIDs) do
                if C_Item.GetItemInfoInstant(tID) then
                    local item = Item:CreateFromItemID(tID)
                    if item and not item:IsItemEmpty() then
                        item:ContinueOnItemLoad(function()
                            local _, spellID = C_Item.GetItemSpell(tID)
                            if spellID then custom_cdmspell_map[spellID] = key end
                        end)
                    end
                else
                    custom_cdmspell_map[tID] = key
                end
            end
        end
    end
end

local function ensure_custom_cdm_overlay(btn)
    if not btn.cdmOverlay then
        btn.cdmOverlay = CreateFrame("Frame", nil, btn, "CDMOverlayTemplate")
        btn.cdmOverlay:ClearAllPoints()
        btn.cdmOverlay:SetAllPoints(btn)
    end
end

dodo.ActionbarOnSpellcastSucceeded = function(unitTarget, castGUID, spellID)
    local matchedItemID = custom_cdmspell_map[spellID]
    if not matchedItemID then return end

    local itemConfig  = CustomCDMConfigs[matchedItemID]
    local duration    = itemConfig and itemConfig.duration or 30
    local refreshType = itemConfig and itemConfig.type or 1
    local now         = GetTime()
    local activeAura  = custom_cdmauras[spellID]

    if activeAura then
        local remaining = activeAura.duration - (now - activeAura.startTime)
        if remaining > 0 then
            if refreshType == 2 then
                activeAura.duration = remaining + duration
                activeAura.startTime = now
            elseif refreshType == 3 then
                activeAura.duration = duration
                activeAura.startTime = now
            end
        else
            custom_cdmauras[spellID] = { startTime = now, duration = duration }
        end
    else
        custom_cdmauras[spellID] = { startTime = now, duration = duration }
    end

    local updatedAura = custom_cdmauras[spellID]
    local buttons = get_matching_buttons(spellID, matchedItemID)
    for _, btn in ipairs(buttons) do
        ensure_custom_cdm_overlay(btn)
        if btn.cdmOverlay then
            btn.cdmOverlay:StartCustomCDM(spellID, updatedAura.duration, updatedAura.startTime)
        end
    end
end

-- ==============================
-- 초기화
-- ==============================
dodo.ActionbarInitCDM = function()
    get_cdm_map() -- 현재 spec 기본값 lazy-init

    init_custom_cdm_spells()
    scan_linked_spells()

    C_Timer.After(0.5, function()
        create_aura_containers()
        update_overlay_filters()
    end)
end

dodo.ActionbarApplyCDM = function()
    update_overlay_filters()
end

-- ACTIONBAR_SLOT_CHANGED 등에서 호출 (Core.lua 인터페이스 유지)
dodo.BuildSpecialButtonCache = function()
    if InCombatLockdown() then return end
    scan_linked_spells()
    create_aura_containers()
    update_overlay_filters()
end

-- ==============================
dodo.AB_CDM_DB_KEYS  = CDM_DB_KEYS
dodo.AB_CDM_DEFAULTS = CDM_DEFAULTS

dodo.setCDMMapping = function(buffSpellID, actionBarSpellID)
    local cdmMap = get_cdm_map()
    if not cdmMap then return end
    cdmMap[buffSpellID] = actionBarSpellID
end

dodo.removeCDMMapping = function(buffSpellID)
    local cdmMap = get_cdm_map()
    if cdmMap then cdmMap[buffSpellID] = nil end
end

dodo.getCDMMappingForSkill = function(actionBarSpellID)
    local result = {}
    local cdmMap = get_cdm_map()
    if not cdmMap then return result end
    for buffID, skillID in pairs(cdmMap) do
        if skillID == actionBarSpellID then
            result[#result + 1] = buffID
        end
    end
    return result
end

-- ==============================
-- 특성/장비 변경 시 링크 재스캔
-- ==============================
local rescan_frame = CreateFrame("Frame")
local rescan_events = {
    "ACTIVE_COMBAT_CONFIG_CHANGED",
    "ACTIVE_PLAYER_SPECIALIZATION_CHANGED",
    "ACTIVE_TALENT_GROUP_CHANGED",
    "COOLDOWN_VIEWER_TABLE_HOTFIXED",
    "PLAYER_EQUIPMENT_CHANGED",
    "PLAYER_PVP_TALENT_UPDATE",
    "SPELLS_CHANGED",
    "TRAIT_CONFIG_UPDATED",
    "PLAYER_TARGET_CHANGED",
    "UNIT_FACTION",
}
for _, ev in ipairs(rescan_events) do rescan_frame:RegisterEvent(ev) end
rescan_frame:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_TARGET_CHANGED" then
        for btn in pairs(dodo.registeredButtons) do update_debuff_filter(btn) end
    elseif event == "UNIT_FACTION" then
        if ... == "target" then
            for btn in pairs(dodo.registeredButtons) do update_debuff_filter(btn) end
        end
    else
        if InCombatLockdown() then return end
        if event == "ACTIVE_PLAYER_SPECIALIZATION_CHANGED" then
            get_cdm_map() -- 새 spec 기본값 lazy-init
        end
        scan_linked_spells()
        update_overlay_filters()
    end
end)
