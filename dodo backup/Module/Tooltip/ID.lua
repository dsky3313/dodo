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

local EXPANSION_NAMES = {
    [0] = "오리지널",
    [1] = "불타는 성전",
    [2] = "리치 왕의 분노",
    [3] = "대격변",
    [4] = "판다리아의 안개",
    [5] = "드레노어의 전쟁군주",
    [6] = "군단",
    [7] = "격전의 아제로스",
    [8] = "어둠땅",
    [9] = "용군단",
    [10] = "내부 전쟁",
    [11] = "한밤",
}

-- 툴팁 데이터 타입과 표시 라벨 간 직접 맵핑
local tooltip_id_labels = {}
local raw_mappings = {
    Quest = "QuestID",
    Achievement = "AchievementID",
    Currency = "CurrencyID",
    Mount = "MountID",
    Companion = "CompanionID",
    Macro = "MacroID",
    TraitNode = "TraitNodeID",
    TraitEntry = "TraitEntryID",
    TraitDefinition = "TraitDefinitionID",
    Vignette = "VignetteID",
    AreaPoi = "AreaPoiID",
    Toy = "ItemID",
}

if Enum.TooltipDataType then
    for name, label in pairs(raw_mappings) do
        local enum_val = Enum.TooltipDataType[name]
        if enum_val then
            tooltip_id_labels[enum_val] = label
        end
    end
end

-- ==============================
-- 캐싱
-- ==============================
local C_Item = C_Item
local C_Spell = C_Spell
local format = string.format
local issecrettable = issecrettable
local issecretvalue = issecretvalue
local pairs = pairs
local tonumber = tonumber
local TooltipDataProcessor = TooltipDataProcessor


local function check_restricted_data(val)
    if not issecretvalue or not issecrettable then return false end
    return issecretvalue(val) or issecrettable(val)
end

-- ==============================
-- 로컬 상태 및 유틸리티
-- ==============================
local has_drawn_divider = true

local function append_tooltip_id_row(tooltip, label, id)
    if not id or dodoDB.useTooltipID == false or dodoDB.enableTooltip == false then return end
    if has_drawn_divider then
        tooltip:AddLine(" ")
        has_drawn_divider = false
    end
    tooltip:AddDoubleLine(format("|cffffd200%s|r", label), format("|cffffffff%s|r", id))
end

local function append_expansion_name(tooltip, exp_id)
    if exp_id and EXPANSION_NAMES[exp_id] then
        append_tooltip_id_row(tooltip, "확장팩", EXPANSION_NAMES[exp_id])
    end
end

-- ==============================
-- 콜백 핸들러
-- ==============================
local function handle_unit_id(tooltip, data)
    if dodoDB.enableTooltip == false or dodoDB.useTooltipID == false then return end
    if not data or check_restricted_data(data) then return end
    
    local guid = data.guid
    if not guid or check_restricted_data(guid) then return end
    
    has_drawn_divider = true
    if not guid:find("Player-") then
        local npc_id = tonumber(guid:match("-(%d+)-%x+$"))
        if npc_id then
            append_tooltip_id_row(tooltip, "NPC ID", npc_id)
        end
    end
end

local function handle_item_id(tooltip, data)
    if dodoDB.enableTooltip == false or dodoDB.useTooltipID == false then return end
    has_drawn_divider = true
    
    local item_id = data.id 
    if not item_id then return end

    if not C_Item then return end
    local _, _, _, _, _, _, _, _, _, icon, _, _, _, _, expac_id = C_Item.GetItemInfo(item_id)
    append_tooltip_id_row(tooltip, "ItemID", item_id)
    append_tooltip_id_row(tooltip, "IconID", icon)
    append_expansion_name(tooltip, expac_id)
end

local function handle_spell_id(tooltip, data)
    if dodoDB.enableTooltip == false or dodoDB.useTooltipID == false then return end
    has_drawn_divider = true
    
    local spell_id = data.id 
    if not spell_id then return end

    if not C_Spell then return end
    local spell_info = C_Spell.GetSpellInfo(spell_id)
    if spell_info and spell_info.iconID then
        append_tooltip_id_row(tooltip, "SpellID", spell_id)
        append_tooltip_id_row(tooltip, "IconID", spell_info.iconID)
    end
end

local function handle_generic_id(tooltip, data)
    if dodoDB.enableTooltip == false or dodoDB.useTooltipID == false then return end
    has_drawn_divider = true
    local label = tooltip_id_labels[data.type] or "ObjectID"
    append_tooltip_id_row(tooltip, label, data.id)
end

-- ==============================
-- 초기화
-- ==============================
local function initialize()
    if dodoDB.useTooltipID == nil then dodoDB.useTooltipID = true end

    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, handle_unit_id)
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, handle_item_id)
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Spell, handle_spell_id)
    
    if Enum.TooltipDataType.UnitAura then
        TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.UnitAura, handle_spell_id)
    end
    if Enum.TooltipDataType.PetAction then
        TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.PetAction, handle_spell_id)
    end
    
    for data_type, _ in pairs(tooltip_id_labels) do
        TooltipDataProcessor.AddTooltipPostCall(data_type, handle_generic_id)
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
            name = "ID 표시",
            get = function() return dodoDB and dodoDB.useTooltipID ~= false end,
            set = function(checked)
                if dodoDB then dodoDB.useTooltipID = checked end
                update_id()
            end,
            disabled = function() return dodoDB and dodoDB.enableTooltip == false end,
        }
    })
end

