-- ==============================
-- Inspired
-- ==============================
-- Enhance QoL (https://www.curseforge.com/wow/addons/eqol)

-- ==============================
-- 설정 및 테이블
-- ==============================
---@diagnostic disable: lowercase-global, param-type-mismatch, redundant-parameter, undefined-field, undefined-global
local addonName, dodo = ...
dodoDB = dodoDB or {}

-- ==============================
-- 캐싱
-- ==============================
local _G = _G
local format = string.format
local GetItemInfo = C_Item and C_Item.GetItemInfo
local GetMacroSpellID = C_ActionBar and C_ActionBar.GetMacroSpellID
local GetSpellInfo = C_Spell and C_Spell.GetSpellInfo
local issecrettable = issecrettable
local issecretvalue = issecretvalue
local string = string
local TooltipDataProcessor = TooltipDataProcessor

local function check_secret_value(val)
    if not issecretvalue or not issecrettable then return false end
    return issecretvalue(val) or issecrettable(val)
end

-- ==============================
-- 로컬 상태 및 유틸리티
-- ==============================
local function find_tooltip_title_element(tooltip)
    local title_element = tooltip.TextLeft1 or tooltip.nameLine
    if not title_element then
        title_element = _G[tooltip:GetName() .. "TextLeft1"]
        tooltip.nameLine = title_element
    end
    return title_element
end

-- ==============================
-- 콜백 핸들러
-- ==============================
local function process_item_icon(tooltip, data)
    if dodoDB.enableTooltip == false or dodoDB.useTooltipIcon == false then return end
    if not GetItemInfo then return end

    local item_id = data.id
    if not item_id then return end

    local _, _, _, _, _, _, _, _, _, icon = GetItemInfo(item_id)
    if icon then
        local title_element = find_tooltip_title_element(tooltip)
        local text = title_element and title_element:GetText()
        if text and not check_secret_value(text) and string.sub(text, 1, 2) ~= "|T" then
            title_element:SetText(format("|T%d:18:18:0:0|t %s", icon, text))
        end
    end
end

local function process_spell_icon(tooltip, data)
    if dodoDB.enableTooltip == false or dodoDB.useTooltipIcon == false then return end
    if not GetSpellInfo then return end

    local spell_id = data.id
    if not spell_id then return end

    local spell_info = GetSpellInfo(spell_id)
    if spell_info and spell_info.iconID then
        local title_element = find_tooltip_title_element(tooltip)
        local text = title_element and title_element:GetText()
        if text and not check_secret_value(text) and string.sub(text, 1, 2) ~= "|T" then
            title_element:SetText(format("|T%d:18:18:0:0|t %s", spell_info.iconID, text))
        end
    end
end

local function process_macro_icon(tooltip, data)
    if dodoDB.enableTooltip == false or dodoDB.useTooltipIcon == false then return end
    if not GetMacroSpellID or not GetSpellInfo then return end

    local macro_id = data.id
    if not macro_id then return end

    local spell_id = GetMacroSpellID(macro_id)
    if not spell_id then return end

    local spell_info = GetSpellInfo(spell_id)
    if spell_info and spell_info.iconID then
        local title_element = find_tooltip_title_element(tooltip)
        local text = title_element and title_element:GetText()
        if text and not check_secret_value(text) and string.sub(text, 1, 2) ~= "|T" then
            title_element:SetText(format("|T%d:18:18:0:0|t %s", spell_info.iconID, text))
        end
    end
end

-- ==============================
-- 초기화
-- ==============================
local function initialize()
    if dodoDB.useTooltipIcon == nil then dodoDB.useTooltipIcon = true end

    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, process_item_icon)
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Spell, process_spell_icon)

    if Enum.TooltipDataType.UnitAura then
        TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.UnitAura, process_spell_icon)
    end
    if Enum.TooltipDataType.PetAction then
        TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.PetAction, process_spell_icon)
    end
    if Enum.TooltipDataType.Macro then
        TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Macro, process_macro_icon)
    end
end

local function on_event(self)
    initialize()
    self:UnregisterEvent("PLAYER_LOGIN")
end

local init_frame = CreateFrame("Frame")
init_frame:RegisterEvent("PLAYER_LOGIN")
init_frame:SetScript("OnEvent", on_event)

-- ==============================
-- 설정 등록
-- ==============================
if dodo.RegisterEditModeSystemSetting then
    dodo.RegisterEditModeSystemSetting(Enum.EditModeSystem.HudTooltip, {
        {
            name = "아이콘 표시",
            get = function() return dodoDB and dodoDB.useTooltipIcon ~= false end,
            set = function(checked)
                if dodoDB then dodoDB.useTooltipIcon = checked end
            end,
            disabled = function() return dodoDB and dodoDB.enableTooltip == false end,
        }
    })
end

