-- ==============================
-- Inspired
-- ==============================
-- EnemyNameplateColors v1.2.0 (Zerkggz)

-- ==============================
-- 설정 및 테이블
-- ==============================
---@diagnostic disable: lowercase-global, param-type-mismatch, redundant-parameter, undefined-field, undefined-global
local addonName, dodo = ...
dodoDB = dodoDB or {}

local interrupt_map = {
    DEATHKNIGHT = { 47528 },
    DEMONHUNTER = { 183752 },
    DRUID       = { 78675, 106839 },
    EVOKER      = { 351338 },
    HUNTER      = { 187707, 147362 },
    MAGE        = { 2139 },
    MONK        = { 116705 },
    PALADIN     = { 96231 },
    PRIEST      = { 15487 },
    ROGUE       = { 1766 },
    SHAMAN      = { 57994 },
    WARLOCK     = { 19647, 89766, 119910, 119914, 132409 },
    WARRIOR     = { 6552 },
}

-- ==============================
-- 캐싱
-- ==============================
local C_NamePlate            = C_NamePlate
local C_SpellBook            = C_SpellBook
local CreateFrame            = CreateFrame
local GetNumGroupMembers     = GetNumGroupMembers
local GetSpecialization      = GetSpecialization
local GetSpecializationRole  = GetSpecializationRole
local InCombatLockdown       = InCombatLockdown
local IsInRaid               = IsInRaid
local ipairs                 = ipairs
local UnitClassBase          = UnitClassBase
local UnitClassification     = UnitClassification
local UnitEffectiveLevel     = UnitEffectiveLevel
local UnitExists             = UnitExists
local UnitGroupRolesAssigned = UnitGroupRolesAssigned
local UnitIsBossMob          = UnitIsBossMob
local UnitIsLieutenant       = UnitIsLieutenant
local UnitIsUnit             = UnitIsUnit
local UnitPowerType          = UnitPowerType
local UnitThreatSituation    = UnitThreatSituation
local wipe                   = wipe

-- ==============================
-- 공유 네임스페이스
-- ==============================
dodo.NamePlate = dodo.NamePlate or {}
local NP = dodo.NamePlate

NP.in_instance      = false
NP.player_in_combat = false
NP.other_tanks      = {}
NP.interrupt_spells = {}
NP.neutral_cache    = {}

-- 서브모듈이 등록하는 이벤트 활성/비활성 콜백
NP.sub_enable  = {}  -- { fn, fn, ... }
NP.sub_disable = {}

local function call_subs(tbl)
    for _, fn in ipairs(tbl) do fn() end
end

-- ==============================
-- 유틸 함수
-- ==============================
function NP.update_instance_status()
    if not dodoDB or not dodoDB.enableNameplate then
        NP.in_instance = false
        return
    end
    NP.in_instance = true
end

function NP.get_unit_type(unit)
    if not unit then return "standard" end

    local cls = UnitClassification(unit)
    if cls == "worldboss" then return "boss" end
    if cls == "rare"      then return "miniBoss" end

    local uLevel = UnitEffectiveLevel(unit)
    local pLevel = UnitEffectiveLevel("player")

    if uLevel == -1 or uLevel == pLevel + 2 then return "boss" end

    if uLevel == pLevel + 1
       or (UnitIsBossMob     and UnitIsBossMob(unit))
       or (UnitIsLieutenant  and UnitIsLieutenant(unit)) then
        return "miniBoss"
    end

    local classBase = UnitClassBase(unit)
    if (not issecretvalue(classBase) and classBase == "PALADIN")
       or UnitPowerType(unit) == Enum.PowerType.Mana then
        return "caster"
    end

    return "standard"
end

function NP.get_threat_status(unit)
    local status = UnitThreatSituation("player", unit)
    if status == nil then return nil end
    if     status >= 3 then return 3
    elseif status >= 2 then return 2
    elseif status >= 1 then return 1
    else                    return 0
    end
end

function NP.is_player_tank()
    local spec = GetSpecialization()
    return spec and GetSpecializationRole(spec) == "TANK"
end

