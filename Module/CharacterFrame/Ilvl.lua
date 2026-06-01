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

local OUTLINE_FONT = "Fonts\\2002.TTF"

-- ==============================
-- 슬롯 빌더 콜백
-- ==============================
table.insert(dodo.CharacterFrameBuildSlotsCallbacks, function(slotFrame, entry, info)
    local ilvlText = slotFrame:CreateFontString(nil, "OVERLAY")
    ilvlText:SetFont(OUTLINE_FONT, 12, "OUTLINE")
    ilvlText:SetPoint("TOPLEFT", slotFrame, "TOPLEFT", 2, -2)
    ilvlText:SetJustifyH("LEFT")
    ilvlText:Hide()
    entry.ilvlText = ilvlText
end)

-- ==============================
-- 슬롯 업데이트
-- ==============================
local ilvl_cache = {}
local ilvl_color_cache = {}

function dodo.UpdateCharacterFrameIlvl(unit, slot_data)
    local is_enabled = (dodoDB.enableCharacterFrame ~= false and dodoDB.useItemLevel ~= false)

    for _, data in ipairs(slot_data) do
        local link = GetInventoryItemLink(unit, data.slotID)
        if not link or not is_enabled then
            if data.ilvlText then data.ilvlText:Hide() end
        else
            local ilvl = ilvl_cache[link]
            local color = ilvl_color_cache[link]

            if not ilvl then
                ilvl = C_Item.GetDetailedItemLevelInfo(link)
                if ilvl and ilvl > 0 then
                    ilvl_cache[link] = ilvl
                    local quality = C_Item.GetItemQualityByID(link)
                    local r, g, b = C_Item.GetItemQualityColor(quality or 1)
                    color = { r = r, g = g, b = b }
                    ilvl_color_cache[link] = color
                end
            end

            if ilvl and data.ilvlText then
                data.ilvlText:SetTextColor(color.r, color.g, color.b)
                data.ilvlText:SetText(ilvl)
                data.ilvlText:Show()
            elseif data.ilvlText then
                data.ilvlText:Hide()
            end
        end
    end
end
