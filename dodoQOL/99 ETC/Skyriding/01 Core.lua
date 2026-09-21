---@diagnostic disable: lowercase-global, undefined-field, undefined-global
local dodo = _G.dodo
dodoDB = dodoDB or {}

-- ==============================
-- 캐싱
-- ==============================
local C_PlayerInfo  = C_PlayerInfo
local C_Spell       = C_Spell
local C_UnitAuras   = C_UnitAuras
local CreateFrame   = CreateFrame
local FrameDeltaLerp = FrameDeltaLerp
local GetTime       = GetTime
local LibStub       = LibStub
local math_abs      = math.abs
local math_min      = math.min
local math_pow      = math.pow
local math_pi       = math.pi
local string_format = string.format

-- ==============================
-- 상수
-- ==============================
local SURGE_SPELL_ID  = 372608
local THRILL_BUFF_ID  = 377234
local GALE_BUFF_ID    = 388367
local ASCENT_SPELL_ID = 372610
local ASCENT_DURATION = 3.5
local SURGE_DURATION  = 1.0
local NUM_ESSENCES    = 6
local ESSENCE_SIZE    = 24
local MAX_SPEED       = 84        -- yards/sec at 1200%
local UPDATE_THROTTLE = 0.0167    -- ~60fps 캡 (Falcon 기준)

-- ==============================
-- 상태
-- ==============================
local hud_frame, anchor_frame
local spark, text, diamond
local _gliding         = false
local smooth_speed     = 0
local prev_charges     = 0
local charges_dirty    = true
local ascent_start     = 0
local surge_start      = 0
local elapsed_acc      = 0
local _spell_registered = false

-- OnUpdate forward declaration (sync_tick에서 참조)
local on_update

-- ==============================
-- 정적 곡선 함수 (핫패스용, 클로저 없음)
-- ==============================
local function curve_speed(v)
    local t = 0.6
    if v <= t then return v end
    return t + 0.6 * math_pow(math_min(v - t, 0.4) * 2.5, 1.2)
end

-- ==============================
-- 틱 관리
-- ==============================
local function tick_wanted()
    return _gliding or charges_dirty
end

local function sync_tick()
    if not hud_frame then return end
    if hud_frame:IsShown() and tick_wanted() then
        hud_frame:SetScript("OnUpdate", on_update)
    else
        hud_frame:SetScript("OnUpdate", nil)
    end
end

-- ==============================
-- 스펠 이벤트 등록/해제 (표시 중일 때만)
-- ==============================
local evt_frame

local function register_spell_events()
    if _spell_registered or not evt_frame then return end
    evt_frame:RegisterEvent("SPELL_UPDATE_CHARGES")
    evt_frame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
    _spell_registered = true
end

local function unregister_spell_events()
    if not _spell_registered or not evt_frame then return end
    evt_frame:UnregisterEvent("SPELL_UPDATE_CHARGES")
    evt_frame:UnregisterEvent("UNIT_SPELLCAST_SUCCEEDED")
    _spell_registered = false
end

-- ==============================
-- 표시/숨김
-- ==============================
local function update_visual()
    if not hud_frame then return end
    local enabled = (dodoDB and dodoDB.enableSkyriding ~= false)
    if not enabled then
        hud_frame:Hide()
        hud_frame:SetScript("OnUpdate", nil)
        _gliding = false
        unregister_spell_events()
        return
    end
    local is_gliding = C_PlayerInfo.GetGlidingInfo()
    _gliding = (is_gliding == true)
    if _gliding then
        hud_frame:Show()
        charges_dirty = true
        register_spell_events()
    else
        hud_frame:Hide()
        unregister_spell_events()
    end
    sync_tick()
end
dodo.SkyridingUpdateVisual = update_visual

