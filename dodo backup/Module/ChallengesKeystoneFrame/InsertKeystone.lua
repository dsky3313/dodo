-- ==============================
-- Inspired
-- ==============================
-- ExwindTools (ExTools.StreamerTools) — TryAutoInsertKeystone

-- ==============================
-- 설정 및 테이블
-- ==============================
-- ChallengesFrame 쐐기돌 슬롯 패널 열릴 때 가방의 쐐기돌을 자동으로 삽입.
-- enableChallengesAutoInsert : 마스터 토글 (기본 ON)
---@diagnostic disable: lowercase-global, param-type-mismatch, redundant-parameter, undefined-field, undefined-global
local addonName, dodo = ...
dodoDB = dodoDB or {}

-- ==============================
-- 캐싱
-- ==============================
local C_ChallengeMode = C_ChallengeMode
local C_Container     = C_Container
local C_Item          = C_Item
local C_MythicPlus    = C_MythicPlus
local C_Timer         = C_Timer
local CreateFrame     = CreateFrame
local CursorHasItem   = CursorHasItem
local ItemLocation    = ItemLocation

-- ==============================
-- 상수 및 상태 변수
-- ==============================
local RETRY_INTERVAL  = 0.15
local RETRY_MAX       = 8

local retry_token     = 0
local current_token   = 0
local retry_remaining = 0

-- ==============================
-- 헬퍼 함수
-- ==============================
local function is_enabled()
    return dodoDB and dodoDB.enableChallengesAutoInsert ~= false
end

local function find_keystone_in_bags()
    if not C_Container or not C_Container.GetContainerNumSlots then return nil, nil end
    if not C_Item or not C_Item.IsItemKeystoneByID then return nil, nil end

    local can_check_map = C_ChallengeMode.CanUseKeystoneInCurrentMap and ItemLocation
    local bag_start     = _G.BACKPACK_CONTAINER or 0
    local bag_end       = _G.NUM_TOTAL_EQUIPPED_BAG_SLOTS or 4

    for bag = bag_start, bag_end do
        local num_slots = C_Container.GetContainerNumSlots(bag) or 0
        for slot = 1, num_slots do
            local item_info = C_Container.GetContainerItemInfo(bag, slot)
            local item_id   = item_info and item_info.itemID
            if item_id and C_Item.IsItemKeystoneByID(item_id) then
                if can_check_map then
                    local loc = ItemLocation:CreateFromBagAndSlot(bag, slot)
                    if loc and C_ChallengeMode.CanUseKeystoneInCurrentMap(loc) then
                        return bag, slot
                    end
                else
                    return bag, slot
                end
            end
        end
    end

    return nil, nil
end

local function try_insert()
    if not is_enabled() then return false end
    if not C_MythicPlus.GetOwnedKeystoneLevel or not C_MythicPlus.GetOwnedKeystoneLevel() then return false end
    if not C_ChallengeMode.SlotKeystone or not C_ChallengeMode.HasSlottedKeystone then return false end
    if C_ChallengeMode.HasSlottedKeystone() then return true end
    if CursorHasItem and CursorHasItem() then return false end

    local bag, slot = find_keystone_in_bags()
    if not bag or not slot then return false end

    C_Container.PickupContainerItem(bag, slot)

    if CursorHasItem and CursorHasItem() then
        C_ChallengeMode.SlotKeystone()
        if C_ChallengeMode.HasSlottedKeystone() then
            return true
        end
        -- 삽입 실패 시 쐐기돌 원위치 (커서 아이템 잔류 방지)
        C_Container.PickupContainerItem(bag, slot)
        return false
    end

    return false
end

-- ==============================
-- 재시도 로직 (가비지 프리)
-- ==============================
local do_attempt

do_attempt = function()
    if current_token ~= retry_token then return end
    if not is_enabled() then return end
    if C_ChallengeMode.HasSlottedKeystone and C_ChallengeMode.HasSlottedKeystone() then return end

    if try_insert() then return end

    retry_remaining = retry_remaining - 1
    if retry_remaining > 0 then
        C_Timer.After(RETRY_INTERVAL, do_attempt)
    end
end

local function schedule_insert()
    if not is_enabled() then return end
    retry_token     = retry_token + 1
    current_token   = retry_token
    retry_remaining = RETRY_MAX
    do_attempt()
end

-- ==============================
-- 이벤트 핸들러
-- ==============================
local event_frame = CreateFrame("Frame")

local function on_event(self, event)
    if event == "CHALLENGE_MODE_KEYSTONE_RECEPTABLE_OPEN" then
        schedule_insert()
    elseif event == "CHALLENGE_MODE_KEYSTONE_SLOTTED" then
        retry_token = retry_token + 1
    end
end

event_frame:SetScript("OnEvent", on_event)

-- ==============================
-- 활성화 상태 제어
-- ==============================
local function update_visual()
    if is_enabled() then
        event_frame:RegisterEvent("CHALLENGE_MODE_KEYSTONE_RECEPTABLE_OPEN")
        event_frame:RegisterEvent("CHALLENGE_MODE_KEYSTONE_SLOTTED")
    else
        event_frame:UnregisterAllEvents()
        retry_token = retry_token + 1
    end
end

-- ==============================
-- 초기화
-- ==============================
local init_frame = CreateFrame("Frame")
init_frame:RegisterEvent("ADDON_LOADED")
init_frame:RegisterEvent("PLAYER_LOGIN")

local function on_init_event(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == addonName then
        dodoDB = dodoDB or {}
        if dodoDB.enableChallengesAutoInsert == nil then dodoDB.enableChallengesAutoInsert = true end
        self:UnregisterEvent("ADDON_LOADED")
    elseif event == "PLAYER_LOGIN" then
        update_visual()
        self:UnregisterEvent("PLAYER_LOGIN")
    end
end

init_frame:SetScript("OnEvent", on_init_event)

-- ==============================
-- 설정 등록
-- ==============================
dodo.OptionRegistrations = dodo.OptionRegistrations or {}
dodo.OptionRegistrations["인터페이스.편의기능"] = dodo.OptionRegistrations["인터페이스.편의기능"] or {}
table.insert(dodo.OptionRegistrations["인터페이스.편의기능"], function(category)
    Checkbox(category, "enableChallengesAutoInsert", "쐐기돌 자동 삽입", "쐐기돌 패널이 열릴 때 가방의 쐐기돌을 자동으로 슬롯에 삽입합니다.", true, update_visual)
end)
