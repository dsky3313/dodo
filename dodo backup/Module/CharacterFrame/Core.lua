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

dodo.OUTLINE_FONT = STANDARD_TEXT_FONT or "Fonts\\2002.TTF"

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

-- ==============================
-- 캐싱
-- ==============================
local C_Timer = C_Timer
local CreateFrame = CreateFrame
local hooksecurefunc = hooksecurefunc
local PaperDollFrame = PaperDollFrame

-- ==============================
-- 기능 1: 로컬 상태 및 설정
-- ==============================
local event_frame = CreateFrame("Frame")

-- ==============================
-- 기능 2: 상태 업데이트
-- ==============================
-- 캐릭터창 및 살펴보기창 통합 갱신 제어 허브
local function update_all_character_slots()
    if dodoDB.enableCharacterFrame == false then
        -- 비활성화 시 모든 오버레이 숨김 처리 유도
        if dodo.UpdateCharacterFrameIlvl then dodo.UpdateCharacterFrameIlvl("player", dodo.CharacterFrameSLOT_LIST) end
        if dodo.UpdateCharacterFrameEnchant then dodo.UpdateCharacterFrameEnchant("player", dodo.CharacterFrameSLOT_LIST) end
        if dodo.UpdateCharacterFrameGem then dodo.UpdateCharacterFrameGem("player", dodo.CharacterFrameSLOT_LIST) end
        return
    end

    -- 모듈별 독립적 업데이트 트리거
    if dodo.UpdateCharacterFrameIlvl then
        dodo.UpdateCharacterFrameIlvl("player", dodo.CharacterFrameSLOT_LIST)
    end
    if dodo.UpdateCharacterFrameEnchant then
        dodo.UpdateCharacterFrameEnchant("player", dodo.CharacterFrameSLOT_LIST)
    end
    if dodo.UpdateCharacterFrameGem then
        dodo.UpdateCharacterFrameGem("player", dodo.CharacterFrameSLOT_LIST)
    end
    if dodo.UpdateCharacterFrameLayout then
        dodo.UpdateCharacterFrameLayout()
    end
end

local is_update_pending = false

local function do_update()
    is_update_pending = false
    update_all_character_slots()
end

local function request_update()
    if not is_update_pending then
        is_update_pending = true
        C_Timer.After(0.1, do_update)
    end
end

dodo.UpdateAllCharacterSlots = update_all_character_slots

-- ==============================
-- 이벤트 핸들러
-- ==============================
local function on_event(self, event, ...)
    if event == "PLAYER_LOGIN" then
        -- DB 변수 기본값 셋팅
        if dodoDB.enableCharacterFrame == nil then dodoDB.enableCharacterFrame = true end
        if dodoDB.useItemLevel == nil then dodoDB.useItemLevel = true end

        -- 활성화 상태인 경우에만 감지 이벤트 등록
        if dodoDB.enableCharacterFrame then
            event_frame:RegisterEvent("UNIT_INVENTORY_CHANGED")
            event_frame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
            event_frame:RegisterEvent("GET_ITEM_INFO_RECEIVED")
            if dodo.UpdateCharacterFrameLayout then
                dodo.UpdateCharacterFrameLayout()
            end
        end

        -- 캐릭터창 켜질 때 1회 갱신 훅
        if PaperDollFrame then
            hooksecurefunc(PaperDollFrame, "Show", update_all_character_slots)
        end
    elseif event == "UNIT_INVENTORY_CHANGED" then
        local unit = ...
        if unit == "player" then
            request_update()
        end
    elseif event == "PLAYER_EQUIPMENT_CHANGED" then
        request_update()
    elseif event == "GET_ITEM_INFO_RECEIVED" then
        if CharacterFrame and CharacterFrame:IsShown() then
            request_update()
        end
    end
end

event_frame:RegisterEvent("PLAYER_LOGIN")
event_frame:SetScript("OnEvent", on_event)

-- ==============================
-- 설정 등록
-- ==============================

local function toggle_character_frame(checked)
    if checked then
        event_frame:RegisterEvent("UNIT_INVENTORY_CHANGED")
        event_frame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
        event_frame:RegisterEvent("GET_ITEM_INFO_RECEIVED")
        if dodo.UpdateCharacterFrameLayout then dodo.UpdateCharacterFrameLayout() end
    else
        event_frame:UnregisterEvent("UNIT_INVENTORY_CHANGED")
        event_frame:UnregisterEvent("PLAYER_EQUIPMENT_CHANGED")
        event_frame:UnregisterEvent("GET_ITEM_INFO_RECEIVED")
        if dodo.ResetCharacterFrameLayout then dodo.ResetCharacterFrameLayout() end
    end
    update_all_character_slots()
end

dodo.OptionRegistrations = dodo.OptionRegistrations or {}
dodo.OptionRegistrations["인터페이스.편의기능"] = dodo.OptionRegistrations["인터페이스.편의기능"] or {}
table.insert(dodo.OptionRegistrations["인터페이스.편의기능"], function(category)
    Checkbox(category, "enableCharacterFrame", "아이템 레벨 및 마법부여", "캐릭터창과 가방에 아이템 레벨, 마법부여, 보석 정보를 표시합니다.", true, toggle_character_frame)
end)
