-- ==============================
-- Inspired
-- ==============================
-- EllesmereUIAuraBuffReminders (공격대 버프 리마인더)

-- ==============================
-- 설정 및 테이블
-- ==============================
---@diagnostic disable: lowercase-global, param-type-mismatch, redundant-parameter, undefined-field, undefined-global
local addonName, dodo = ...
local LibIcon = dodo.LibIcon
dodoDB = dodoDB or {}

local Config = {
    defaultX = 0,
    defaultY = 220,
    iconsize = {36, 36},
}

---@class RaidBuffData
---@field name string 버프 이름
---@field castSpell number 시전 주문ID
---@field buffIDs number[] 버프(오라) 주문ID 목록

---@type table<string, RaidBuffData>
local RAID_BUFFS = {
    DRUID   = { name = "야생의 징표", castSpell = 1126,   buffIDs = {1126, 432661} },
    WARRIOR = { name = "전투의 함성", castSpell = 6673,   buffIDs = {6673} },
    PRIEST  = { name = "인내의 권능", castSpell = 21562,  buffIDs = {21562} },
    MAGE    = { name = "신비한 지능", castSpell = 1459,   buffIDs = {1459, 432778} },
    EVOKER  = { name = "청동의 축복", castSpell = 364342,
        buffIDs = {381732,381741,381746,381748,381749,381750,381751,381752,381753,381754,381756,381757,381758} },
    SHAMAN  = { name = "천공의 분노", castSpell = 462854, buffIDs = {462854} },
}

-- ==============================
-- 캐싱
-- ==============================
local C_SpellBook = C_SpellBook
local C_Timer = C_Timer
local CheckInteractDistance = CheckInteractDistance
local CreateFrame = CreateFrame
local GetNumSubgroupMembers = GetNumSubgroupMembers
local GetPlayerAuraBySpellID = C_UnitAuras.GetPlayerAuraBySpellID
local GetUnitAuraBySpellID = C_UnitAuras.GetUnitAuraBySpellID
local InCombatLockdown = InCombatLockdown
local IsInGroup = IsInGroup
local IsInRaid = IsInRaid
local pcall = pcall
local UIParent = UIParent
local UnitClass = UnitClass
local UnitExists = UnitExists
local UnitIsConnected = UnitIsConnected
local UnitIsDeadOrGhost = UnitIsDeadOrGhost
local UnitIsPlayer = UnitIsPlayer

-- ==============================
-- 기능 1: 로컬 상태 및 설정
-- ==============================
local icon = nil
local icon_container = nil -- 시큐어 액션버튼(icon)은 전투중 Show/Hide 보호됨 - 비보안 컨테이너로 표시 제어
local buff_data = nil -- RAID_BUFFS[플레이어 클래스], 없으면 nil
local ticker_obj = nil -- 파티원 버프 확인용 ticker

-- ==============================
-- 기능 2: 상태 업데이트
-- ==============================
local function update_position()
    if not icon_container then return end
    local anchorFrame = dodo.EditMode and dodo.EditMode:GetSystem("RaidBuff")
    icon_container:ClearAllPoints()
    if anchorFrame then
        icon_container:SetPoint("CENTER", anchorFrame, "CENTER", 0, 0)
    else
        icon_container:SetPoint("CENTER", UIParent, "CENTER", Config.defaultX, Config.defaultY)
    end
end

local function is_known(spellID)
    return spellID and (C_SpellBook.IsSpellKnown(spellID) or C_SpellBook.IsSpellInSpellBook(spellID))
end

local function has_own_buff()
    local ids = buff_data.buffIDs
    for i = 1, #ids do
        if GetPlayerAuraBySpellID(ids[i]) then return true end
    end
    return false
end

local function unit_ok(u)
    return UnitExists(u) and UnitIsConnected(u) and not UnitIsDeadOrGhost(u) and UnitIsPlayer(u)
end

local function unit_in_range(u)
    if InCombatLockdown() then return true end -- 전투 중 CheckInteractDistance 보호됨
    local ok, result = pcall(CheckInteractDistance, u, 4)
    return ok and result == true
end

local function unit_has_buff(u, ids)
    for i = 1, #ids do
        if GetUnitAuraBySpellID(u, ids[i]) then return true end
    end
    return false
end

local function any_party_member_missing()
    local ids = buff_data.buffIDs
    for i = 1, GetNumSubgroupMembers() do
        local u = "party" .. i
        if unit_ok(u) and unit_in_range(u) and not unit_has_buff(u, ids) then
            return true
        end
    end
    return false
end

local function refresh()
    if not (icon_container and buff_data) then return end
    if not is_known(buff_data.castSpell) then
        icon_container:Execute([[ self:Hide() ]])
        return
    end
    local missing = not has_own_buff()
    if not missing and dodoDB and dodoDB.useRaidBuffPartyCheck ~= false
       and IsInGroup() and not IsInRaid() then
        missing = any_party_member_missing()
    end
    if missing then
        icon_container:Execute([[ self:Show() ]])
    else
        icon_container:Execute([[ self:Hide() ]])
    end
