-- ==============================
-- 설정 및 테이블
-- ==============================
---@diagnostic disable: lowercase-global, param-type-mismatch, redundant-parameter, undefined-field, undefined-global
local addonName, dodo = ...
dodoDB = dodoDB or {}

-- ==============================
-- 캐싱
-- ==============================
local C_Item = C_Item
local GetInventoryItemLink = GetInventoryItemLink
local ipairs = ipairs
local table_insert = table.insert

local OUTLINE_FONT = "Fonts\\2002.TTF"

-- ==============================
-- 슬롯 빌더 콜백
-- ==============================
table.insert(dodo.CharacterFrameBuildSlotsCallbacks, function(slotFrame, entry, info)
    local gemText = slotFrame:CreateFontString(nil, "OVERLAY")
    gemText:SetFont(OUTLINE_FONT, 11, "OUTLINE")
    gemText:Hide()
    entry.gemText = gemText

    if info.dir == "RIGHT" then
        gemText:SetPoint("BOTTOMLEFT", slotFrame, "BOTTOMRIGHT", 10, 2)
        gemText:SetJustifyH("LEFT")
    else
        gemText:SetPoint("BOTTOMRIGHT", slotFrame, "BOTTOMLEFT", -10, 2)
        gemText:SetJustifyH("RIGHT")
    end
end)

-- ==============================
-- 보석 조회 및 오버레이
-- ==============================
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

function dodo.UpdateCharacterFrameGem(unit, slot_data)
    local is_enabled = (dodoDB.enableCharacterFrame ~= false and dodoDB.useEnhancedCharFrame ~= false)

    for _, data in ipairs(slot_data) do
        local link = GetInventoryItemLink(unit, data.slotID)
        if not link or not is_enabled then
            if data.gemText then data.gemText:Hide() end
        else
            local gemString = get_gems_string_optimized(unit, data.slotID)
            local hasGems = (gemString and gemString ~= "")

            if hasGems and data.gemText then
                data.gemText:SetText(gemString)
                data.gemText:Show()
            elseif data.gemText then
                data.gemText:Hide()
            end
        end
    end
end
