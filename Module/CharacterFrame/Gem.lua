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
local table_concat = table.concat
local table_insert = table.insert
local _G = _G

-- ==============================
-- 기능 1: 로컬 상태 및 설정
-- ==============================
local gem_cache = {}

-- ==============================
-- 기능 2: 상태 업데이트
-- ==============================
-- 1. 장비 슬롯 전용 보석 글자 객체 가져오거나 생성 (Lazy load)
local function get_or_create_gem_text(slot_frame, dir)
    if not slot_frame.dodoGemText then
        local text = slot_frame:CreateFontString(nil, "OVERLAY")
        text:SetFont(OUTLINE_FONT, 11, "OUTLINE")

        -- RIGHT/LEFT 방향 정렬 앵커 지정
        if dir == "RIGHT" then
            text:SetPoint("BOTTOMLEFT", slot_frame, "BOTTOMRIGHT", 10, 2)
            text:SetJustifyH("LEFT")
        else
            text:SetPoint("BOTTOMRIGHT", slot_frame, "BOTTOMLEFT", -10, 2)
            text:SetJustifyH("RIGHT")
        end

        slot_frame.dodoGemText = text
    end
    return slot_frame.dodoGemText
end

-- 2. 보석 정보 획득 및 최적화 캐싱
local function get_gems_string(unit, slotID)
    local link = GetInventoryItemLink(unit, slotID)
    if not link then return nil end

    if gem_cache[link] ~= nil then
        return gem_cache[link] or nil
    end

    local num_sockets = C_Item.GetItemNumSockets(link) or 0
    if num_sockets == 0 then
        gem_cache[link] = false
        return nil
    end

    local gem_strings = {}
    for i = 1, num_sockets do
        local gem_id = C_Item.GetItemGemID(link, i)
        local icon = nil
        if gem_id then
            icon = C_Item.GetItemIconByID(gem_id)
        end

        -- 보석 미장착 시 순정 빈 소켓 아이콘 사용
        if not icon then
            icon = "Interface\\ItemSocketingFrame\\UI-EmptySocket-Prismatic"
        end

        -- 인라인 텍스처 마크업 구성 (\124T = |T, \124t = |t)
        table_insert(gem_strings, "\124T" .. icon .. ":11:11:0:0:64:64:4:60:4:60\124t")
    end

    if #gem_strings > 0 then
        local gem_string = table_concat(gem_strings, " ")
        gem_cache[link] = gem_string
        return gem_string
    end

    gem_cache[link] = false
    return nil
end

-- 3. 보석 상태 업데이트 함수
function dodo.UpdateCharacterFrameGem(unit, slot_list)
    local is_enabled = (dodoDB.enableCharacterFrame ~= false)

    for _, info in ipairs(slot_list) do
        local prefix = (unit == "player") and "Character" or "Inspect"
        local slot_name = info.frame:gsub("Character", prefix)
        local slot_frame = _G[slot_name]

        if slot_frame then
            local gem_text = get_or_create_gem_text(slot_frame, info.dir)
            local link = GetInventoryItemLink(unit, info.slotID)

            if not link or not is_enabled then
                gem_text:Hide()
            else
                local gem_string = get_gems_string(unit, info.slotID)
                if gem_string and gem_string ~= "" then
                    gem_text:SetText(gem_string)
                    gem_text:Show()
                else
                    gem_text:Hide()
                end
            end
        end
    end
end
