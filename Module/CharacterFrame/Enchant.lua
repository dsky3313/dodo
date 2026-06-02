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
local C_TooltipInfo = C_TooltipInfo
local CreateColor = CreateColor
local GetInventoryItemLink = GetInventoryItemLink
local ipairs = ipairs
local match = string.match
local _G = _G

-- ==============================
-- 기능 1: 로컬 상태 및 설정
-- ==============================
local enchant_cache = {}

-- ==============================
-- 기능 2: 상태 업데이트
-- ==============================
-- 1. 장비 슬롯 전용 그라데이션 배경 및 마부 텍스트 프레임 생성 (Lazy load)
local function get_or_create_enchant_objects(slot_frame, dir)
    if not slot_frame.dodoEnchantText then
        -- 그라데이션 바 생성
        local gradient = slot_frame:CreateTexture(nil, "BORDER")
        gradient:SetTexture("Interface\\BUTTONS\\WHITE8X8")
        gradient:SetWidth(115)
        
        -- 마법부여 텍스트 생성
        local text = slot_frame:CreateFontString(nil, "OVERLAY")
        text:SetFont(OUTLINE_FONT, 12, "OUTLINE")

        -- 방향(RIGHT/LEFT)에 맞춰 정렬 및 위치 앵커 설정
        if dir == "RIGHT" then
            gradient:SetPoint("TOPLEFT", slot_frame, "TOPRIGHT")
            gradient:SetPoint("BOTTOMLEFT", slot_frame, "BOTTOMRIGHT")
            text:SetPoint("TOPLEFT", slot_frame, "TOPRIGHT", 4, -2)
            text:SetJustifyH("LEFT")
        else
            gradient:SetPoint("TOPRIGHT", slot_frame, "TOPLEFT")
            gradient:SetPoint("BOTTOMRIGHT", slot_frame, "BOTTOMLEFT")
            text:SetPoint("TOPRIGHT", slot_frame, "TOPLEFT", -4, -2)
            text:SetJustifyH("RIGHT")
        end

        slot_frame.dodoEnchantGradient = gradient
        slot_frame.dodoEnchantText = text
    end
    return slot_frame.dodoEnchantText, slot_frame.dodoEnchantGradient
end

-- 2. 마법부여 데이터 파싱 및 캐싱
local function get_enchant_name(unit, slotID)
    local link = GetInventoryItemLink(unit, slotID)
    if not link then return nil end

    if enchant_cache[link] ~= nil then
        return enchant_cache[link] or nil
    end

    local data = C_TooltipInfo.GetInventoryItem(unit, slotID)
    if not data or not data.lines then
        enchant_cache[link] = false
        return nil
    end

    -- 와우 내장 마법부여 포맷 문자열 파싱 ("마법부여: %s")
    local enchant_pattern = ENCHANTED_TOOLTIP_LINE:gsub("%%s", "(.*)")
    for _, line in ipairs(data.lines) do
        local text = line.leftText
        if text then
            local name = match(text, enchant_pattern)
            if name then
                -- 툴팁 텍스트에서 불필요한 접미사 정리 (" - 지능" 등 제거)
                local suffix = match(name, " %- (.+)$")
                local result = suffix or name
                enchant_cache[link] = result
                return result
            end
        end
    end

    enchant_cache[link] = false
    return nil
end

-- 3. 마법부여 업데이트 함수
function dodo.UpdateCharacterFrameEnchant(unit, slot_list)
    local is_enabled = (dodoDB.enableCharacterFrame ~= false)

    for _, info in ipairs(slot_list) do
        local prefix = (unit == "player") and "Character" or "Inspect"
        local slot_name = info.frame:gsub("Character", prefix)
        local slot_frame = _G[slot_name]

        if slot_frame then
            local enchant_text, enchant_gradient = get_or_create_enchant_objects(slot_frame, info.dir)
            local link = GetInventoryItemLink(unit, info.slotID)

            if not link or not is_enabled then
                enchant_text:Hide()
                enchant_gradient:Hide()
            else
                -- 마법부여가 가능한 슬롯인 경우에만 갱신 처리
                if info.enchant then
                    local name = get_enchant_name(unit, info.slotID)
                    local r, g, b = 1, 1, 1

                    if name then
                        enchant_text:SetText(name)
                        enchant_text:SetTextColor(0, 1, 0.6, 1) -- 마부 완료: 에메랄드 녹색
                        r, g, b = 0, 1, 0.6
                    else
                        enchant_text:SetText("마부없음!")
                        enchant_text:SetTextColor(1, 0, 0, 1) -- 마부 누락: 빨간색 경고
                        r, g, b = 1, 0, 0
                    end

                    -- 그라데이션 그리기
                    if info.dir == "RIGHT" then
                        enchant_gradient:SetGradient("HORIZONTAL", CreateColor(r, g, b, 0.35), CreateColor(r, g, b, 0))
                    else
                        enchant_gradient:SetGradient("HORIZONTAL", CreateColor(r, g, b, 0), CreateColor(r, g, b, 0.35))
                    end

                    enchant_text:Show()
                    enchant_gradient:Show()
                else
                    enchant_text:Hide()
                    enchant_gradient:Hide()
                end
            end
        end
    end
end
