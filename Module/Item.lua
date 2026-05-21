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
local module = {}
dodo:RegisterModule("Item", module)

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
    gem_bg_size         = 14,
    gem_size            = 10,
    gem_stride          = 16,
    ilvl_space          = 10, -- 아이콘과 텍스트 사이 간격
    wide_width          = 650,
    normal_width        = 448,
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

-- 글로벌에서 빈 소켓 문자열 동적 캐싱 (로컬라이징 대응)
local emptySockets = {}
for name, v in pairs(_G) do
    if name and type(name) == "string" and string.find(name, "EMPTY_SOCKET_", 1, true) then
        table_insert(emptySockets, v)
    end
end

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

local function get_gem_data(unit, slotID)
    local link = GetInventoryItemLink(unit, slotID)
    if not link then return nil end

    -- 1. 링크에서 박혀있는 보석 ID 직접 추출 (100% 신뢰성 보장)
    local gemLinks = {}
    local g1, g2, g3, g4 = match(link, "item:%d*:%d*:(%d*):(%d*):(%d*):(%d*)")
    for _, gStr in ipairs({g1, g2, g3, g4}) do
        local gID = tonumber(gStr)
        if gID and gID > 0 then
            table_insert(gemLinks, gID)
        end
    end

    -- 2. 툴팁에서 빈 소켓 개수 검출
    local emptyCount = 0
    local tooltipData = C_TooltipInfo.GetInventoryItem(unit, slotID)
    if tooltipData and tooltipData.lines then
        for _, line in ipairs(tooltipData.lines) do
            local text = line.leftText
            if text then
                for _, socketName in ipairs(emptySockets) do
                    if text:find(socketName, 1, true) then
                        emptyCount = emptyCount + 1
                        break
                    end
                end
            end
        end
    end

    -- 보석이 아예 없으면 nil 반환
    if #gemLinks == 0 and emptyCount == 0 then
        return nil
    end

    local gems = {}
    -- 채워진 보석 추가
    for _, gID in ipairs(gemLinks) do
        local gemIcon = select(5, GetItemInfoInstant(gID)) or 134400
        table_insert(gems, { filled = true, texture = gemIcon })
    end
    -- 빈 소켓 추가
    for _ = 1, emptyCount do
        table_insert(gems, { filled = false })
    end

    return gems
