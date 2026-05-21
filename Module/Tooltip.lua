-- ==============================
-- Inspired
-- ==============================
-- Enhance QoL (https://www.curseforge.com/wow/addons/eqol)
-- idTip (https://www.curseforge.com/wow/addons/idtip)

-- ==============================
-- 설정 및 테이블
-- ==============================
---@diagnostic disable: lowercase-global, param-type-mismatch, redundant-parameter, undefined-field, undefined-global
local addonName, dodo = ...
local module = {}
dodo:RegisterModule("Tooltip", module)

local LibEditMode = LibStub and LibStub("LibEditMode", true)

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

-- 안전한 타입 매핑 생성
local typeMapping = {}
local function register_type(enumName, label)
    if Enum.TooltipDataType[enumName] then
        typeMapping[Enum.TooltipDataType[enumName]] = label
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
-- 프레임 및 이벤트
-- ==============================

-- ==============================
-- 캐싱
-- ==============================
local AuraUtil = AuraUtil
local C_MountJournal = C_MountJournal
local C_UnitAuras = C_UnitAuras
local CreateFrame = CreateFrame
local Enum = Enum
local FACTION_BAR_COLORS = FACTION_BAR_COLORS
local GameTooltip = GameTooltip
local GameTooltipStatusBar = GameTooltipStatusBar
local GetItemInfo = C_Item and C_Item.GetItemInfo
local GetSpellInfo = C_Spell and C_Spell.GetSpellInfo
local hooksecurefunc = hooksecurefunc
local ipairs = ipairs
local IsMounted = IsMounted
local issecretvalue = issecretvalue or function() return false end
local issecrettable = issecrettable or function() return false end
local pairs = pairs
local RAID_CLASS_COLORS = RAID_CLASS_COLORS
local TooltipDataProcessor = TooltipDataProcessor
local UnitClass = UnitClass
local UnitExists = UnitExists
local UnitGUID = UnitGUID
local UnitIsPlayer = UnitIsPlayer
local UnitReaction = UnitReaction
local UnitTokenFromGUID = UnitTokenFromGUID
local _G = _G
local format = string.format
local select = select
local tonumber = tonumber
local tostring = tostring
local type = type

-- 안전성 검사
local function is_secret(v)
    return issecretvalue(v) or issecrettable(v)
end

-- ==============================
-- 기능 1: 유틸리티 헬퍼
-- ==============================
local needSpacer = true

local function add_id_line(self, label, id)
    if not id or not dodo.DB or dodo.DB.useTooltipID == false then return end
    if needSpacer then
        self:AddLine(" ")
        needSpacer = false
    end
    self:AddDoubleLine(format("|cffffd200%s|r", label), format("|cffffffff%s|r", id))
end

local function add_expansion_line(self, expID)
    if expID == nil or not EXPANSION_NAMES[expID] then return end
    add_id_line(self, "확장팩", EXPANSION_NAMES[expID])
end

local function apply_border_color(tooltip, r, g, b)
    if not tooltip or not tooltip.NineSlice then return end
    tooltip.NineSlice:SetBorderColor(r, g, b, 1)
end

local function reset_border_color(tooltip)
    if not tooltip or not tooltip.NineSlice then return end
    tooltip.NineSlice:SetBorderColor(1, 1, 1, 1)
end

local function get_name_line(tooltip)
    local nameLine = tooltip.TextLeft1 or tooltip.nameLine
    if not nameLine then
        nameLine = _G[tooltip:GetName() .. "TextLeft1"]
        tooltip.nameLine = nameLine
    end
    return nameLine
end

-- 이름 라인에서 색상을 훔쳐오는 함수
local function match_border_to_name_color(self, r, g, b)
    if not dodo.DB or dodo.DB.useTooltipColor == false then return end
    if not r then
        local nameLine = self.TextLeft1 or self.nameLine
        if not nameLine then
            nameLine = _G[self:GetName() .. "TextLeft1"]
            self.nameLine = nameLine
        end
        if nameLine then
            r, g, b = nameLine:GetTextColor()
        end
    end
    if r and g and b then
        apply_border_color(self, r, g, b)
    end
end

local function get_mount_info(unit)
    if not unit or not UnitIsPlayer(unit) then return end
    if unit == "player" and not IsMounted() then return end
    
    local foundName, foundIcon
    AuraUtil.ForEachAura(unit, "HELPFUL", nil, function(aura)
        local spellID = aura and aura.spellId
        if spellID and not is_secret(spellID) then
            local mountID = C_MountJournal.GetMountFromSpell(spellID)
            if mountID then
                local name, _, icon = C_MountJournal.GetMountInfoByID(mountID)
                if name and name ~= "" then
                    foundName, foundIcon = name, icon
                    return true -- 순회 중단
                end
            end
        end
    end, true)
    return foundName, foundIcon
end

-- ==============================
-- 기능 2: 툴팁 개선 콜백
-- ==============================
local function OnUnitTooltip(self, data)
    if not dodo.DB or dodo.DB.enableTooltipModule == false then return end
    if not data or is_secret(data) then return end
    
    local guid = data.guid
    if not guid or is_secret(guid) then return end
    
    local unit = UnitTokenFromGUID(guid)
    if not unit and UnitGUID("mouseover") == guid then
        unit = "mouseover"
    end
    
    if not unit or not UnitExists(unit) or is_secret(unit) then return end

    needSpacer = true
    local nameLine = get_name_line(self)
    if not nameLine then return end

    local r, g, b
    if UnitIsPlayer(unit) then
        local _, class = UnitClass(unit)
        if class and dodo.DB.useTooltipColor ~= false then
            local color = RAID_CLASS_COLORS[class]
            if color then
                r, g, b = color.r, color.g, color.b
                nameLine:SetTextColor(r, g, b)
            end
        end
        if dodo.DB.useTooltipMount ~= false then
            local mountName, mountIcon = get_mount_info(unit)
            if mountName then
                local iconText = mountIcon and format("|T%d:14:14:0:0|t ", mountIcon) or ""
                self:AddDoubleLine("|cffffd200탈것|r", iconText .. mountName)
            end
        end
    else
        local reaction = UnitReaction(unit, "player")
        if reaction and dodo.DB.useTooltipColor ~= false then
            local color = FACTION_BAR_COLORS[reaction]
            if color then
                r, g, b = color.r, color.g, color.b
                nameLine:SetTextColor(r, g, b)
            end
        end
        local npcID = tonumber(guid:match("-(%d+)-%x+$"))
        if npcID then add_id_line(self, "NPC ID", npcID) end
    end
    match_border_to_name_color(self, r, g, b)
end

local function OnItemTooltip(self, data)
    if not dodo.DB or dodo.DB.enableTooltipModule == false then return end
    needSpacer = true
    
    local itemID = data.id 
    if not itemID then return end

    -- 아이템 등급에 따른 테두리 색상
    match_border_to_name_color(self)

    local _, _, _, _, _, _, _, _, _, icon, _, _, _, _, expacID = GetItemInfo(itemID)
    if icon then
        local nameLine = get_name_line(self)
        local text = nameLine and nameLine:GetText()
        if text and not is_secret(text) and not text:find("|T") then
            nameLine:SetText(format("|T%d:18:18:0:0|t %s", icon, text))
        end
    end

    add_id_line(self, "ItemID", itemID)
    add_id_line(self, "IconID", icon)
    add_expansion_line(self, expacID)
end

local function OnSpellTooltip(self, data)
    if not dodo.DB or dodo.DB.enableTooltipModule == false then return end
    needSpacer = true
    
    local spellID = data.id 
    if not spellID then return end

    local spellInfo = GetSpellInfo(spellID)
    if spellInfo and spellInfo.iconID then
        local nameLine = get_name_line(self)
        local text = nameLine and nameLine:GetText()
        if text and not is_secret(text) and not text:find("|T") then
            nameLine:SetText(format("|T%d:18:18:0:0|t %s", spellInfo.iconID, text))
        end
        add_id_line(self, "SpellID", spellID)
        add_id_line(self, "IconID", spellInfo.iconID)
    end
    if dodo.DB.useTooltipColor ~= false then
        apply_border_color(self, 1, 0.82, 0)
    end
end

local function OnGenericTooltip(self, data)
    if not dodo.DB or dodo.DB.enableTooltipModule == false then return end
    needSpacer = true
    local label = typeMapping[data.type] or "ObjectID"
    add_id_line(self, label, data.id)
end

-- ==============================
-- 모듈 On/Off 활성화 상태 제어
-- ==============================
local function update_module_state()
    if not dodo.DB then return end
    
    local enabled = (dodo.DB.enableTooltipModule ~= false)
    if not enabled then
        reset_border_color(GameTooltip)
        reset_border_color(ShoppingTooltip1)
        reset_border_color(ShoppingTooltip2)
        if _G.ItemRefTooltip then reset_border_color(_G.ItemRefTooltip) end
        if not GameTooltipStatusBar:IsShown() and UnitExists("mouseover") then
            GameTooltipStatusBar:Show()
        end
    else
        if dodo.DB.useTooltipHealthHide then
            GameTooltipStatusBar:Hide()
        else
            if not GameTooltipStatusBar:IsShown() and UnitExists("mouseover") then
                GameTooltipStatusBar:Show()
            end
        end
    end
end

dodo.UpdateTooltipModuleState = update_module_state

-- ==============================
-- 초기화
-- ==============================
local function create_ui()
    -- TooltipDataProcessor 등록
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, OnUnitTooltip)
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, OnItemTooltip)
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Spell, OnSpellTooltip)
    
    if Enum.TooltipDataType.UnitAura then
        TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.UnitAura, OnSpellTooltip)
    end
    if Enum.TooltipDataType.PetAction then
        TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.PetAction, OnSpellTooltip)
    end
    
    for dataType, _ in pairs(typeMapping) do
        TooltipDataProcessor.AddTooltipPostCall(dataType, OnGenericTooltip)
    end

    local tooltips = { GameTooltip, ShoppingTooltip1, ShoppingTooltip2, _G.ItemRefTooltip }
    for _, tt in ipairs(tooltips) do
        if tt then
            tt:HookScript("OnHide", reset_border_color)
        end
    end
