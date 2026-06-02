-- ==============================
-- Inspired
-- ==============================
-- ArmoryUtils (https://www.curseforge.com/wow/addons/armoryutils)
-- Fex (https://www.curseforge.com/wow/addons/fex)

-- ==============================
-- 설정 및 테이블
-- ==============================
local addonName, dodo = ...
dodoDB = dodoDB or {}

local OUTLINE_FONT = "Fonts\\2002.TTF"

-- ==============================
-- 캐싱
-- ==============================
local C_Item = C_Item
local GetInventoryItemLink = GetInventoryItemLink
local ipairs = ipairs
local _G = _G

-- ==============================
-- 기능 1: 로컬 상태 및 설정
-- ==============================
local ilvl_cache = {}
local color_cache = {}

-- ==============================
-- 기능 2: 상태 업데이트
-- ==============================
-- 1. 장비 슬롯 전용 글자 객체 가져오거나 생성 (Lazy load)
local function get_or_create_ilvl_text(slotFrame)
    if not slotFrame.dodoIlvlText then
        local text = slotFrame:CreateFontString(nil, "OVERLAY")
        text:SetFont(OUTLINE_FONT, 12, "OUTLINE")
        text:SetPoint("TOPLEFT", slotFrame, "TOPLEFT", 2, -2)
        text:SetJustifyH("LEFT")
        slotFrame.dodoIlvlText = text
    end
    return slotFrame.dodoIlvlText
end

-- 2. 아이템 레벨 업데이트 함수
function dodo.UpdateCharacterFrameIlvl(unit, slot_list)
    local is_enabled = (dodoDB.enableCharacterFrame ~= false and dodoDB.useItemLevel ~= false)

    for _, info in ipairs(slot_list) do
        -- unit 접두사에 따라 캐릭터창("Character") 또는 살펴보기창("Inspect") 슬롯 프레임 획득
        local prefix = (unit == "player") and "Character" or "Inspect"
        local slotName = info.frame:gsub("Character", prefix)
        local slotFrame = _G[slotName]

        if slotFrame then
            local ilvlText = get_or_create_ilvl_text(slotFrame)
            local link = GetInventoryItemLink(unit, info.slotID)

            if not link or not is_enabled then
                ilvlText:Hide()
            else
                local ilvl = ilvl_cache[link]
                local color = color_cache[link]

                -- 미캐싱된 장비 정보 획득 및 캐싱
                if not ilvl then
                    ilvl = C_Item.GetDetailedItemLevelInfo(link)
                    if ilvl and ilvl > 0 then
                        ilvl_cache[link] = ilvl
                        local quality = C_Item.GetItemQualityByID(link)
                        local r, g, b = C_Item.GetItemQualityColor(quality or 1)
                        color = { r = r, g = g, b = b }
                        color_cache[link] = color
                    end
                end

                -- 아이템 레벨 텍스트 적용 및 시각화
                if ilvl and ilvl > 0 and color then
                    ilvlText:SetText(ilvl)
                    ilvlText:SetTextColor(color.r, color.g, color.b)
                    ilvlText:Show()
                else
                    ilvlText:Hide()
                end
            end
        end
    end
end
