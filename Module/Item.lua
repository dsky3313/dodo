-- ==============================
-- Inspired
-- ==============================
-- Chonky Character Sheet (https://www.curseforge.com/wow/addons/chonky-character-sheet)
-- Fex (https://www.curseforge.com/wow/addons/fex)

-- ==============================
-- 설정 및 테이블
-- ==============================
---@diagnostic disable: lowercase-global, param-type-mismatch, redundant-parameter, undefined-field, undefined-global
local addonName, dodo = ...
dodoDB = dodoDB or {}

-- ============================================================
-- 캐싱 (가나다 순)
-- ============================================================
local _G = _G
local C_AddOns = C_AddOns
local C_Container = C_Container
local C_Item = C_Item
local C_Timer = C_Timer
local C_TooltipInfo = C_TooltipInfo
local CreateColor = CreateColor
local CreateFrame = CreateFrame
local GetInventoryItemID = GetInventoryItemID
local GetInventoryItemLink = GetInventoryItemLink
local GetItemInfo = GetItemInfo
local GetItemInfoInstant = GetItemInfoInstant
local hooksecurefunc = hooksecurefunc
local ipairs = ipairs
local match = string.match
local pairs = pairs
local PaperDollFrame = PaperDollFrame
local select = select
local table_insert = table.insert
local tonumber = tonumber
local wipe = wipe

local NUM_CONTAINER_FRAMES = NUM_CONTAINER_FRAMES or 13

local configs = {
    ilvl_font_size       = 12,
    enchant_font_size    = 12,
    ilvl_space          = 10, -- 아이콘과 텍스트 사이 간격
    wide_width          = 650,
    normal_width        = 448,
    gem_size            = 12, -- 보석 마크업 폰트 사이즈
}

local SLOT_LIST = {
    { frame = "CharacterHeadSlot",          slotID = 1,  dir = "RIGHT", enchant = true },
    { frame = "CharacterNeckSlot",          slotID = 2,  dir = "RIGHT", enchant = false },
    { frame = "CharacterShoulderSlot",      slotID = 3,  dir = "RIGHT", enchant = true },
    { frame = "CharacterBackSlot",          slotID = 15, dir = "RIGHT", enchant = false },
    { frame = "CharacterChestSlot",         slotID = 5,  dir = "RIGHT", enchant = true },
    { frame = "CharacterWristSlot",         slotID = 9,  dir = "RIGHT", enchant = false },
    { frame = "CharacterHandsSlot",         slotID = 10, dir = "LEFT",  enchant = false },
    { frame = "CharacterWaistSlot",         slotID = 6,  dir = "LEFT",  enchant = false },
    { frame = "CharacterLegsSlot",          slotID = 7,  dir = "LEFT",  enchant = true },
    { frame = "CharacterFeetSlot",          slotID = 8,  dir = "LEFT",  enchant = true },
    { frame = "CharacterFinger0Slot",       slotID = 11, dir = "LEFT",  enchant = true },
    { frame = "CharacterFinger1Slot",       slotID = 12, dir = "LEFT",  enchant = true },
    { frame = "CharacterTrinket0Slot",      slotID = 13, dir = "LEFT",  enchant = false },
    { frame = "CharacterTrinket1Slot",      slotID = 14, dir = "LEFT",  enchant = false },
    { frame = "CharacterMainHandSlot",      slotID = 16, dir = "LEFT",  enchant = true },
    { frame = "CharacterSecondaryHandSlot", slotID = 17, dir = "RIGHT", enchant = false },
}

local fexSlotData = {}
local fexInspectSlotData = {}
local fexCompCharacterData = {}
local fexCompInspectData = {}
local fexSlotBuilt = false
local fexInspectBuilt = false
local fexCompCharacterBuilt = false
local fexCompInspectBuilt = false
local fexOriginalHeight = nil
local inspectUnit = nil

local OUTLINE_FONT = "Fonts\\2002.TTF"

-- ============================================================
-- 함수
-- ============================================================
local enchantCache = {}
local function get_enchant_name(unit, slotID)
    local link = GetInventoryItemLink(unit, slotID)
    if not link then return nil end

    if enchantCache[link] ~= nil then
        return enchantCache[link] or nil
    end

    local data = C_TooltipInfo.GetInventoryItem(unit, slotID)
    if not data or not data.lines then 
        enchantCache[link] = false
        return nil 
    end
    
    local enchantPattern = ENCHANTED_TOOLTIP_LINE:gsub("%%s", "(.*)")
    for _, line in ipairs(data.lines) do
        local text = line.leftText
        if text then
            local name = match(text, enchantPattern)
            if name then
                local suffix = match(name, " %- (.+)$")
                local result = suffix or name
                enchantCache[link] = result
                return result
            end
        end
    end
    enchantCache[link] = false
    return nil
end

local gemCache = {}
local function get_gems_string_optimized(unit, slotID)
    local link = GetInventoryItemLink(unit, slotID)
    if not link then return nil end

    if gemCache[link] ~= nil then
        return gemCache[link] or nil
    end

    local numSockets = C_Item.GetItemNumSockets(link) or 0
    if numSockets == 0 then
        gemCache[link] = false
        return nil
    end

    local gemStrings = {}
    for i = 1, numSockets do
        local gemID = C_Item.GetItemGemID(link, i)
        local icon
        if gemID then
            icon = C_Item.GetItemIconByID(gemID)
        end

        if not icon then
            icon = "Interface\\ItemSocketingFrame\\UI-EmptySocket-Prismatic"
        end

        table_insert(gemStrings, "\124T" .. icon .. ":11:11:0:0:64:64:4:60:4:60\124t")
    end

    if #gemStrings > 0 then
        local gemString = table.concat(gemStrings, " ")
        gemCache[link] = gemString
        return gemString
    end
    
    gemCache[link] = false
    return nil
end

local function hide_character_backgrounds()
    local bgs = {
        "CharacterModelFrameBackgroundOverlay",
        "CharacterModelFrameBackgroundTopLeft",
        "CharacterModelFrameBackgroundTopRight",
        "CharacterModelFrameBackgroundBotLeft",
        "CharacterModelFrameBackgroundBotRight",
    }
    for _, name in ipairs(bgs) do
        local f = _G[name]
        if f then 
            f:SetAlpha(0)
            if f.Hide then f:Hide() end
        end
    end
end

local ilvlCache = {}
local ilvlColorCache = {}

local function update_slots(unit, slotData)
    if not unit then return end
    if unit == "player" and not (PaperDollFrame:IsShown() or (CCS_InspectCompare and CCS_InspectCompare:IsShown())) then return end
    if unit ~= "player" and (not InspectFrame or not InspectFrame:IsShown()) and not (CCS_InspectCompare and CCS_InspectCompare:IsShown()) then return end

    for _, data in ipairs(slotData) do
        local link = GetInventoryItemLink(unit, data.slotID)
        if not link then
            if data.tex then data.tex:Hide() end
            if data.enchantText then data.enchantText:Hide() end
            data.ilvlText:Hide()
            if data.gemText then data.gemText:Hide() end
        else
            local gemString = get_gems_string_optimized(unit, data.slotID)
            local hasGems = (gemString and gemString ~= "")

            -- 배경 그라데이션 및 마법부여
            if dodoDB.useEnhancedCharFrame and data.tex then
                local r, g, b = 1, 1, 1

                if data.isEnchantSlot then
                    local name = get_enchant_name(unit, data.slotID)
                    if name then
                        data.enchantText:SetText(name)
                        data.enchantText:SetTextColor(0, 1, 0.6, 1)
                        data.enchantText:Show()
                    else
                        r, g, b = 1, 0, 0
                        data.enchantText:SetText("마부없음!")
                        data.enchantText:SetTextColor(1, 0, 0, 1)
                        data.enchantText:Show()
                    end
                else
                    if data.enchantText then data.enchantText:Hide() end
                end

                if data.isEnchantSlot or hasGems then
                    if data.dir == "RIGHT" then
                        data.tex:SetGradient("HORIZONTAL", CreateColor(r, g, b, 0.4), CreateColor(r, g, b, 0))
                    else
                        data.tex:SetGradient("HORIZONTAL", CreateColor(r, g, b, 0), CreateColor(r, g, b, 0.4))
                    end
                    data.tex:Show()
                else
                    data.tex:Hide()
                end
            else
                if data.tex then data.tex:Hide() end
                if data.enchantText then data.enchantText:Hide() end
            end

            -- 아이템 레벨
            if dodoDB.useItemLevel then
                local ilvl = ilvlCache[link]
                local color = ilvlColorCache[link]

                if not ilvl then
                    ilvl = C_Item.GetDetailedItemLevelInfo(link)
                    if ilvl and ilvl > 0 then
                        ilvlCache[link] = ilvl
                        local quality = C_Item.GetItemQualityByID(link)
                        local r, g, b = C_Item.GetItemQualityColor(quality or 1)
                        color = { r = r, g = g, b = b }
                        ilvlColorCache[link] = color
                    end
                end

                if ilvl then
                    data.ilvlText:SetTextColor(color.r, color.g, color.b)
                    data.ilvlText:SetText(ilvl)
                    data.ilvlText:Show()
                else
                    data.ilvlText:Hide()
                end
            else
                data.ilvlText:Hide()
            end

            -- 보석 아이콘 표시
            if dodoDB.useEnhancedCharFrame and data.gemText then
                if hasGems then
                    data.gemText:SetText(gemString)
                    data.gemText:Show()
                else
                    data.gemText:Hide()
                end
            else
                if data.gemText then data.gemText:Hide() end
            end
        end
    end
end

local function build_slots(prefix, slotData)
    if prefix == "Character" and fexSlotBuilt then return end
    if prefix == "Inspect" and fexInspectBuilt then return end
    if prefix == "CompCharacter" and fexCompCharacterBuilt then return end
    if prefix == "CompInspect" and fexCompInspectBuilt then return end
    
    if prefix == "Character" then fexSlotBuilt = true 
    elseif prefix == "Inspect" then fexInspectBuilt = true 
    elseif prefix == "CompCharacter" then fexCompCharacterBuilt = true
    elseif prefix == "CompInspect" then fexCompInspectBuilt = true end

    for _, info in ipairs(SLOT_LIST) do
        local slotName = info.frame:gsub("Character", prefix)
        local slotFrame = _G[slotName]
        if slotFrame then
            local entry = { slotID = info.slotID, dir = info.dir, isEnchantSlot = info.enchant, slotFrame = slotFrame }

            -- 아이템 레벨 텍스트
            local ilvlText = slotFrame:CreateFontString(nil, "OVERLAY")
            ilvlText:SetFont(OUTLINE_FONT, configs.ilvl_font_size, "OUTLINE")
            ilvlText:SetPoint("TOPLEFT", slotFrame, "TOPLEFT", 2, -2)
            ilvlText:Hide()
            entry.ilvlText = ilvlText

            -- 배경 그라데이션 텍스처
            local tex = slotFrame:CreateTexture(nil, "BORDER")
            tex:SetTexture("Interface\\BUTTONS\\WHITE8X8")
            tex:Hide()
            entry.tex = tex

            -- 마법부여 텍스트
            if info.enchant then
                local enchantText = slotFrame:CreateFontString(nil, "OVERLAY")
                enchantText:SetFont(OUTLINE_FONT, configs.enchant_font_size, "OUTLINE")
                enchantText:Hide()
                entry.enchantText = enchantText
            end

            -- 보석 텍스트 (단일 FontString 방식)
            local gemText = slotFrame:CreateFontString(nil, "OVERLAY")
            gemText:SetFont(OUTLINE_FONT, configs.gem_size or 11, "OUTLINE")
            gemText:Hide()
            entry.gemText = gemText

            -- 위치 설정
            if info.dir == "RIGHT" then
                entry.tex:SetPoint("TOPLEFT", slotFrame, "TOPRIGHT")
                entry.tex:SetPoint("BOTTOMLEFT", slotFrame, "BOTTOMRIGHT")
                entry.tex:SetWidth(115)
                if info.enchant then
                    entry.enchantText:SetPoint("TOPLEFT", slotFrame, "TOPRIGHT", 4, -2)
                    entry.enchantText:SetJustifyH("LEFT")
                end
                entry.ilvlText:SetJustifyH("LEFT")
                gemText:SetPoint("BOTTOMLEFT", slotFrame, "BOTTOMRIGHT", configs.ilvl_space, 2)
                gemText:SetJustifyH("LEFT")
            else
                entry.tex:SetPoint("TOPRIGHT", slotFrame, "TOPLEFT")
                entry.tex:SetPoint("BOTTOMRIGHT", slotFrame, "BOTTOMLEFT")
                entry.tex:SetWidth(115)
                if info.enchant then
                    entry.enchantText:SetPoint("TOPRIGHT", slotFrame, "TOPLEFT", -4, -2)
                    entry.enchantText:SetJustifyH("RIGHT")
                end
                entry.ilvlText:SetJustifyH("LEFT")
                gemText:SetPoint("BOTTOMRIGHT", slotFrame, "BOTTOMLEFT", -configs.ilvl_space, 2)
                gemText:SetJustifyH("RIGHT")
            end

            table_insert(slotData, entry)
        end
    end
end

local function reset_layout()
    CharacterFrame:SetWidth(configs.normal_width)
    if fexOriginalHeight then
        CharacterFrame:SetHeight(fexOriginalHeight)
    end
end

local function apply_wide_layout()
    if not PaperDollFrame or not PaperDollFrame:IsShown() then return end
    if not dodoDB.useEnhancedCharFrame then return end

    if not fexOriginalHeight then
        fexOriginalHeight = CharacterFrame:GetHeight()
    end
    CharacterFrame:SetWidth(configs.wide_width)
    
    CharacterFrameInset:ClearAllPoints()
    CharacterFrameInset:SetPoint("TOPLEFT", CharacterFrame, "TOPLEFT", 4, -60)
    CharacterFrameInset:SetPoint("BOTTOMRIGHT", CharacterFrame, "BOTTOMLEFT", configs.wide_width - 206, 4)

    if CharacterMainHandSlot then
        CharacterMainHandSlot:SetPoint("BOTTOMLEFT", PaperDollItemsFrame, "BOTTOMLEFT", 185, 14)
    end
    if CharacterSecondaryHandSlot then
        CharacterSecondaryHandSlot:SetPoint("BOTTOMLEFT", CharacterMainHandSlot, "BOTTOMRIGHT", 5, 0)
    end

    if CharacterModelScene then
        local LeftSlot = CharacterHeadSlot
        local RightSlot = CharacterTrinket1Slot
        if LeftSlot and RightSlot then
            CharacterModelScene:ClearAllPoints()
            CharacterModelScene:SetPoint("TOPLEFT", LeftSlot, "TOPRIGHT", 0, -4)
            CharacterModelScene:SetPoint("BOTTOMRIGHT", RightSlot, "BOTTOMLEFT", 0, 0)
        end
    end
end

-- 가방 아이템 레벨 관련
local bagSlotCache = {}
local function update_bag_slot(button)
    if not button then return end
    local bagID, slotID
    if button.GetBagID then
        bagID = button:GetBagID()
        slotID = button:GetID()
    else
        local parent = button:GetParent()
        if parent and parent.GetID then
            bagID = parent:GetID()
            slotID = button:GetID()
        end
    end
    if not bagID or not slotID then return end

    if not bagSlotCache[button] then
        local container = CreateFrame("Frame", nil, button)
        container:SetFrameLevel(button:GetFrameLevel() + 5)
        container:SetAllPoints(button)
        local ilvlFS = container:CreateFontString(nil, "OVERLAY")
        ilvlFS:SetFont(OUTLINE_FONT, configs.ilvl_font_size, "OUTLINE")
        ilvlFS:SetPoint("TOPLEFT", 2, -2)
        container.ilvlFS = ilvlFS
        bagSlotCache[button] = container
    end

    local ilvlFS = bagSlotCache[button].ilvlFS
    if not dodoDB.useItemLevel then
        ilvlFS:Hide()
        return
    end

    local info = C_Container.GetContainerItemInfo(bagID, slotID)
    if info and info.hyperlink then
        local _, _, quality, _, _, _, _, _, equipLoc, _, _, classID = C_Item.GetItemInfo(info.hyperlink)
        local isEquip = (classID == 2 or classID == 4) and equipLoc and equipLoc ~= "" and equipLoc ~= "INVTYPE_NON_EQUIP"

        if isEquip then
            local itemLevel = C_Item.GetDetailedItemLevelInfo(info.hyperlink)
            if itemLevel and itemLevel > 1 then
                local r, g, b = C_Item.GetItemQualityColor(quality or 1)
                ilvlFS:SetTextColor(r, g, b)
                ilvlFS:SetText(itemLevel)
                ilvlFS:Show()
                return
            end
        end
    end
    ilvlFS:Hide()
end

local function update_bag_frame(frame)
    if not frame or not frame:IsShown() then return end
    if frame.EnumerateValidItems then
        for _, button in frame:EnumerateValidItems() do
            update_bag_slot(button)
        end
    end
end

-- ==============================
-- 동작
-- ==============================
local isPendingUpdate = false

local function try_update_slots()
    local allReady = true
    for slot = 1, 19 do
        local link = GetInventoryItemLink("player", slot)
        if link then
            local itemID = tonumber(match(link, "item:(%d+)"))
            if itemID and not C_Item.IsItemDataCachedByID(itemID) then
                allReady = false
                break
            end
        end
    end

    if allReady then
        isPendingUpdate = false
        update_slots("player", fexSlotData)
    else
        C_Timer.After(0.05, try_update_slots)
    end
end

local function request_update_slots()
    if isPendingUpdate then return end
    isPendingUpdate = true
    try_update_slots()
end

local function update_feature()
    request_update_slots()
    if InspectFrame and InspectFrame:IsShown() then
        update_slots(inspectUnit or "target", fexInspectSlotData)
    end
    -- ChonkyCharacterSheet 지원
    if _G["CompInspectHeadSlot"] then
        update_slots(inspectUnit or "target", fexCompInspectData)
    end
    if _G["CompCharacterHeadSlot"] then
        update_slots("player", fexCompCharacterData)
    end
    -- 가방 업데이트
    for i = 1, NUM_CONTAINER_FRAMES do
        update_bag_frame(_G["ContainerFrame" .. i])
    end
    if ContainerFrameCombinedBags then update_bag_frame(ContainerFrameCombinedBags) end
end

dodo.ItemLevelDisplay = function(value)
    update_feature()
end

dodo.EnhancedCharFrame = function(value)
    if value then
        apply_wide_layout()
    else
        reset_layout()
    end
    update_feature()
end

local function on_event(self, event, ...)
    if event == "PLAYER_LOGIN" then
        C_AddOns.LoadAddOn("Blizzard_CharacterFrame")
        C_Timer.After(0.5, function()
            hide_character_backgrounds()
            build_slots("Character", fexSlotData)
            request_update_slots()
        end)
        
        if C_AddOns.IsAddOnLoaded("Blizzard_InspectUI") then
            build_slots("Inspect", fexInspectSlotData)
        end
    elseif event == "PLAYER_ENTERING_WORLD" then
        for slot = 1, 19 do
            local link = GetInventoryItemLink("player", slot)
            if link then
                GetItemInfo(link)
                local itemID = GetInventoryItemID("player", slot)
                if itemID then
                    C_Item.RequestLoadItemDataByID(itemID)
                end
            end
        end
        request_update_slots()
    elseif event == "ADDON_LOADED" then
        local addon = ...
        if addon == "Blizzard_InspectUI" then
            build_slots("Inspect", fexInspectSlotData)
        end
    elseif event == "INSPECT_READY" then
        local unit = inspectUnit or "target"
        update_slots(unit, fexInspectSlotData)
        
        -- ChonkyCharacterSheet 지원
        if _G["CompInspectHeadSlot"] then
            build_slots("CompInspect", fexCompInspectData)
            update_slots(unit, fexCompInspectData)
        end
        if _G["CompCharacterHeadSlot"] then
            build_slots("CompCharacter", fexCompCharacterData)
            update_slots("player", fexCompCharacterData)
        end
    elseif event == "BAG_UPDATE_DELAYED" then
        for i = 1, NUM_CONTAINER_FRAMES do
            update_bag_frame(_G["ContainerFrame" .. i])
        end
        if ContainerFrameCombinedBags then update_bag_frame(ContainerFrameCombinedBags) end
    else
        request_update_slots()
    end
end

-- ==============================
-- 이벤트 및 훅 설정
-- ==============================
local event_frame = CreateFrame("Frame")
event_frame:RegisterEvent("PLAYER_LOGIN")
event_frame:RegisterEvent("PLAYER_ENTERING_WORLD")
event_frame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
event_frame:RegisterEvent("UNIT_INVENTORY_CHANGED")
event_frame:RegisterEvent("GET_ITEM_INFO_RECEIVED")
event_frame:RegisterEvent("ENCHANT_SPELL_COMPLETED")
event_frame:RegisterEvent("WEAPON_ENCHANT_CHANGED")
event_frame:RegisterEvent("BAG_UPDATE_DELAYED")
event_frame:RegisterEvent("INSPECT_READY")
event_frame:RegisterEvent("ADDON_LOADED")
event_frame:SetScript("OnEvent", on_event)

hooksecurefunc("NotifyInspect", function(unit)
    inspectUnit = unit
end)

local function on_character_frame_show()
    hide_character_backgrounds()
    apply_wide_layout()
    request_update_slots()
end

CharacterFrame:HookScript("OnShow", on_character_frame_show)

hooksecurefunc(CharacterFrame, "Expand", apply_wide_layout)
hooksecurefunc(CharacterFrame, "UpdateSize", apply_wide_layout)
hooksecurefunc(CharacterFrame, "Collapse", reset_layout)

local function on_bag_update_items(self)
    update_bag_frame(self)
end

for i = 1, NUM_CONTAINER_FRAMES do
    local cf = _G["ContainerFrame" .. i]
    if cf then
        hooksecurefunc(cf, "UpdateItems", on_bag_update_items)
    end
end
if ContainerFrameCombinedBags then
    hooksecurefunc(ContainerFrameCombinedBags, "UpdateItems", on_bag_update_items)
end

-- ==============================
-- 외부 노출 및 설정 동적 등록 (Option.lua 연동)
-- ==============================
local SettingsPanel = SettingsPanel
local Checkbox = Checkbox

dodo.OptionRegistrations = dodo.OptionRegistrations or {}
dodo.OptionRegistrations["interface"] = dodo.OptionRegistrations["interface"] or {}
table.insert(dodo.OptionRegistrations["interface"], function(category)
    local layout = SettingsPanel:GetLayout(category)
    if not layout then return end

    Checkbox(category, "useItemLevel", "아이템 레벨 표시", "장비창 및 가방 아이템에 아이템 레벨을 표시합니다.", true, dodo.ItemLevelDisplay)
    Checkbox(category, "useEnhancedCharFrame", "장비창+", "장비창에 마법부여, 보석 정보를 표시하고 창 크기를 넓힙니다.", true, dodo.EnhancedCharFrame)
end)