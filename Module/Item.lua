-- ==============================
-- Inspired
-- ==============================
-- Chonky Character Sheet (https://www.curseforge.com/wow/addons/chonky-character-sheet)
-- Fex (https://www.curseforge.com/wow/addons/fex)

-- ==============================
-- 설정 및 테이블
-- ==============================
---@diagnostic disable: lowercase-global, undefined-field, undefined-global
local addonName, dodo = ...
dodoDB = dodoDB or {}

-- API 로컬 캐싱
local _G = _G
local select, tonumber = select, tonumber
local table_insert = table.insert
local match = string.match
local GetInventoryItemLink = GetInventoryItemLink
local GetInventoryItemID = GetInventoryItemID
local GetItemInfoInstant = GetItemInfoInstant
local C_Item = C_Item
local C_Container = C_Container
local C_Timer = C_Timer
local C_TooltipInfo = C_TooltipInfo

local configs = {
    ilvl_font_size       = 12,
    enchant_font_size    = 12,
    gem_bg_size         = 14,
    gem_size            = 10,
    gem_stride          = 16,
    ilvl_space          = 10, -- 아이콘과 텍스트 사이 간격
    wide_width          = 650,
    normal_width        = 448,
};

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
};

-- ============================================================
-- 캐싱
-- ============================================================

local fexSlotData = {};
local fexInspectSlotData = {};
local fexCompCharacterData = {};
local fexCompInspectData = {};
local fexSlotBuilt = false;
local fexInspectBuilt = false;
local fexCompCharacterBuilt = false;
local fexCompInspectBuilt = false;
local fexOriginalHeight = nil;
local inspectUnit = nil;

local MAX_GEMS = 4;
local OUTLINE_FONT = "Fonts\\FRIZQT__.TTF";

-- ============================================================
-- 함수
-- ============================================================


local ENCHANT_PATTERNS = { "^마법부여: (.+)", "^Enchanted: (.+)" }
local function get_enchant_name(unit, slotID)
    local data = C_TooltipInfo.GetInventoryItem(unit, slotID);
    if not data or not data.lines then return nil end
    for _, line in ipairs(data.lines) do
        local text = line.leftText;
        if text then
            for _, p in ipairs(ENCHANT_PATTERNS) do
                local name = match(text, p);
                if name then
                    local suffix = match(name, " %- (.+)$");
                    return suffix or name;
                end
            end
        end
    end
    return nil;
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
    local link = GetInventoryItemLink(unit, slotID);
    if not link then return nil end
    
    local gems = {};
    -- 1. 이미 장착된 보석 확인
    for i = 1, MAX_GEMS do
        local _, gemLink = C_Item.GetItemGem(link, i);
        if gemLink and gemLink ~= "" then
            local itemID = tonumber(match(gemLink, "item:(%d+)"));
            local gemIcon = itemID and C_Item.GetItemIconByID(itemID);
            if not gemIcon and itemID then
                _, _, _, _, gemIcon = GetItemInfoInstant(itemID);
            end
            table_insert(gems, { filled = true, texture = gemIcon or 134400 });
        end
    end
    
    -- 2. 빈 소켓 확인 (툴팁 텍스트 이용 - 훨씬 정확함)
    local tooltipData = C_TooltipInfo.GetInventoryItem(unit, slotID);
    if tooltipData and tooltipData.lines then
        for _, line in ipairs(tooltipData.lines) do
            local text = line.leftText;
            if text then
                -- Blizzard 글로벌 스트링 및 한국어/영어 공용 패턴 확인
                if text:find("보석 홈") or text:find("Socket") or text:find(EMPTY_SOCKET_PRISMATIC or "") then
                    table_insert(gems, { filled = false });
                end
            end
        end
    end
    
    return #gems > 0 and gems or nil;
end

local function update_slots(unit, slotData)
    if not unit then return end
    if unit == "player" and not (PaperDollFrame:IsShown() or (CCS_InspectCompare and CCS_InspectCompare:IsShown())) then return end
    if unit ~= "player" and (not InspectFrame or not InspectFrame:IsShown()) and not (CCS_InspectCompare and CCS_InspectCompare:IsShown()) then return end

    for _, data in ipairs(slotData) do
        local hasItem = GetInventoryItemID(unit, data.slotID) ~= nil;
        if not hasItem then
            if data.tex then data.tex:Hide() end
            if data.enchantText then data.enchantText:Hide() end
            data.ilvlText:Hide();
            for i = 1, MAX_GEMS do
                data.gemBgs[i]:Hide();
                data.gemTexs[i]:Hide();
            end
        else
            -- 보석 데이터 미리 가져오기 (중복 호출 방지)
            local gems = get_gem_data(unit, data.slotID);
            local hasGems = (gems ~= nil);

            -- 배경 그라데이션 및 마법부여
            if dodoDB.useEnhancedCharFrame and data.tex then
                local r, g, b = 1, 1, 1;

                if data.isEnchantSlot then
                    local name = get_enchant_name(unit, data.slotID);
                    if name then
                        data.enchantText:SetText(name);
                        data.enchantText:SetTextColor(0, 1, 0.6, 1);
                        data.enchantText:Show();
                    else
                        r, g, b = 1, 0, 0; -- 마부 누락 시 빨간색
                        data.enchantText:SetText("마부없음!");
                        data.enchantText:SetTextColor(1, 0, 0, 1);
                        data.enchantText:Show();
                    end
                else
                    if data.enchantText then data.enchantText:Hide() end
                end

                -- 마부 가능 슬롯이거나 보석홈이 있는 경우에만 강조 표시
                if data.isEnchantSlot or hasGems then
                    if data.dir == "RIGHT" then
                        data.tex:SetGradient("HORIZONTAL", CreateColor(r, g, b, 0.4), CreateColor(r, g, b, 0));
                    else
                        data.tex:SetGradient("HORIZONTAL", CreateColor(r, g, b, 0), CreateColor(r, g, b, 0.4));
                    end
                    data.tex:Show();
                else
                    data.tex:Hide();
                end
            else
                if data.tex then data.tex:Hide() end
                if data.enchantText then data.enchantText:Hide() end
            end

            -- 아이템 레벨
            if dodoDB.useItemLevel then
                local itemLoc = ItemLocation:CreateFromEquipmentSlot(data.slotID);
                if unit == "player" and itemLoc and C_Item.DoesItemExist(itemLoc) then
                    local ilvl = C_Item.GetCurrentItemLevel(itemLoc);
                    local quality = C_Item.GetItemQuality(itemLoc);
                    local r, g, b = C_Item.GetItemQualityColor(quality or 1);
                    data.ilvlText:SetTextColor(r, g, b);
                    data.ilvlText:SetText(ilvl);
                    data.ilvlText:Show();
                else
                    local link = GetInventoryItemLink(unit, data.slotID);
                    if link then
                        local ilvl = C_Item.GetDetailedItemLevelInfo(link);
                        local quality = C_Item.GetItemQualityByID(link);
                        local r, g, b = C_Item.GetItemQualityColor(quality or 1);
                        data.ilvlText:SetTextColor(r, g, b);
                        data.ilvlText:SetText(ilvl);
                        data.ilvlText:Show();
                    else
                        data.ilvlText:Hide();
                    end
                end
            else
                data.ilvlText:Hide();
            end

            -- 보석 아이콘 표시
            if dodoDB.useEnhancedCharFrame then
                for i = 1, MAX_GEMS do
                    if gems and gems[i] then
                        data.gemBgs[i]:Show();
                        local gem = gems[i];
                        if gem.filled then
                            data.gemTexs[i]:SetTexture(gem.texture or "Interface\\BUTTONS\\WHITE8X8");
                            data.gemTexs[i]:SetTexCoord(0.07, 0.93, 0.07, 0.93);
                            data.gemTexs[i]:Show();
                        else
                            data.gemTexs[i]:Hide();
                        end
                    else
                        data.gemBgs[i]:Hide();
                        data.gemTexs[i]:Hide();
                    end
                end
            else
                for i = 1, MAX_GEMS do
                    data.gemBgs[i]:Hide();
                    data.gemTexs[i]:Hide();
                end
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
        local slotName = info.frame:gsub("Character", prefix);
        local slotFrame = _G[slotName];
        if slotFrame then
            local entry = { slotID = info.slotID, dir = info.dir, gemBgs = {}, gemTexs = {}, isEnchantSlot = info.enchant, slotFrame = slotFrame };

            -- 아이템 레벨 텍스트
            local ilvlText = slotFrame:CreateFontString(nil, "OVERLAY");
            ilvlText:SetFont(OUTLINE_FONT, configs.ilvl_font_size, "OUTLINE");
            ilvlText:SetPoint("TOPLEFT", slotFrame, "TOPLEFT", 2, -2);
            ilvlText:Hide();
            entry.ilvlText = ilvlText;

            -- 배경 그라데이션 텍스처
            local tex = slotFrame:CreateTexture(nil, "BORDER");
            tex:SetTexture("Interface\\BUTTONS\\WHITE8X8");
            tex:Hide();
            entry.tex = tex;

            -- 마법부여 텍스트
            if info.enchant then
                local enchantText = slotFrame:CreateFontString(nil, "OVERLAY");
                enchantText:SetFont(OUTLINE_FONT, configs.enchant_font_size, "OUTLINE");
                enchantText:Hide();
                entry.enchantText = enchantText;
            end

            -- 보석 슬롯
            for i = 1, MAX_GEMS do
                local bgOffsetX = configs.ilvl_space + (i - 1) * configs.gem_stride;
                local texOffsetX = bgOffsetX + 2;

                local bg = slotFrame:CreateTexture(nil, "OVERLAY");
                bg:SetSize(configs.gem_bg_size, configs.gem_bg_size);
                bg:SetTexture("Interface\\ItemSocketingFrame\\UI-EmptySocket-Prismatic");
                bg:Hide();

                local gt = slotFrame:CreateTexture(nil, "OVERLAY");
                gt:SetSize(configs.gem_size, configs.gem_size);
                gt:Hide();

                if info.dir == "RIGHT" then
                    bg:SetPoint("BOTTOMLEFT", slotFrame, "BOTTOMRIGHT", bgOffsetX, 2);
                    gt:SetPoint("BOTTOMLEFT", slotFrame, "BOTTOMRIGHT", texOffsetX, 4);
                else
                    bg:SetPoint("BOTTOMRIGHT", slotFrame, "BOTTOMLEFT", -bgOffsetX, 2);
                    gt:SetPoint("BOTTOMRIGHT", slotFrame, "BOTTOMLEFT", -texOffsetX, 4);
                end

                table.insert(entry.gemBgs, bg);
                table.insert(entry.gemTexs, gt);
            end

            -- 위치 설정
            if info.dir == "RIGHT" then
                entry.tex:SetPoint("TOPLEFT", slotFrame, "TOPRIGHT");
                entry.tex:SetPoint("BOTTOMLEFT", slotFrame, "BOTTOMRIGHT");
                entry.tex:SetWidth(115);
                if info.enchant then
                    entry.enchantText:SetPoint("TOPLEFT", slotFrame, "TOPRIGHT", 4, -2);
                    entry.enchantText:SetJustifyH("LEFT");
                end
                entry.ilvlText:SetJustifyH("LEFT");
            else
                entry.tex:SetPoint("TOPRIGHT", slotFrame, "TOPLEFT");
                entry.tex:SetPoint("BOTTOMRIGHT", slotFrame, "BOTTOMLEFT");
                entry.tex:SetWidth(115);
                if info.enchant then
                    entry.enchantText:SetPoint("TOPRIGHT", slotFrame, "TOPLEFT", -4, -2);
                    entry.enchantText:SetJustifyH("RIGHT");
                end
                entry.ilvlText:SetJustifyH("LEFT");
            end

            table.insert(slotData, entry);
        end
    end
end

local function reset_layout()
    CharacterFrame:SetWidth(configs.normal_width);
    if fexOriginalHeight then
        CharacterFrame:SetHeight(fexOriginalHeight);
    end
end

local function apply_wide_layout()
    if not PaperDollFrame or not PaperDollFrame:IsShown() then return end

    if not dodoDB.useEnhancedCharFrame then
        reset_layout();
        return;
    end

    CharacterFrame:SetWidth(configs.wide_width);
    
    CharacterFrameInset:ClearAllPoints();
    CharacterFrameInset:SetPoint("TOPLEFT", CharacterFrame, "TOPLEFT", 4, -60);
    CharacterFrameInset:SetPoint("BOTTOMRIGHT", CharacterFrame, "BOTTOMLEFT", configs.wide_width - 206, 4);

    if CharacterMainHandSlot then
        CharacterMainHandSlot:SetPoint("BOTTOMLEFT", PaperDollItemsFrame, "BOTTOMLEFT", 145, 14);
    end
    if CharacterSecondaryHandSlot then
        CharacterSecondaryHandSlot:SetPoint("BOTTOMLEFT", CharacterMainHandSlot, "BOTTOMRIGHT", 5, 0);
    end

    if CharacterModelScene then
        local LeftSlot = CharacterHeadSlot;
        local RightSlot = CharacterTrinket1Slot;
        if LeftSlot and RightSlot then
            CharacterModelScene:ClearAllPoints();
            -- 상단 여백을 위해 y축에 -30 오프셋, 하단 조절을 위해 20 오프셋 추가
            CharacterModelScene:SetPoint("TOPLEFT", LeftSlot, "TOPRIGHT", 0, -4);
            CharacterModelScene:SetPoint("BOTTOMRIGHT", RightSlot, "BOTTOMLEFT", 0, 0);
        end
    end
end

-- 가방 아이템 레벨 관련
local bagSlotCache = {};
local function update_bag_slot(button)
    if not button then return end
    local bagID, slotID;
    if button.GetBagID then
        bagID = button:GetBagID();
        slotID = button:GetID();
    else
        -- Combined bags 등 대응
        local parent = button:GetParent();
        if parent and parent.GetID then
            bagID = parent:GetID();
            slotID = button:GetID();
        end
    end
    if not bagID or not slotID then return end

    if not bagSlotCache[button] then
        local container = CreateFrame("Frame", nil, button);
        container:SetFrameLevel(button:GetFrameLevel() + 5);
        container:SetAllPoints(button);
        local ilvlFS = container:CreateFontString(nil, "OVERLAY");
        ilvlFS:SetFont(OUTLINE_FONT, configs.ilvl_font_size, "OUTLINE");
        ilvlFS:SetPoint("TOPLEFT", 2, -2);
        container.ilvlFS = ilvlFS;
        bagSlotCache[button] = container;
    end

    local ilvlFS = bagSlotCache[button].ilvlFS;
    if not dodoDB.useItemLevel then
        ilvlFS:Hide();
        return;
    end

    local info = C_Container.GetContainerItemInfo(bagID, slotID);
    if info and info.hyperlink then
        local _, _, quality, _, _, _, _, _, equipLoc, _, _, classID = C_Item.GetItemInfo(info.hyperlink);
        local isEquip = (classID == 2 or classID == 4) and equipLoc and equipLoc ~= "" and equipLoc ~= "INVTYPE_NON_EQUIP";

        if isEquip then
            local itemLevel = C_Item.GetDetailedItemLevelInfo(info.hyperlink);
            if itemLevel and itemLevel > 1 then
                local r, g, b = C_Item.GetItemQualityColor(quality or 1);
                ilvlFS:SetTextColor(r, g, b);
                ilvlFS:SetText(itemLevel);
                ilvlFS:Show();
                return;
            end
        end
    end
    ilvlFS:Hide();
end

local function update_bag_frame(frame)
    if not frame then return end
    if frame.EnumerateValidItems then
        for _, button in frame:EnumerateValidItems() do
            update_bag_slot(button);
        end
    end
end

-- ==============================
-- 동작
-- ==============================

local isPendingUpdate = false;

local function try_update_slots()
    local allReady = true;
    for _, info in ipairs(SLOT_LIST) do
        local link = GetInventoryItemLink("player", info.slotID);
        if link then
            local itemID = tonumber(match(link, "item:(%d+)"));
            if itemID and not C_Item.IsItemDataCachedByID(itemID) then
                allReady = false;
                break;
            end
            
            -- Fex 스타일: 링크를 직접 파싱하여 보석 ID 추출 및 캐시 확인
            -- item:itemID:enchantID:gemID1:gemID2:gemID3:gemID4
            local _, _, g1, g2, g3, g4 = match(link, "item:(%d*):(%d*):(%d*):(%d*):(%d*):(%d*)");
            for _, gStr in ipairs({g1, g2, g3, g4}) do
                local gID = tonumber(gStr);
                if gID and gID > 0 and not C_Item.IsItemDataCachedByID(gID) then
                    allReady = false;
                    break;
                end
            end
        end
        if not allReady then break end
    end

    if allReady then
        isPendingUpdate = false;
        update_slots("player", fexSlotData);
    else
        C_Timer.After(0.1, try_update_slots);
    end
end

local function request_update_slots()
    if isPendingUpdate then return end
    isPendingUpdate = true;
    try_update_slots();
end

function dodo.ItemLevelDisplay(value)
    request_update_slots();
    if InspectFrame and InspectFrame:IsShown() then
        update_slots(inspectUnit or "target", fexInspectSlotData);
    end
    -- ChonkyCharacterSheet 지원
    if _G["CompInspectHeadSlot"] then
        update_slots(inspectUnit or "target", fexCompInspectData);
    end
    if _G["CompCharacterHeadSlot"] then
        update_slots("player", fexCompCharacterData);
    end
    -- 가방 업데이트
    for i = 1, NUM_CONTAINER_FRAMES do
        update_bag_frame(_G["ContainerFrame" .. i]);
    end
    if ContainerFrameCombinedBags then update_bag_frame(ContainerFrameCombinedBags) end
end

function dodo.EnhancedCharFrame(value)
    if value then
        apply_wide_layout();
    else
        reset_layout();
    end
    request_update_slots();
    if InspectFrame and InspectFrame:IsShown() then
        update_slots(inspectUnit or "target", fexInspectSlotData);
    end
    -- ChonkyCharacterSheet 지원
    if _G["CompInspectHeadSlot"] then
        update_slots(inspectUnit or "target", fexCompInspectData);
    end
    if _G["CompCharacterHeadSlot"] then
        update_slots("player", fexCompCharacterData);
    end
end

local function on_event(self, event, ...)
    if event == "PLAYER_LOGIN" then
        C_AddOns.LoadAddOn("Blizzard_CharacterFrame");
        C_Timer.After(0.5, function()
            hide_character_backgrounds();
            build_slots("Character", fexSlotData);
            request_update_slots();
        end);
        
        if C_AddOns.IsAddOnLoaded("Blizzard_InspectUI") then
            build_slots("Inspect", fexInspectSlotData);
        end
    elseif event == "PLAYER_ENTERING_WORLD" then
        for slot = 1, 19 do
            local link = GetInventoryItemLink("player", slot);
            if link then
                local itemID = tonumber(match(link, "item:(%d+)"));
                if itemID then
                    C_Item.RequestLoadItemDataByID(itemID);
                end
                
                -- Fex 스타일: 링크 파싱으로 보석 데이터 로드 요청 (GetItemGem보다 빠름)
                local _, _, g1, g2, g3, g4 = match(link, "item:(%d*):(%d*):(%d*):(%d*):(%d*):(%d*)");
                for _, gStr in ipairs({g1, g2, g3, g4}) do
                    local gID = tonumber(gStr);
                    if gID and gID > 0 then
                        C_Item.RequestLoadItemDataByID(gID);
                    end
                end
            end
        end
        request_update_slots();
    elseif event == "ADDON_LOADED" then
        local addon = ...;
        if addon == "Blizzard_InspectUI" then
            build_slots("Inspect", fexInspectSlotData);
        end
    elseif event == "INSPECT_READY" then
        local unit = inspectUnit or "target";
        update_slots(unit, fexInspectSlotData);
        
        -- ChonkyCharacterSheet 지원
        if _G["CompInspectHeadSlot"] then
            build_slots("CompInspect", fexCompInspectData);
            update_slots(unit, fexCompInspectData);
        end
        if _G["CompCharacterHeadSlot"] then
            build_slots("CompCharacter", fexCompCharacterData);
            update_slots("player", fexCompCharacterData);
        end
    elseif event == "BAG_UPDATE_DELAYED" then
        for i = 1, NUM_CONTAINER_FRAMES do
            update_bag_frame(_G["ContainerFrame" .. i]);
        end
        if ContainerFrameCombinedBags then update_bag_frame(ContainerFrameCombinedBags) end
    else
        request_update_slots();
    end
end

-- ==============================
-- 이벤트
-- ==============================
local event_frame = CreateFrame("Frame");
event_frame:RegisterEvent("PLAYER_LOGIN");
event_frame:RegisterEvent("PLAYER_ENTERING_WORLD");
event_frame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED");
event_frame:RegisterEvent("UNIT_INVENTORY_CHANGED");
event_frame:RegisterEvent("GET_ITEM_INFO_RECEIVED");
event_frame:RegisterEvent("ENCHANT_SPELL_COMPLETED");
event_frame:RegisterEvent("WEAPON_ENCHANT_CHANGED");
event_frame:RegisterEvent("BAG_UPDATE_DELAYED");
event_frame:RegisterEvent("INSPECT_READY");
event_frame:RegisterEvent("ADDON_LOADED");
event_frame:SetScript("OnEvent", on_event);

hooksecurefunc("NotifyInspect", function(unit)
    inspectUnit = unit;
end);

CharacterFrame:HookScript("OnShow", function()
    hide_character_backgrounds();
    apply_wide_layout();
    update_slots("player", fexSlotData);
end);

hooksecurefunc(CharacterFrame, "Expand", apply_wide_layout);
hooksecurefunc(CharacterFrame, "UpdateSize", apply_wide_layout);
hooksecurefunc(CharacterFrame, "Collapse", reset_layout);

for i = 1, NUM_CONTAINER_FRAMES do
    local cf = _G["ContainerFrame" .. i];
    if cf then
        hooksecurefunc(cf, "UpdateItems", function(self) update_bag_frame(self) end);
    end
end
if ContainerFrameCombinedBags then
    hooksecurefunc(ContainerFrameCombinedBags, "UpdateItems", function(self) update_bag_frame(self) end);
end