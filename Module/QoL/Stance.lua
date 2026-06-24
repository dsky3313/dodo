-- ==============================
-- 설정 및 테이블
-- ==============================
---@diagnostic disable: lowercase-global, param-type-mismatch, redundant-parameter, undefined-field, undefined-global
local addonName, dodo = ...
dodoDB = dodoDB or {}

-- ==============================
-- 캐싱
-- ==============================
local C_Timer               = C_Timer
local C_UnitAuras           = C_UnitAuras
local C_Spell               = C_Spell
local CreateFrame           = CreateFrame
local GetSpecialization     = GetSpecialization
local GetSpecializationInfo = GetSpecializationInfo
local InCombatLockdown      = InCombatLockdown
local IsInInstance          = IsInInstance
local UnitClass             = UnitClass
local UIParent              = UIParent

-- ==============================
-- 상수
-- ==============================
local _, player_class = UnitClass("player")

-- -- 팔라딘/드루이드: aura 있으면 무조건 표시
-- local STANCE_LISTS = {
--     PALADIN = { 465, 32223, 317920 },
--     DRUID   = { 5487, 102558, 768, 1850, 24858, 783, 33943, 40120, 114282, 210053 },
-- }

-- 워리어: 스펙별 감시 태세 (이 태세가 활성화됐을 때만 표시)
-- 71=무기 72=분노 73=방어
-- 386208=방어 태세  386164=공격 태세  386196=광전사 자세
local WARRIOR_ALERT_STANCES = {
    [71] = 386208, -- 무기전사 → 방어 태세
    [72] = 386208, -- 분노전사 → 방어 태세
    [73] = 386164, -- 방어전사 → 공격 태세
}

-- UNIT_SPELLCAST_SUCCEEDED 트리거용
local CAST_TRIGGERS = {}
if player_class == "WARRIOR" then
    CAST_TRIGGERS[386208] = true
    CAST_TRIGGERS[386164] = true
    CAST_TRIGGERS[386196] = true
-- elseif STANCE_LISTS[player_class] then
--     for _, id in ipairs(STANCE_LISTS[player_class]) do
--         CAST_TRIGGERS[id] = true
--     end
end

-- ==============================
-- 로컬 상태
-- ==============================
local stance_icon    = nil
local last_texture   = nil
local warrior_spec   = nil  -- 워리어 현재 스펙 ID

-- ==============================
-- 크기 적용
-- ==============================
local function apply_icon_size(val)
    if stance_icon then
        stance_icon:SetSize(val, val)
        if stance_icon.RescaleIcon then stance_icon:RescaleIcon() end
    end
    local anchor = dodo.EditMode and dodo.EditMode:GetSystem("Stance")
    if anchor then anchor:SetSize(val, val) end
end

-- ==============================
-- 스펙 갱신
-- ==============================
local function refresh_warrior_spec()
    local idx = GetSpecialization()
    if not idx then return end
    warrior_spec = GetSpecializationInfo(idx)
end

-- ==============================
-- 아이콘 업데이트
-- ==============================
local function update_icon()
    if not stance_icon then return end

    local texture, shown = nil, false

    if not InCombatLockdown() and not IsInInstance() then
        if player_class == "WARRIOR" then
            local alert = WARRIOR_ALERT_STANCES[warrior_spec]
            if alert then
                local aura = C_UnitAuras.GetPlayerAuraBySpellID(alert)
                if aura and aura.icon then
                    texture = aura.icon
                    shown   = true
                end
            end
        -- else
        --     local list = STANCE_LISTS[player_class]
        --     if list then
        --         for _, spellID in ipairs(list) do
        --             local aura = C_UnitAuras.GetPlayerAuraBySpellID(spellID)
        --             if aura and aura.icon then
        --                 texture = aura.icon
        --                 shown   = true
        --                 break
        --             end
        --         end
        --     end
        end
        last_texture = shown and texture or nil
    else
        if last_texture then
            texture = last_texture
            shown   = true
        end
    end

    stance_icon.icon:SetTexture(texture)
    stance_icon:SetShown(shown and dodoDB.enableStance ~= false)
end

-- ==============================
-- 이벤트
-- ==============================
local event_frame = CreateFrame("Frame")

