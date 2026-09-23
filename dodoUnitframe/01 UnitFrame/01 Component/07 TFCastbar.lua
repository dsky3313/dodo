-- ==============================
-- 설정 및 테이블
-- ==============================
---@diagnostic disable: lowercase-global, param-type-mismatch, redundant-parameter, undefined-field, undefined-global
local dodo = _G.dodo
dodoDB = dodoDB or {}

-- ==============================
-- 캐싱
-- ==============================
local C_CurveUtil     = C_CurveUtil
local C_DurationUtil  = C_DurationUtil
local C_Spell         = C_Spell
local C_StringUtil    = C_StringUtil
local C_Timer         = C_Timer
local CreateFrame     = CreateFrame
local Enum            = Enum
local ipairs          = ipairs
local IsSpellKnown    = IsSpellKnown
local issecretvalue   = issecretvalue or function() return false end
local NineSliceUtil   = NineSliceUtil
local select          = select
local UnitCastingDuration          = UnitCastingDuration
local UnitCastingInfo              = UnitCastingInfo
local UnitChannelDuration          = UnitChannelDuration
local UnitChannelInfo              = UnitChannelInfo
local UnitEmpoweredChannelDuration = UnitEmpoweredChannelDuration
local UnitClass                    = UnitClass
local UnitExists                   = UnitExists
local UnitShouldDisplaySpellTargetName = UnitShouldDisplaySpellTargetName
local UnitSpellTargetName              = UnitSpellTargetName

-- ==============================
-- 상수
-- ==============================
local BAR_W       = 400
local BAR_H       = 30
local KICK_BAR_W  = BAR_W - BAR_H - 6  -- sb 픽셀 너비 (GetWidth 런타임 호출 대체)
local SYSTEM_NAME = "TFCastbar"
local DEFAULT_PT  = { point = "TOP", xOfs = 0, yOfs = -80 }

-- ==============================
-- 로컬 상태
-- ==============================
local bar
local active_unit
local cast_active    = false
local is_edit_mode   = false

local bar_is_channel    = false
local bar_cast_type     = "cast"  -- "cast", "channel", "empower"
local bar_not_interruptible = false

-- ==============================
-- 차단 스킬
-- ==============================
local KICK_SPELLS = {
    WARRIOR     = { 6552 },           -- Pummel
    PALADIN     = { 96231 },          -- Rebuke
    HUNTER      = { 147362, 187707 }, -- Counter Shot, Muzzle
    ROGUE       = { 1766 },           -- Kick
    DEATHKNIGHT = { 47528 },          -- Mind Freeze
    SHAMAN      = { 57994 },          -- Wind Shear
    MAGE        = { 2139 },           -- Counterspell
    WARLOCK     = { 19647 },          -- Spell Lock
    MONK        = { 116705 },         -- Spear Hand Strike
    DRUID       = { 106839 },         -- Skull Bash
    DEMONHUNTER = { 183752 },         -- Disrupt
    EVOKER      = { 351338 },         -- Quell
}
local active_kick_spell = nil

local function refresh_kick_spell()
    local cls = select(2, UnitClass("player"))
    local list = KICK_SPELLS[cls]
    if not list then active_kick_spell = nil; return end
    for _, id in ipairs(list) do
        if not IsSpellKnown or IsSpellKnown(id) then
            active_kick_spell = id; return
        end
    end
    active_kick_spell = nil
end

-- ==============================
-- 기능 1: 차단 눈금
-- ==============================
local function hide_kick_tick()
    if not bar then return end
    if bar.kick_tick       then bar.kick_tick:Hide() end
    if bar.kick_positioner then bar.kick_positioner:Hide() end
    if bar.kick_marker     then bar.kick_marker:Hide() end
end

