-- ==============================
-- 설정 및 테이블
-- ==============================
---@diagnostic disable: lowercase-global, param-type-mismatch, redundant-parameter, undefined-field, undefined-global
local addonName, dodo = ...
dodoDB = dodoDB or {}

dodo.CharacterFrameSLOT_LIST = {
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

dodo.CharacterFrameSlotData = {}
dodo.CharacterFrameInspectSlotData = {}
dodo.CharacterFrameCompCharacterData = {}
dodo.CharacterFrameCompInspectData = {}
dodo.CharacterFrameBuildSlotsCallbacks = {}

-- ==============================
-- 캐싱
-- ==============================
local C_AddOns = C_AddOns
local C_Item = C_Item
local C_Timer = C_Timer
local CreateFrame = CreateFrame
local GetInventoryItemID = GetInventoryItemID
local GetInventoryItemLink = GetInventoryItemLink
local GetItemInfo = GetItemInfo
local hooksecurefunc = hooksecurefunc
local ipairs = ipairs
local match = string.match
local pairs = pairs
local PaperDollFrame = PaperDollFrame
local table_insert = table.insert
local tonumber = tonumber
local _G = _G

local NUM_CONTAINER_FRAMES = NUM_CONTAINER_FRAMES or 13

-- ==============================
-- 슬롯 빌드 컨트롤러
-- ==============================
local slot_built = { Character = false, Inspect = false, CompCharacter = false, CompInspect = false }

local function build_slots(prefix, slot_data)
    if slot_built[prefix] then return end
    slot_built[prefix] = true

    for _, info in ipairs(dodo.CharacterFrameSLOT_LIST) do
        local slot_name = info.frame:gsub("Character", prefix)
        local slot_frame = _G[slot_name]
        if slot_frame then
            local entry = { slotID = info.slotID, dir = info.dir, isEnchantSlot = info.enchant, slotFrame = slot_frame }

            for _, callback in ipairs(dodo.CharacterFrameBuildSlotsCallbacks) do
                callback(slot_frame, entry, info)
            end

            table_insert(slot_data, entry)
        end
    end
end

-- ==============================
-- 업데이트 제어
-- ==============================
local is_pending_update = false

local function try_update_slots()
    local all_ready = true
    for slot = 1, 19 do
        local link = GetInventoryItemLink("player", slot)
        if link then
            local item_id = tonumber(match(link, "item:(%d+)"))
            if item_id and not C_Item.IsItemDataCachedByID(item_id) then
                all_ready = false
                break
            end
        end
    end

    if all_ready then
        is_pending_update = false
        if dodo.UpdateCharacterFrameIlvl then dodo.UpdateCharacterFrameIlvl("player", dodo.CharacterFrameSlotData) end
        if dodo.UpdateCharacterFrameEnchant then dodo.UpdateCharacterFrameEnchant("player", dodo.CharacterFrameSlotData) end
        if dodo.UpdateCharacterFrameGem then dodo.UpdateCharacterFrameGem("player", dodo.CharacterFrameSlotData) end
    else
        C_Timer.After(0.05, try_update_slots)
    end
end

function dodo.RequestUpdateCharacterSlots()
    if is_pending_update then return end
    is_pending_update = true
    try_update_slots()
end

function dodo.UpdateCharacterFrameAll()
    if dodoDB.enableCharacterFrame == false then
        if dodo.ResetCharacterFrameLayout then dodo.ResetCharacterFrameLayout() end
        if dodo.UpdateCharacterFrameIlvl then dodo.UpdateCharacterFrameIlvl("player", dodo.CharacterFrameSlotData) end
        if dodo.UpdateCharacterFrameIlvlBag then dodo.UpdateCharacterFrameIlvlBag() end
        if dodo.UpdateCharacterFrameEnchant then dodo.UpdateCharacterFrameEnchant("player", dodo.CharacterFrameSlotData) end
        if dodo.UpdateCharacterFrameGem then dodo.UpdateCharacterFrameGem("player", dodo.CharacterFrameSlotData) end
        return
    end

    if dodo.UpdateCharacterFrameLayout then dodo.UpdateCharacterFrameLayout() end
    dodo.RequestUpdateCharacterSlots()

    if InspectFrame and InspectFrame:IsShown() then
        local unit = dodo.CharacterFrameInspectUnit or "target"
        if dodo.UpdateCharacterFrameIlvl then dodo.UpdateCharacterFrameIlvl(unit, dodo.CharacterFrameInspectSlotData) end
        if dodo.UpdateCharacterFrameEnchant then dodo.UpdateCharacterFrameEnchant(unit, dodo.CharacterFrameInspectSlotData) end
        if dodo.UpdateCharacterFrameGem then dodo.UpdateCharacterFrameGem(unit, dodo.CharacterFrameInspectSlotData) end
    end

    if _G["CompInspectHeadSlot"] and dodo.UpdateCharacterFrameIlvl then
        local unit = dodo.CharacterFrameInspectUnit or "target"
        dodo.UpdateCharacterFrameIlvl(unit, dodo.CharacterFrameCompInspectData)
        dodo.UpdateCharacterFrameEnchant(unit, dodo.CharacterFrameCompInspectData)
        dodo.UpdateCharacterFrameGem(unit, dodo.CharacterFrameCompInspectData)
    end
    if _G["CompCharacterHeadSlot"] and dodo.UpdateCharacterFrameIlvl then
        dodo.UpdateCharacterFrameIlvl("player", dodo.CharacterFrameCompCharacterData)
        dodo.UpdateCharacterFrameEnchant("player", dodo.CharacterFrameCompCharacterData)
        dodo.UpdateCharacterFrameGem("player", dodo.CharacterFrameCompCharacterData)
    end

    if dodo.UpdateCharacterFrameIlvlBag then dodo.UpdateCharacterFrameIlvlBag() end
end

-- ==============================
-- 초기화 및 이벤트 라우팅
-- ==============================
local function on_event(self, event, ...)
    if event == "PLAYER_LOGIN" then
        C_AddOns.LoadAddOn("Blizzard_CharacterFrame")
        C_Timer.After(0.5, function()
            if dodo.HideCharacterFrameBackgrounds then dodo.HideCharacterFrameBackgrounds() end
            build_slots("Character", dodo.CharacterFrameSlotData)
            dodo.UpdateCharacterFrameAll()
        end)
        
        if C_AddOns.IsAddOnLoaded("Blizzard_InspectUI") then
            build_slots("Inspect", dodo.CharacterFrameInspectSlotData)
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
        dodo.RequestUpdateCharacterSlots()
    elseif event == "ADDON_LOADED" then
        local addon = ...
        if addon == "Blizzard_InspectUI" then
            build_slots("Inspect", dodo.CharacterFrameInspectSlotData)
        end
    elseif event == "INSPECT_READY" then
        local unit = dodo.CharacterFrameInspectUnit or "target"
        build_slots("Inspect", dodo.CharacterFrameInspectSlotData)
        
        if dodo.UpdateCharacterFrameIlvl then dodo.UpdateCharacterFrameIlvl(unit, dodo.CharacterFrameInspectSlotData) end
        if dodo.UpdateCharacterFrameEnchant then dodo.UpdateCharacterFrameEnchant(unit, dodo.CharacterFrameInspectSlotData) end
        if dodo.UpdateCharacterFrameGem then dodo.UpdateCharacterFrameGem(unit, dodo.CharacterFrameInspectSlotData) end
        
        if _G["CompInspectHeadSlot"] then
            build_slots("CompInspect", dodo.CharacterFrameCompInspectData)
            if dodo.UpdateCharacterFrameIlvl then dodo.UpdateCharacterFrameIlvl(unit, dodo.CharacterFrameCompInspectData) end
            if dodo.UpdateCharacterFrameEnchant then dodo.UpdateCharacterFrameEnchant(unit, dodo.CharacterFrameCompInspectData) end
            if dodo.UpdateCharacterFrameGem then dodo.UpdateCharacterFrameGem(unit, dodo.CharacterFrameCompInspectData) end
        end
        if _G["CompCharacterHeadSlot"] then
            build_slots("CompCharacter", dodo.CharacterFrameCompCharacterData)
            if dodo.UpdateCharacterFrameIlvl then dodo.UpdateCharacterFrameIlvl("player", dodo.CharacterFrameCompCharacterData) end
            if dodo.UpdateCharacterFrameEnchant then dodo.UpdateCharacterFrameEnchant("player", dodo.CharacterFrameCompCharacterData) end
            if dodo.UpdateCharacterFrameGem then dodo.UpdateCharacterFrameGem("player", dodo.CharacterFrameCompCharacterData) end
        end
    elseif event == "BAG_UPDATE_DELAYED" then
        if dodo.UpdateCharacterFrameIlvlBag then dodo.UpdateCharacterFrameIlvlBag() end
    else
        dodo.RequestUpdateCharacterSlots()
    end
end

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
    dodo.CharacterFrameInspectUnit = unit
end)