-- ==============================
-- 정수(Essence) 업데이트
-- ==============================
local function update_essence_status()
    local info = C_Spell.GetSpellCharges(SURGE_SPELL_ID)
    if not info then return end

    local cur         = info.currentCharges
    local charge_start = info.cooldownStartTime
    local charge_dur  = info.cooldownDuration
    local actual_dur  = (charge_dur and charge_dur > 0) and charge_dur or 10

    if cur < prev_charges then
        for i = cur + 1, prev_charges do
            local e = hud_frame.essences[i]
            if e then e.deplete:Show(); e.deplete.anim:Play(); e.iconActive:Hide() end
        end
    elseif cur > prev_charges then
        for i = prev_charges + 1, cur do
            local e = hud_frame.essences[i]
            if e then e.done:Show(); e.done.anim:Play() end
        end
    end
    prev_charges = cur

    for i = 1, NUM_ESSENCES do
        local e = hud_frame.essences[i]
        if i <= cur then
            e.filling:Hide(); e.cd:Hide(); e.ebg:SetDesaturated(false)
            if not e.deplete.anim:IsPlaying() then e.iconActive:Show() end
        elseif i == cur + 1 then
            e.iconActive:Hide(); e.filling:Show()
            local progress = math_min((GetTime() - charge_start) / actual_dur, 1)
            local angle = -progress * (math_pi * 2)
            e.filling.timer:SetRotation(angle); e.filling.trail:SetRotation(angle)
            e.cd:Show(); e.cd:SetCooldown(charge_start, actual_dur); e.ebg:SetDesaturated(true)
        else
            e.iconActive:Hide(); e.filling:Hide(); e.cd:Hide(); e.ebg:SetDesaturated(true)
        end
    end

    charges_dirty = (cur < NUM_ESSENCES)
end

-- ==============================
-- OnUpdate (핫패스 — 정적 함수, 익명 클로저 없음)
-- ==============================
on_update = function(self, dt)
    elapsed_acc = elapsed_acc + dt
    if elapsed_acc < UPDATE_THROTTLE then return end
    elapsed_acc = 0

    local bar_w = (dodoDB and dodoDB.skyridingBarWidth) or dodo.SK_DEFAULTS.skyridingBarWidth

    -- 속도 폴링
    local is_gliding, _, fwd_speed = C_PlayerInfo.GetGlidingInfo()
    if not is_gliding then
        self:Hide()
        _gliding = false
        unregister_spell_events()
        sync_tick()
        smooth_speed = 0
        return
    end

    local target_speed = fwd_speed / MAX_SPEED
    if math_abs(smooth_speed - target_speed) > 0.0001 then
        smooth_speed = FrameDeltaLerp(smooth_speed, target_speed, 0.2)
    end
    local final_val = curve_speed(smooth_speed)
    self:SetValue(final_val)
    spark:SetPoint("CENTER", self, "LEFT", (final_val / 1.2) * bar_w, 0)
    text:SetText(string_format("%.0f", fwd_speed * (100 / 7)))

    -- 버프 색상
    local now     = GetTime()
    local thrill  = C_UnitAuras.GetPlayerAuraBySpellID(THRILL_BUFF_ID)
    local gale    = C_UnitAuras.GetPlayerAuraBySpellID(GALE_BUFF_ID)
    local boosting = thrill and (now < ascent_start + ASCENT_DURATION)
    local surging  = (now < surge_start + SURGE_DURATION)

    if boosting then
        -- 하늘의 전율(377234) + 하늘로의 도약(372610) 직후 — 상승 가속 중
        self:SetStatusBarTexture("UI-CastingBar-Filling-Channel")
        self:SetStatusBarColor(1, 1, 1)
        text:SetTextColor(0.1, 1, 0.1)
        spark:SetVertexColor(0.1, 1, 0.1)
    elseif gale then
        -- 질풍(388367) 버프 — 지면 활강
        self:SetStatusBarTexture("UI-CastingBar-Filling-ApplyingCrafting")
        self:SetStatusBarColor(0.5, 1, 1)
        text:SetTextColor(0.2, 0.5, 0.94)
        spark:SetVertexColor(0.41, 0.8, 0.94)
    elseif thrill then
        -- 하늘의 전율(377234) 버프 보유 — 고속 비행
        self:SetStatusBarTexture("UI-CastingBar-Filling-ApplyingCrafting")
        self:SetStatusBarColor(1, 1, 1)
        text:SetTextColor(0, 0.45, 0.95)
        spark:SetVertexColor(0, 0.45, 0.95)
    elseif surging then
        -- 앞으로 돌진(372608) 직후 — 수평 가속
        self:SetStatusBarTexture("UI-CastingBar-Filling-Standard")
        self:SetStatusBarColor(1, 0.9, 0.5)
        text:SetTextColor(1, 1, 1)
        spark:SetVertexColor(1, 1, 1)
    else
        -- LowSpeed: 버프 없음 / 저속
        self:SetStatusBarTexture("UI-CastingBar-Interrupted")
        self:SetStatusBarColor(0.86, 0.32, 0.39)
        text:SetTextColor(0.86, 0.32, 0.39)
        spark:SetVertexColor(0.86, 0.32, 0.39)
    end

    -- 정수 충전 업데이트 (dirty일 때만)
    if charges_dirty then
        update_essence_status()
    end