local function update_kick_tick()
    if not bar or not bar.kick_tick then return end

    if not cast_active or not active_unit then hide_kick_tick(); return end
    if not active_kick_spell            then hide_kick_tick(); return end

    local castDur = (bar_is_channel or bar_cast_type == "empower")
        and UnitChannelDuration(active_unit)
        or  UnitCastingDuration(active_unit)
    if not castDur then hide_kick_tick(); return end

    local kickDur = C_Spell.GetSpellCooldownDuration(active_kick_spell)
    if not kickDur then hide_kick_tick(); return end

    -- Plater 방식: secret 값 비교 없이 C-side에 직접 전달
    bar.kick_positioner:SetMinMaxValues(0, castDur:GetTotalDuration())
    bar.kick_positioner:SetValue(castDur:GetElapsedDuration())
    bar.kick_marker:SetMinMaxValues(0, castDur:GetTotalDuration())
    bar.kick_marker:SetWidth(KICK_BAR_W)
    bar.kick_marker:SetValue(kickDur:GetRemainingDuration())

    bar.kick_positioner:Show()
    bar.kick_marker:Show()
    local base_alpha = C_CurveUtil.EvaluateColorValueFromBoolean(kickDur:IsZero(), 0.4, 1.0)
    bar.kick_tick:SetAlpha(C_CurveUtil.EvaluateColorValueFromBoolean(bar_not_interruptible, 0, base_alpha))
    bar.kick_tick:Show()
end

-- ==============================
-- 기능 2: 색상
-- ==============================
local function apply_color(not_interruptible, spellID)
    bar_not_interruptible = not_interruptible
    local CC = dodo.ColorsUnitframe and dodo.ColorsUnitframe.Castbar

    local isImp = false
    if C_Spell and C_Spell.IsSpellImportant and spellID and not issecretvalue(spellID) then
        local ok, v = pcall(C_Spell.IsSpellImportant, spellID)
        if ok and v then isImp = true end
    end
    local base
    if isImp then
        base = (CC and CC.importantColor) or { r = 1.00, g = 0.20, b = 0.78 }
    elseif bar_cast_type == "empower" then
        base = (CC and CC.empoweredColor) or { r = 0.00, g = 1.00, b = 0.00 }
    elseif bar_cast_type == "channel" then
        base = (CC and CC.channelColor) or { r = 0.39, g = 1.00, b = 0.39 }
    else
        base = (CC and CC.castColor) or { r = 1.00, g = 1.00, b = 0.00 }
    end
    local ni_c = (CC and CC.uninterruptible) or { r = 0.71, g = 0.71, b = 0.71 }
    bar.sb:SetStatusBarColor(
        C_CurveUtil.EvaluateColorValueFromBoolean(not_interruptible, ni_c.r, base.r),
        C_CurveUtil.EvaluateColorValueFromBoolean(not_interruptible, ni_c.g, base.g),
        C_CurveUtil.EvaluateColorValueFromBoolean(not_interruptible, ni_c.b, base.b)
    )
end

-- ==============================
-- 기능 3: 캐스팅 표시
-- ==============================
local function show_cast(unit)
    local name, _, texture, _, _, _, _, not_interruptible, spellID = UnitCastingInfo(unit)
    local is_ch = false
    if type(name) == "nil" then
        name, _, texture, _, _, _, not_interruptible, spellID = UnitChannelInfo(unit)
        is_ch = true
    end
    if type(name) == "nil" then return false end

    bar_is_channel = is_ch
    if is_ch then bar_cast_type = "channel" end

    -- oUF 방식: target/focus는 startMS/endMS 불신뢰 → DurationObject + SetTimerDuration
    local dur, dir
    if bar_cast_type == "empower" then
        dur = UnitEmpoweredChannelDuration(unit)
        dir = Enum.StatusBarTimerDirection.ElapsedTime
    elseif is_ch then
        dur = UnitChannelDuration(unit)
        dir = Enum.StatusBarTimerDirection.RemainingTime
    else
        dur = UnitCastingDuration(unit)
        dir = Enum.StatusBarTimerDirection.ElapsedTime
    end
    if dur then
        bar.sb:SetTimerDuration(dur, Enum.StatusBarInterpolation.Immediate, dir)
        bar.time_binding:SetDuration(dur)
        bar.time_binding:SetEnabled(true)
    end
    bar.time_text:Show()

    active_unit = unit
    if type(texture) ~= "nil" then bar.icon:SetTexture(texture) end
    bar.spell_text:SetText(name)
    apply_color(not_interruptible, spellID)

    -- 주문대상
    if bar.target_text then
        if UnitShouldDisplaySpellTargetName and UnitShouldDisplaySpellTargetName(unit) then
            -- UnitSpellTargetClass: 캐스팅 대상의 직업 토큰 (secret value 아님)
            local targetClass = UnitSpellTargetClass and UnitSpellTargetClass(unit)
            if targetClass then
                local cc = C_ClassColor.GetClassColor(targetClass)
                if cc then
                    bar.target_text:SetTextColor(cc:GetRGBA())
                else
                    bar.target_text:SetTextColor(1, 1, 1)
                end
            else
                bar.target_text:SetTextColor(1, 1, 1)
            end
            -- UnitSpellTargetName은 secret value → SetText에 직접 전달 (비교/분기 금지)
            bar.target_text:SetText(UnitSpellTargetName and UnitSpellTargetName(unit) or "")
            bar.target_text:Show()
        else
            bar.target_text:SetText("")
            bar.target_text:Hide()
        end
    end

    cast_active = true
    bar:Show()
    return true