-- 외부 공개 API 매핑
dodo.ItemLevelDisplay = function() dodo.UpdateCharacterFrameAll() end
dodo.EnhancedCharFrame = function() dodo.UpdateCharacterFrameAll() end

-- ==============================
-- 초기화
-- ==============================
local function initialize()
    if dodoDB.enableCharacterFrame == nil then dodoDB.enableCharacterFrame = true end
    if dodoDB.useItemLevel == nil then dodoDB.useItemLevel = true end
    if dodoDB.useEnhancedCharFrame == nil then dodoDB.useEnhancedCharFrame = true end

    dodo.UpdateCharacterFrameAll()
end

local init_frame = CreateFrame("Frame")
init_frame:RegisterEvent("PLAYER_LOGIN")
init_frame:SetScript("OnEvent", function(self)
    initialize()
    self:UnregisterAllEvents()
end)

-- ==============================
-- 설정 등록 (마스터토글)
-- ==============================
if dodo.RegisterEditModeModuleSetting then
    dodo.RegisterEditModeModuleSetting("인터페이스", {
        {
            name = "장비창",
            get = function() return dodoDB and dodoDB.enableCharacterFrame ~= false end,
            set = function(checked)
                if dodoDB then dodoDB.enableCharacterFrame = checked end
                dodo.UpdateCharacterFrameAll()
            end
        }
    })
end
