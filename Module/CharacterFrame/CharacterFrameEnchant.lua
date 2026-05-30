-- ==============================
-- 설정 및 테이블
-- ==============================
---@diagnostic disable: lowercase-global, param-type-mismatch, redundant-parameter, undefined-field, undefined-global
local addonName, dodo = ...
dodoDB = dodoDB or {}

-- ==============================
-- 캐싱
-- ==============================
local C_TooltipInfo = C_TooltipInfo
local CreateColor = CreateColor
local GetInventoryItemLink = GetInventoryItemLink
local ipairs = ipairs
local match = string.match

local OUTLINE_FONT = "Fonts\\2002.TTF"

-- ==============================
-- 슬롯 빌더 콜백
-- ==============================
table.insert(dodo.CharacterFrameBuildSlotsCallbacks, function(slotFrame, entry, info)
    local tex = slotFrame:CreateTexture(nil, "BORDER")
    tex:SetTexture("Interface\\BUTTONS\\WHITE8X8")
    tex:Hide()
    entry.tex = tex

    if info.enchant then
        local enchantText = slotFrame:CreateFontString(nil, "OVERLAY")
        enchantText:SetFont(OUTLINE_FONT, 12, "OUTLINE")
        enchantText:Hide()
        entry.enchantText = enchantText

        if info.dir == "RIGHT" then
            tex:SetPoint("TOPLEFT", slotFrame, "TOPRIGHT")
            tex:SetPoint("BOTTOMLEFT", slotFrame, "BOTTOMRIGHT")
            tex:SetWidth(115)
            enchantText:SetPoint("TOPLEFT", slotFrame, "TOPRIGHT", 4, -2)
            enchantText:SetJustifyH("LEFT")
        else
            tex:SetPoint("TOPRIGHT", slotFrame, "TOPLEFT")
            tex:SetPoint("BOTTOMRIGHT", slotFrame, "BOTTOMLEFT")
            tex:SetWidth(115)
            enchantText:SetPoint("TOPRIGHT", slotFrame, "TOPLEFT", -4, -2)
            enchantText:SetJustifyH("RIGHT")
        end
    end
end)

-- ==============================
-- 마법부여 파싱 로직
-- ==============================
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

function dodo.UpdateCharacterFrameEnchant(unit, slot_data)
    local is_enabled = (dodoDB.enableCharacterFrame ~= false and dodoDB.useEnhancedCharFrame ~= false)

    for _, data in ipairs(slot_data) do
        local link = GetInventoryItemLink(unit, data.slotID)
        if not link or not is_enabled then
            if data.tex then data.tex:Hide() end
            if data.enchantText then data.enchantText:Hide() end
        else
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

            if data.isEnchantSlot and data.tex then
                if data.dir == "RIGHT" then
                    data.tex:SetGradient("HORIZONTAL", CreateColor(r, g, b, 0.4), CreateColor(r, g, b, 0))
                else
                    data.tex:SetGradient("HORIZONTAL", CreateColor(r, g, b, 0), CreateColor(r, g, b, 0.4))
                end
                data.tex:Show()
            elseif data.tex then
                data.tex:Hide()
            end
        end
    end
end
