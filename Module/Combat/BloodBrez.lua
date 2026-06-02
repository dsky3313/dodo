-- ==============================
-- Inspired
-- ==============================
-- BResLustTracker [Retail] (https://www.curseforge.com/wow/addons/breslusttracker)

-- ==============================
-- 설정 및 테이블
-- ==============================
---@diagnostic disable: lowercase-global, param-type-mismatch, redundant-parameter, undefined-field, undefined-global
local addonName, dodo = ...
local LibIcon = dodo.LibIcon
dodoDB = dodoDB or {}

local Config = {
    iconPositionX = 465,
    iconPositionY = 2,
    iconPadding   = 2,
    iconsize      = {45, 45},
    fontsize      = 12,
    soundPath     = "Interface\\AddOns\\" .. addonName .. "\\Media\\Sound\\1-Stimpack.mp3",
}

local BL_DEBUFFS = {
    57723,  -- 소진 (영웅심)
    57724,  -- 만족함 (피의 욕망)
    80354,  -- 시간 변위 (시간왜곡)
    264689, -- 피로 (원초적 분노)
    390435, -- 탈진 (위상의 격노)
}

-- ==============================
-- 캐싱
-- ==============================
local C_SpellBook      = C_SpellBook
local C_Timer          = C_Timer
local CreateFrame      = CreateFrame
local GetPlayerAuraBySpellID = C_UnitAuras.GetPlayerAuraBySpellID
local GetSpellCharges  = C_Spell.GetSpellCharges
local GetTime          = GetTime
local issecretvalue    = issecretvalue
local math_ceil        = math.ceil
local PlaySoundFile    = PlaySoundFile
local tostring         = tostring
local type             = type
local UIParent         = UIParent

-- ==============================
-- 기능 1: 로컬 상태 및 설정
-- ==============================
local BL_ICON_SPELL    = 2825
local BREZ_SPELL_ID    = 20484
local bl_active_until  = 0
local bl_phase         = "idle"   -- "idle" / "active" / "sated" / "init"
local brez_desat_cache = nil
local is_sated_active  = false

-- UI 객체 local 캡슐화
local main_frame       = nil
local blood_icon       = nil
local brez_icon        = nil
local blood_overlay    = nil
local blood_overlay_glow = nil
local blood_overlay_timer = nil
local ticker_obj       = nil

-- ==============================
-- 기능 2: 상태 업데이트
-- ==============================
local function update_position()
    local anchorFrame = dodo.EditMode and dodo.EditMode:GetSystem("BloodBrez")
    if not main_frame then return end
    main_frame:ClearAllPoints()
    if anchorFrame then
        main_frame:SetPoint("CENTER", anchorFrame, "CENTER", 0, 0)
    else
        main_frame:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", Config.iconPositionX, Config.iconPositionY)
    end
end

local function update_bloodlust()
    local foundAura = nil
    for i = 1, #BL_DEBUFFS do
        local id = BL_DEBUFFS[i]
        local aura = GetPlayerAuraBySpellID(id)
        if aura then foundAura = aura; break end
    end

    local now = GetTime()
    if foundAura then
        local isExpSecret = issecretvalue(foundAura.expirationTime)
        if not is_sated_active then
            if not isExpSecret then
                local debuffStartTime = foundAura.expirationTime - foundAura.duration
                bl_active_until = debuffStartTime + 40
                is_sated_active = true
                if now < bl_active_until then PlaySoundFile(Config.soundPath, "Master") end
            else
                is_sated_active = true
                PlaySoundFile(Config.soundPath, "Master")
                bl_active_until = 0
            end
        end

        local remainingText = ""
        local isShowingOverlay = false
        
        if not isExpSecret and bl_active_until > 0 and now < bl_active_until then
            -- Active 페이즈 (처음 40초)
            if bl_phase ~= "active" then
                bl_phase = "active"
                blood_icon.icon:SetDesaturated(false)
                blood_icon.cooldown:Clear()
                blood_icon.Name:SetText("")
                blood_overlay:Show()
            end
            local rem = math_ceil(bl_active_until - now - 1)
            remainingText = tostring(rem < 0 and 0 or rem)
            isShowingOverlay = true
        else
            -- Sated 페이즈 (디버프 지속시간)
            if bl_phase ~= "sated" then
                bl_phase = "sated"
                blood_overlay:Hide()
                blood_icon.icon:SetDesaturated(true)
                blood_icon.cooldown:SetCooldown(foundAura.expirationTime - foundAura.duration, foundAura.duration)
                blood_icon.Name:SetText("")
            end
            remainingText = ""
            isShowingOverlay = false
        end

        if remainingText ~= blood_overlay_timer._lastText then
            blood_overlay_timer:SetText(remainingText)
            blood_overlay_timer._lastText = remainingText
        end
        if isShowingOverlay then blood_overlay:Show() else blood_overlay:Hide() end
    else
        if bl_phase ~= "idle" then
            bl_phase = "idle"
            is_sated_active = false
            bl_active_until = 0
            blood_overlay:Hide()
            blood_overlay_timer:SetText("")
            blood_icon.icon:SetDesaturated(false)
            blood_icon.cooldown:Clear()
            blood_icon.Name:SetText("")
        end
    end
end

local function update_brez()
    local chargeInfo = GetSpellCharges(BREZ_SPELL_ID)
    if not chargeInfo or (chargeInfo.currentCharges == 0 and chargeInfo.maxCharges == 0) then
        brez_icon.Count:SetText("")
        if brez_desat_cache ~= false then
            brez_desat_cache = false
            brez_icon.icon:SetDesaturated(false)
            brez_icon.cooldown:Clear()
        end
        return
    end

    local current  = chargeInfo.currentCharges   or 0
    local start    = chargeInfo.cooldownStartTime or 0
    local duration = chargeInfo.cooldownDuration  or 0

    -- 비밀값 비교 에러 가드
    local is_current_secret = issecretvalue(current)
    local is_duration_secret = issecretvalue(duration)

    local chargeText = tostring(current)
    if chargeText ~= brez_icon.Count._lastText or is_current_secret then
        brez_icon.Count:SetText(chargeText)
        if not is_current_secret then brez_icon.Count._lastText = chargeText end
    end
    brez_icon.Count:SetTextColor(1, 0.82, 0)

    -- 안전한 비교를 위해 비밀값 체크
    local check_current = is_current_secret and 0 or current
    local check_duration = is_duration_secret and 0 or duration

    if check_current == 0 and check_duration > 0 then
        if brez_desat_cache ~= true then brez_desat_cache = true; brez_icon.icon:SetDesaturated(true) end
        brez_icon.cooldown:SetCooldown(start, duration)
    else
        if brez_desat_cache ~= false then brez_desat_cache = false; brez_icon.icon:SetDesaturated(false) end
        if check_duration > 0 then brez_icon.cooldown:SetCooldown(start, duration) else brez_icon.cooldown:Clear() end
    end
end

local function apply_icons()
    if not blood_icon or not brez_icon then return end
    blood_icon:ApplyConfig({ type = "spell", id = BL_ICON_SPELL, fontsize = Config.fontsize })
    blood_icon.icon:SetDesaturated(false)
    blood_icon.cooldown:Clear()
    blood_icon.Name:SetText("")
    bl_phase = "init"

    brez_icon:ApplyConfig({ type = "spell", id = BREZ_SPELL_ID, fontsize = Config.fontsize })
    brez_icon.icon:SetDesaturated(false)
    brez_desat_cache = false
end

-- ==============================
-- 기능 3: UI 생성
-- ==============================
local function create_ui()
    if main_frame then return end

    main_frame = CreateFrame("Frame", "BLBR_TrackerFrame", UIParent)
    main_frame:SetSize(100, 50)
    update_position()

    blood_icon = LibIcon:Create("BLBR_BloodlustIcon", main_frame, {
        isAction = false,
        iconsize = Config.iconsize,
    })
    blood_icon:SetPoint("LEFT", main_frame, "LEFT", 0, 0)

    blood_overlay = CreateFrame("Frame", nil, blood_icon)
    blood_overlay:SetAllPoints(blood_icon)
    blood_overlay:Hide()

    blood_overlay_glow = blood_overlay:CreateTexture(nil, "ARTWORK")
    blood_overlay_glow:SetAtlas("UI-HUD-ActionBar-IconFrame-Mouseover")
    blood_overlay_glow:SetVertexColor(0, 1, 0, 1)
    blood_overlay_glow:SetAllPoints(blood_overlay)
    blood_overlay_glow:SetBlendMode("BLEND")

    blood_overlay_timer = blood_overlay:CreateFontString(nil, "ARTWORK", "NumberFontNormal")
    blood_overlay_timer:SetPoint("TOPLEFT", blood_overlay, "TOPLEFT", 5, -5)
    blood_overlay_timer:SetTextColor(0.1, 1, 0.1)

    brez_icon = LibIcon:Create("BLBR_BrezIcon", main_frame, {
        isAction = false,
        iconsize = Config.iconsize,
    })
    brez_icon:SetPoint("LEFT", blood_icon, "RIGHT", Config.iconPadding, 0)
end

-- ==============================
-- 이벤트 핸들러
-- ==============================
local function on_event(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == addonName then
        dodoDB = dodoDB or {}
    elseif event == "PLAYER_LOGIN" then
        if dodo.EditMode then
            dodo.EditMode:CreateSystem("BloodBrez", "블러드 & 전투부활", "블러드 & 전투부활", UIParent, 100, 50, { point = "BOTTOMLEFT", relativeTo = "UIParent", relativePoint = "BOTTOMLEFT", xOfs = Config.iconPositionX, yOfs = Config.iconPositionY }, nil, function() return dodoDB and dodoDB.useBloodBrez ~= false end)
        end
        create_ui()
        apply_icons()
        dodo.BloodBrez() -- 초기 설정 적용
        self:UnregisterEvent("PLAYER_LOGIN")
    elseif event == "PLAYER_ENTERING_WORLD" then
        create_ui()
        apply_icons()
        dodo.BloodBrez() -- 초기 설정 적용
    end
end

local function on_ticker_tick()
    if main_frame and main_frame:IsShown() then -- 프레임이 보일 때만 업데이트
        update_bloodlust()
        update_brez()
    end
end

-- 초기화 및 이벤트 관리용 독립 프레임 (2dodo 격리 규격 준수)
local init_frame = CreateFrame("Frame")

local function update_ticker_and_events()
    local isEnabled = (dodoDB and dodoDB.useBloodBrez ~= false)
    if isEnabled then
        if not ticker_obj then
            ticker_obj = C_Timer.NewTicker(0.5, on_ticker_tick)
        end
        if init_frame then
            init_frame:RegisterEvent("PLAYER_ENTERING_WORLD")
        end
    else
        if ticker_obj then
            ticker_obj:Cancel()
            ticker_obj = nil
        end
        if init_frame then
            init_frame:UnregisterEvent("PLAYER_ENTERING_WORLD")
        end
    end
end

local function on_init_delay()
    create_ui()
    apply_icons()
    dodo.BloodBrez()
end

init_frame:RegisterEvent("ADDON_LOADED")
init_frame:RegisterEvent("PLAYER_LOGIN")
init_frame:SetScript("OnEvent", on_event)

C_Timer.After(1, on_init_delay)

-- ==============================
-- 설정 등록
-- ==============================
dodo.BloodBrez = function()
    local isEnabled = (dodoDB and dodoDB.useBloodBrez ~= false)
    if isEnabled then
        create_ui()
        update_position()
        if main_frame then main_frame:Show() end
    else
        if main_frame then main_frame:Hide() end
    end
    update_ticker_and_events()
end

local SettingsPanel = SettingsPanel
local CreateSettingsListSectionHeaderInitializer = CreateSettingsListSectionHeaderInitializer
local Checkbox = Checkbox

dodo.OptionRegistrations = dodo.OptionRegistrations or {}
dodo.OptionRegistrations["combat"] = dodo.OptionRegistrations["combat"] or {}
table.insert(dodo.OptionRegistrations["combat"], function(category)
    local layoutCombat = SettingsPanel:GetLayout(category)
    if not layoutCombat then return end

    layoutCombat:AddInitializer(CreateSettingsListSectionHeaderInitializer("블러드 & 전투부활"))
    Checkbox(category, "useBloodBrez", "블러드 & 전투부활", "블러드 & 전투부활", true, dodo.BloodBrez)
end)

if dodo.RegisterEditModeModuleSetting then
    dodo.RegisterEditModeModuleSetting("전투", {
        {
            name = "블러드 & 전투부활",
            get = function()
                return dodoDB and dodoDB.useBloodBrez ~= false
            end,
            set = function(checked)
                if dodoDB then
                    dodoDB.useBloodBrez = checked
                end
                dodo.BloodBrez()
            end
        }
    })
end