end

-- ==============================
-- 기능 5: 우선순위 평가 (focus > target)
-- ==============================

local function update()
    if not bar then return end
    if is_edit_mode then return end
    if dodoDB.enableUnitCastBar == false then
        cast_active = false; bar:Hide(); active_unit = nil; return
    end

    if UnitExists("focus") then
        -- focus 있으면 target은 완전 무시 (focus 시전 없으면 빈 상태)
        local fn = UnitCastingInfo("focus")
        if type(fn) == "nil" then fn = UnitChannelInfo("focus") end
        if type(fn) ~= "nil" then
            if show_cast("focus") then return end
        end
    elseif UnitExists("target") then
        local tn = UnitCastingInfo("target")
        if type(tn) == "nil" then tn = UnitChannelInfo("target") end
        if type(tn) ~= "nil" then
            if show_cast("target") then return end
        end
    end

    cast_active = false; bar:Hide(); active_unit = nil
end

-- ==============================
-- 기능 5: 프레임 빌드
-- ==============================
local function build()
    if bar then return end

    bar = CreateFrame("Frame", "dodoTFCastbar", UIParent)
    bar:SetSize(BAR_W, BAR_H)
    bar:Hide()

    -- 아이콘
    local icon = bar:CreateTexture(nil, 'ARTWORK')
    icon:SetSize(BAR_H, BAR_H)
    icon:SetPoint('TOPLEFT', bar, 'TOPLEFT', 0, 0)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    bar.icon = icon

    -- 아이콘 테두리 (NineSlice)
    local icon_frame = CreateFrame('Frame', nil, bar)
    icon_frame:SetAllPoints(icon)
    icon_frame.NineSlice = CreateFrame('Frame', nil, icon_frame, 'NineSliceCodeTemplate')
    icon_frame.NineSlice:SetPoint('TOPLEFT',     icon_frame, 'TOPLEFT',     -4,  3)
    icon_frame.NineSlice:SetPoint('BOTTOMRIGHT', icon_frame, 'BOTTOMRIGHT',  7, -6)
    icon_frame.NineSlice:SetFrameLevel(icon_frame:GetFrameLevel() + 3)
    icon_frame.NineSlice:SetScale(0.6)
    NineSliceUtil.ApplyUniqueCornersLayout(icon_frame.NineSlice, 'UI-HUD-ActionBar-Frame')

    -- 캐스팅바 (StatusBar)
    local sb = CreateFrame('StatusBar', nil, bar)
    sb:SetPoint('LEFT',        icon, 'RIGHT',      6, 0)
    sb:SetPoint('BOTTOMRIGHT', bar,  'BOTTOMRIGHT', 0, 0)
    sb:SetStatusBarTexture([[Interface\Buttons\WHITE8X8]])
    sb:SetStatusBarColor(1, 0.7, 0)
    bar.sb = sb

    -- 배경
    sb.bg = sb:CreateTexture(nil, 'BACKGROUND')
    sb.bg:SetAllPoints()
    sb.bg:SetColorTexture(0.1, 0.1, 0.1, 0.8)

    -- 테두리 (NineSlice)
    sb.NineSlice = CreateFrame('Frame', nil, sb, 'NineSliceCodeTemplate')
    sb.NineSlice:SetPoint('TOPLEFT',     sb, 'TOPLEFT',     -4,  3)
    sb.NineSlice:SetPoint('BOTTOMRIGHT', sb, 'BOTTOMRIGHT',  7, -6)
    sb.NineSlice:SetFrameLevel(sb:GetFrameLevel() + 3)
    sb.NineSlice:SetScale(0.6)
    NineSliceUtil.ApplyUniqueCornersLayout(sb.NineSlice, 'UI-HUD-ActionBar-Frame')

    -- 차단 눈금 클립 (bar 자식 → StatusBar fill clip 영향 없음)
    local kick_clip = CreateFrame("Frame", nil, bar)
    kick_clip:SetAllPoints(sb)
    kick_clip:SetClipsChildren(true)
    kick_clip:SetFrameLevel(sb:GetFrameLevel() + 4)
    bar.kick_clip = kick_clip

    -- positioner: elapsed 위치 추적 (투명 StatusBar)
    local kick_positioner = CreateFrame("StatusBar", nil, kick_clip)
    kick_positioner:SetAllPoints(kick_clip)
    kick_positioner:SetStatusBarTexture([[Interface\Buttons\WHITE8X8]])
    kick_positioner:GetStatusBarTexture():SetAlpha(0)
    kick_positioner:SetMinMaxValues(0, 1)
    kick_positioner:SetValue(0)
    kick_positioner:Hide()
    bar.kick_positioner = kick_positioner

    -- marker: kickRem 크기만큼 채움 (투명), positioner 텍스처 우측에 부착
    local kick_marker = CreateFrame("StatusBar", nil, kick_clip)
    kick_marker:SetStatusBarTexture([[Interface\Buttons\WHITE8X8]])
    kick_marker:GetStatusBarTexture():SetAlpha(0)
    kick_marker:SetPoint("TOP",    kick_clip, "TOP")
    kick_marker:SetPoint("BOTTOM", kick_clip, "BOTTOM")
    kick_marker:SetPoint("LEFT",   kick_positioner:GetStatusBarTexture(), "RIGHT")
    kick_marker:SetMinMaxValues(0, 1)
    kick_marker:SetValue(0)
    kick_marker:Hide()
    bar.kick_marker = kick_marker

    -- tick: marker 텍스처 우측에 표시되는 2px 세로선
    local kick_tick = kick_clip:CreateTexture(nil, "OVERLAY", nil, 7)
    kick_tick:SetColorTexture(1, 0, 0, 1)
    kick_tick:SetWidth(2)
    kick_tick:SetPoint("TOP",    kick_clip,                         "TOP")
    kick_tick:SetPoint("BOTTOM", kick_clip,                         "BOTTOM")
    kick_tick:SetPoint("LEFT",   kick_marker:GetStatusBarTexture(), "RIGHT")
    kick_tick:Hide()
    bar.kick_tick = kick_tick

    -- 스킬 이름 텍스트
    local spell_text = sb:CreateFontString(nil, 'OVERLAY', 'SystemFont_Outline')
    spell_text:SetPoint('LEFT',  sb, 'LEFT',   5,   0)
    spell_text:SetPoint('RIGHT', sb, 'RIGHT', -40,  0)
    spell_text:SetJustifyH('LEFT')
    bar.spell_text = spell_text

    -- 시간 텍스트 + DurationTextBinding (시크릿 remaining 값 처리)
    local time_text = sb:CreateFontString(nil, 'OVERLAY', 'SystemFont_Outline')
    time_text:SetPoint('RIGHT', sb, 'RIGHT', -5, 0)
    time_text:SetJustifyH('RIGHT')
    bar.time_text = time_text

    local fmt = C_StringUtil.CreateSecondsFormatter()
    fmt:SetDefaultAbbreviation(Enum.SecondsFormatterAbbreviation.None)
    fmt:SetMinInterval(Enum.SecondsFormatterInterval.Seconds)
    fmt:SetMillisecondsThreshold(60)
    local binding = C_DurationUtil.CreateDurationTextBinding()
    binding:SetFormatter(fmt)
    binding:SetFontString(time_text)
    binding:SetEnabled(false)
    bar.time_binding = binding

    -- 주문대상 (바 우측 외부)
    local target_text = bar:CreateFontString(nil, 'OVERLAY', 'SystemFont_Outline')
    target_text:SetPoint('LEFT', sb, 'RIGHT', 6, 0)
    target_text:SetJustifyH('LEFT')
    target_text:Hide()
    bar.target_text = target_text

    -- SetTimerDuration이 바 진행을 구동 → OnUpdate는 차단 눈금만 담당
    bar:SetScript('OnUpdate', function()
        if not cast_active then return end
        update_kick_tick()
    end)
