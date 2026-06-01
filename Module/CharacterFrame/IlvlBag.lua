-- ==============================
-- 설정 및 테이블
-- ==============================
---@diagnostic disable: lowercase-global, param-type-mismatch, redundant-parameter, undefined-field, undefined-global
local addonName, dodo = ...
dodoDB = dodoDB or {}

-- ==============================
-- 캐싱
-- ==============================
local C_Container = C_Container
local C_Item = C_Item
local CreateFrame = CreateFrame
local hooksecurefunc = hooksecurefunc
local _G = _G

local NUM_CONTAINER_FRAMES = NUM_CONTAINER_FRAMES or 13
local OUTLINE_FONT = "Fonts\\2002.TTF"

-- ==============================
-- 가방 슬롯 업데이트
-- ==============================
local bag_slot_cache = {}

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

    if not bag_slot_cache[button] then
        local container = CreateFrame("Frame", nil, button)
        container:SetFrameLevel(button:GetFrameLevel() + 5)
        container:SetAllPoints(button)
        local ilvlFS = container:CreateFontString(nil, "OVERLAY")
        ilvlFS:SetFont(OUTLINE_FONT, 12, "OUTLINE")
        ilvlFS:SetPoint("TOPLEFT", 2, -2)
        container.ilvlFS = ilvlFS
        bag_slot_cache[button] = container
    end

    local ilvlFS = bag_slot_cache[button].ilvlFS
    if dodoDB.enableCharacterFrame == false or not dodoDB.useItemLevel then
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

function dodo.UpdateCharacterFrameIlvlBag()
    for i = 1, NUM_CONTAINER_FRAMES do
        update_bag_frame(_G["ContainerFrame" .. i])
    end
    if ContainerFrameCombinedBags then update_bag_frame(ContainerFrameCombinedBags) end
end

-- 가방 아이템 슬롯 훅
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
