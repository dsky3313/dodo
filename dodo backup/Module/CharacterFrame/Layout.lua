-- ==============================
-- Inspired
-- ==============================
-- Fex (https://www.curseforge.com/wow/addons/fex)

-- ==============================
-- 설정 및 테이블
-- ==============================
local addonName, dodo = ...
dodoDB = dodoDB or {}
dodo.DB = dodo.DB or dodoDB

local EXTENDED_WIDTH  = 650
local STANDARD_WIDTH  = 448
local SIDEBAR_SPACE   = 206

-- ==============================
-- 캐싱
-- ==============================
local CharacterFrame = CharacterFrame
local CharacterFrameInset = CharacterFrameInset
local CharacterHeadSlot = CharacterHeadSlot
local CharacterMainHandSlot = CharacterMainHandSlot
local CharacterModelScene = CharacterModelScene
local CharacterSecondaryHandSlot = CharacterSecondaryHandSlot
local CharacterTrinket1Slot = CharacterTrinket1Slot
local hooksecurefunc = hooksecurefunc
local ipairs = ipairs
local PaperDollFrame = PaperDollFrame
local PaperDollItemsFrame = PaperDollItemsFrame
local _G = _G

-- ==============================
-- 기능 1: 로컬 상태 및 설정
-- ==============================
local saved_original_height = nil
local saved_main_hand_anchor = nil
local saved_secondary_hand_anchor = nil

-- 앵커 백업 도우미 함수
local function backup_slot_anchors()
    if saved_main_hand_anchor or not CharacterMainHandSlot then return end

    local point, relativeTo, relativePoint, xOfs, yOfs = CharacterMainHandSlot:GetPoint(1)
    if point then
        saved_main_hand_anchor = {
            point = point,
            relativeTo = relativeTo,
            relativePoint = relativePoint,
            xOfs = xOfs,
            yOfs = yOfs
        }
    end

    if CharacterSecondaryHandSlot then
        local p, rt, rp, x, y = CharacterSecondaryHandSlot:GetPoint(1)
        if p then
            saved_secondary_hand_anchor = {
                point = p,
                relativeTo = rt,
                relativePoint = rp,
                xOfs = x,
                yOfs = y
            }
        end
    end
end

-- ==============================
-- 기능 2: 상태 업데이트
-- ==============================
-- 1. 장비창 기본 배경 투명화
function dodo.HideCharacterFrameBackgrounds()
    if dodoDB.enableCharacterFrame == false then return end

    local textures = {
        "CharacterModelFrameBackgroundOverlay",
        "CharacterModelFrameBackgroundTopLeft",
        "CharacterModelFrameBackgroundTopRight",
        "CharacterModelFrameBackgroundBotLeft",
        "CharacterModelFrameBackgroundBotRight",
    }
    for _, name in ipairs(textures) do
        local tex = _G[name]
        if tex then 
            tex:SetAlpha(0)
            if tex.Hide then tex:Hide() end
        end
    end
end

-- 2. 확장 상태 해제 및 원상 복구 (구버전 스펙 100% 복제 - 단순 크기 복구만 수행)
local function disable_extended_layout(force_reset)
    if not CharacterFrame then return end

    -- 마스터 토글(enableCharacterFrame)이 꺼져있을 때는
    -- 외부 복원 지시(force_reset)가 아닌 한 훅 개입 방지 즉시 리턴
    local is_module_active = (dodoDB.enableCharacterFrame ~= false)
    if not is_module_active and not force_reset then
        return
    end

    -- 프레임 너비 무조건 448 순정 기본 복구
    CharacterFrame:SetWidth(STANDARD_WIDTH)
    if saved_original_height then
        CharacterFrame:SetHeight(saved_original_height)
    end

    -- 순정 상세창 접힘 상태로 완전히 동기화
    if CharacterFrame.Collapse and CharacterFrame.Expanded then
        CharacterFrame:Collapse()
    end

    -- CharacterFrameInset 앵커를 순정 기본(접힘) 상태로 완벽히 복구
    CharacterFrameInset:ClearAllPoints()
    CharacterFrameInset:SetPoint("TOPLEFT", CharacterFrame, "TOPLEFT", 4, -60)
    CharacterFrameInset:SetPoint("BOTTOMRIGHT", CharacterFrame, "BOTTOMRIGHT", -4, 4)

    -- 주장비 및 보조장비 슬롯 순정 복구 (백업된 원래 앵커로 완벽 롤백)
    if CharacterMainHandSlot then
        CharacterMainHandSlot:ClearAllPoints()
        if saved_main_hand_anchor then
            CharacterMainHandSlot:SetPoint(
                saved_main_hand_anchor.point,
                saved_main_hand_anchor.relativeTo,
                saved_main_hand_anchor.relativePoint,
                saved_main_hand_anchor.xOfs,
                saved_main_hand_anchor.yOfs
            )
        else
            CharacterMainHandSlot:SetPoint("BOTTOMLEFT", PaperDollItemsFrame, "BOTTOMLEFT", 120, 14)
        end
    end
    if CharacterSecondaryHandSlot then
        CharacterSecondaryHandSlot:ClearAllPoints()
        if saved_secondary_hand_anchor then
            CharacterSecondaryHandSlot:SetPoint(
                saved_secondary_hand_anchor.point,
                saved_secondary_hand_anchor.relativeTo,
                saved_secondary_hand_anchor.relativePoint,
                saved_secondary_hand_anchor.xOfs,
                saved_secondary_hand_anchor.yOfs
            )
        else
            CharacterSecondaryHandSlot:SetPoint("BOTTOMLEFT", CharacterMainHandSlot, "BOTTOMRIGHT", 5, 0)
        end
    end

    -- 3D 캐릭터 모델 씬 앵커 순정 복구
    if CharacterModelScene then
        CharacterModelScene:ClearAllPoints()
        CharacterModelScene:SetPoint("TOPLEFT", CharacterFrameInset, "TOPLEFT", 4, -4)
        CharacterModelScene:SetPoint("BOTTOMRIGHT", CharacterFrameInset, "BOTTOMRIGHT", -4, 4)
    end
end

dodo.ResetCharacterFrameLayout = function()
    disable_extended_layout(true)
end

-- 3. 광폭 레이아웃 전환 (구버전 앵커 연산 스펙 100% 대조 복원)
local function enable_extended_layout()
    if not PaperDollFrame or not PaperDollFrame:IsShown() then return end
    
    -- 마스터 토글이 꺼져있으면 개입 방지 즉시 리턴
    if dodoDB.enableCharacterFrame == false then
        return
    end

    -- 원본 슬롯 앵커 백업
    backup_slot_anchors()

    -- 원본 프레임 높이 기록 백업
    if not saved_original_height then
        saved_original_height = CharacterFrame:GetHeight()
    end
    
    -- 광폭 너비 전개
    CharacterFrame:SetWidth(EXTENDED_WIDTH)
    
    -- 우측 206px 영역을 스탯 정보 패널용으로 확보하고, 인셋은 원래 444 그대로 배치하는 구버전 앵커 복원
    CharacterFrameInset:ClearAllPoints()
    CharacterFrameInset:SetPoint("TOPLEFT", CharacterFrame, "TOPLEFT", 4, -60)
    CharacterFrameInset:SetPoint("BOTTOMRIGHT", CharacterFrame, "BOTTOMLEFT", EXTENDED_WIDTH - SIDEBAR_SPACE, 4)

    -- 주장비 및 보조장비 슬롯 정렬 (구버전 185 복원)
    if CharacterMainHandSlot then
        CharacterMainHandSlot:SetPoint("BOTTOMLEFT", PaperDollItemsFrame, "BOTTOMLEFT", 185, 14)
    end
    if CharacterSecondaryHandSlot then
        CharacterSecondaryHandSlot:SetPoint("BOTTOMLEFT", CharacterMainHandSlot, "BOTTOMRIGHT", 5, 0)
    end

    -- 3D 모델 Scene 정밀 확대 배치
    if CharacterModelScene then
        local head_slot = CharacterHeadSlot
        local trinket_slot = CharacterTrinket1Slot
        if head_slot and trinket_slot then
            CharacterModelScene:ClearAllPoints()
            CharacterModelScene:SetPoint("TOPLEFT", head_slot, "TOPRIGHT", 0, -4)
            CharacterModelScene:SetPoint("BOTTOMRIGHT", trinket_slot, "BOTTOMLEFT", 0, 0)
        end
    end
end

dodo.UpdateCharacterFrameLayout = enable_extended_layout

-- 4. 설정 UI 제어 외부 콜백 (구버전 스펙 100% 동일하게 연동)
dodo.EnhancedCharFrame = function(value)
    if value then
        enable_extended_layout()
    else
        disable_extended_layout(true)
    end
    if dodo.UpdateAllCharacterSlots then
        dodo.UpdateAllCharacterSlots()
    end
end

-- ==============================
-- 이벤트 핸들러
-- ==============================
local function on_show_character_frame()
    dodo.HideCharacterFrameBackgrounds()
    enable_extended_layout()
end

CharacterFrame:HookScript("OnShow", on_show_character_frame)

hooksecurefunc(CharacterFrame, "Expand", enable_extended_layout)
hooksecurefunc(CharacterFrame, "UpdateSize", enable_extended_layout)
hooksecurefunc(CharacterFrame, "Collapse", disable_extended_layout)