end

-- ==============================
-- 기능 6: LEM 등록
-- ==============================
local function register_lem()
    local LEM = LibStub("LibEditMode")
    local _sv = dodoDB.editMode and dodoDB.editMode[SYSTEM_NAME]
    local _pt = (_sv and _sv.point) and _sv or DEFAULT_PT

    bar:ClearAllPoints()
    bar:SetPoint(_pt.point, UIParent, _pt.relativePoint or _pt.point, _pt.xOfs or 0, _pt.yOfs or 0)

    LEM:AddFrame(bar, function(_, _, pt, x, y)
        dodoDB.editMode = dodoDB.editMode or {}
        dodoDB.editMode[SYSTEM_NAME] = { point = pt, relativePoint = pt, xOfs = x, yOfs = y }
    end, {
        point = _pt.point or "TOP",
        x     = _pt.xOfs  or 0,
        y     = _pt.yOfs  or 0,
    }, "TF 캐스팅바")

    LEM:RegisterCallback("enter", function()
        is_edit_mode = true
        bar.time_binding:SetEnabled(false)
        bar.sb:SetMinMaxValues(0, 1)
        bar.sb:SetValue(0.5)
        bar.spell_text:SetText("TF 캐스팅바")
        bar.time_text:SetText("2.5")
        if bar.target_text then bar.target_text:Hide() end
        if bar.kick_tick   then bar.kick_tick:Hide() end
        bar:Show()
    end)
    LEM:RegisterCallback("exit", function()
        is_edit_mode = false
        bar.sb:SetMinMaxValues(0, 1)
        bar.sb:SetValue(0)
        if not active_unit then
            bar.spell_text:SetText("")
            bar.time_text:SetText("")
            bar:Hide()
        end
    end)

    if LEM:IsInEditMode() then
        is_edit_mode = true
        bar.time_binding:SetEnabled(false)
        bar.sb:SetMinMaxValues(0, 1)
        bar.sb:SetValue(0.5)
        bar.spell_text:SetText("TF 캐스팅바")
        bar.time_text:SetText("2.5")
        if bar.target_text then bar.target_text:Hide() end
        if bar.kick_tick   then bar.kick_tick:Hide() end
        bar:Show()
    end