end

-- ==============================
-- 기능 3: UI 생성
-- ==============================
local function create_icon()
    if icon then return end
    icon_container = CreateFrame("Frame", "dodoRaidBuffIconContainer", UIParent, "SecureHandlerBaseTemplate")
    icon_container:SetSize(Config.iconsize[1], Config.iconsize[2])
    icon = LibIcon:Create("dodoRaidBuffIcon", icon_container, { isAction = true, iconsize = Config.iconsize })
    icon:SetAllPoints(icon_container)
    icon:ApplyConfig({ type = "spell", id = buff_data.castSpell, isAction = true, useTooltip = true })
    update_position()
end

-- ==============================
-- 모듈 On/Off 제어
-- ==============================
local init_frame = CreateFrame("Frame")

local function update_party_ticker()
    local need_ticker = (dodoDB and dodoDB.enableRaidBuff ~= false)
        and (dodoDB and dodoDB.useRaidBuffPartyCheck ~= false)
        and buff_data ~= nil and IsInGroup() and not IsInRaid()
    if need_ticker then
        if not ticker_obj then
            ticker_obj = C_Timer.NewTicker(2, refresh)
        end
    else
        if ticker_obj then
            ticker_obj:Cancel()
            ticker_obj = nil
        end
    end
end

local function update_module_state()
    local isEnabled = (dodoDB and dodoDB.enableRaidBuff ~= false) and buff_data ~= nil
    if isEnabled then
        create_icon()
        update_position()
        init_frame:RegisterEvent("UNIT_AURA")
        init_frame:RegisterEvent("GROUP_ROSTER_UPDATE")
        update_party_ticker()
        refresh()
    else
        if icon_container then icon_container:Execute([[ self:Hide() ]]) end
        init_frame:UnregisterEvent("UNIT_AURA")
        init_frame:UnregisterEvent("GROUP_ROSTER_UPDATE")
        if ticker_obj then
            ticker_obj:Cancel()
            ticker_obj = nil
        end
    end
end

-- ==============================
-- 이벤트 핸들러
-- ==============================
local function on_event(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == addonName then
        dodoDB = dodoDB or {}
        if dodoDB.enableRaidBuff == nil then dodoDB.enableRaidBuff = true end
        if dodoDB.useRaidBuffPartyCheck == nil then dodoDB.useRaidBuffPartyCheck = true end
    elseif event == "PLAYER_LOGIN" then
        local _, class = UnitClass("player")
        buff_data = RAID_BUFFS[class]
        if dodo.EditMode then
            dodo.EditMode:CreateSystem("RaidBuff", "공격대 버프", "공격대 버프 미보유 알림", UIParent,
                Config.iconsize[1], Config.iconsize[2],
                { point = "CENTER", relativeTo = "UIParent", relativePoint = "CENTER", xOfs = Config.defaultX, yOfs = Config.defaultY },
                nil, function() return dodoDB and dodoDB.enableRaidBuff ~= false end)
        end
        update_module_state()
        self:UnregisterEvent("PLAYER_LOGIN")
    elseif event == "PLAYER_ENTERING_WORLD" then
        update_position()
        refresh()
    elseif event == "UNIT_AURA" then
        if arg1 == "player" then refresh() end
    elseif event == "GROUP_ROSTER_UPDATE" then
        update_party_ticker()
        refresh()
    end
end

init_frame:RegisterEvent("ADDON_LOADED")
init_frame:RegisterEvent("PLAYER_LOGIN")
init_frame:RegisterEvent("PLAYER_ENTERING_WORLD")
init_frame:SetScript("OnEvent", on_event)

-- ==============================
-- 설정 등록
-- ==============================
if dodo.RegisterEditModeModuleSetting then
    dodo.RegisterEditModeModuleSetting("편의기능", {
        {
            name = "공격대 버프 알림",
            get = function() return dodoDB and dodoDB.enableRaidBuff ~= false end,
            set = function(checked)
                if dodoDB then dodoDB.enableRaidBuff = checked end
                update_module_state()
            end
        }
    })
end

if dodo.RegisterEditModeSystemSetting then
    dodo.RegisterEditModeSystemSetting("RaidBuff", {
        {
            name = "파티원 버프 확인",
            get = function() return dodoDB and dodoDB.useRaidBuffPartyCheck ~= false end,
            set = function(checked)
                if dodoDB then dodoDB.useRaidBuffPartyCheck = checked end
                update_party_ticker()
                refresh()
            end,
            disabled = function() return dodoDB and dodoDB.enableRaidBuff == false end,
        }
    })
end
