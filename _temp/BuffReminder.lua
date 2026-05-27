-- ==============================
-- Inspired
-- ==============================
-- RefineUI (BuffReminder)

-- ==============================
-- 설정 및 테이블
-- ==============================
---@diagnostic disable: lowercase-global, param-type-mismatch, redundant-parameter, undefined-field, undefined-global
local addonName, dodo = ...
local module = {}
dodo:RegisterModule("BuffReminder", module)

local Colors = dodo.Colors
local LibEditMode = LibStub and LibStub("LibEditMode", true)

-- ==============================
-- 캐싱 및 상수
-- ==============================
local C_Spell = C_Spell
local C_UnitAuras = C_UnitAuras
local CreateFrame = CreateFrame
local GetNumGroupMembers = GetNumGroupMembers
local GetSpecialization = GetSpecialization
local GetSpecializationInfo = GetSpecializationInfo
local GetSpecializationRole = GetSpecializationRole
local GetWeaponEnchantInfo = GetWeaponEnchantInfo
local InCombatLockdown = InCombatLockdown
local IsInInstance = IsInInstance
local IsInRaid = IsInRaid
local IsPlayerSpell = IsPlayerSpell
local PlaySound = PlaySound
local UnitCanAssist = UnitCanAssist
local UnitClass = UnitClass
local UnitExists = UnitExists
local UnitGroupRolesAssigned = UnitGroupRolesAssigned
local UnitIsConnected = UnitIsConnected
local UnitIsDeadOrGhost = UnitIsDeadOrGhost
local UnitIsPlayer = UnitIsPlayer
local UnitIsUnit = UnitIsUnit
local UnitLevel = UnitLevel
local UIParent = UIParent

local MyClass = dodo.MyClass

-- ==============================
-- 데이터: 버프 정의
-- ==============================
local CATEGORY_ORDER = { "raid", "targeted", "self" }

local RAID_BUFFS = {
    { key = "intellect", name = "신비한 지능", class = "MAGE", spellID = { 1459, 432778 } },
    { key = "attackPower", name = "전투의 외침", class = "WARRIOR", spellID = 6673 },
    { key = "devotionAura", name = "기오라", class = "PALADIN", spellID = 465 },
    { key = "bronze", name = "청동용군단의 축복", class = "EVOKER", spellID = { 381732, 381741, 381746, 381748, 381749, 381750, 381751, 381752, 381753, 381754, 381756, 381757, 381758 } },
    { key = "versatility", name = "야생의 징표", class = "DRUID", spellID = { 1126, 432661 } },
    { key = "stamina", name = "신의 권능: 인내", class = "PRIEST", spellID = 21562 },
    { key = "skyfury", name = "하늘분노", class = "SHAMAN", spellID = 462854 },
}

local TARGETED_BUFFS = {
    { key = "beaconOfFaith", name = "신념의 봉화", class = "PALADIN", spellID = 156910, requireSpecId = 65 },
    { key = "beaconOfLight", name = "빛의 봉화", class = "PALADIN", spellID = 53563, requireSpecId = 65, excludeTalentSpellID = 200025 },
    { key = "earthShieldOthers", name = "대지의 보호막", class = "SHAMAN", spellID = 974 },
}

local SELF_BUFFS = {
    { key = "roguePoisons", name = "도적 독", class = "ROGUE", spellID = 2823, customCheck = "roguePoisons" },
    { key = "shadowform", name = "어둠의 형상", class = "PRIEST", spellID = 232698 },
    { key = "earthlivingWeapon", name = "생명폭발 무기", class = "SHAMAN", spellID = 382021, enchantID = 6498 },
    { key = "flametongueWeapon", name = "불꽃혓바닥 무기", class = "SHAMAN", spellID = 318038, enchantID = 5400 },
    { key = "windfuryWeapon", name = "질풍의 무기", class = "SHAMAN", spellID = 33757, enchantID = 5401 },
    { key = "hunterPet", name = "소환수 없음", class = "HUNTER", spellID = 883, customCheck = "missingPet" },
    { key = "warlockPet", name = "소환수 없음", class = "WARLOCK", spellID = 688, customCheck = "missingPet", excludeTalentSpellID = 108503 },
}

local BUFF_BENEFICIARIES = {
    intellect = { MAGE = true, WARLOCK = true, PRIEST = true, DRUID = true, SHAMAN = true, MONK = true, EVOKER = true, PALADIN = true, DEMONHUNTER = true },
    attackPower = { WARRIOR = true, ROGUE = true, HUNTER = true, DEATHKNIGHT = true, PALADIN = true, MONK = true, DRUID = true, DEMONHUNTER = true, SHAMAN = true },
}

