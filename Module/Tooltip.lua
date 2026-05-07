-- ==============================
-- Inspired
-- ==============================
-- Enhance QoL (https://www.curseforge.com/wow/addons/eqol)
-- idTip (https://www.curseforge.com/wow/addons/idtip)

-- ==============================
-- 설정 및 테이블
-- ==============================
---@diagnostic disable: lowercase-global, undefined-field, undefined-global
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

-- 안전한 타입 매핑 생성
local typeMapping = {}
local function RegisterType(enumName, label)
    if Enum.TooltipDataType[enumName] then
        typeMapping[Enum.TooltipDataType[enumName]] = label
    end
end

RegisterType("Quest", "QuestID")
RegisterType("Achievement", "AchievementID")
RegisterType("Currency", "CurrencyID")
RegisterType("Mount", "MountID")
RegisterType("Companion", "CompanionID")
RegisterType("Macro", "MacroID")
RegisterType("TraitNode", "TraitNodeID")
RegisterType("TraitEntry", "TraitEntryID")
RegisterType("TraitDefinition", "TraitDefinitionID")
RegisterType("Vignette", "VignetteID")
RegisterType("AreaPoi", "AreaPoiID")

RegisterType("Toy", "ItemID")

-- ==============================
-- 캐싱 (Upvalues)
-- ==============================
local _G = _G
local format, select, tonumber, type, tostring = string.format, select, tonumber, type, tostring
local GameTooltip = GameTooltip
local UnitClass = UnitClass
local UnitExists = UnitExists
local UnitGUID = UnitGUID
local UnitIsPlayer = UnitIsPlayer
local UnitReaction = UnitReaction
local UnitTokenFromGUID = UnitTokenFromGUID
local IsMounted = IsMounted
local GetItemInfo = (C_Item and C_Item.GetItemInfo)
local GetSpellInfo = (C_Spell and C_Spell.GetSpellInfo)
local RAID_CLASS_COLORS = RAID_CLASS_COLORS
local FACTION_BAR_COLORS = FACTION_BAR_COLORS
local TooltipDataProcessor = TooltipDataProcessor
local C_UnitAuras = C_UnitAuras
local C_MountJournal = C_MountJournal

-- 안전성 검사
local function isSecret(v)
    if not issecretvalue or not issecrettable then return false end
    return issecretvalue(v) or issecrettable(v)
end

-- ==============================
-- 동작 (유틸리티)
-- ==============================
local needSpacer = true

local function AddIDLine(self, label, id)
    if not id or dodoDB.useTooltipID == false then return end
    if needSpacer then
        self:AddLine(" ")
        needSpacer = false
    end
    self:AddDoubleLine(format("|cffffd200%s|r", label), format("|cffffffff%s|r", id))
end

local function AddExpansionLine(self, expID)
    if expID == nil or not EXPANSION_NAMES[expID] then return end
    AddIDLine(self, "확장팩", EXPANSION_NAMES[expID])
end

local function ApplyBorderColor(tooltip, r, g, b)
    if not tooltip or not tooltip.NineSlice then return end
    tooltip.NineSlice:SetBorderColor(r, g, b, 1)
end

local function ResetBorderColor(tooltip)
    if not tooltip or not tooltip.NineSlice then return end
    tooltip.NineSlice:SetBorderColor(1, 1, 1, 1)
end

local function GetNameLine(tooltip)
    local nameLine = tooltip.TextLeft1 or tooltip.nameLine
    if not nameLine then
        nameLine = _G[tooltip:GetName() .. "TextLeft1"]
        tooltip.nameLine = nameLine
    end
    return nameLine
end


-- 이름 라인에서 색상을 훔쳐오는 함수 (Foolproof)
local function MatchBorderToNameColor(self, r, g, b)
    if dodoDB.useTooltipColor == false then return end
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
        ApplyBorderColor(self, r, g, b)
    end
end

local function GetMountInfo(unit)
    if not unit or not UnitIsPlayer(unit) then return end
    if unit == "player" and not IsMounted() then return end
    
    local foundName, foundIcon
    AuraUtil.ForEachAura(unit, "HELPFUL", nil, function(aura)
        local spellID = aura and aura.spellId
        if spellID and not isSecret(spellID) then
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
-- 메인 처리 (PostCalls)
-- ==============================
local function OnUnitTooltip(self, data)
    if dodoDB.useTooltip == false then return end
    if not data or isSecret(data) then return end
    
    local guid = data.guid
    if not guid or isSecret(guid) then return end
    
    local unit = UnitTokenFromGUID(guid)
    -- GUID로 유닛을 찾지 못한 경우 mouseover를 fallback으로 사용
    if not unit and UnitGUID("mouseover") == guid then
        unit = "mouseover"
    end
    
    if not unit or not UnitExists(unit) or isSecret(unit) then return end

    needSpacer = true
    local nameLine = GetNameLine(self)
    if not nameLine then return end


    local r, g, b
    if UnitIsPlayer(unit) then
        local _, class = UnitClass(unit)
        if class and dodoDB.useTooltipColor ~= false then
            local color = RAID_CLASS_COLORS[class]
            if color then
                r, g, b = color.r, color.g, color.b
                nameLine:SetTextColor(r, g, b)
            end
        end
        if dodoDB.useTooltipMount ~= false then
            local mountName, mountIcon = GetMountInfo(unit)
            if mountName then
                local iconText = mountIcon and format("|T%d:14:14:0:0|t ", mountIcon) or ""
                self:AddDoubleLine("|cffffd200탈것|r", iconText .. mountName)
            end
        end
    else
        local reaction = UnitReaction(unit, "player")
        if reaction and dodoDB.useTooltipColor ~= false then
            local color = FACTION_BAR_COLORS[reaction]
            if color then
                r, g, b = color.r, color.g, color.b
                nameLine:SetTextColor(r, g, b)
            end
        end
        local npcID = tonumber(guid:match("-(%d+)-%x+$"))
        if npcID then AddIDLine(self, "NPC ID", npcID) end
    end
    
    -- 이미 결정된 색상이 있으면 직접 전달하여 중복 조회를 방지
    MatchBorderToNameColor(self, r, g, b)
end

local function OnItemTooltip(self, data)
    if dodoDB.useTooltip == false then return end
    needSpacer = true
    
    local itemID = data.id 
    if not itemID then return end

    -- 아이템 등급에 따른 테두리 색상: 
    -- 복잡한 등급 계산 대신 이름 라인의 색상을 실시간으로 훔쳐옵니다.
    MatchBorderToNameColor(self)

    local _, _, _, _, _, _, _, _, _, icon, _, _, _, _, expacID = GetItemInfo(itemID)
    if icon then
        local nameLine = GetNameLine(self)
        local text = nameLine and nameLine:GetText()
        if text and not isSecret(text) and not text:find("|T") then
            nameLine:SetText(format("|T%d:18:18:0:0|t %s", icon, text))
        end
    end

    AddIDLine(self, "ItemID", itemID)
    AddIDLine(self, "IconID", icon)
    AddExpansionLine(self, expacID)
end

local function OnSpellTooltip(self, data)
    if dodoDB.useTooltip == false then return end
    needSpacer = true
    
    local spellID = data.id 
    if not spellID then return end

    local spellInfo = GetSpellInfo(spellID)
    if spellInfo and spellInfo.iconID then
        local nameLine = GetNameLine(self)
        local text = nameLine and nameLine:GetText()
        if text and not isSecret(text) and not text:find("|T") then
            nameLine:SetText(format("|T%d:18:18:0:0|t %s", spellInfo.iconID, text))
        end
        AddIDLine(self, "SpellID", spellID)
        AddIDLine(self, "IconID", spellInfo.iconID)
    end
    if dodoDB.useTooltipColor ~= false then
        ApplyBorderColor(self, 1, 0.82, 0)
    end
end

local function OnGenericTooltip(self, data)
    if dodoDB.useTooltip == false then return end
    needSpacer = true
    local label = typeMapping[data.type] or "ObjectID"
    AddIDLine(self, label, data.id)
end

-- ==============================
-- 초기화 및 콜백
-- ==============================
function dodo.UpdateTooltip()
    if dodoDB.useTooltipHealthHide then
        GameTooltipStatusBar:Hide()
    else
        -- 기본 상태바를 다시 보여주고 싶을 경우의 처리 (Blizzard 기본값은 항상 보임)
        if not GameTooltipStatusBar:IsShown() and UnitExists("mouseover") then
            GameTooltipStatusBar:Show()
        end
    end
end

local function Initialize()
    if dodoDB.useTooltipHealthHide ~= false then
        GameTooltipStatusBar:Hide()
    end
    hooksecurefunc(GameTooltipStatusBar, "Show", function(self) 
        if dodoDB.useTooltipHealthHide ~= false then 
            self:Hide() 
        end 
    end)

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

    local tooltips = { GameTooltip, ShoppingTooltip1, ShoppingTooltip2, ItemRefTooltip }
    for _, tt in ipairs(tooltips) do
        if tt then
            tt:HookScript("OnHide", ResetBorderColor)
        end
    end
end

local group = CreateFrame("Frame")
group:RegisterEvent("PLAYER_LOGIN")
group:SetScript("OnEvent", function(self)
    Initialize()
    self:UnregisterEvent("PLAYER_LOGIN")
end)