-- ==============================
-- Inspired
-- ==============================
-- Chonky Character Sheet (https://www.curseforge.com/wow/addons/chonky-character-sheet)
-- Enhanced QOL (ahttps://www.curseforge.com/wow/addons/fex)
-- Fex (https://www.curseforge.com/wow/addons/fex)

-- ==============================
-- 설정 및 테이블
-- ==============================
---@diagnostic disable: lowercase-global, param-type-mismatch, redundant-parameter, undefined-field, undefined-global
local addonName, dodo = ...
local module = {}
dodo:RegisterModule("Item", module)

local Colors = dodo.Colors -- 엔진

-- API 로컬 캐싱
local _G = _G
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
local PaperDollFrame = PaperDollFrame
local ipairs = ipairs
local match = string.match
local pairs = pairs
local select = select
local table_insert = table.insert
local tonumber = tonumber
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

-- ============================================================
-- 캐싱
-- ============================================================
local fexSlotData = {}
local fexInspectSlotData = {}
local fexSlotBuilt = false
local fexInspectBuilt = false
local fexOriginalHeight = nil
local inspectUnit = nil

local MAX_GEMS = 4
local OUTLINE_FONT = "Fonts\\2002.TTF"

-- ============================================================
-- 함수
-- ============================================================
local function get_enchant_name(unit, slotID)
    local data = C_TooltipInfo.GetInventoryItem(unit, slotID)
    if not data or not data.lines then return nil end
    
    local enchantPattern = ENCHANTED_TOOLTIP_LINE:gsub("%%s", "(.*)")
    for _, line in ipairs(data.lines) do
        local text = line.leftText
        if text then
            local name = match(text, enchantPattern)
            if name then
                local suffix = match(name, " %- (.+)$")
                return suffix or name
            end
        end
    end
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

-- get_gems_string removed

local function update_slots(unit, slotData)
    if not unit then return end
    if not (dodo.DB and dodo.DB.useItemLevel) then return end
    if unit == "player" and not PaperDollFrame:IsShown() then return end
    if unit ~= "player" and (not InspectFrame or not InspectFrame:IsShown()) then return end

    for _, data in ipairs(slotData) do
        local hasItem = GetInventoryItemID(unit, data.slotID) ~= nil
        if not hasItem then
            if data.tex then data.tex:Hide() end
            if data.enchantText then data.enchantText:Hide() end
            data.ilvlText:Hide()
            if data.gemText then data.gemText:Hide() end
        else
            local gemString = get_gems_string_optimized(unit, data.slotID)
            local hasGems = (gemString and gemString ~= "")

            -- 배경 그라데이션 및 마법부여
            if dodo.DB and dodo.DB.useItemLevel and data.tex then
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
            if dodo.DB and dodo.DB.useItemLevel then
                local itemLoc = ItemLocation:CreateFromEquipmentSlot(data.slotID)
                if unit == "player" and itemLoc and C_Item.DoesItemExist(itemLoc) then
                    local ilvl = C_Item.GetCurrentItemLevel(itemLoc)
                    local quality = C_Item.GetItemQuality(itemLoc)
                    local qColor = (Colors and Colors.Quality[quality or 1]) or { r = 1, g = 1, b = 1 }
                    local r, g, b = qColor.r, qColor.g, qColor.b
                    data.ilvlText:SetTextColor(r, g, b)
                    data.ilvlText:SetText(ilvl)
                    data.ilvlText:Show()
                else
                    local link = GetInventoryItemLink(unit, data.slotID)
                    if link then
                        local ilvl = C_Item.GetDetailedItemLevelInfo(link)
                        local quality = C_Item.GetItemQualityByID(link)
                        local qColor = (Colors and Colors.Quality[quality or 1]) or { r = 1, g = 1, b = 1 }
                        local r, g, b = qColor.r, qColor.g, qColor.b
                        data.ilvlText:SetTextColor(r, g, b)
                        data.ilvlText:SetText(ilvl)
                        data.ilvlText:Show()
                    else
                        data.ilvlText:Hide()
                    end
                end
            else
                data.ilvlText:Hide()
            end

            -- 보석 아이콘 표시
            if dodo.DB and dodo.DB.useItemLevel and data.gemText then
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
    
    if prefix == "Character" then fexSlotBuilt = true 
    elseif prefix == "Inspect" then fexInspectBuilt = true end

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
    if CharacterFrame and CharacterFrame.Collapse then
        CharacterFrame:Collapse()
    else
        if CharacterFrame then
            CharacterFrame:SetWidth(configs.normal_width)
            if fexOriginalHeight then
                CharacterFrame:SetHeight(fexOriginalHeight)
            end
        end
    end
end

local function apply_wide_layout()
    if not PaperDollFrame or not PaperDollFrame:IsShown() then return end
    if not (dodo.DB and dodo.DB.useItemLevel) then return end

    if CharacterFrame then
        if not fexOriginalHeight then
            fexOriginalHeight = CharacterFrame:GetHeight()
        end
        CharacterFrame:SetWidth(configs.wide_width)
    end
    
    if CharacterFrameInset then
        CharacterFrameInset:ClearAllPoints()
        CharacterFrameInset:SetPoint("TOPLEFT", CharacterFrame, "TOPLEFT", 4, -60)
        CharacterFrameInset:SetPoint("BOTTOMRIGHT", CharacterFrame, "BOTTOMLEFT", configs.wide_width - 206, 4)
    end

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
    if not (dodo.DB and dodo.DB.useItemLevel) then
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
                local qColor = (Colors and Colors.Quality[quality or 1]) or { r = 1, g = 1, b = 1 }
                local r, g, b = qColor.r, qColor.g, qColor.b
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
local updateSlotsTimer = nil

local function request_update_slots()
    if not (dodo.DB and dodo.DB.useItemLevel) then return end
    if updateSlotsTimer then return end
    
    updateSlotsTimer = C_Timer.NewTimer(0.2, function()
        updateSlotsTimer = nil
        if PaperDollFrame and PaperDollFrame:IsShown() then
            update_slots("player", fexSlotData)
        end
    end)
end

local function update_feature()
    if not (dodo.DB and dodo.DB.useItemLevel) then return end

    request_update_slots()
    if InspectFrame and InspectFrame:IsShown() then
        update_slots(inspectUnit or "target", fexInspectSlotData)
    end

    apply_wide_layout()

    -- 가방 업데이트
    for i = 1, NUM_CONTAINER_FRAMES do
        local cf = _G["ContainerFrame" .. i]
        update_bag_frame(cf)
    end
    if ContainerFrameCombinedBags then
        update_bag_frame(ContainerFrameCombinedBags)
    end
end

dodo.ItemLevelDisplay = function(value)
    update_feature()
end

dodo.EnhancedCharFrame = function(value)
    update_feature()
end

local function on_event(self, event, ...)
    if not (dodo.DB and dodo.DB.useItemLevel) then return end

    if not fexSlotBuilt then
        C_AddOns.LoadAddOn("Blizzard_CharacterFrame")
        hide_character_backgrounds()
        build_slots("Character", fexSlotData)
    end
    if C_AddOns.IsAddOnLoaded("Blizzard_InspectUI") and not fexInspectBuilt then
        build_slots("Inspect", fexInspectSlotData)
    end

    if event == "PLAYER_LOGIN" then
        request_update_slots()
    elseif event == "PLAYER_ENTERING_WORLD" then
        for slot = 1, 19 do
            local link = GetInventoryItemLink("player", slot)
            if link then
                local itemID = GetInventoryItemID("player", slot)
                if itemID then
                    C_Item.RequestLoadItemDataByID(itemID)
                end
            end
        end
        request_update_slots()
    elseif event == "PLAYER_EQUIPMENT_CHANGED" or event == "SOCKET_INFO_ACCEPT" then
        request_update_slots()
    elseif event == "ADDON_LOADED" then
        local addon = ...
        if addon == "Blizzard_InspectUI" then
            build_slots("Inspect", fexInspectSlotData)
        end
    elseif event == "INSPECT_READY" then
        local unit = inspectUnit or "target"
        update_slots(unit, fexInspectSlotData)
    elseif event == "BAG_UPDATE_DELAYED" then
        for i = 1, NUM_CONTAINER_FRAMES do
            local cf = _G["ContainerFrame" .. i]
            update_bag_frame(cf)
        end
        if ContainerFrameCombinedBags then
            update_bag_frame(ContainerFrameCombinedBags)
        end
    else
        request_update_slots()
    end
end

-- ==============================
-- 모듈 On/Off 활성화 상태 제어
-- ==============================
local event_frame = CreateFrame("Frame")

local function update_module_state()
    local enabled = true
    if dodo.DB and dodo.DB.useItemLevel ~= nil then
        enabled = dodo.DB.useItemLevel
    end

    if not enabled then
        event_frame:UnregisterAllEvents()
        reset_layout()
        -- 가방 UI 템렙 숨김
        for _, container in pairs(bagSlotCache) do
            if container.ilvlFS then container.ilvlFS:Hide() end
        end
        -- 캐릭터 슬롯 상태 리셋
        for _, data in ipairs(fexSlotData) do
            if data.tex then data.tex:Hide() end
            if data.enchantText then data.enchantText:Hide() end
            if data.ilvlText then data.ilvlText:Hide() end
            if data.gemText then data.gemText:Hide() end
        end
    else
        if not fexSlotBuilt then
            C_AddOns.LoadAddOn("Blizzard_CharacterFrame")
            hide_character_backgrounds()
            build_slots("Character", fexSlotData)
        end
        if C_AddOns.IsAddOnLoaded("Blizzard_InspectUI") and not fexInspectBuilt then
            build_slots("Inspect", fexInspectSlotData)
        end

        event_frame:RegisterEvent("PLAYER_LOGIN")
        event_frame:RegisterEvent("PLAYER_ENTERING_WORLD")
        event_frame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
        event_frame:RegisterEvent("SOCKET_INFO_ACCEPT")
        event_frame:RegisterEvent("UNIT_INVENTORY_CHANGED")
        event_frame:RegisterEvent("GET_ITEM_INFO_RECEIVED")
        event_frame:RegisterEvent("ENCHANT_SPELL_COMPLETED")
        event_frame:RegisterEvent("WEAPON_ENCHANT_CHANGED")
        event_frame:RegisterEvent("BAG_UPDATE_DELAYED")
        event_frame:RegisterEvent("INSPECT_READY")
        event_frame:RegisterEvent("ADDON_LOADED")
        
        if PaperDollFrame:IsShown() then
            apply_wide_layout()
        end
        update_feature()
    end
end

dodo.UpdateItemModuleState = update_module_state
dodo.ItemApplyFeature = update_feature

-- ==============================
-- 초기화
-- ==============================
local function initialize()
    if dodo.DB then
        if dodo.DB.useItemLevel == nil then
            dodo.DB.useItemLevel = true
        end
    end

    -- Hook 설정 (중복 훅 방지 적용)
    dodo.HookOnce("NotifyInspect", function(unit)
        inspectUnit = unit
    end)

    if CharacterFrame then
        if not CharacterFrame.dodoHookedOnShow then
            CharacterFrame.dodoHookedOnShow = true
            CharacterFrame:HookScript("OnShow", function()
                if not (dodo.DB and dodo.DB.useItemLevel) then return end
                if not fexSlotBuilt then
                    C_AddOns.LoadAddOn("Blizzard_CharacterFrame")
                    hide_character_backgrounds()
                    build_slots("Character", fexSlotData)
                end
                hide_character_backgrounds()
                apply_wide_layout()

                for slot = 1, 19 do
                    local link = GetInventoryItemLink("player", slot)
                    if link then
                        local itemID = GetInventoryItemID("player", slot)
                        if itemID then
                            C_Item.RequestLoadItemDataByID(itemID)
                        end
                    end
                end
                request_update_slots()
            end)
        end

        dodo.HookOnce(CharacterFrame, "Expand", apply_wide_layout)
        dodo.HookOnce(CharacterFrame, "UpdateSize", apply_wide_layout)
        dodo.HookOnce(CharacterFrame, "Collapse", function()
            if not (dodo.DB and dodo.DB.useItemLevel) then return end
            CharacterFrame:SetWidth(configs.normal_width)
            if fexOriginalHeight then
                CharacterFrame:SetHeight(fexOriginalHeight)
            end
        end)
    end

    for i = 1, NUM_CONTAINER_FRAMES do
        local cf = _G["ContainerFrame" .. i]
        if cf then
            dodo.HookOnce(cf, "UpdateItems", function(self) update_bag_frame(self) end)
        end
    end
    if ContainerFrameCombinedBags then
        dodo.HookOnce(ContainerFrameCombinedBags, "UpdateItems", function(self) update_bag_frame(self) end)
    end
end

-- ==============================
-- 모듈 생명주기
-- ==============================
local isInitialized = false
function module:OnEnable()
    initialize()
    update_module_state()

    if isInitialized then return end
    isInitialized = true

    event_frame:SetScript("OnEvent", on_event)

    -- dodoEditModePanel 내부에 세부 설정 동적 주입 등록
    if dodo.RegisterEditModeSetting then
        dodo.RegisterEditModeSetting("인터페이스", {
            {
                name = "아이템 레벨 표시",
                get = function() return dodo.DB and dodo.DB.useItemLevel or false end,
                set = function(checked)
                    if dodo.DB then dodo.DB.useItemLevel = checked end
                    update_module_state()
                end
            }
        })
    end
end