end

-- ==============================
-- 크기/폰트 적용
-- ==============================
local function apply_size()
    if not hud_frame then return end
    local D = dodo.SK_DEFAULTS
    local w = (dodoDB and dodoDB.skyridingBarWidth)  or D.skyridingBarWidth
    local h = (dodoDB and dodoDB.skyridingBarHeight) or D.skyridingBarHeight
    hud_frame:SetSize(w, h)
    anchor_frame:SetSize(w + 80, h + ESSENCE_SIZE + 8)
    if spark   then spark:SetSize(4, h * 1.5) end
    if diamond then
        local target_val  = (789 / 100 * 7) / 84
        local marker_pos  = curve_speed(target_val)
        diamond:ClearAllPoints()
        diamond:SetPoint("CENTER", hud_frame, "LEFT", (marker_pos / 1.2) * w, 0)
    end
end
dodo.SkyridingApplySize = apply_size

local function apply_font()
    if not text then return end
    local size = (dodoDB and dodoDB.skyridingFontSize) or dodo.SK_DEFAULTS.skyridingFontSize
    text:SetFont("Fonts\\2002.TTF", size, "OUTLINE")
end
dodo.SkyridingApplyFont = apply_font

-- ==============================
-- UI 생성 (PLAYER_LOGIN에서 1회 호출)
-- ==============================
local function build_hud()
    if hud_frame then return end
    local D = dodo.SK_DEFAULTS
    local bar_w = (dodoDB and dodoDB.skyridingBarWidth)  or D.skyridingBarWidth
    local bar_h = (dodoDB and dodoDB.skyridingBarHeight) or D.skyridingBarHeight

    -- LEM 앵커
    local LEM = LibStub("LibEditMode")
    local _dp = { point="CENTER", relativePoint="CENTER", xOfs=0, yOfs=-150 }
    local _sv = dodoDB.editMode and dodoDB.editMode["SkyridingHUD"]
    local _pt = (_sv and _sv.point) and _sv or _dp

    anchor_frame = CreateFrame("Frame", "dodoEditModeSkyridingHUD", UIParent)
    anchor_frame:SetSize(bar_w + 80, bar_h + ESSENCE_SIZE + 8)
    anchor_frame:SetPoint(_pt.point, UIParent, _pt.relativePoint or _pt.point, _pt.xOfs or 0, _pt.yOfs or 0)

    LEM:AddFrame(anchor_frame, function(f, layout, pt, x, y)
        dodoDB.editMode = dodoDB.editMode or {}
        dodoDB.editMode["SkyridingHUD"] = { point=pt, relativeTo="UIParent", relativePoint=pt, xOfs=x, yOfs=y }
    end, { point=_pt.point, x=_pt.xOfs or 0, y=_pt.yOfs or 0 }, "하늘타기 HUD")

    LEM:AddFrameSettings(anchor_frame, {
        { kind=LEM.SettingType.Checkbox, name="하늘타기 HUD 활성화", default=true,
          get=function() return dodoDB and dodoDB.enableSkyriding ~= false end,
          set=function(l, v)
              if dodoDB then dodoDB.enableSkyriding = v end
              update_visual()
          end },
    })

    -- 속도 StatusBar
    hud_frame = CreateFrame("StatusBar", "dodoSkyridingHUD", anchor_frame)
    hud_frame:SetSize(bar_w, bar_h)
    hud_frame:SetPoint("TOPLEFT", anchor_frame, "TOPLEFT", 0, 0)
    hud_frame:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    hud_frame:SetMinMaxValues(0, 1.2)
    hud_frame:Hide()

    local bg = hud_frame:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(true)
    bg:SetAtlas("ui-castingbar-background", true)
    bg:SetDesaturated(true)

    -- 정수(Essence) 6칸
    hud_frame.essences = {}
    local total_w = ESSENCE_SIZE * NUM_ESSENCES

    for i = 1, NUM_ESSENCES do
        local container = CreateFrame("Frame", nil, hud_frame)
        container:SetSize(ESSENCE_SIZE, ESSENCE_SIZE)
        if i == 1 then
            container:SetPoint("TOP", bg, "BOTTOM", -(total_w / 2) + (ESSENCE_SIZE / 2), -4)
        else
            container:SetPoint("LEFT", hud_frame.essences[i-1].container, "RIGHT", 0, 0)
        end

        local ebg = container:CreateTexture(nil, "BACKGROUND")
        ebg:SetAtlas("UF-Essence-BG", true)
        ebg:SetAllPoints(); ebg:SetDesaturated(true)

        local filling = CreateFrame("Frame", nil, container)
        filling:SetAllPoints(); filling:Hide()
        filling.timer = filling:CreateTexture(nil, "OVERLAY")
        filling.timer:SetAtlas("UF-Essence-TimerSpin", true); filling.timer:SetPoint("CENTER")
        filling.trail = filling:CreateTexture(nil, "ARTWORK")
        filling.trail:SetAtlas("UF-Essence-Spinner", true); filling.trail:SetPoint("CENTER")

        local cd = CreateFrame("Cooldown", nil, container, "CooldownFrameTemplate")
        cd:SetAllPoints(); cd:SetDrawSwipe(false); cd:SetDrawEdge(false); cd:SetHideCountdownNumbers(true)

        local icon_active = container:CreateTexture(nil, "OVERLAY", nil, 5)
        icon_active:SetAtlas("UF-Essence-Icon-Active", true); icon_active:SetPoint("CENTER"); icon_active:Hide()

        local done = CreateFrame("Frame", nil, container)
        done:SetAllPoints(); done:Hide()
        done.burst = done:CreateTexture(nil, "OVERLAY", nil, 6)
        done.burst:SetAtlas("UF-Essence-FX-Burst", true); done.burst:SetPoint("CENTER")
        done.rim = done:CreateTexture(nil, "OVERLAY", nil, 4)
        done.rim:SetAtlas("UF-Essence-RimGlow", true); done.rim:SetPoint("CENTER")
        done.anim = done:CreateAnimationGroup()
        local b_rot   = done.anim:CreateAnimation("Rotation"); b_rot:SetChildKey("burst"); b_rot:SetDuration(0.3); b_rot:SetDegrees(-30)
        local b_alpha = done.anim:CreateAnimation("Alpha");    b_alpha:SetChildKey("burst"); b_alpha:SetFromAlpha(1); b_alpha:SetToAlpha(0); b_alpha:SetDuration(0.5)
        local r_scale = done.anim:CreateAnimation("Scale");    r_scale:SetChildKey("rim");   r_scale:SetScale(1.2, 1.2); r_scale:SetDuration(0.4)
        local r_alpha = done.anim:CreateAnimation("Alpha");    r_alpha:SetFromAlpha(1); r_alpha:SetToAlpha(0); r_alpha:SetDuration(0.4)
        done.anim:SetScript("OnFinished", function() done:Hide() end)

        local deplete = CreateFrame("Frame", nil, container)
        deplete:SetAllPoints(); deplete:Hide()
        deplete.smoke = deplete:CreateTexture(nil, "OVERLAY", nil, 7)
        deplete.smoke:SetAtlas("UF-Essence-FX-Smoke", true); deplete.smoke:SetPoint("CENTER")
        deplete.anim = deplete:CreateAnimationGroup()
        local s_scale = deplete.anim:CreateAnimation("Scale");       s_scale:SetScale(1.4, 1.4); s_scale:SetDuration(0.6)
        local s_alpha = deplete.anim:CreateAnimation("Alpha");       s_alpha:SetFromAlpha(1); s_alpha:SetToAlpha(0); s_alpha:SetDuration(0.6)
        local s_trans = deplete.anim:CreateAnimation("Translation"); s_trans:SetOffset(0, 10); s_trans:SetDuration(0.6)
        deplete.anim:SetScript("OnFinished", function() deplete:Hide() end)

        hud_frame.essences[i] = {
            container  = container,
            ebg        = ebg,
            cd         = cd,
            filling    = filling,
            iconActive = icon_active,
            done       = done,
            deplete    = deplete,
        }
    end

    -- 장식
    local border = hud_frame:CreateTexture(nil, "OVERLAY", nil, 1)
    border:SetAtlas("UI-CastingBar-Frame", true)
    border:SetPoint("TOPLEFT",     hud_frame, "TOPLEFT",     -2,  3)
    border:SetPoint("BOTTOMRIGHT", hud_frame, "BOTTOMRIGHT",  2, -3)

    local target_val = (789 / 100 * 7) / 84
    local marker_pos = curve_speed(target_val)
    diamond = hud_frame:CreateTexture(nil, "OVERLAY", nil, 7)
    diamond:SetAtlas("gradientbar-marker-diamond", true)
    diamond:SetSize(16, 16)
    diamond:SetPoint("CENTER", hud_frame, "LEFT", (marker_pos / 1.2) * bar_w, 0)

    spark = hud_frame:CreateTexture(nil, "OVERLAY", nil, 6)
    spark:SetAtlas("UI-CastingBar-Pip", true)
    spark:SetSize(4, bar_h * 1.5)
    spark:SetBlendMode("ADD")

    text = hud_frame:CreateFontString(nil, "OVERLAY")
    text:SetFont("Fonts\\2002.TTF", (dodoDB and dodoDB.skyridingFontSize) or D.skyridingFontSize, "OUTLINE")
    text:SetPoint("LEFT", hud_frame, "RIGHT", 12, 0)