end

-- ==============================
-- 이벤트
-- ==============================
local evt = CreateFrame("Frame")

evt:SetScript("OnEvent", function(_, event, unit)
    if event == "PLAYER_LOGIN" then
        if dodoDB.enableUnitCastBar == nil then dodoDB.enableUnitCastBar = true end
        build()
        refresh_kick_spell()
        register_lem()
        update()
        return
    end

    if event == "SPELLS_CHANGED" then
        refresh_kick_spell(); return
    end

    if event == "PLAYER_TARGET_CHANGED" or event == "PLAYER_FOCUS_CHANGED" then
        update(); return
    end

    -- 이하 unit 이벤트 — target / focus 만 수신
    if event == "UNIT_SPELLCAST_START" then
        bar_cast_type = "cast"
        if unit == "target" and UnitExists("focus") then return end
        show_cast(unit)
    elseif event == "UNIT_SPELLCAST_CHANNEL_START" then
        bar_cast_type = "channel"
        if unit == "target" and UnitExists("focus") then return end
        show_cast(unit)
    elseif event == "UNIT_SPELLCAST_EMPOWER_START" then
        bar_cast_type = "empower"
        if unit == "target" and UnitExists("focus") then return end
        show_cast(unit)

    elseif event == "UNIT_SPELLCAST_DELAYED"
    or     event == "UNIT_SPELLCAST_CHANNEL_UPDATE"
    or     event == "UNIT_SPELLCAST_EMPOWER_UPDATE" then
        if unit == active_unit then show_cast(unit) end

    elseif event == "UNIT_SPELLCAST_STOP" then
        if unit == active_unit then
            cast_active = false
            bar.time_binding:SetEnabled(false)
            bar.time_text:SetText("")
            bar.sb:SetMinMaxValues(0, 1)
            bar.sb:SetValue(1)
            local CC = dodo.ColorsUnitframe and dodo.ColorsUnitframe.Castbar
            local c = CC and CC.successColor or { r = 0.39, g = 1.00, b = 0.39 }
            bar.sb:SetStatusBarColor(c.r, c.g, c.b)
            hide_kick_tick()
            if bar.target_text then bar.target_text:Hide() end
            active_unit = nil
            C_Timer.After(0.5, update)
        end

    elseif event == "UNIT_SPELLCAST_FAILED" then
        if unit == active_unit then
            cast_active = false
            bar.time_binding:SetEnabled(false)
            bar.time_text:SetText("")
            bar.time_text:Hide()
            bar.sb:SetMinMaxValues(0, 1)
            bar.sb:SetValue(1)
            bar.spell_text:SetText("실패")
            hide_kick_tick()
            if bar.target_text then bar.target_text:Hide() end
            active_unit = nil
            C_Timer.After(0.5, update)
        end

    elseif event == "UNIT_SPELLCAST_CHANNEL_STOP"
    or     event == "UNIT_SPELLCAST_EMPOWER_STOP" then
        if unit == active_unit then
            cast_active = false
            bar.time_binding:SetEnabled(false)
            bar.time_text:SetText("")
            bar.sb:SetMinMaxValues(0, 1)
            bar.sb:SetValue(1)
            local CC = dodo.ColorsUnitframe and dodo.ColorsUnitframe.Castbar
            local c = CC and CC.successColor or { r = 0.39, g = 1.00, b = 0.39 }
            bar.sb:SetStatusBarColor(c.r, c.g, c.b)
            hide_kick_tick()
            if bar.target_text then bar.target_text:Hide() end
            active_unit = nil
            C_Timer.After(0.5, update)
        end

    elseif event == "UNIT_SPELLCAST_INTERRUPTED" then
        if unit == active_unit then
            cast_active = false
            bar.time_binding:SetEnabled(false)
            bar.time_text:SetText("")
            bar.time_text:Hide()
            bar.sb:SetMinMaxValues(0, 1)
            bar.sb:SetValue(1)
            local CC = dodo.ColorsUnitframe and dodo.ColorsUnitframe.Castbar
            local c = CC and CC.interruptedColor or { r = 0.8, g = 0, b = 0 }
            bar.sb:SetStatusBarColor(c.r, c.g, c.b)
            bar.spell_text:SetText("실패")
            hide_kick_tick()
            if bar.target_text then bar.target_text:Hide() end
            active_unit = nil
            C_Timer.After(0.5, update)
        end

    elseif event == "UNIT_SPELLCAST_INTERRUPTIBLE"
    or     event == "UNIT_SPELLCAST_NOT_INTERRUPTIBLE" then
        if unit ~= active_unit then return end
        local _, _, _, _, _, _, _, ni, sid = UnitCastingInfo(unit)
        if type(ni) == "nil" then _, _, _, _, _, _, ni, sid = UnitChannelInfo(unit) end
        if type(ni) ~= "nil" then apply_color(ni, sid) end
    end
end)