end

local function initialize()
    create_ui()
end

local function update_feature()
    if dodo.DB.useTooltipHealthHide ~= false then
        GameTooltipStatusBar:Hide()
    end
end

-- ==============================
-- 모듈 생명주기
-- ==============================
function module:OnEnable()
    if not dodo.DB then return end

    initialize()
    update_feature()
    update_module_state()

    -- 상태바 숨김을 위한 훅
    hooksecurefunc(GameTooltipStatusBar, "Show", function(self) 
        if dodo.DB and dodo.DB.enableTooltipModule ~= false and dodo.DB.useTooltipHealthHide ~= false then 
            self:Hide() 
        end
    end)

    -- LibEditMode 등록
    if LibEditMode then
        local systemID = Enum.EditModeSystem.HudTooltip or 10

        LibEditMode:AddSystemSettings(systemID, {
            {
                kind = LibEditMode.SettingType.Checkbox,
                name = "아이디(ID) 표시",
                desc = "툴팁 하단에 스펠 ID, 아이템 ID, NPC ID 등 각종 게임 내 식별 정보를 출력합니다.",
                default = true,
                get = function()
                    return (dodo and dodo.DB and dodo.DB.useTooltipID ~= false)
                end,
                set = function(_, newValue)
                    if dodo and dodo.DB then
                        dodo.DB.useTooltipID = newValue
                    end
                end,
                disabled = function()
                    return (dodo and dodo.DB and dodo.DB.enableTooltipModule == false)
                end,
            },
            {
                kind = LibEditMode.SettingType.Checkbox,
                name = "직업/우호도 색상 테두리",
                desc = "툴팁 테두리와 유닛 이름을 직업 색상(플레이어) 또는 우호도 색상(NPC)으로 변경합니다.",
                default = true,
                get = function()
                    return (dodo and dodo.DB and dodo.DB.useTooltipColor ~= false)
                end,
                set = function(_, newValue)
                    if dodo and dodo.DB then
                        dodo.DB.useTooltipColor = newValue
                    end
                end,
                disabled = function()
                    return (dodo and dodo.DB and dodo.DB.enableTooltipModule == false)
                end,
            },
            {
                kind = LibEditMode.SettingType.Checkbox,
                name = "체력바 숨기기",
                desc = "툴팁 하단의 기본 체력 바(GameTooltipStatusBar)를 보이지 않도록 숨깁니다.",
                default = true,
                get = function()
                    return (dodo and dodo.DB and dodo.DB.useTooltipHealthHide ~= false)
                end,
                set = function(_, newValue)
                    if dodo and dodo.DB then
                        dodo.DB.useTooltipHealthHide = newValue
                    end
                    update_module_state()
                end,
                disabled = function()
                    return (dodo and dodo.DB and dodo.DB.enableTooltipModule == false)
                end,
            },
            {
                kind = LibEditMode.SettingType.Checkbox,
                name = "탈것 정보 표시",
                desc = "플레이어 툴팁에 현재 탑승 중인 탈것의 이름과 아이콘 정보를 표시합니다.",
                default = true,
                get = function()
                    return (dodo and dodo.DB and dodo.DB.useTooltipMount ~= false)
                end,
                set = function(_, newValue)
                    if dodo and dodo.DB then
                        dodo.DB.useTooltipMount = newValue
                    end
                end,
                disabled = function()
                    return (dodo and dodo.DB and dodo.DB.enableTooltipModule == false)
                end,
            }
        })
    end

    if dodo.RegisterEditModeSetting then
        dodo.RegisterEditModeSetting("편의기능", {
            {
                name = "툴팁",
                get = function() return dodo.DB and dodo.DB.enableTooltipModule ~= false end,
                set = function(checked)
                    if dodo.DB then dodo.DB.enableTooltipModule = checked end
                    update_module_state()
                end
            }
        })
    end
end