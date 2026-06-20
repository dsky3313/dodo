-- ==============================
-- Inspired
-- ==============================
-- Enhance QoL (https://www.curseforge.com/wow/addons/eqol)

-- ==============================
-- 설정 및 테이블
-- ==============================
---@diagnostic disable: lowercase-global, param-type-mismatch, redundant-parameter, undefined-field, undefined-global
local addonName, dodo = ...
dodoDB = dodoDB or {}

-- ==============================
-- 캐싱
-- ==============================
local AuraUtil = AuraUtil
local C_MountJournal = C_MountJournal
local format = string.format
local IsMounted = IsMounted
local issecrettable = issecrettable
local issecretvalue = issecretvalue
local TooltipDataProcessor = TooltipDataProcessor
local UnitExists = UnitExists
local UnitGUID = UnitGUID
local UnitIsPlayer = UnitIsPlayer
local UnitTokenFromGUID = UnitTokenFromGUID

local function is_secret(v)
    if not issecretvalue or not issecrettable then return false end
    return issecretvalue(v) or issecrettable(v)
end

-- ==============================
-- 로컬 상태 및 유틸리티
-- ==============================
local found_mount_name, found_mount_icon

local function on_mount_aura_check(aura)
    local spell_id = aura and aura.spellId
    if spell_id and not is_secret(spell_id) then
        local mount_id = C_MountJournal.GetMountFromSpell(spell_id)
        if mount_id then
            local name, _, icon = C_MountJournal.GetMountInfoByID(mount_id)
            if name and name ~= "" then
                found_mount_name, found_mount_icon = name, icon
                return true -- 순회 중단
            end
        end
    end
end

local function get_mount_info(unit)
    if not unit or not UnitIsPlayer(unit) then return end
    if unit == "player" and not IsMounted() then return end
    
    found_mount_name, found_mount_icon = nil, nil
    AuraUtil.ForEachAura(unit, "HELPFUL", nil, on_mount_aura_check, true)
    return found_mount_name, found_mount_icon
end

-- ==============================
-- 콜백 핸들러
-- ==============================
local function on_unit_tooltip(self, data)
    if dodoDB.enableTooltip == false or dodoDB.useTooltipMount == false then return end
    if not data or is_secret(data) then return end
    
    local guid = data.guid
    if not guid or is_secret(guid) then return end
    
    local unit = UnitTokenFromGUID(guid)
    if not unit and UnitGUID("mouseover") == guid then
        unit = "mouseover"
    end
    
    if not unit or not UnitExists(unit) or is_secret(unit) then return end

    if UnitIsPlayer(unit) then
        local mount_name, mount_icon = get_mount_info(unit)
        if mount_name then
            local icon_text = mount_icon and format("|T%d:14:14:0:0|t ", mount_icon) or ""
            self:AddDoubleLine("|cffffd200탈것|r", icon_text .. mount_name)
        end
    end
end

-- ==============================
-- 초기화
-- ==============================
local function initialize()
    if dodoDB.useTooltipMount == nil then dodoDB.useTooltipMount = true end

    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, on_unit_tooltip)
end

local function on_event(self)
    initialize()
    self:UnregisterEvent("PLAYER_LOGIN")
end

local init_frame = CreateFrame("Frame")
init_frame:RegisterEvent("PLAYER_LOGIN")
init_frame:SetScript("OnEvent", on_event)

-- ==============================
-- 설정 등록
-- ==============================
if dodo.RegisterEditModeSystemSetting then
    dodo.RegisterEditModeSystemSetting(Enum.EditModeSystem.HudTooltip, {
        {
            name = "탈것 정보 표시",
            get = function() return dodoDB and dodoDB.useTooltipMount ~= false end,
            set = function(checked)
                if dodoDB then dodoDB.useTooltipMount = checked end
                update_vehicle()
            end,
            disabled = function() return dodoDB and dodoDB.enableTooltip == false end,
        }
    })
end