-- ==============================
-- Inspired
-- ==============================
-- Raid Frame Anchor (https://www.curseforge.com/wow/addons/raid-frame-anchor)

-- ==============================
-- 설정 및 테이블
-- ==============================
---@diagnostic disable: lowercase-global, param-type-mismatch, redundant-parameter, undefined-field, undefined-global
local addonName, dodo = ...
dodoDB = dodoDB or {}

-- WoW 에디트모드 유닛프레임 특수 고유 ID 빌드 (안전 가드 적용)
local Enum_EditModeSystem_UnitFrame = (Enum and Enum.EditModeSystem and Enum.EditModeSystem.UnitFrame) or 3
local Enum_EditModeUnitFrameSystem_Raid = (Enum and Enum.EditModeUnitFrameSystem and Enum.EditModeUnitFrameSystem.Raid) or 4
local Enum_EditModeUnitFrameSystem_Party = (Enum and Enum.EditModeUnitFrameSystem and Enum.EditModeUnitFrameSystem.Party) or 3

local raid_system_id = string.format("%d_%d", Enum_EditModeSystem_UnitFrame, Enum_EditModeUnitFrameSystem_Raid)
local party_system_id = string.format("%d_%d", Enum_EditModeSystem_UnitFrame, Enum_EditModeUnitFrameSystem_Party)

local anchor_list = {
    { text = "좌측 상단", value = "TOPLEFT" },
    { text = "상단", value = "TOP" },
    { text = "우측 상단", value = "TOPRIGHT" },
    { text = "좌측", value = "LEFT" },
    { text = "중앙", value = "CENTER" },
    { text = "우측", value = "RIGHT" },
    { text = "좌측 하단", value = "BOTTOMLEFT" },
    { text = "하단", value = "BOTTOM" },
    { text = "우측 하단", value = "BOTTOMRIGHT" }
}

-- ==============================
-- 캐싱
-- ==============================
local CompactRaidFrameContainer = CompactRaidFrameContainer
local CreateFrame = CreateFrame
local EditModeManagerFrame = EditModeManagerFrame
local hooksecurefunc = hooksecurefunc
local InCombatLockdown = InCombatLockdown
local PartyFrame = PartyFrame
local print = print
local securecallmethod = securecallmethod

-- ==============================
-- 로컬 상태 및 설정
-- ==============================
local is_active = false
local refresh_queued = false
local init_frame = CreateFrame("Frame")

-- ==============================
-- 기능 1: 앵커 오프셋 수학적 보정 및 재설정 (Taint 방지 securecall 적용)
-- ==============================
local function check_combat_lockdown()
    if InCombatLockdown() then
        if not refresh_queued then
            print("dodo: 전투 종료 후 공격대 프레임 설정이 적용됩니다.")
            refresh_queued = true
        end
        return true
    end
    return false
end

local function update_anchor(frame, anchor_point)
    if not frame or not anchor_point then return end
    
    local point, relative_to, relative_point, x_offset, y_offset = frame:GetPoint(1)
    if not point then return end
    if point == anchor_point then
        return
    end
    
    if check_combat_lockdown() then
        return
    end

    local width, height = frame:GetSize()
    local new_x, new_y

    -- 1단계: 현재 임의의 앵커 기준 오프셋을 CENTER 기준 오프셋으로 역산
    if point == "CENTER" then
        new_x, new_y = x_offset, y_offset
    elseif point == "RIGHT" then
        new_x, new_y = x_offset - width / 2, y_offset
    elseif point == "TOPRIGHT" then
        new_x, new_y = x_offset - width / 2, y_offset - height / 2
    elseif point == "TOP" then
        new_x, new_y = x_offset, y_offset - height / 2
    elseif point == "TOPLEFT" then
        new_x, new_y = x_offset + width / 2, y_offset - height / 2
    elseif point == "LEFT" then
        new_x, new_y = x_offset + width / 2, y_offset
    elseif point == "BOTTOMLEFT" then
        new_x, new_y = x_offset + width / 2, y_offset + height / 2
    elseif point == "BOTTOM" then
        new_x, new_y = x_offset, y_offset + height / 2
    elseif point == "BOTTOMRIGHT" then
        new_x, new_y = x_offset - width / 2, y_offset + height / 2
    else
        return
    end

    -- 2단계: CENTER 오프셋으로부터 목표 앵커 기준 오프셋으로 변환
    if anchor_point == "CENTER" then
        -- 변환 없음
    elseif anchor_point == "RIGHT" then
        new_x = new_x + width / 2
    elseif anchor_point == "TOPRIGHT" then
        new_x, new_y = new_x + width / 2, new_y + height / 2
    elseif anchor_point == "TOP" then
        new_y = new_y + height / 2
    elseif anchor_point == "TOPLEFT" then
        new_x, new_y = new_x - width / 2, new_y + height / 2
    elseif anchor_point == "LEFT" then
        new_x = new_x - width / 2
    elseif anchor_point == "BOTTOMLEFT" then
        new_x, new_y = new_x - width / 2, new_y - height / 2
    elseif anchor_point == "BOTTOM" then
        new_y = new_y - height / 2
    elseif anchor_point == "BOTTOMRIGHT" then
        new_x, new_y = new_x + width / 2, new_y - height / 2
    else
        return
    end

    -- Taint 차단을 위한 securecallmethod 및 안전 적용
    securecallmethod(frame, "ClearAllPoints")
    securecallmethod(frame, "SetPoint", anchor_point, relative_to, relative_point, new_x, new_y)

    local updated = securecallmethod(EditModeManagerFrame, "UpdateSystemAnchorInfo", frame)
    if updated then
        securecallmethod(frame, "SetHasActiveChanges", true)
    end
end

-- ==============================
-- 기능 2: 훅 및 안전 가드 지점 정의
-- ==============================
local function on_drag_stop_raid()
    if not is_active then return end
    update_anchor(CompactRaidFrameContainer, dodoDB.raidAnchorPoint)
end

local function on_drag_stop_party()
    if not is_active then return end
    update_anchor(PartyFrame, dodoDB.partyAnchorPoint)
end

local function on_update_system_raid()
    if not is_active then return end
    update_anchor(CompactRaidFrameContainer, dodoDB.raidAnchorPoint)
end

local function on_update_system_party()
    if not is_active then return end
    update_anchor(PartyFrame, dodoDB.partyAnchorPoint)
end

local function on_combat_changed()
    if refresh_queued and not InCombatLockdown() then
        refresh_queued = false
        update_anchor(CompactRaidFrameContainer, dodoDB.raidAnchorPoint)
        update_anchor(PartyFrame, dodoDB.partyAnchorPoint)
    end
end

-- ==============================
-- 기능 3: 상태 업데이트 및 활성 제어
-- ==============================
local function update_visual()
    local is_enabled = (dodoDB and dodoDB.enableRaidFrameAnchor ~= false)
    is_active = is_enabled

    if is_enabled then
        if dodoDB.raidAnchorPoint == nil then
            dodoDB.raidAnchorPoint = CompactRaidFrameContainer:GetPoint(1) or "TOPLEFT"
        end
        if dodoDB.partyAnchorPoint == nil then
            dodoDB.partyAnchorPoint = PartyFrame:GetPoint(1) or "TOPLEFT"
        end

        init_frame:RegisterEvent("PLAYER_REGEN_ENABLED")
        
        update_anchor(CompactRaidFrameContainer, dodoDB.raidAnchorPoint)
        update_anchor(PartyFrame, dodoDB.partyAnchorPoint)
    else
        init_frame:UnregisterEvent("PLAYER_REGEN_ENABLED")
    end
end

-- ==============================
-- 이벤트 핸들러 및 초기화
-- ==============================
local function on_event(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == addonName then
        dodoDB = dodoDB or {}
        self:RegisterEvent("PLAYER_LOGIN")
        self:UnregisterEvent("ADDON_LOADED")
    elseif event == "PLAYER_LOGIN" then
        hooksecurefunc(CompactRaidFrameContainer, "OnDragStop", on_drag_stop_raid)
        hooksecurefunc(PartyFrame, "OnDragStop", on_drag_stop_party)
        hooksecurefunc(CompactRaidFrameContainer, "UpdateSystem", on_update_system_raid)
        hooksecurefunc(PartyFrame, "UpdateSystem", on_update_system_party)

        update_visual()
        self:UnregisterEvent("PLAYER_LOGIN")
    end
end

init_frame:RegisterEvent("ADDON_LOADED")
init_frame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" or event == "PLAYER_LOGIN" then
        on_event(self, event, ...)
    elseif event == "PLAYER_REGEN_ENABLED" then
        on_combat_changed()
    end
end)

-- ==============================
-- 설정 등록
-- ==============================
if dodo.RegisterEditModeModuleSetting then
    dodo.RegisterEditModeModuleSetting("인터페이스", {
        {
            name = "공격대/파티 프레임 성장방향",
            get = function() return dodoDB and dodoDB.enableRaidFrameAnchor ~= false end,
            set = function(checked)
                if dodoDB then dodoDB.enableRaidFrameAnchor = checked end
                update_visual()
            end
        }
    })
end

if dodo.RegisterEditModeSystemSetting then
    dodo.RegisterEditModeSystemSetting(raid_system_id, {
        {
            name = "프레임 성장방향",
            get = function() return dodoDB and dodoDB.enableRaidFrameAnchor ~= false end,
            set = function(checked)
                if dodoDB then dodoDB.enableRaidFrameAnchor = checked end
                update_visual()
            end
        },
        {
            name = "성장기준",
            type = "dropdown",
            get = function() return dodoDB.raidAnchorPoint or "TOPLEFT" end,
            set = function(val)
                if dodoDB then dodoDB.raidAnchorPoint = val end
                update_anchor(CompactRaidFrameContainer, val)
            end,
            values = anchor_list,
            disabled = function() return dodoDB and dodoDB.enableRaidFrameAnchor == false end
        }
    })

    dodo.RegisterEditModeSystemSetting(party_system_id, {
        {
            name = "프레임 성장방향",
            get = function() return dodoDB and dodoDB.enableRaidFrameAnchor ~= false end,
            set = function(checked)
                if dodoDB then dodoDB.enableRaidFrameAnchor = checked end
                update_visual()
            end
        },
        {
            name = "성장기준",
            type = "dropdown",
            get = function() return dodoDB.partyAnchorPoint or "TOPLEFT" end,
            set = function(val)
                if dodoDB then dodoDB.partyAnchorPoint = val end
                update_anchor(PartyFrame, val)
            end,
            values = anchor_list,
            disabled = function() return dodoDB and dodoDB.enableRaidFrameAnchor == false end
        }
    })
end