-- ==============================
-- 프레임 생성
-- ==============================
local main_frame = CreateFrame("Frame", "dodoBuffReminderFrame", UIParent)
main_frame:SetSize(40, 40)
main_frame:SetPoint("CENTER", 0, -150)
main_frame:Hide()

local icon_frames = {}

local function create_icon_frame(index)
    if icon_frames[index] then return icon_frames[index] end

    local f = CreateFrame("Frame", nil, main_frame, "BackdropTemplate")
    f:SetSize(40, 40)
    f:SetBackdrop({
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    f:SetBackdropEdgeColor(0, 0, 0, 1)

    f.icon = f:CreateTexture(nil, "ARTWORK")
    f.icon:SetAllPoints()
    f.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    -- 애니메이션 (반짝임)
    local group = f:CreateAnimationGroup()
    group:SetLooping("REPEAT")
    local alpha = group:CreateAnimation("Alpha")
    alpha:SetFromAlpha(1)
    alpha:SetToAlpha(0.3)
    alpha:SetDuration(0.6)
    alpha:SetSmoothing("IN_OUT")
    f.anim = group

    icon_frames[index] = f
    return f
end

-- ==============================
-- 헬퍼 함수
-- ==============================
local function get_aura_data(spellID)
    if not spellID then return nil end
    if type(spellID) == "table" then
        for _, id in ipairs(spellID) do
            local data = C_UnitAuras.GetPlayerAuraBySpellID(id)
            if data then return data end
        end
    else
        return C_UnitAuras.GetPlayerAuraBySpellID(spellID)
    end
    return nil
end

local function has_aura(spellID)
    return get_aura_data(spellID) ~= nil
end

local function get_valid_units()
    local units = {}
    local total = GetNumGroupMembers()
    if total == 0 then
        units[1] = { unit = "player", class = MyClass }
    else
        local inRaid = IsInRaid()
        for i = 1, total do
            local unit = inRaid and ("raid"..i) or (i == 1 and "player" or "party"..(i-1))
            if UnitExists(unit) and not UnitIsDeadOrGhost(unit) and UnitIsConnected(unit) then
                local _, class = UnitClass(unit)
                table.insert(units, { unit = unit, class = class })
            end
        end
    end
    return units
end

-- ==============================
-- 기능: 버프 체크 메인 로직
-- ==============================
local function update_buffs()
    if InCombatLockdown() or not main_frame:IsShown() then return end

    dodo.Throttle("BuffReminderUpdate", function()
        local missing = {}
        local valid_units = get_valid_units()
        local specID = GetSpecialization() and GetSpecializationInfo(GetSpecialization())
        local _, _, _, mainEnchant, _, _, _, offEnchant = GetWeaponEnchantInfo()

        -- 1. 공격대 버프 체크
        for _, entry in ipairs(RAID_BUFFS) do
            local available = false
            for _, u in ipairs(valid_units) do
                if u.class == entry.class then
                    available = true
                    break
                end
            end

            if available then
                local isBeneficiary = not BUFF_BENEFICIARIES[entry.key] or BUFF_BENEFICIARIES[entry.key][MyClass]
                if isBeneficiary and not has_aura(entry.spellID) then
                    table.insert(missing, entry)
                end
            end
        end

        -- 2. 대상 지정 버프 체크 (지정된 역할군에 활성화된 내 버프가 있는지)
        for _, entry in ipairs(TARGETED_BUFFS) do
            if entry.class == MyClass and (not entry.requireSpecId or entry.requireSpecId == specID) then
                if IsPlayerSpell(type(entry.spellID) == "table" and entry.spellID[1] or entry.spellID) then
                    local activeFromMe = false
                    for _, u in ipairs(valid_units) do
                        local data = get_aura_data(entry.spellID)
                        if data and data.sourceUnit == "player" then
                            activeFromMe = true
                            break
                        end
                    end
                    if not activeFromMe and #valid_units > 1 then
                        table.insert(missing, entry)
                    end
                end
            end
        end

        -- 3. 자가 버프 체크
        for _, entry in ipairs(SELF_BUFFS) do
            if entry.class == MyClass then
                local show = false
                if entry.customCheck == "roguePoisons" then
                    local count = 0
                    for _, id in ipairs({ 315584, 8679, 2823, 381664 }) do if has_aura(id) then count = count + 1 end end
                    if count < (IsPlayerSpell(381801) and 2 or 1) then show = true end
                elseif entry.customCheck == "missingPet" then
                    show = not UnitExists("pet")
                elseif entry.enchantID then
                    show = (mainEnchant ~= entry.enchantID and offEnchant ~= entry.enchantID)
                else
                    show = not has_aura(entry.spellID)
                end

                if show and IsPlayerSpell(type(entry.spellID) == "table" and entry.spellID[1] or entry.spellID) then
                    table.insert(missing, entry)
                end
            end
        end

        -- UI 렌더링
        local iconSize = (dodo.DB and dodo.DB.buffReminderSize) or 40
        local spacing = (dodo.DB and dodo.DB.buffReminderSpacing) or 5
        
        for i = 1, #icon_frames do icon_frames[i]:Hide() end

        for i, entry in ipairs(missing) do
            local f = create_icon_frame(i)
            f:SetSize(iconSize, iconSize)
            f:SetPoint("LEFT", (i-1) * (iconSize + spacing), 0)
            
            local spellID = type(entry.spellID) == "table" and entry.spellID[1] or entry.spellID
            f.icon:SetTexture(C_Spell.GetSpellTexture(spellID))
            
            -- 직업 색상 테두리
            if Colors.Class[entry.class] then
                local c = Colors.Class[entry.class]
                f:SetBackdropEdgeColor(c.r, c.g, c.b, 1)
            else
                f:SetBackdropEdgeColor(0, 0, 0, 1)
            end

            f:Show()
            if not f.anim:IsPlaying() then f.anim:Play() end
        end

        main_frame:SetSize(#missing * (iconSize + spacing), iconSize)
        if #missing > 0 then main_frame:Show() else main_frame:Hide() end
    end, 0.1)
end

-- ==============================
-- 모듈 On/Off 제어
-- ==============================
local function update_module_state()
    local enabled = (dodo.DB and dodo.DB.enableBuffReminderModule ~= false)
    
    if not enabled then
        main_frame:Hide()
        main_frame:UnregisterAllEvents()
    else
        main_frame:RegisterEvent("PLAYER_ENTERING_WORLD")
        main_frame:RegisterEvent("UNIT_AURA")
        main_frame:RegisterEvent("GROUP_ROSTER_UPDATE")
        main_frame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
        main_frame:RegisterEvent("UNIT_INVENTORY_CHANGED")
        main_frame:RegisterEvent("UNIT_PET")
        update_buffs()
    end
end

dodo.UpdateBuffReminderModuleState = update_module_state

-- ==============================
-- 이벤트 핸들러
-- ==============================
main_frame:SetScript("OnEvent", function(self, event, unit)
    if event == "UNIT_AURA" or event == "UNIT_INVENTORY_CHANGED" then
        if unit == "player" or unit == "pet" or (unit and (unit:find("party") or unit:find("raid"))) then
            update_buffs()
        end
    else
        update_buffs()
    end
end)

-- ==============================
-- 모듈 생명주기
-- ==============================
local isInitialized = false
function module:OnEnable()
    update_module_state()

    if isInitialized then return end
    isInitialized = true

    if LibEditMode then
        LibEditMode:AddFrame(main_frame, function(f, layout, p, x, y)
            if dodo.DB then
                dodo.DB.buffReminderX = x
                dodo.DB.buffReminderY = y
                dodo.DB.buffReminderPoint = p
            end
        end, {
            point = "CENTER",
            x = 0,
            y = -150,
        }, "버프 누락 알림")

        LibEditMode:AddFrameSettings(main_frame, {
            {
                kind = LibEditMode.SettingType.Slider,
                name = "아이콘 크기",
                minValue = 20,
                maxValue = 80,
                step = 2,
                get = function() return dodo.DB and dodo.DB.buffReminderSize or 40 end,
                set = function(_, val)
                    if dodo.DB then dodo.DB.buffReminderSize = val end
                    update_buffs()
                end
            },
            {
                kind = LibEditMode.SettingType.Slider,
                name = "아이콘 간격",
                minValue = 0,
                maxValue = 20,
                step = 1,
                get = function() return dodo.DB and dodo.DB.buffReminderSpacing or 5 end,
                set = function(_, val)
                    if dodo.DB then dodo.DB.buffReminderSpacing = val end
                    update_buffs()
                end
            }
        })
    end
end
