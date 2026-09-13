-- ==============================
-- Inspired
-- ==============================
-- BResLustTracker [Retail] (https://www.curseforge.com/wow/addons/breslusttracker)

-- ==============================
-- 설정 및 테이블
-- ==============================
---@diagnostic disable: lowercase-global, param-type-mismatch, redundant-parameter, undefined-field, undefined-global
local dodo = _G.dodo
local LibIcon = dodo.LibIcon
dodoDB = dodoDB or {}

local Config = {
    iconPositionX = 465,
    iconPositionY = 2,
    iconPadding   = 2,
    iconsize      = {46, 46},
    fontsize      = 12,
    soundPath     = "Interface\\AddOns\\dodo\\Media\\Sound\\Blood.mp3",
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
local anchor_frame     = nil
local main_frame       = nil
local blood_icon       = nil
local brez_icon        = nil
local blood_overlay    = nil
local blood_overlay_glow = nil
local blood_overlay_timer = nil
local active_ticker    = nil

-- ==============================
-- 기능 2: 상태 업데이트
-- ==============================
local on_active_tick  -- forward declaration (update_bloodlust에서 참조)

local function update_position()
    if not main_frame then return end
    main_frame:ClearAllPoints()
    if anchor_frame then
        main_frame:SetPoint("CENTER", anchor_frame, "CENTER", 0, 0)
    else
        main_frame:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", Config.iconPositionX, Config.iconPositionY)
    end
end

local function update_bloodlust()
    local foundAura = nil
    for i = 1, #BL_DEBUFFS do
        local aura = GetPlayerAuraBySpellID(BL_DEBUFFS[i])
        if aura then foundAura = aura; break end
    end

    if foundAura then
        if not is_sated_active then
            -- 블러드 최초 감지 → active 페이즈 시작
            local isExpSecret = issecretvalue(foundAura.expirationTime)
            local now = GetTime()
            if not isExpSecret then
                bl_active_until = (foundAura.expirationTime - foundAura.duration) + 40
                is_sated_active = true
                if now < bl_active_until then PlaySoundFile(Config.soundPath, "Master") end
            else
                is_sated_active = true
                PlaySoundFile(Config.soundPath, "Master")
                bl_active_until = 0
            end
            bl_phase = "active"
            blood_icon.icon:SetDesaturated(false)
            blood_icon.cooldown:Clear()
            blood_icon.Name:SetText("")
            blood_overlay:Show()
            if not active_ticker then
                active_ticker = C_Timer.NewTicker(1, on_active_tick)
            end
        end
        -- sated 페이즈 중 UNIT_AURA 재발화: cooldown 프레임이 자동 처리하므로 무시
    else
        if bl_phase ~= "idle" then
            bl_phase = "idle"
            is_sated_active = false
            bl_active_until = 0
            if active_ticker then active_ticker:Cancel(); active_ticker = nil end
            blood_overlay:Hide()
            blood_overlay_timer:SetText("")
            blood_overlay_timer._lastText = nil
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

local function apply_size()
    local sz  = (dodoDB and dodoDB.blbrIconSize)    or dodo.COMBAT_DEFAULTS.blbrIconSize
    local pad = (dodoDB and dodoDB.blbrIconPadding) or dodo.COMBAT_DEFAULTS.blbrIconPadding
    Config.iconsize[1] = sz
    Config.iconsize[2] = sz
    Config.iconPadding = pad
    if not main_frame then return end
    main_frame:SetSize(sz * 2 + pad, sz)
    if blood_icon then blood_icon:SetSize(sz, sz) end
    if brez_icon then
        brez_icon:SetSize(sz, sz)
        brez_icon:ClearAllPoints()
        brez_icon:SetPoint("LEFT", blood_icon, "RIGHT", pad, 0)
    end
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
    if event == "ADDON_LOADED" and arg1 == "dodoCombat" then
        dodoDB = dodoDB or {}
    elseif event == "PLAYER_LOGIN" then
        local LEM = LibStub("LibEditMode")
        local _dp = { point="BOTTOMLEFT", relativePoint="BOTTOMLEFT", xOfs=Config.iconPositionX, yOfs=Config.iconPositionY }
        local _sv = dodoDB.editMode and dodoDB.editMode["BloodBrez"]
        local _pt = (_sv and _sv.point) and _sv or _dp
        anchor_frame = CreateFrame("Frame", "dodoEditModeBloodBrez", UIParent)
        anchor_frame:SetSize(100, 50)
        anchor_frame:SetPoint(_pt.point, UIParent, _pt.relativePoint or _pt.point, _pt.xOfs or 0, _pt.yOfs or 0)
        LEM:AddFrame(anchor_frame, function(f, l, p, x, y)
            dodoDB.editMode = dodoDB.editMode or {}
            dodoDB.editMode["BloodBrez"] = { point=p, relativeTo="UIParent", relativePoint=p, xOfs=x, yOfs=y }
            update_position()
        end, { point=_pt.point, x=_pt.xOfs or 0, y=_pt.yOfs or 0 }, "블러드 & 전투부활")
        LEM:AddFrameSettings(anchor_frame, {
            { kind=LEM.SettingType.Slider, name="아이콘 크기", default=50, minValue=30, maxValue=60, valueStep=2,
              disabled=function() return dodoDB and dodoDB.useBloodBrez == false end,
              get=function(l) return dodoDB and dodoDB.blbrIconSize or dodo.COMBAT_DEFAULTS.blbrIconSize end,
              set=function(l,v) if dodoDB then dodoDB.blbrIconSize=v end; if dodo.BloodBrezApplySize then dodo.BloodBrezApplySize() end end },
            { kind=LEM.SettingType.Slider, name="아이콘 간격", default=4, minValue=0, maxValue=10, valueStep=1,
              disabled=function() return dodoDB and dodoDB.useBloodBrez == false end,
              get=function(l) return dodoDB and dodoDB.blbrIconPadding or dodo.COMBAT_DEFAULTS.blbrIconPadding end,
              set=function(l,v) if dodoDB then dodoDB.blbrIconPadding=v end; if dodo.BloodBrezApplySize then dodo.BloodBrezApplySize() end end },
        })
        create_ui()
        apply_size()
        apply_icons()
        dodo.BloodBrez() -- 초기 설정 적용
        self:UnregisterEvent("PLAYER_LOGIN")
    elseif event == "PLAYER_ENTERING_WORLD" then
        create_ui()
        apply_size()
        apply_icons()
        dodo.BloodBrez()
        update_bloodlust()
        update_brez()
    elseif event == "UNIT_AURA" then
        update_bloodlust()
    elseif event == "SPELL_UPDATE_CHARGES" then
        update_brez()
    end
end

on_active_tick = function()
    if bl_phase ~= "active" then
        if active_ticker then active_ticker:Cancel(); active_ticker = nil end
        return
    end
    local now = GetTime()
    if bl_active_until == 0 or now >= bl_active_until then
        -- active → sated 전환
        bl_phase = "sated"
        if active_ticker then active_ticker:Cancel(); active_ticker = nil end
        blood_overlay:Hide()
        blood_overlay_timer:SetText("")
        blood_overlay_timer._lastText = nil
        blood_icon.icon:SetDesaturated(true)
        for i = 1, #BL_DEBUFFS do
            local aura = GetPlayerAuraBySpellID(BL_DEBUFFS[i])
            if aura then
                blood_icon.cooldown:SetCooldown(aura.expirationTime - aura.duration, aura.duration)
                break
            end
        end
        return
    end
    local rem = math_ceil(bl_active_until - now - 1)
    local remainingText = tostring(rem < 0 and 0 or rem)
    if remainingText ~= blood_overlay_timer._lastText then
        blood_overlay_timer:SetText(remainingText)
        blood_overlay_timer._lastText = remainingText
    end
end

-- 초기화 및 이벤트 관리용 독립 프레임 (2dodo 격리 규격 준수)
local init_frame = CreateFrame("Frame")

local function update_ticker_and_events()
    local isEnabled = (dodoDB and dodoDB.useBloodBrez ~= false)
    if isEnabled then
        init_frame:RegisterUnitEvent("UNIT_AURA", "player")
        init_frame:RegisterEvent("SPELL_UPDATE_CHARGES")
        init_frame:RegisterEvent("PLAYER_ENTERING_WORLD")
    else
        if active_ticker then active_ticker:Cancel(); active_ticker = nil end
        init_frame:UnregisterEvent("UNIT_AURA")
        init_frame:UnregisterEvent("SPELL_UPDATE_CHARGES")
        init_frame:UnregisterEvent("PLAYER_ENTERING_WORLD")
    end
end

init_frame:RegisterEvent("ADDON_LOADED")
init_frame:RegisterEvent("PLAYER_LOGIN")
init_frame:SetScript("OnEvent", on_event)

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

dodo.BloodBrezApplySize = apply_size