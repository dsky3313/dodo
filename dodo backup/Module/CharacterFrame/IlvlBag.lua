-- ==============================
-- Inspired
-- ==============================
-- 

-- ==============================
-- 설정 및 테이블
-- ==============================
local addonName, dodo = ...
dodoDB = dodoDB or {}

local NUM_CONTAINER_FRAMES = NUM_CONTAINER_FRAMES or 13
local OUTLINE_FONT = dodo.OUTLINE_FONT

-- ==============================
-- 캐싱
-- ==============================
local C_Container = C_Container
local C_Item = C_Item
local ContainerFrameCombinedBags = ContainerFrameCombinedBags
local CreateFrame = CreateFrame
local hooksecurefunc = hooksecurefunc
local _G = _G

-- ==============================
-- 기능 1: 로컬 상태 및 설정
-- ==============================
local bag_slot_cache = {}

-- ==============================
-- 기능 2: 상태 업데이트
-- ==============================
-- 1. 각 가방 슬롯 버튼별 아이템 레벨 글자 객체 가져오거나 생성 (Lazy load)
local function get_or_create_bag_ilvl_fs(button)
    if not bag_slot_cache[button] then
        -- 프레임 레벨 겹침 방지를 위해 단독 컨테이너 생성
        local container = CreateFrame("Frame", nil, button)
        container:SetFrameLevel(button:GetFrameLevel() + 5)
        container:SetAllPoints(button)
        
        local fs = container:CreateFontString(nil, "OVERLAY")
        fs:SetFont(OUTLINE_FONT, 12, "OUTLINE")
        fs:SetPoint("TOPLEFT", 2, -2)
        fs:Hide()
        
        container.fs = fs
        bag_slot_cache[button] = container
    end
    return bag_slot_cache[button].fs
end

-- 2. 단일 가방 버튼의 아이템 레벨 갱신
local function update_bag_slot(button)
    if not button then return end

    -- 가방 및 슬롯 ID 안전 획득
    local bag_id, slot_id
    if button.GetBagID then
        bag_id = button:GetBagID()
        slot_id = button:GetID()
    else
        local parent = button:GetParent()
        if parent and parent.GetID then
            bag_id = parent:GetID()
            slot_id = button:GetID()
        end
    end
    if not bag_id or not slot_id then return end

    local ilvl_fs = get_or_create_bag_ilvl_fs(button)

    -- 애드온 전체 또는 가방 템렙 설정 비활성화 시 감추기 처리
    if dodoDB.enableCharacterFrame == false or not dodoDB.useItemLevel then
        ilvl_fs:Hide()
        return
    end

    -- 가방 정보 획득
    local info = C_Container.GetContainerItemInfo(bag_id, slot_id)
    if info and info.hyperlink then
        local _, _, quality, _, _, _, _, _, equipLoc, _, _, classID = C_Item.GetItemInfo(info.hyperlink)
        -- 장비(무기 = classID 2, 방어구 = classID 4) 유형 검사
        local is_equip = (classID == 2 or classID == 4) and equipLoc and equipLoc ~= "" and equipLoc ~= "INVTYPE_NON_EQUIP"

        if is_equip then
            local item_level = C_Item.GetDetailedItemLevelInfo(info.hyperlink)
            if item_level and item_level > 1 then
                -- 아이템 레벨 텍스트 지정 및 품질 색상 도포
                local r, g, b = C_Item.GetItemQualityColor(quality or 1)
                ilvl_fs:SetTextColor(r, g, b)
                ilvl_fs:SetText(item_level)
                ilvl_fs:Show()
                return
            end
        end
    end
    ilvl_fs:Hide()
end

-- 3. 가방 프레임에 소속된 모든 버튼 순회 갱신
local function update_bag_frame(frame)
    if not frame or not frame:IsShown() then return end
    if frame.EnumerateValidItems then
        for _, button in frame:EnumerateValidItems() do
            update_bag_slot(button)
        end
    end
end

-- 외부 호출용 함수 매핑
function dodo.UpdateCharacterFrameIlvlBag()
    for i = 1, NUM_CONTAINER_FRAMES do
        update_bag_frame(_G["ContainerFrame" .. i])
    end
    if ContainerFrameCombinedBags then
        update_bag_frame(ContainerFrameCombinedBags)
    end
end

-- ==============================
-- 이벤트 핸들러
-- ==============================
local function on_bag_update_items(self)
    if dodoDB.enableCharacterFrame == false or not dodoDB.useItemLevel then return end
    update_bag_frame(self)
end

-- 각 기본 가방 13개와 통합 가방에 훅 설치
for i = 1, NUM_CONTAINER_FRAMES do
    local cf = _G["ContainerFrame" .. i]
    if cf then
        hooksecurefunc(cf, "UpdateItems", on_bag_update_items)
    end
end
if ContainerFrameCombinedBags then
    hooksecurefunc(ContainerFrameCombinedBags, "UpdateItems", on_bag_update_items)
end
