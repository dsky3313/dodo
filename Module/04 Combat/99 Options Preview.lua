-- ==============================
-- 전투 미리보기 Mixin
-- ==============================
---@diagnostic disable: lowercase-global, undefined-field, undefined-global
local addonName, dodo = ...
dodoDB = dodoDB or {}

local C_Spell     = C_Spell
local CreateFrame = CreateFrame
local GetTime     = GetTime
local math_max    = math.max

local COLORS = {
    { 0.32, 0.66, 1.00 }, { 0.67, 0.16, 1.00 }, { 0.70, 0.47, 0.00 },
    { 0.00, 1.00, 0.00 }, { 1.00, 0.29, 0.17 }, { 0.50, 0.50, 0.50 },
}
local ICONS    = { 135900, 136121, 135869, 135925, 132242, 136183 }
local SPELLS_BB = { 2825, 20484 }

local _preview_ref   = nil
local _tab_change_fn = nil

dodoCombatPreviewMixin = dodo.UI:CreatePreviewMixin({
    GetExtent = function() return 160 end,
    ref       = function(f) _preview_ref = f end,
    trigger   = function() if _tab_change_fn then _tab_change_fn() end end,
    panels    = {
        { -- 탭1: 자원바
            OnLoad = function(p, ns)
                p.bar1 = CreateFrame("StatusBar", nil, p)
                p.bar1:SetStatusBarTexture([[Interface\BUTTONS\WHITE8X8]])
                p.bar1:GetStatusBarTexture():SetAtlas("UI-HUD-CoolDownManager-Bar")
                local bg1 = p.bar1:CreateTexture(nil, "BACKGROUND")
                bg1:SetAtlas("UI-HUD-CoolDownManager-Bar-BG")
                bg1:SetPoint("TOPLEFT",     p.bar1, "TOPLEFT",     -2,  2)
                bg1:SetPoint("BOTTOMRIGHT", p.bar1, "BOTTOMRIGHT",  6, -7)
                p.bar1.countPower = p.bar1:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
                p.bar1.countPower:SetPoint("CENTER", p.bar1, "CENTER", 0, 3)
                p.bar1.countPower:SetJustifyH("CENTER")
                p.bar2 = CreateFrame("StatusBar", nil, p)
                p.bar2:SetStatusBarTexture([[Interface\BUTTONS\WHITE8X8]])
                p.bar2:GetStatusBarTexture():SetAtlas("UI-HUD-CoolDownManager-Bar")
                local bg2 = p.bar2:CreateTexture(nil, "BACKGROUND")
                bg2:SetAtlas("UI-HUD-CoolDownManager-Bar-BG")
                bg2:SetPoint("TOPLEFT",     p.bar2, "TOPLEFT",     -2,  2)
                bg2:SetPoint("BOTTOMRIGHT", p.bar2, "BOTTOMRIGHT",  6, -7)
                p.bar2.countStack = p.bar2:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
                p.bar2.countStack:SetPoint("RIGHT", p.bar2, "RIGHT", -5, 3)
                p.bar2.countStack:SetJustifyH("RIGHT")
                -- rune 모드용 서브바 (죽기)
                p.bar2_runebars = {}
                for i = 1, 6 do
                    local rb = CreateFrame("StatusBar", nil, p)
                    rb:SetStatusBarTexture([[Interface\BUTTONS\WHITE8X8]])
                    rb:GetStatusBarTexture():SetAtlas("UI-HUD-CoolDownManager-Bar")
                    local rbg = rb:CreateTexture(nil, "BACKGROUND")
                    rbg:SetAtlas("UI-HUD-CoolDownManager-Bar-BG")
                    rbg:SetPoint("TOPLEFT",     rb, "TOPLEFT",     -2,  2)
                    rbg:SetPoint("BOTTOMRIGHT", rb, "BOTTOMRIGHT",  6, -7)
                    rb:Hide()
                    p.bar2_runebars[i] = rb
                end
            end,
            Update = function(p, ns)
                local D   = dodo.COMBAT_DEFAULTS
                local db  = dodoDB or {}
                local RB  = dodo.ResourceBar
                local w   = db.resourceBarWidth  or D.resourceBarWidth
                local h1  = db.resourceBarHeight or D.resourceBarHeight
                local h2  = math_max(h1 - 3, 5)
                -- bar1 색상: 실제 power 모듈 캐싱 색상
                local c   = (RB and RB.cachedPowerColor) or (RB and RB.cachedSpecColor) or { r=1, g=0.59, b=0.20 }
                -- bar2 barmode 및 색상
                local bar2_config = RB and RB.bar2Frame and RB.bar2Frame.buffConfig
                local bar2_mode   = bar2_config and bar2_config.barMode
                local c2  = (bar2_config and bar2_config.color) or (RB and RB.cachedSpecColor) or { r=0.20, g=0.85, b=1.00 }
                local show_bar2 = db.useResourceBar2 ~= false

                p.bar1:SetSize(w, h1)
                p.bar1:ClearAllPoints()
                p.bar1:SetPoint("CENTER", ns, "CENTER", 0, h2 / 2 + 2)
                p.bar1:SetStatusBarColor(c.r, c.g, c.b, 1)
                p.bar1:SetMinMaxValues(0, 100)
                p.bar1:SetValue(75)
                p.bar1:SetShown(db.useResourceBar1 ~= false)
                if p.bar1.countPower then p.bar1.countPower:SetText("75") end

                -- bar2 위치는 항상 설정 (runebar 앵커 기준)
                p.bar2:SetSize(w, h2)
                p.bar2:ClearAllPoints()
                p.bar2:SetPoint("TOP", p.bar1, "BOTTOM", 0, -4)

                if bar2_mode == "rune" then
                    p.bar2:Hide()
                    local runeW = (w - 5) / 6
                    local fakeVals = { 1, 1, 1, 1, 0.7, 0.3 }
                    for i = 1, 6 do
                        local rb = p.bar2_runebars[i]
                        local ready = (i <= 4)
                        rb:SetSize(runeW, h2)
                        rb:ClearAllPoints()
                        rb:SetPoint("LEFT", p.bar2, "LEFT", (i - 1) * (runeW + 1), 0)
                        rb:SetMinMaxValues(0, 1)
                        if ready then
                            rb:SetStatusBarColor(c2.r, c2.g, c2.b, 1)
                            rb:SetValue(1)
                        else
                            rb:SetStatusBarColor(1, 1, 1, 1)
                            rb:SetValue(fakeVals[i])
                        end
                        rb:SetShown(show_bar2)
                    end
                else
                    for _, rb in ipairs(p.bar2_runebars) do rb:Hide() end
                    p.bar2:SetStatusBarColor(c2.r, c2.g, c2.b, 1)
                    p.bar2:SetMinMaxValues(0, 100)
                    p.bar2:SetValue(50)
                    p.bar2:SetShown(show_bar2)
                    if p.bar2.countStack then p.bar2.countStack:SetText("3") end
                end
            end,
        },
        { -- 탭2: 디버프
            OnLoad = function(p, ns)
                local DISPEL_ATLASES = {
                    Magic="RaidFrame-Icon-DebuffMagic",   Curse="RaidFrame-Icon-DebuffCurse",
                    Disease="RaidFrame-Icon-DebuffDisease", Poison="RaidFrame-Icon-DebuffPoison",
                    Bleed="RaidFrame-Icon-DebuffBleed",
                }
                p.icon_frames = {}
                for i = 1, 6 do
                    local f = CreateFrame("Frame", nil, p)
                    -- icon: 3px inset — AuraBorder.tga 투명 margin(~2-3px) 안으로 들어오게
                    f.icon = f:CreateTexture(nil, "BACKGROUND")
                    f.icon:SetPoint("TOPLEFT",     f, "TOPLEFT",      3, -3)
                    f.icon:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -3,  3)
                    f.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
                    -- cooldown swipe
                    f.cooldown = CreateFrame("Cooldown", nil, f, "CooldownFrameTemplate")
                    f.cooldown:SetAllPoints(f.icon)
                    f.cooldown:SetReverse(true)
                    f.cooldown:SetDrawEdge(false)
                    f.cooldown:SetDrawSwipe(true)
                    f.cooldown:SetHideCountdownNumbers(false)
                    f.cooldown:Hide()
                    -- cooldown 위에 border/count 올리기 위한 오버레이 프레임
                    local ov = CreateFrame("Frame", nil, f)
                    ov:SetAllPoints(f)
                    ov:SetFrameLevel(f:GetFrameLevel() + 2)
                    -- border
                    f.border = ov:CreateTexture(nil, "ARTWORK")
                    f.border:SetPoint("CENTER", f, "CENTER")
                    f.border:SetTexture("Interface\\Addons\\dodo\\Media\\Texture\\AuraBorder.tga")
                    -- count (NumberFontNormal → 폰트 미설정 에러 없음)
                    f.count = ov:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
                    f.count:SetPoint("BOTTOMRIGHT", ov, "BOTTOMRIGHT", -2, 2)
                    f.count:SetJustifyH("RIGHT")
                    f.count:SetTextColor(1, 1, 0)
                    -- dispel 인디케이터
                    for name, atlas in pairs(DISPEL_ATLASES) do
                        local di = ov:CreateTexture(nil, "OVERLAY")
                        di:SetAtlas(atlas)
                        di:SetSize(14, 14)
                        di:SetPoint("TOPRIGHT", ov, "TOPRIGHT", 1, 1)
                        di:Hide()
                        f["dispel" .. name] = di
                    end
                    f:Hide()
                    p.icon_frames[i] = f
                end
            end,
            Update = function(p, ns)
                local DISPEL_NAMES  = { "Magic", "Curse", "Disease", "Poison", "Bleed" }
                local BORDER_COLORS = {
                    Magic   = { 0.32, 0.66, 1.00 },
                    Curse   = { 0.67, 0.16, 1.00 },
                    Disease = { 0.70, 0.47, 0.00 },
                    Poison  = { 0.00, 1.00, 0.00 },
                    Bleed   = { 1.00, 0.29, 0.17 },
                }
                local FAKE = {
                    { icon=135900, count=1, dispel="Magic",   duration=15 },
                    { icon=136121, count=2, dispel="Curse",   duration=10 },
                    { icon=135869, count=0, dispel="Disease", duration=8  },
                    { icon=135925, count=5, dispel="Poison",  duration=12 },
                    { icon=132242, count=0, dispel="Bleed",   duration=20 },
                    { icon=136183, count=0, dispel=nil,       duration=0  },
                }
                local D   = dodo.COMBAT_DEFAULTS
                local db  = dodoDB or {}
                local sz  = db.debuffSize or D.debuffSize
                local max = db.debuffMax  or D.debuffMax
                local gap = 2
                for i = 1, 6 do
                    local f = p.icon_frames[i]
                    if i <= max then
                        local data = FAKE[i] or {}
                        f:SetSize(sz, sz)
                        f.border:SetSize(sz, sz)
                        f:ClearAllPoints()
                        f:SetPoint("CENTER", ns, "CENTER", (i - (max + 1) / 2) * (sz + gap), 0)
                        f.icon:SetTexture(data.icon)
                        f.count:SetText((data.count and data.count > 0) and data.count or "")
                        local c = data.dispel and BORDER_COLORS[data.dispel]
                        if c then
                            f.border:SetVertexColor(c[1], c[2], c[3])
                        else
                            f.border:SetVertexColor(0.5, 0.5, 0.5)
                        end
                        if data.duration and data.duration > 0 then
                            f.cooldown:SetCooldown(GetTime(), data.duration)
                            f.cooldown:Show()
                        else
                            f.cooldown:Clear()
                            f.cooldown:Hide()
                        end
                        for _, name in ipairs(DISPEL_NAMES) do
                            local di = f["dispel" .. name]
                            if di then
                                di:SetAlpha(name == data.dispel and 1 or 0)
                                di:Show()
                            end
                        end
                        f:Show()
                    else
                        f:Hide()
                    end
                end
            end,
        },
        { -- 탭3: 혈부활
            OnLoad = function(p, ns)
                p.icon_frames = {}
                for i = 1, 2 do
                    local f = CreateFrame("Frame", nil, p)
                    local bg = f:CreateTexture(nil, "BACKGROUND")
                    bg:SetAllPoints()
                    bg:SetColorTexture(0.15, 0.15, 0.15, 0.9)
                    f.icon = f:CreateTexture(nil, "ARTWORK")
                    f.icon:SetPoint("TOPLEFT",     f, "TOPLEFT",      2, -2)
                    f.icon:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -2,  2)
                    f.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
                    local info = C_Spell.GetSpellInfo and C_Spell.GetSpellInfo(SPELLS_BB[i])
                    if info and info.iconID then f.icon:SetTexture(info.iconID) end
                    -- cooldown: icon 텍스쳐 기준 앵커 (Icon.lua 패턴)
                    f.cooldown = CreateFrame("Cooldown", nil, f, "CooldownFrameTemplate")
                    f.cooldown:SetPoint("TOPLEFT",     f.icon, "TOPLEFT",     0, 0)
                    f.cooldown:SetPoint("BOTTOMRIGHT", f.icon, "BOTTOMRIGHT", 0, 0)
                    f.cooldown:SetFrameLevel(f:GetFrameLevel() + 1)
                    f.cooldown:SetDrawEdge(false)
                    f.cooldown:SetDrawSwipe(true)
                    f.cooldown:SetSwipeColor(0, 0, 0, 0.8)
                    f.cooldown:SetHideCountdownNumbers(i == 1)
                    f.cooldown:Hide()
                    -- border + count/timer 오버레이 (cooldown 위)
                    local ov = CreateFrame("Frame", nil, f)
                    ov:SetAllPoints(f)
                    ov:SetFrameLevel(f:GetFrameLevel() + 2)
                    local border = ov:CreateTexture(nil, "OVERLAY")
                    border:SetAllPoints()
                    border:SetAtlas("UI-HUD-ActionBar-IconFrame", false)
                    if i == 1 then
                        -- 블러드러스트: 초록 글로우 + 타이머 (TOPLEFT)
                        f.glow = ov:CreateTexture(nil, "OVERLAY", nil, 1)
                        f.glow:SetAllPoints()
                        f.glow:SetAtlas("UI-HUD-ActionBar-IconFrame-Mouseover")
                        f.glow:SetVertexColor(0, 1, 0, 1)
                        f.timer = ov:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
                        f.timer:SetPoint("TOPLEFT", ov, "TOPLEFT", 5, -5)
                        f.timer:SetTextColor(0.1, 1, 0.1)
                    else
                        -- 전투부활: 충전 횟수 (BOTTOMRIGHT)
                        f.count = ov:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
                        f.count:SetPoint("BOTTOMRIGHT", ov, "BOTTOMRIGHT", -2, 2)
                        f.count:SetJustifyH("RIGHT")
                        f.count:SetTextColor(1, 0.82, 0)
                    end
                    p.icon_frames[i] = f
                end
            end,
            Update = function(p, ns)
                local D   = dodo.COMBAT_DEFAULTS
                local db  = dodoDB or {}
                local sz  = db.blbrIconSize    or D.blbrIconSize
                local pad = db.blbrIconPadding or D.blbrIconPadding
                local half = (sz + pad) * 0.5
                -- 아이콘1: 블러드러스트 활성 페이즈 (글로우 + 타이머)
                local f1 = p.icon_frames[1]
                f1:SetSize(sz, sz)
                f1:ClearAllPoints()
                f1:SetPoint("CENTER", ns, "CENTER", -half, 0)
                if f1.glow  then f1.glow:Show() end
                if f1.timer then f1.timer:SetText("23") end
                f1.cooldown:Clear()
                f1.cooldown:Hide()
                -- 아이콘2: 전투부활 충전1 + 쿨다운 진행 중
                local f2 = p.icon_frames[2]
                f2:SetSize(sz, sz)
                f2:ClearAllPoints()
                f2:SetPoint("CENTER", ns, "CENTER",  half, 0)
                if f2.count then f2.count:SetText("1") end
                f2.cooldown:SetCooldown(GetTime() - 45, 90)
                f2.cooldown:Show()
            end,
        },
        { -- 탭4: 태세
            OnLoad = function(p, ns)
                local f = CreateFrame("Frame", nil, p)
                local bg = f:CreateTexture(nil, "BACKGROUND")
                bg:SetAllPoints()
                bg:SetColorTexture(0.15, 0.15, 0.15, 0.9)
                f.icon = f:CreateTexture(nil, "ARTWORK")
                f.icon:SetPoint("TOPLEFT",     f, "TOPLEFT",      2, -2)
                f.icon:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -2,  2)
                f.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
                local border = f:CreateTexture(nil, "OVERLAY")
                border:SetAllPoints()
                border:SetAtlas("UI-HUD-ActionBar-IconFrame", false)
                p.icon_frame = f
            end,
            Update = function(p, ns)
                local D    = dodo.COMBAT_DEFAULTS
                local db   = dodoDB or {}
                local sz   = db.stanceIconSize or D.stanceIconSize
                local spec = GetSpecialization and GetSpecialization()
                p.icon_frame.icon:SetTexture(spec == 73 and 132349 or 132341)
                p.icon_frame:SetSize(sz, sz)
                p.icon_frame:ClearAllPoints()
                p.icon_frame:SetPoint("CENTER", ns, "CENTER", 0, 0)
            end,
        },
    },
})

local function refresh_preview()
    if _preview_ref and _preview_ref.Update then _preview_ref:Update() end
end
dodo.CombatRefreshPreview = refresh_preview

function dodo.CombatGetPreviewTab()
    return _preview_ref and _preview_ref._current_tab or 1
end

function dodo.CombatSetTabChangeFn(fn)
    _tab_change_fn = fn
end
