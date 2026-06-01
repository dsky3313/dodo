-- ==============================
-- Inspired
-- ==============================
-- idTip (https://www.curseforge.com/wow/addons/idtip)

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

local type_mapping = {}
local function register_type(enum_name, label)
    if Enum.TooltipDataType[enum_name] then
        type_mapping[Enum.TooltipDataType[enum_name]] = label
    end
end

register_type("Quest", "QuestID")
register_type("Achievement", "AchievementID")
register_type("Currency", "CurrencyID")
register_type("Mount", "MountID")
register_type("Companion", "CompanionID")
register_type("Macro", "MacroID")
register_type("TraitNode", "TraitNodeID")
register_type("TraitEntry", "TraitEntryID")
register_type("TraitDefinition", "TraitDefinitionID")
register_type("Vignette", "VignetteID")
register_type("AreaPoi", "AreaPoiID")
register_type("Toy", "ItemID")

-- ==============================
-- 캐싱
-- ==============================
local format = string.format
local issecrettable = issecrettable
local issecretvalue = issecretvalue
local pairs = pairs
local tonumber = tonumber
local TooltipDataProcessor = TooltipDataProcessor

local function is_secret(v)
    if not issecretvalue or not issecrettable then return false end
    return issecretvalue(v) or issecrettable(v)
end

-- ==============================
-- 로컬 상태 및 유틸리티
-- ==============================
local need_spacer = true

local function add_id_line(tooltip, label, id)
    if not id or dodoDB.useTooltipID == false or dodoDB.enableTooltip == false then return end
    if need_spacer then
        tooltip:AddLine(" ")
        need_spacer = false
    end
    tooltip:AddDoubleLine(format("|cffffd200%s|r", label), format("|cffffffff%s|r", id))
end

local function add_expansion_line(tooltip, exp_id)
    if exp_id == nil or not EXPANSION_NAMES[exp_id] then return end
    add_id_line(tooltip, "확장팩", EXPANSION_NAMES[exp_id])
end

-- ==============================
-- 콜백 핸들러
-- ==============================
local function on_unit_tooltip(self, data)
    if dodoDB.enableTooltip == false or dodoDB.useTooltipID == false then return end
    if not data or is_secret(data) then return end
    
    local guid = data.guid
    if not guid or is_secret(guid) then return end
    
    need_spacer = true
    if not guid:find("Player-") then
        local npc_id = tonumber(guid:match("-(%d+)-%x+$"))
        if npc_id then
            add_id_line(self, "NPC ID", npc_id)
        end
    end
end

local function on_item_tooltip(self, data)
    if dodoDB.enableTooltip == false or dodoDB.useTooltipID == false then return end
    need_spacer = true
    
    local item_id = data.id 
    if not item_id then return end

    local GetItemInfo = (C_Item and C_Item.GetItemInfo)
    local _, _, _, _, _, _, _, _, _, icon, _, _, _, _, expac_id = GetItemInfo(item_id)

    add_id_line(self, "ItemID", item_id)
    add_id_line(self, "IconID", icon)
    add_expansion_line(self, expac_id)
end

local function on_spell_tooltip(self, data)
    if dodoDB.enableTooltip == false or dodoDB.useTooltipID == false then return end
    need_spacer = true
    
    local spell_id = data.id 
    if not spell_id then return end

    local GetSpellInfo = (C_Spell and C_Spell.GetSpellInfo)
    local spell_info = GetSpellInfo(spell_id)
    if spell_info and spell_info.iconID then
        add_id_line(self, "SpellID", spell_id)
        add_id_line(self, "IconID", spell_info.iconID)
    end
end

local function on_generic_tooltip(self, data)
    if dodoDB.enableTooltip == false or dodoDB.useTooltipID == false then return end
    need_spacer = true
    local label = type_mapping[data.type] or "ObjectID"
    add_id_line(self, label, data.id)
end

-- ==============================
-- 초기화
-- ==============================
local function update_id()
    -- 필요시 상태 동기화
end

dodo.UpdateTooltipID = update_id

local function initialize()
    if dodoDB.useTooltipID == nil then dodoDB.useTooltipID = true end

    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, on_unit_tooltip)
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, on_item_tooltip)
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Spell, on_spell_tooltip)
    
    if Enum.TooltipDataType.UnitAura then
        TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.UnitAura, on_spell_tooltip)
    end
    if Enum.TooltipDataType.PetAction then
        TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.PetAction, on_spell_tooltip)
    end
    
    for data_type, _ in pairs(type_mapping) do
        TooltipDataProcessor.AddTooltipPostCall(data_type, on_generic_tooltip)
    end
end

local init_frame = CreateFrame("Frame")
init_frame:RegisterEvent("PLAYER_LOGIN")
init_frame:SetScript("OnEvent", function(self, event)
    initialize()
    self:UnregisterEvent("PLAYER_LOGIN")
end)

-- ==============================
-- 설정 등록
-- ==============================
if dodo.RegisterEditModeSystemSetting then
    dodo.RegisterEditModeSystemSetting("Tooltip", {
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