function NP.update_other_tanks()
    wipe(NP.other_tanks)
    local prefix = IsInRaid() and "raid" or "party"
    for i = 1, GetNumGroupMembers() do
        local u = prefix .. i
        if UnitExists(u) and not UnitIsUnit(u, "player")
           and UnitGroupRolesAssigned(u) == "TANK" then
            NP.other_tanks[#NP.other_tanks + 1] = u
        end
    end
end

function NP.is_being_tanked_by_other(unit)
    for _, tank in ipairs(NP.other_tanks) do
        if UnitExists(tank) then
            local s = UnitThreatSituation(tank, unit)
            if s and s >= 2 then return true end
        end
    end
    return false
end

function NP.update_interrupt_spells()
    local class = UnitClassBase("player")
    NP.interrupt_spells = {}
    for _, spellID in ipairs(interrupt_map[class] or {}) do
        if C_SpellBook and C_SpellBook.IsSpellKnownOrInSpellBook then
            if C_SpellBook.IsSpellKnownOrInSpellBook(spellID)
               or C_SpellBook.IsSpellKnownOrInSpellBook(spellID, Enum.SpellBookSpellBank.Pet) then
                NP.interrupt_spells[#NP.interrupt_spells + 1] = spellID
            end
        end
    end
end

-- ==============================
-- DB 초기화
-- ==============================
local function init_db()
    local db = dodoDB
    local function def(key, val)
        if db[key] == nil then db[key] = val end
    end
    local function def_hex(key, c)
        local v = db[key]
        if type(v) == "table" then
            db[key] = string.format("ff%02x%02x%02x", v.r * 255, v.g * 255, v.b * 255)
        elseif not v then
            db[key] = c.hex
        end
    end
    local function def_rgba(key, c, a)
        if not db[key] then db[key] = { r = c.r, g = c.g, b = c.b, a = a or 1.0 } end
    end

    def("enableNameplate",             true)
    def("nameplateHealthColor",        true)
    def("nameplateTankThreatEnabled",  true)
    def("nameplateDpsThreatEnabled",   true)
    def("nameplateFocusColor",         false)
    def("nameplateFocusTexture",       false)
    def("nameplateCastBarColor",       false)
    def("nameplateInterruptBorder",    true)
    def("nameplateDispelGlow",         true)

    local C  = dodo.Colors.NamePlate
    local Cp = dodo.Colors.Primary
    local Ce = dodo.Colors.ETC

    def_hex ("nameplateColorBoss",             C.Boss)
    def_hex ("nameplateColorMiniBoss",         C.MiniBoss)
    def_hex ("nameplateColorCaster",           C.Caster)
    def_hex ("nameplateColorStandard",         C.Standard)
    def_hex ("nameplateColorTankHasThreat",    Cp.Green)
    def_hex ("nameplateColorTankLosingThreat", Cp.Orange)
    def_hex ("nameplateColorTankNoThreat",     Cp.Red)
    def_hex ("nameplateColorTankOnOtherTank",  C.TankOnOtherTank)
    def_hex ("nameplateColorDpsHasThreat",     Cp.Red)
    def_hex ("nameplateColorDpsGainingThreat", Cp.Orange)
    def_hex ("nameplateColorDpsNoThreat",      Ce.SoftGreen)
    def_rgba("nameplateColorFocus",            C.Focus,               1.0)
    def_rgba("nameplateCastBarStandard",       C.CastStandard,        1.0)
    def_rgba("nameplateCastBarUninterruptible",C.CastUninterruptible, 1.0)
    def_rgba("nameplateCastBarChannel",        Cp.Green,              1.0)
    def_rgba("nameplateCastBarImportant",      C.CastImportant,       1.0)
    def_rgba("nameplateCastBarInterruptReady", Cp.Green,              1.0)
    def_rgb ("nameplateColorDispelGlow",       C.DispelGlow)
end

-- ==============================
-- 이벤트
-- ==============================
local init_frame = CreateFrame("Frame")

local function on_event(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == addonName then
        dodoDB = dodoDB or {}
        init_db()
    elseif event == "PLAYER_LOGIN" then
        NP.player_in_combat = InCombatLockdown()
        NP.update_instance_status()
        NP.update_other_tanks()
        NP.update_interrupt_spells()
        if dodoDB and dodoDB.enableNameplate then
            call_subs(NP.sub_enable)
        end
        self:UnregisterEvent("PLAYER_LOGIN")
    elseif event == "PLAYER_ENTERING_WORLD" then
        NP.update_instance_status()
        NP.update_other_tanks()
        if NP.update_all_nameplates then NP.update_all_nameplates() end
    elseif event == "GROUP_ROSTER_UPDATE" then
        NP.update_other_tanks()
        if NP.update_all_nameplates then NP.update_all_nameplates() end
    elseif event == "SPELLS_CHANGED" then
        NP.update_interrupt_spells()
    elseif event == "PLAYER_REGEN_DISABLED" then
        NP.player_in_combat = true
    elseif event == "PLAYER_REGEN_ENABLED" then
        NP.player_in_combat = false
    elseif event == "NAME_PLATE_UNIT_REMOVED" then
        NP.neutral_cache[arg1] = nil
    end
end

init_frame:RegisterEvent("ADDON_LOADED")
init_frame:RegisterEvent("PLAYER_LOGIN")
init_frame:RegisterEvent("PLAYER_ENTERING_WORLD")
init_frame:RegisterEvent("GROUP_ROSTER_UPDATE")
init_frame:RegisterEvent("SPELLS_CHANGED")
init_frame:RegisterEvent("PLAYER_REGEN_DISABLED")
init_frame:RegisterEvent("PLAYER_REGEN_ENABLED")
init_frame:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
init_frame:SetScript("OnEvent", on_event)

-- ==============================
-- 설정 등록
-- ==============================
local Checkbox      = Checkbox
local ColorRow      = ColorRow
local SectionHeader = SectionHeader
dodo.OptionRegistrations = dodo.OptionRegistrations or {}
dodo.OptionRegistrations["이름표"] = dodo.OptionRegistrations["이름표"] or {}
table.insert(dodo.OptionRegistrations["이름표"], function(category)
    local function update_np()
        NP.update_instance_status()
        if NP.update_all_nameplates then NP.update_all_nameplates() end
    end
    local function on_master_change(checked)
        NP.update_instance_status()
        if checked then call_subs(NP.sub_enable) else call_subs(NP.sub_disable) end
        if NP.update_all_nameplates then NP.update_all_nameplates() end
    end

    -- 마스터 토글
    dodo.UI:SettingsCheckbox(category, "enableNameplate", "이름표 색상 변경", "유닛 종류·위협에 따라 적 네임플레이트 체력바 색상을 변경합니다.", true, on_master_change)

    local C  = dodo.Colors.NamePlate
    local Cp = dodo.Colors.Primary
    local Ce = dodo.Colors.ETC

    -- 유닛 색상 섹션
    dodo.UI:SettingsSectionHeader(category, "유닛 색상")
    dodo.UI:SettingsCheckbox(category, "nameplateHealthColor", "유닛 색상 적용", "", true, update_np)
    dodo.UI:SettingsColorRow(category, "nameplateColorBoss",     "  보스",    "", C.Boss.hex,             update_np)
    dodo.UI:SettingsColorRow(category, "nameplateColorMiniBoss", "  미니보스", "", C.MiniBoss.hex,         update_np)
    dodo.UI:SettingsColorRow(category, "nameplateColorCaster",   "  캐스터",  "", C.Caster.hex,           update_np)
    dodo.UI:SettingsColorRow(category, "nameplateColorStandard", "  일반",    "", C.Standard.hex,         update_np)

    -- 위협 색상 (탱커) 섹션
    dodo.UI:SettingsSectionHeader(category, "위협 색상 (탱커)")
    dodo.UI:SettingsCheckbox(category, "nameplateTankThreatEnabled", "탱커 위협 색상 적용", "", true, update_np)
    dodo.UI:SettingsColorRow(category, "nameplateColorTankHasThreat",   "  어그로 있음",      "", Cp.Green.hex,          update_np)
    dodo.UI:SettingsColorRow(category, "nameplateColorTankLosingThreat","  어그로 낮음",      "", Cp.Orange.hex,         update_np)
    dodo.UI:SettingsColorRow(category, "nameplateColorTankNoThreat",    "  어그로 없음",      "", Cp.Red.hex,            update_np)
    dodo.UI:SettingsColorRow(category, "nameplateColorTankOnOtherTank", "  다른 탱커 어그로", "", C.TankOnOtherTank.hex, update_np)

    -- 위협 색상 (딜러/힐러) 섹션
    dodo.UI:SettingsSectionHeader(category, "위협 색상 (딜러/힐러)")
    dodo.UI:SettingsCheckbox(category, "nameplateDpsThreatEnabled", "딜힐 위협 색상 적용", "", true, update_np)
    dodo.UI:SettingsColorRow(category, "nameplateColorDpsHasThreat",    "  어그로 있음", "", Cp.Red.hex,       update_np)
    dodo.UI:SettingsColorRow(category, "nameplateColorDpsGainingThreat","  어그로 낮음", "", Cp.Orange.hex,    update_np)
    dodo.UI:SettingsColorRow(category, "nameplateColorDpsNoThreat",     "  어그로 없음", "", Ce.SoftGreen.hex, update_np)
end)