local function on_event(self, event, arg1, _, spellID)
    if event == "ADDON_LOADED" then
        if arg1 == addonName then
            dodoDB = dodoDB or {}
            self:UnregisterEvent("ADDON_LOADED")
        end

    elseif event == "PLAYER_LOGIN" then
        local supported = (player_class == "WARRIOR") -- or (STANCE_LISTS[player_class] ~= nil)
        if not supported then
            self:UnregisterAllEvents()
            return
        end
        if dodoDB.enableStance == nil then dodoDB.enableStance = true end
        if dodoDB.stanceIconSize == nil then dodoDB.stanceIconSize = 60 end

        if player_class == "WARRIOR" then
            refresh_warrior_spec()
        end

        local icon_size = dodoDB.stanceIconSize

        if dodo.EditMode then
            dodo.EditMode:CreateSystem("Stance", "스탠스", "스탠스", UIParent, icon_size, icon_size,
                { point = "BOTTOMRIGHT", relativeTo = "PlayerFrame", relativePoint = "TOPRIGHT", xOfs = -20, yOfs = 15 },
                nil,
                function() return dodoDB and dodoDB.enableStance ~= false end)
        end

        stance_icon = dodo.LibIcon:Create("dodoStanceIcon", UIParent, { iconsize = { icon_size, icon_size } })
        stance_icon:SetFrameStrata("LOW")
        stance_icon:SetClampedToScreen(true)
        stance_icon:EnableMouse(false)

        local anchor = dodo.EditMode and dodo.EditMode:GetSystem("Stance")
        stance_icon:ClearAllPoints()
        if anchor then
            stance_icon:SetPoint("CENTER", anchor, "CENTER", 0, 0)
        else
            stance_icon:SetPoint("BOTTOMRIGHT", PlayerFrame, "TOPRIGHT", 10, 15)
        end

        self:RegisterEvent("PLAYER_ENTERING_WORLD")
        self:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
        self:RegisterEvent("UPDATE_SHAPESHIFT_FORM")
        self:RegisterEvent("UPDATE_SHAPESHIFT_FORMS")
        self:RegisterEvent("UNIT_AURA")
        self:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
        self:UnregisterEvent("PLAYER_LOGIN")

    elseif event == "PLAYER_ENTERING_WORLD" then
        update_icon()

    elseif event == "PLAYER_SPECIALIZATION_CHANGED" then
        if arg1 == "player" and player_class == "WARRIOR" then
            refresh_warrior_spec()
            update_icon()
        end

    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        if arg1 ~= "player" or not CAST_TRIGGERS[spellID] then return end
        if dodoDB.enableStance == false then return end

        local should_show
        if player_class == "WARRIOR" then
            should_show = (WARRIOR_ALERT_STANCES[warrior_spec] == spellID)
        else
            should_show = true
        end

        if should_show then
            local tex = C_Spell.GetSpellTexture(spellID)
            if tex then
                last_texture = tex
                stance_icon.icon:SetTexture(tex)
                stance_icon:Show()
            end
        else
            -- 감시 태세 → 일반 태세로 복귀: 즉시 숨김
            last_texture = nil
            stance_icon:Hide()
        end

    elseif event == "UNIT_AURA" then
        if arg1 == "player" then
            C_Timer.After(0.1, update_icon)
        end

    elseif event == "UPDATE_SHAPESHIFT_FORM" or event == "UPDATE_SHAPESHIFT_FORMS" then
        update_icon()
    end
end

event_frame:RegisterEvent("ADDON_LOADED")
event_frame:RegisterEvent("PLAYER_LOGIN")
event_frame:SetScript("OnEvent", on_event)

-- ==============================
-- 설정 등록
-- ==============================
if dodo.RegisterEditModeModuleSetting then
    dodo.RegisterEditModeModuleSetting("편의기능", {
        {
            name = "스탠스 아이콘",
            get  = function() return dodoDB.enableStance ~= false end,
            set  = function(v)
                dodoDB.enableStance = v
                if stance_icon then
                    if v then update_icon() else stance_icon:Hide() end
                end
            end,
        }
    })
end

if dodo.RegisterEditModeSystemSetting then
    dodo.RegisterEditModeSystemSetting("Stance", {
        {
            name   = "아이콘 크기",
            type   = "slider",
            get    = function() return dodoDB and dodoDB.stanceIconSize or 60 end,
            set    = function(val)
                dodoDB.stanceIconSize = val
                apply_icon_size(val)
            end,
            minVal = 40,
            maxVal = 80,
            step   = 2,
        },
    })
end
