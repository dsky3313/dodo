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
local issecrettable = issecrettable
local issecretvalue = issecretvalue
local TooltipDataProcessor = TooltipDataProcessor

local function is_secret(v)
    if not issecretvalue or not issecrettable then return false end
    return issecretvalue(v) or issecrettable(v)
end

-- ==============================
-- 로컬 상태 및 유틸리티
-- ==============================
local function get_name_line(tooltip)
    local name_line = tooltip.TextLeft1 or tooltip.nameLine
    if not name_line then
        name_line = _G[tooltip:GetName() .. "TextLeft1"]
        tooltip.nameLine = name_line
    end
    return name_line
end

-- ==============================
-- 콜백 핸들러
-- ==============================
local function on_item_tooltip(self, data)
    if dodoDB.enableTooltip == false then return end
    
    local item_id = data.id 
    if not item_id then return end

    local GetItemInfo = (C_Item and C_Item.GetItemInfo)
    local _, _, _, _, _, _, _, _, _, icon = GetItemInfo(item_id)
    if icon then
        local name_line = get_name_line(self)
        local text = name_line and name_line:GetText()
        if text and not is_secret(text) and not text:find("|T") then
            name_line:SetText(format("|T%d:18:18:0:0|t %s", icon, text))
        end
    end
end

local function on_spell_tooltip(self, data)
    if dodoDB.enableTooltip == false then return end
    
    local spell_id = data.id 
    if not spell_id then return end

    local GetSpellInfo = (C_Spell and C_Spell.GetSpellInfo)
    local spell_info = GetSpellInfo(spell_id)
    if spell_info and spell_info.iconID then
        local name_line = get_name_line(self)
        local text = name_line and name_line:GetText()
        if text and not is_secret(text) and not text:find("|T") then
            name_line:SetText(format("|T%d:18:18:0:0|t %s", spell_info.iconID, text))
        end
    end
end

-- ==============================
-- 초기화
-- ==============================
local function update_icon()
    -- 필요시 상태 동기화
end

dodo.UpdateTooltipIcon = update_icon

local function initialize()
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, on_item_tooltip)
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Spell, on_spell_tooltip)
    
    if Enum.TooltipDataType.UnitAura then
        TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.UnitAura, on_spell_tooltip)
    end
    if Enum.TooltipDataType.PetAction then
        TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.PetAction, on_spell_tooltip)
    end
end

local init_frame = CreateFrame("Frame")
init_frame:RegisterEvent("PLAYER_LOGIN")
init_frame:SetScript("OnEvent", function(self, event)
    initialize()
    self:UnregisterEvent("PLAYER_LOGIN")
end)
