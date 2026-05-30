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
local FACTION_BAR_COLORS = FACTION_BAR_COLORS
local GameTooltip = GameTooltip
local ipairs = ipairs
local issecrettable = issecrettable
local issecretvalue = issecretvalue
local RAID_CLASS_COLORS = RAID_CLASS_COLORS
local TooltipDataProcessor = TooltipDataProcessor
local UnitClass = UnitClass
local UnitExists = UnitExists
local UnitGUID = UnitGUID
local UnitIsPlayer = UnitIsPlayer
local UnitReaction = UnitReaction
local UnitTokenFromGUID = UnitTokenFromGUID

local function is_secret(v)
    if not issecretvalue or not issecrettable then return false end
    return issecretvalue(v) or issecrettable(v)
end

-- ==============================
-- 로컬 상태 및 유틸리티
-- ==============================
local function apply_border_color(tooltip, r, g, b)
    if not tooltip or not tooltip.NineSlice then return end
    tooltip.NineSlice:SetBorderColor(r, g, b, 1)
end

local function reset_border_color(tooltip)
    if dodoDB.enableTooltip == false or dodoDB.useTooltipColor == false then return end
    if not tooltip or not tooltip.NineSlice then return end
    tooltip.NineSlice:SetBorderColor(1, 1, 1, 1)
end

local function get_name_line(tooltip)
    local name_line = tooltip.TextLeft1 or tooltip.nameLine
    if not name_line then
        name_line = _G[tooltip:GetName() .. "TextLeft1"]
        tooltip.nameLine = name_line
    end
    return name_line
end

local function match_border_to_name_color(tooltip, r, g, b)
    if dodoDB.useTooltipColor == false or dodoDB.enableTooltip == false then return end
    if not r then
        local name_line = get_name_line(tooltip)
        if name_line then
            r, g, b = name_line:GetTextColor()
        end
    end
    if r and g and b then
        apply_border_color(tooltip, r, g, b)
    end
end

local function get_ouf_color(class)
    local oUF = _G.oUF
    if oUF and oUF.colors and oUF.colors.class then
        local color = oUF.colors.class[class]
        if color then
            return color.r or color[1], color.g or color[2], color.b or color[3]
        end
    end
    local color = RAID_CLASS_COLORS[class]
    if color then
        return color.r, color.g, color.b
    end
end

local function get_ouf_reaction_color(reaction)
    local oUF = _G.oUF
    if oUF and oUF.colors and oUF.colors.reaction then
        local color = oUF.colors.reaction[reaction]
        if color then
            return color.r or color[1], color.g or color[2], color.b or color[3]
        end
    end
    local color = FACTION_BAR_COLORS[reaction]
    if color then
        return color.r, color.g, color.b
    end
end

-- ==============================
-- 콜백 핸들러
-- ==============================
local function on_unit_tooltip(self, data)
    if dodoDB.enableTooltip == false or dodoDB.useTooltipColor == false then return end
    if not data or is_secret(data) then return end
    
    local guid = data.guid
    if not guid or is_secret(guid) then return end
    
    local unit = UnitTokenFromGUID(guid)
    if not unit and UnitGUID("mouseover") == guid then
        unit = "mouseover"
    end
    
    if not unit or not UnitExists(unit) or is_secret(unit) then return end

    local name_line = get_name_line(self)
    if not name_line then return end

    local r, g, b
    if UnitIsPlayer(unit) then
        local _, class = UnitClass(unit)
        if class then
            r, g, b = get_ouf_color(class)
            if r then
                name_line:SetTextColor(r, g, b)
            end
        end
    else
        local reaction = UnitReaction(unit, "player")
        if reaction then
            r, g, b = get_ouf_reaction_color(reaction)
            if r then
                name_line:SetTextColor(r, g, b)
            end
        end
    end
    
    match_border_to_name_color(self, r, g, b)
end

local function on_item_tooltip(self, data)
    if dodoDB.enableTooltip == false or dodoDB.useTooltipColor == false then return end
    match_border_to_name_color(self)
end

local function on_spell_tooltip(self, data)
    if dodoDB.enableTooltip == false or dodoDB.useTooltipColor == false then return end
    apply_border_color(self, 1, 0.82, 0)
end

-- ==============================
-- 초기화
-- ==============================
local function update_color()
    -- 필요시 상태 동기화
end

dodo.UpdateTooltipColor = update_color

local function initialize()
    if dodoDB.useTooltipColor == nil then dodoDB.useTooltipColor = true end

    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, on_unit_tooltip)
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, on_item_tooltip)
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Spell, on_spell_tooltip)
    
    if Enum.TooltipDataType.UnitAura then
        TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.UnitAura, on_spell_tooltip)
    end
    if Enum.TooltipDataType.PetAction then
        TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.PetAction, on_spell_tooltip)
    end

    local tooltips = { GameTooltip, ShoppingTooltip1, ShoppingTooltip2, ItemRefTooltip }
    for _, tt in ipairs(tooltips) do
        if tt then
            tt:HookScript("OnHide", reset_border_color)
        end
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
            name = "색상 변경",
            get = function() return dodoDB and dodoDB.useTooltipColor ~= false end,
            set = function(checked)
                if dodoDB then dodoDB.useTooltipColor = checked end
                update_color()
            end,
            disabled = function() return dodoDB and dodoDB.enableTooltip == false end,
        }
    })
end