evt:RegisterEvent("PLAYER_LOGIN")
evt:RegisterEvent("PLAYER_TARGET_CHANGED")
evt:RegisterEvent("PLAYER_FOCUS_CHANGED")
evt:RegisterEvent("SPELLS_CHANGED")
evt:RegisterUnitEvent("UNIT_SPELLCAST_START",             "target", "focus")
evt:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_START",     "target", "focus")
evt:RegisterUnitEvent("UNIT_SPELLCAST_EMPOWER_START",     "target", "focus")
evt:RegisterUnitEvent("UNIT_SPELLCAST_DELAYED",           "target", "focus")
evt:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_UPDATE",    "target", "focus")
evt:RegisterUnitEvent("UNIT_SPELLCAST_EMPOWER_UPDATE",    "target", "focus")
evt:RegisterUnitEvent("UNIT_SPELLCAST_STOP",              "target", "focus")
evt:RegisterUnitEvent("UNIT_SPELLCAST_FAILED",            "target", "focus")
evt:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_STOP",      "target", "focus")
evt:RegisterUnitEvent("UNIT_SPELLCAST_EMPOWER_STOP",      "target", "focus")
evt:RegisterUnitEvent("UNIT_SPELLCAST_INTERRUPTED",       "target", "focus")
evt:RegisterUnitEvent("UNIT_SPELLCAST_INTERRUPTIBLE",     "target", "focus")
evt:RegisterUnitEvent("UNIT_SPELLCAST_NOT_INTERRUPTIBLE", "target", "focus")