end

-- ==============================
-- 이벤트 프레임
-- ==============================
evt_frame = CreateFrame("Frame")
evt_frame:RegisterEvent("PLAYER_LOGIN")

evt_frame:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_LOGIN" then
        self:UnregisterEvent("PLAYER_LOGIN")
        self:RegisterEvent("PLAYER_ENTERING_WORLD")
        self:RegisterEvent("PLAYER_IS_GLIDING_CHANGED")

        build_hud()
        update_visual()

    elseif event == "PLAYER_ENTERING_WORLD" then
        charges_dirty = true
        update_visual()

    elseif event == "PLAYER_IS_GLIDING_CHANGED" then
        local is_gliding = C_PlayerInfo.GetGlidingInfo()
        _gliding = (is_gliding == true)
        if _gliding and hud_frame then
            local enabled = (dodoDB and dodoDB.enableSkyriding ~= false)
            if enabled then
                hud_frame:Show()
                charges_dirty = true
                register_spell_events()
                sync_tick()
            end
        elseif hud_frame then
            hud_frame:Hide()
            unregister_spell_events()
            sync_tick()
        end

    elseif event == "SPELL_UPDATE_CHARGES" then
        charges_dirty = true
        sync_tick()

    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        local unit, _, sid = ...
        if unit == "player" then
            if     sid == SURGE_SPELL_ID  then surge_start  = GetTime()
            elseif sid == ASCENT_SPELL_ID then ascent_start = GetTime()
            end
        end
    end
end)