end

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
            for i = 1, MAX_GEMS do
                data.gemBgs[i]:Hide()
                data.gemTexs[i]:Hide()
            end
        else
            local gems = get_gem_data(unit, data.slotID)
            local hasGems = (gems ~= nil)

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
                    local r, g, b = C_Item.GetItemQualityColor(quality or 1)
                    data.ilvlText:SetTextColor(r, g, b)
                    data.ilvlText:SetText(ilvl)
                    data.ilvlText:Show()
                else
                    local link = GetInventoryItemLink(unit, data.slotID)
                    if link then
                        local ilvl = C_Item.GetDetailedItemLevelInfo(link)
                        local quality = C_Item.GetItemQualityByID(link)
                        local r, g, b = C_Item.GetItemQualityColor(quality or 1)
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
            if dodo.DB and dodo.DB.useItemLevel then
                for i = 1, MAX_GEMS do
                    if gems and gems[i] then
                        data.gemBgs[i]:Show()
                        local gem = gems[i]
                        if gem.filled then
                            data.gemTexs[i]:SetTexture(gem.texture or "Interface\\BUTTONS\\WHITE8X8")
                            data.gemTexs[i]:SetTexCoord(0.07, 0.93, 0.07, 0.93)
                            data.gemTexs[i]:Show()
                        else
                            data.gemTexs[i]:Hide()
                        end
                    else
                        data.gemBgs[i]:Hide()
                        data.gemTexs[i]:Hide()
                    end
                end
            else
                for i = 1, MAX_GEMS do
                    data.gemBgs[i]:Hide()
                    data.gemTexs[i]:Hide()
                end
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
            local entry = { slotID = info.slotID, dir = info.dir, gemBgs = {}, gemTexs = {}, isEnchantSlot = info.enchant, slotFrame = slotFrame }

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

            -- 보석 슬롯
            for i = 1, MAX_GEMS do
                local bgOffsetX = configs.ilvl_space + (i - 1) * configs.gem_stride
                local texOffsetX = bgOffsetX + 2

                local bg = slotFrame:CreateTexture(nil, "OVERLAY")
                bg:SetSize(configs.gem_bg_size, configs.gem_bg_size)
                bg:SetTexture("Interface\\ItemSocketingFrame\\UI-EmptySocket-Prismatic")
                bg:Hide()

                local gt = slotFrame:CreateTexture(nil, "OVERLAY")
                gt:SetSize(configs.gem_size, configs.gem_size)
                gt:Hide()

                if info.dir == "RIGHT" then
                    bg:SetPoint("BOTTOMLEFT", slotFrame, "BOTTOMRIGHT", bgOffsetX, 2)
                    gt:SetPoint("BOTTOMLEFT", slotFrame, "BOTTOMRIGHT", texOffsetX, 4)
                else
                    bg:SetPoint("BOTTOMRIGHT", slotFrame, "BOTTOMLEFT", -bgOffsetX, 2)
                    gt:SetPoint("BOTTOMRIGHT", slotFrame, "BOTTOMLEFT", -texOffsetX, 4)
                end

                table_insert(entry.gemBgs, bg)
                table_insert(entry.gemTexs, gt)
            end

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
            else
                entry.tex:SetPoint("TOPRIGHT", slotFrame, "TOPLEFT")
                entry.tex:SetPoint("BOTTOMRIGHT", slotFrame, "BOTTOMLEFT")
                entry.tex:SetWidth(115)
                if info.enchant then
                    entry.enchantText:SetPoint("TOPRIGHT", slotFrame, "TOPLEFT", -4, -2)
                    entry.enchantText:SetJustifyH("RIGHT")
                end
                entry.ilvlText:SetJustifyH("LEFT")
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
    isPendingUpdate = false
    if not PaperDollFrame:IsShown() then return end
    update_slots("player", fexSlotData)
end

local function request_update_slots()
    if not (dodo.DB and dodo.DB.useItemLevel) then return end
    if isPendingUpdate then return end
    isPendingUpdate = true
    try_update_slots()
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
                local g1, g2, g3, g4 = match(link, "item:%d*:%d*:(%d*):(%d*):(%d*):(%d*)")
                for _, gStr in ipairs({g1, g2, g3, g4}) do
                    local gID = tonumber(gStr)
                    if gID and gID > 0 then
                        C_Item.RequestLoadItemDataByID(gID)
                    end
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
            for i = 1, MAX_GEMS do
                if data.gemBgs[i] then data.gemBgs[i]:Hide() end
                if data.gemTexs[i] then data.gemTexs[i]:Hide() end
            end
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

    -- Hook 설정
    hooksecurefunc("NotifyInspect", function(unit)
        inspectUnit = unit
    end)

    if CharacterFrame then
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
                    local g1, g2, g3, g4 = match(link, "item:%d*:%d*:(%d*):(%d*):(%d*):(%d*)")
                    for _, gStr in ipairs({g1, g2, g3, g4}) do
                        local gID = tonumber(gStr)
                        if gID and gID > 0 then
                            C_Item.RequestLoadItemDataByID(gID)
                        end
                    end
                end
            end
            request_update_slots()
        end)

        hooksecurefunc(CharacterFrame, "Expand", apply_wide_layout)
        hooksecurefunc(CharacterFrame, "UpdateSize", apply_wide_layout)
        hooksecurefunc(CharacterFrame, "Collapse", function()
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
            hooksecurefunc(cf, "UpdateItems", function(self) update_bag_frame(self) end)
        end
    end
    if ContainerFrameCombinedBags then
        hooksecurefunc(ContainerFrameCombinedBags, "UpdateItems", function(self) update_bag_frame(self) end)
    end
end

-- ==============================
-- 모듈 생명주기
-- ==============================
function module:OnEnable()
    initialize()
    update_module_state()
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