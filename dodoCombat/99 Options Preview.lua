-- ==============================
-- 전투 미리보기 Mixin
-- ==============================
---@diagnostic disable: lowercase-global, undefined-field, undefined-global
local dodo = _G.dodo
dodoDB = dodoDB or {}

local C_Spell     = C_Spell
local CreateFrame = CreateFrame
local GetTime     = GetTime
local math_max    = math.max

local SPELLS_BB = { 2825, 20484 }

local PREVIEW_DISPEL_NAMES = { "Magic", "Curse", "Disease", "Poison", "Bleed" }
local PREVIEW_BORDER_COLORS = {
    Magic   = { 0.32, 0.66, 1.00 },
    Curse   = { 0.67, 0.16, 1.00 },
    Disease = { 0.70, 0.47, 0.00 },
    Poison  = { 0.00, 1.00, 0.00 },
    Bleed   = { 1.00, 0.29, 0.17 },
}
local PREVIEW_FAKE = {
    { icon=135900, count=1, dispel="Magic",   duration=15 },
    { icon=136121, count=2, dispel="Curse",   duration=10 },
    { icon=135869, count=0, dispel="Disease", duration=8  },
    { icon=135925, count=5, dispel="Poison",  duration=12 },
    { icon=132242, count=0, dispel="Bleed",   duration=20 },
    { icon=136183, count=0, dispel=nil,        duration=0  },
}

-- 커서 주문추적: 현재 특성 추적 목록이 없을 때 쓰는 샘플 (전사 기준)
local CST_SAMPLE_SPELLS = {
    { spellID = 6552, group = "interrupt" }, -- 차단
    { spellID = 107570, group = "cc" },      -- 폭망
    { spellID = 46968, group = "cc" },       -- 충파
    { spellID = 5246, group = "cc" },        -- 공포
}

-- cursorSizePreferred cvar → 커서 픽셀 크기 (접근성 > 커서 크기, -1 = 기본값은 32로 간주)
local CURSOR_PX = { [0] = 32, [1] = 48, [2] = 64, [3] = 96, [4] = 128 }

-- 커서 픽셀 크기 + UIParent 단위 환산 크기 (아이콘 크기/오프셋과 같은 단위)
local function get_cursor_size()
    local px = CURSOR_PX[tonumber(C_CVar.GetCVar("cursorSizePreferred"))] or 32
    local _, physH = GetPhysicalScreenSize()
    if not physH or physH <= 0 then return px, px end
    return px, px * 768 / physH / UIParent:GetEffectiveScale()
end

-- 03 CursorSpellTracker create_icon()과 동일 구조 (아이콘 + 테두리)
local function create_cst_preview_icon(parent)
    local f = CreateFrame("Frame", nil, parent)
    f.icon = f:CreateTexture(nil, "BACKGROUND")
    f.icon:SetTexCoord(0.1, 0.9, 0.1, 0.9)
    f.border = f:CreateTexture(nil, "ARTWORK")
    f.border:SetAtlas("UI-HUD-ActionBar-IconFrame")
    f.border:SetAllPoints(f)
    return f
end

local _preview_ref   = nil
local _tab_change_fn = nil

dodoCombatPreviewMixin = dodo.UI:CreatePreviewMixin({
    GetExtent = function() return 160 end,
    ref       = function(f) _preview_ref = f end,
    trigger   = function() if _tab_change_fn then _tab_change_fn() end end,
    panels    = {
        { -- 탭1: 자원바
            OnLoad = function(p, ns)
                -- 공유 배경 (bar1 상단 ~ bar2 하단, Update에서 앵커 설정)
                p.sharedBG = CreateFrame("Frame", nil, p)
                local bgTex = p.sharedBG:CreateTexture(nil, "BACKGROUND")
                bgTex:SetAllPoints(p.sharedBG)
                bgTex:SetAtlas("UI-HUD-CoolDownManager-Bar-BG")

                p.bar1 = CreateFrame("StatusBar", nil, p)
                p.bar1:SetStatusBarTexture([[Interface\BUTTONS\WHITE8X8]])
                p.bar1:GetStatusBarTexture():SetAtlas("UI-HUD-CoolDownManager-Bar")
                p.bar1.countPower = p.bar1:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
                p.bar1.countPower:SetPoint("CENTER", p.bar1, "CENTER", 0, 3)
                p.bar1.countPower:SetJustifyH("CENTER")

                p.bar2 = CreateFrame("StatusBar", nil, p)
                p.bar2:SetStatusBarTexture([[Interface\BUTTONS\WHITE8X8]])
                p.bar2:GetStatusBarTexture():SetAtlas("UI-HUD-CoolDownManager-Bar")
                p.bar2.countStack = p.bar2:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
                p.bar2.countStack:SetPoint("RIGHT", p.bar2, "RIGHT", -5, 3)
                p.bar2.countStack:SetJustifyH("RIGHT")

                p.bar1.EdgeBottom = p.bar1:CreateTexture(nil, "BORDER")
                p.bar1.EdgeBottom:SetAtlas("_UI-Frame-Metal-EdgeBottom", true)
                p.bar1.EdgeBottom:SetPoint("BOTTOMLEFT",  p.bar1, "BOTTOMLEFT",  0, -6)
                p.bar1.EdgeBottom:SetPoint("BOTTOMRIGHT", p.bar1, "BOTTOMRIGHT", 0, -6)

                -- rune 모드용 서브바 (죽기)
                p.bar2_runebars = {}
                for i = 1, 6 do
                    local rb = CreateFrame("StatusBar", nil, p)
                    rb:SetStatusBarTexture([[Interface\BUTTONS\WHITE8X8]])
                    rb:GetStatusBarTexture():SetAtlas("UI-HUD-CoolDownManager-Bar")
                    rb:Hide()
                    p.bar2_runebars[i] = rb
                end
            end,
            Update = function(p, ns)
                local D   = dodo.COMBAT_DEFAULTS
                local db  = dodoDB or {}
                local RB  = dodo.ResourceBar
                local w   = db.resourceBarWidth  or D.resourceBarWidth
                local h1  = db.resourceBarHeight  or D.resourceBarHeight
                local h2  = db.resourceBarHeight2 or D.resourceBarHeight2
                -- bar1 색상: 실제 power 모듈 캐싱 색상
                local c   = (RB and RB.cachedPowerColor) or (RB and RB.cachedSpecColor) or { r=1, g=0.59, b=0.20 }
                -- bar2 barmode 및 색상
                local bar2_config = RB and RB.bar2Frame and RB.bar2Frame.buffConfig
                local bar2_mode   = bar2_config and bar2_config.barMode
                local c2  = (bar2_config and bar2_config.color) or (RB and RB.cachedSpecColor) or { r=0.20, g=0.85, b=1.00 }
                -- bar2 위치 먼저 확정 (sharedBG 앵커 기준)
                p.bar2:SetSize(w, h2)
                p.bar2:ClearAllPoints()
                p.bar2:SetPoint("TOP", p.bar1, "BOTTOM", 0, -1)

                -- 공유 배경 앵커 (bar1 상단 ~ bar2 하단)
                p.sharedBG:ClearAllPoints()
                p.sharedBG:SetPoint("TOPLEFT",     p.bar1, "TOPLEFT",     -2,  2)
                p.sharedBG:SetPoint("BOTTOMRIGHT", p.bar2, "BOTTOMRIGHT",  6, -8)
                p.sharedBG:Show()

                p.bar1:SetSize(w, h1)
                p.bar1:ClearAllPoints()
                p.bar1:SetPoint("CENTER", ns, "CENTER", 0, h2 / 2 + 2)
                p.bar1:SetStatusBarColor(c.r, c.g, c.b, 1)
                p.bar1:SetMinMaxValues(0, 100)
                p.bar1:SetValue(75)
                p.bar1:Show()
                if p.bar1.countPower then p.bar1.countPower:SetText("75") end

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
                        rb:Show()
                    end
                else
                    for _, rb in ipairs(p.bar2_runebars) do rb:Hide() end
                    p.bar2:SetStatusBarColor(c2.r, c2.g, c2.b, 1)
                    p.bar2:SetMinMaxValues(0, 100)
                    p.bar2:SetValue(50)
                    p.bar2:Show()
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
                local D   = dodo.COMBAT_DEFAULTS
                local db  = dodoDB
                local sz  = (db and db.debuffSize) or D.debuffSize
                local max = (db and db.debuffMax)  or D.debuffMax
                local gap = 2
                for i = 1, 6 do
                    local f = p.icon_frames[i]
                    if i <= max then
                        local data = PREVIEW_FAKE[i] or {}
                        f:SetSize(sz, sz)
                        f.border:SetSize(sz, sz)
                        f:ClearAllPoints()
                        f:SetPoint("CENTER", ns, "CENTER", (i - (max + 1) / 2) * (sz + gap), 0)
                        f.icon:SetTexture(data.icon)
                        f.count:SetText((data.count and data.count > 0) and data.count or "")
                        local c = data.dispel and PREVIEW_BORDER_COLORS[data.dispel]
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
                        for _, name in ipairs(PREVIEW_DISPEL_NAMES) do
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
        { -- 탭3: 커서 주문추적
            OnLoad = function(p, ns)
                -- 범위 밖으로 나간 아이콘은 잘라냄
                p:SetClipsChildren(true)
                p.cursor = p:CreateTexture(nil, "OVERLAY")
                -- 커서 핫스팟(텍스처 좌상단) 위치, 아이콘은 이 커서 기준으로 배치
                p.cursor:SetPoint("TOPLEFT", p, "CENTER", -40, 20)
                p.icons = {}
                p.row_counts = { 0, 0 }
            end,
            Update = function(p, ns)
                local D  = dodo.COMBAT_DEFAULTS
                local db = dodoDB or {}

                -- 크기별 커서 아틀라스 (Cursor_Point_32/48/64/96/128)
                local cursorPx, cursorSize = get_cursor_size()
                p.cursor:SetAtlas("Cursor_Point_" .. cursorPx)
                p.cursor:SetSize(cursorSize, cursorSize)

                local list = dodo.CursorSpellTrackerGetActiveSpells and dodo.CursorSpellTrackerGetActiveSpells()
                if not list or #list == 0 then list = CST_SAMPLE_SPELLS end

                local size    = db.cursorSpellTrackerIconSize or D.cursorSpellTrackerIconSize
                local step    = size + (db.cursorSpellTrackerIconGap or D.cursorSpellTrackerIconGap)
                local rowStep = size + (db.cursorSpellTrackerRowGap or D.cursorSpellTrackerRowGap)
                local twoRows = (db.cursorSpellTrackerRowCount or D.cursorSpellTrackerRowCount) == "2"
                -- 03 CursorSpellTracker 레이아웃과 동일: 커서 + 오프셋, 아이콘 LEFT 기준
                local hx = db.cursorSpellTrackerX or D.cursorSpellTrackerX
                local hy = db.cursorSpellTrackerY or D.cursorSpellTrackerY
                local counts = p.row_counts
                counts[1], counts[2] = 0, 0

                for i, entry in ipairs(list) do
                    local f = p.icons[i] or create_cst_preview_icon(p)
                    p.icons[i] = f
                    f:SetSize(size, size)
                    local margin = math_max(2, size * 0.07)
                    f.icon:ClearAllPoints()
                    f.icon:SetPoint("TOPLEFT", f, "TOPLEFT", margin, -margin)
                    f.icon:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -margin, margin)
                    f.icon:SetTexture(C_Spell.GetSpellTexture(entry.spellID))
                    f:Show()
                end

                -- 배치: 03 CursorSpellTracker relayout과 동일 (같은 열 안 CST_GROUP_ORDER 순 → 나머지)
                local function place(f, entry)
                    local row = twoRows and dodo.CST_ROW_BY_GROUP[entry.group] or 1
                    f:ClearAllPoints()
                    f:SetPoint("LEFT", p.cursor, "TOPLEFT", hx + counts[row] * step, hy + (row - 1) * rowStep)
                    counts[row] = counts[row] + 1
                end
                local ordered = {}
                for _, group in ipairs(dodo.CST_GROUP_ORDER) do
                    ordered[group] = true
                    for i, entry in ipairs(list) do
                        if entry.group == group then place(p.icons[i], entry) end
                    end
                end
                for i, entry in ipairs(list) do
                    if not ordered[entry.group] then place(p.icons[i], entry) end
                end
                for i = #list + 1, #p.icons do
                    p.icons[i]:Hide()
                end
            end,
        },
        { -- 탭4: 혈부활
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
        { -- 탭5: 태세
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

-- ==============================
-- 커서 주문추적: 주문 목록 (직업/특성 선택 + 켜기/끄기)
-- ==============================
-- 저장: dodoDB.cursorSpellTrackerDisabled = { [specID] = { [spellID] = true } } (03 CursorSpellTracker/01 Core.lua 참고)
--       dodoDB.cursorSpellTrackerCustom   = { [specID] = { { spellID = , group = }, ... } }
local CST_GROUP_LABEL = { interrupt = "차단기", dispel = "해제", cd = "쿨기", cc = "군중제어" }
local CST_GROUP_ORDER = dodo.CST_GROUP_ORDER -- 카테고리 드롭다운 순서 (99 Options.lua)
local CST_LIST_H = 360 -- 드롭다운 + 헤더 + 목록 박스 (주문추가 줄 포함 10줄 + 오류 문구)
local CST_ROW_H  = 26
local CST_HEADER_H = 28 -- 컬럼 헤더 높이 (WhoFrameColumnHeaderTemplate)

local _cst_class_id, _cst_spec_id = nil, nil -- 편집 중 직업/특성 (세션 한정, 저장 안 함)
local _cst_list_ref = nil                    -- 주문 목록 프레임 (추가/삭제 후 Update)
local _cst_add_group = "cc"                  -- 주문 추가 줄 카테고리 선택값

local function cst_num_specs(classID)
    if C_SpecializationInfo and C_SpecializationInfo.GetNumSpecializationsForClassID then
        return C_SpecializationInfo.GetNumSpecializationsForClassID(classID) or 0
    end
    return 0
end

local function cst_first_spec(classID)
    return (GetSpecializationInfoForClassID(classID, 1))
end

-- 편집 대상 기본값: 현재 내 직업/특성
local function cst_init_selection()
    if _cst_class_id then return end
    local _, _, classID = UnitClass("player")
    _cst_class_id = classID
    local specIndex = GetSpecialization()
    _cst_spec_id = (specIndex and GetSpecializationInfo(specIndex)) or cst_first_spec(classID)
end

-- 판정 규칙은 03 CursorSpellTracker/01 Core.lua is_entry_disabled와 동일
-- 저장값 true(사용자 끔) / false(사용자 켬) / nil(미변경 → defaultOff = 데이터 enabled == false)
local function cst_is_disabled(specID, spellID, defaultOff)
    local root = dodoDB and dodoDB.cursorSpellTrackerDisabled
    local v = root and root[specID] and root[specID][spellID]
    if v == nil then return defaultOff == true end
    return v
end

local function cst_set_disabled(specID, spellID, disabled, defaultOff)
    dodoDB.cursorSpellTrackerDisabled = dodoDB.cursorSpellTrackerDisabled or {}
    local root = dodoDB.cursorSpellTrackerDisabled
    root[specID] = root[specID] or {}
    -- 데이터 기본값과 같으면 저장 안 함 (기본값과 다른 것만 DB에 남김)
    if disabled == (defaultOff == true) then
        root[specID][spellID] = nil
    else
        root[specID][spellID] = disabled
    end
    -- 빈 테이블 정리 (기본값 상태면 DB 키 자체 제거)
    if next(root[specID]) == nil then root[specID] = nil end
    if next(root) == nil then dodoDB.cursorSpellTrackerDisabled = nil end
    if dodo.CursorSpellTrackerRefreshSpells then dodo.CursorSpellTrackerRefreshSpells() end
    refresh_preview()
end

-- 기본 데이터(00 Data.lua) + 사용자 추가 주문
local function cst_build_rows(specID)
    local rows = {}
    local base = dodo.CST_SPELLS_BY_SPEC and dodo.CST_SPELLS_BY_SPEC[specID]
    if base then
        for _, e in ipairs(base) do rows[#rows + 1] = { spellID = e.spellID, group = e.group, defaultOff = e.enabled == false } end
    end
    local customRoot = dodoDB and dodoDB.cursorSpellTrackerCustom
    local custom = customRoot and customRoot[specID]
    if custom then
        for _, e in ipairs(custom) do rows[#rows + 1] = { spellID = e.spellID, group = e.group, custom = true } end
    end
    return rows
end

local function cst_on_check_click(self)
    local data = self:GetParent().data
    if data and _cst_spec_id then cst_set_disabled(_cst_spec_id, data.spellID, not self:GetChecked(), data.defaultOff) end
end

-- 같은 특성의 기본 목록 또는 추가 목록에 이미 있는지
local function cst_has_spell(specID, spellID)
    local base = dodo.CST_SPELLS_BY_SPEC and dodo.CST_SPELLS_BY_SPEC[specID]
    if base then
        for _, e in ipairs(base) do if e.spellID == spellID then return true, e.enabled == false end end
    end
    local customRoot = dodoDB and dodoDB.cursorSpellTrackerCustom
    local custom = customRoot and customRoot[specID]
    if custom then
        for _, e in ipairs(custom) do if e.spellID == spellID then return true end end
    end
    return false
end

-- 추가/삭제 후 커서 아이콘 + 미리보기 + 목록 갱신
local function cst_after_list_change()
    if dodo.CursorSpellTrackerRefreshSpells then dodo.CursorSpellTrackerRefreshSpells() end
    refresh_preview()
    if _cst_list_ref then _cst_list_ref:Update() end
end

local function cst_add_custom(specID, spellID, group)
    dodoDB.cursorSpellTrackerCustom = dodoDB.cursorSpellTrackerCustom or {}
    local root = dodoDB.cursorSpellTrackerCustom
    root[specID] = root[specID] or {}
    local list = root[specID]
    list[#list + 1] = { spellID = spellID, group = group }
    cst_after_list_change()
end

local function cst_remove_custom(specID, spellID)
    local root = dodoDB.cursorSpellTrackerCustom
    local list = root and root[specID]
    if not list then return end
    for i = #list, 1, -1 do
        if list[i].spellID == spellID then table.remove(list, i) end
    end
    -- 빈 테이블 정리 + 끄기 목록에 남은 같은 주문도 제거
    -- (cst_set_disabled는 자체 갱신을 하므로 쓰지 않고 직접 정리 → 갱신은 아래 1회만)
    if #list == 0 then root[specID] = nil end
    if next(root) == nil then dodoDB.cursorSpellTrackerCustom = nil end
    local disRoot = dodoDB.cursorSpellTrackerDisabled
    local dis = disRoot and disRoot[specID]
    if dis then
        dis[spellID] = nil
        if next(dis) == nil then disRoot[specID] = nil end
        if next(disRoot) == nil then dodoDB.cursorSpellTrackerDisabled = nil end
    end
    cst_after_list_change()
end

local function cst_on_delete_click(self)
    local data = self:GetParent().data
    if data and data.custom and _cst_spec_id then cst_remove_custom(_cst_spec_id, data.spellID) end
end

local function cst_init_row(row, data)
    if not row.check then
        row.check = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
        row.check:SetSize(24, 24)
        row.check:SetPoint("LEFT", row, "LEFT", 2, 0)
        row.check:SetScript("OnClick", cst_on_check_click)

        row.icon = row:CreateTexture(nil, "ARTWORK")
        row.icon:SetSize(20, 20)
        row.icon:SetPoint("LEFT", row.check, "RIGHT", 4, 0)
        row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

        row.name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        row.name:SetPoint("LEFT", row.icon, "RIGHT", 6, 0)
        row.name:SetWidth(150)
        row.name:SetJustifyH("LEFT")
        row.name:SetWordWrap(false)

        row.spellid = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        row.spellid:SetPoint("LEFT", row.name, "RIGHT", 6, 0)
        row.spellid:SetWidth(70)
        row.spellid:SetJustifyH("LEFT")

        row.group = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        row.group:SetPoint("LEFT", row.spellid, "RIGHT", 6, 0)
        row.group:SetJustifyH("LEFT")

        -- 삭제 (직접 추가한 주문만, 항상 표시)
        row.del = CreateFrame("Button", nil, row)
        row.del:SetSize(16, 16)
        row.del:SetPoint("RIGHT", row, "RIGHT", -6, 0)
        row.del:SetNormalAtlas("common-icon-redx")
        row.del:SetHighlightAtlas("common-icon-redx", "ADD")
        row.del:SetScript("OnClick", cst_on_delete_click)
    end
    row.data = data
    row.del:SetShown(data.custom == true)
    row.check:SetChecked(not cst_is_disabled(_cst_spec_id, data.spellID, data.defaultOff))
    row.icon:SetTexture(C_Spell.GetSpellTexture(data.spellID) or 134400)
    local name = C_Spell.GetSpellName(data.spellID) or "?"
    row.name:SetText(data.custom and (name .. " |cff888888(추가)|r") or name)
    row.spellid:SetText(data.spellID)
    row.group:SetText(CST_GROUP_LABEL[data.group] or "-")
end

-- ── 주문 추가 줄 ──────────────────────────────────────
-- 평소: [+] 주문 추가 / 클릭 시 입력 모드: 미리보기 아이콘·이름 + spellID 입력칸 + 카테고리 드롭다운 + ✓/X
local function cst_add_set_editing(addRow, editing)
    addRow.editing = editing
    addRow.plus:SetShown(not editing)
    addRow.label:SetShown(not editing)
    addRow.previewIcon:SetShown(editing)
    addRow.previewName:SetShown(editing)
    addRow.input:SetShown(editing)
    addRow.groupDD:SetShown(editing)
    addRow.ok:SetShown(editing)
    addRow.cancel:SetShown(editing)
    addRow.error:SetText("")
    addRow:EnableMouse(not editing)
    if editing then
        addRow.input:SetText("")
        addRow.previewIcon:SetTexture(134400)
        addRow.previewName:SetText("")
        addRow.input:SetFocus()
    else
        addRow.input:ClearFocus()
    end
end

-- 입력 중 미리보기 (아이콘 + 주문명)
local function cst_add_on_text_changed(input)
    local addRow = input:GetParent()
    local id = tonumber(input:GetText())
    local valid = id and C_Spell.DoesSpellExist(id)
    addRow.previewIcon:SetTexture(valid and C_Spell.GetSpellTexture(id) or 134400)
    addRow.previewName:SetText(valid and (C_Spell.GetSpellName(id) or "") or "")
    addRow.error:SetText("")
end

local function cst_add_confirm(addRow)
    local id = tonumber(addRow.input:GetText())
    if not id or id <= 0 then
        addRow.error:SetText("spellID를 입력하세요.")
        return
    end
    if not C_Spell.DoesSpellExist(id) then
        addRow.error:SetText("존재하지 않는 주문입니다.")
        return
    end
    local exists, defaultOff = cst_has_spell(_cst_spec_id, id)
    if exists then
        addRow.error:SetText(cst_is_disabled(_cst_spec_id, id, defaultOff)
            and "이미 목록에 있습니다. (체크를 켜세요)" or "이미 목록에 있습니다.")
        return
    end
    cst_add_set_editing(addRow, false)
    cst_add_custom(_cst_spec_id, id, _cst_add_group)
end

local function cst_add_on_click(addRow) cst_add_set_editing(addRow, true) end
local function cst_add_on_enter(input) cst_add_confirm(input:GetParent()) end
local function cst_add_on_escape(input) cst_add_set_editing(input:GetParent(), false) end
local function cst_add_on_ok(btn) cst_add_confirm(btn:GetParent()) end
local function cst_add_on_cancel(btn) cst_add_set_editing(btn:GetParent(), false) end

local function cst_is_add_group(group) return _cst_add_group == group end
local function cst_set_add_group(group) _cst_add_group = group end

-- 열 위치는 cst_init_row와 동일 (아이콘 30 / 주문명 56 / spellID 212 / 카테고리 288)
local function cst_create_add_row(parent)
    local addRow = CreateFrame("Button", nil, parent)
    addRow:SetHeight(CST_ROW_H)
    addRow:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
    addRow:SetScript("OnClick", cst_add_on_click)

    addRow.plus = addRow:CreateTexture(nil, "ARTWORK")
    addRow.plus:SetSize(16, 16)
    addRow.plus:SetPoint("LEFT", addRow, "LEFT", 32, 0)
    addRow.plus:SetAtlas("communities-icon-addchannelplus")

    addRow.label = addRow:CreateFontString(nil, "OVERLAY", "GameFontGreen")
    addRow.label:SetPoint("LEFT", addRow, "LEFT", 56, 0)
    addRow.label:SetText("주문 추가")

    addRow.previewIcon = addRow:CreateTexture(nil, "ARTWORK")
    addRow.previewIcon:SetSize(20, 20)
    addRow.previewIcon:SetPoint("LEFT", addRow, "LEFT", 30, 0)
    addRow.previewIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    addRow.previewName = addRow:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    addRow.previewName:SetPoint("LEFT", addRow, "LEFT", 56, 0)
    addRow.previewName:SetWidth(150)
    addRow.previewName:SetJustifyH("LEFT")
    addRow.previewName:SetWordWrap(false)

    addRow.input = CreateFrame("EditBox", nil, addRow, "InputBoxTemplate")
    addRow.input:SetSize(64, 20)
    addRow.input:SetPoint("LEFT", addRow, "LEFT", 218, 0) -- InputBoxTemplate 좌측 테두리 여백 6
    addRow.input:SetAutoFocus(false)
    addRow.input:SetNumeric(true)
    addRow.input:SetMaxLetters(8)
    addRow.input:SetScript("OnTextChanged", cst_add_on_text_changed)
    addRow.input:SetScript("OnEnterPressed", cst_add_on_enter)
    addRow.input:SetScript("OnEscapePressed", cst_add_on_escape)

    addRow.groupDD = CreateFrame("DropdownButton", nil, addRow, "WowStyle2DropdownTemplate")
    addRow.groupDD:SetSize(90, 22)
    addRow.groupDD:SetPoint("LEFT", addRow, "LEFT", 288, 0)
    addRow.groupDD:SetupMenu(function(_, root)
        for _, group in ipairs(CST_GROUP_ORDER) do
            root:CreateRadio(CST_GROUP_LABEL[group], cst_is_add_group, cst_set_add_group, group)
        end
    end)

    addRow.ok = CreateFrame("Button", nil, addRow)
    addRow.ok:SetSize(18, 18)
    addRow.ok:SetPoint("LEFT", addRow.groupDD, "RIGHT", 6, 0)
    addRow.ok:SetNormalAtlas("common-icon-checkmark")
    addRow.ok:SetHighlightAtlas("common-icon-checkmark", "ADD")
    addRow.ok:SetScript("OnClick", cst_add_on_ok)

    addRow.cancel = CreateFrame("Button", nil, addRow)
    addRow.cancel:SetSize(16, 16)
    addRow.cancel:SetPoint("LEFT", addRow.ok, "RIGHT", 4, 0)
    addRow.cancel:SetNormalAtlas("common-icon-redx")
    addRow.cancel:SetHighlightAtlas("common-icon-redx", "ADD")
    addRow.cancel:SetScript("OnClick", cst_add_on_cancel)

    -- 오류 문구 (추가 줄 바로 아래, 마지막 줄이라 빈 공간)
    addRow.error = addRow:CreateFontString(nil, "OVERLAY", "GameFontRedSmall")
    addRow.error:SetPoint("TOPLEFT", addRow, "BOTTOMLEFT", 56, 0)

    cst_add_set_editing(addRow, false)
    return addRow
end

dodoCSTSpellListMixin = {}

dodoCSTSpellListMixin.GetExtent = function()
    return CST_LIST_H
end

function dodoCSTSpellListMixin:OnLoad()
    _cst_list_ref = self
    cst_init_selection()

    -- 직업 → 특성 하위 드롭다운 (dodoInterface 03 Minimap/IconAddons.lua 프로필 메뉴 방식)
    local function is_spec_selected(id) return _cst_spec_id == id end
    local function select_spec(id)
        _cst_spec_id = id
        self:Update()
    end

    self.specDD = CreateFrame("DropdownButton", nil, self, "WowStyle2DropdownTemplate")
    self.specDD:SetSize(140, 25)
    self.specDD:SetPoint("TOPLEFT", self, "TOPLEFT", 37, -4)
    self.specDD:SetupMenu(function(_, root)
        for i = 1, GetNumClasses() do
            local className, classFile, classID = GetClassInfo(i)
            if classID then
                local color = C_ClassColor.GetClassColor(classFile)
                local sub = root:CreateButton(color and color:WrapTextInColorCode(className) or className)
                for j = 1, cst_num_specs(classID) do
                    local specID, specName = GetSpecializationInfoForClassID(classID, j)
                    if specID then
                        sub:CreateRadio(specName, is_spec_selected, select_spec, specID)
                    end
                end
            end
        end
    end)
    -- 버튼 표시: "직업 - 특성" (직업 색상)
    self.specDD:SetSelectionText(function()
        if not _cst_spec_id then return "직업/특성 선택" end
        local _, specName, _, _, _, classFile, className = GetSpecializationInfoByID(_cst_spec_id)
        local color = classFile and C_ClassColor.GetClassColor(classFile)
        local text = (className or "?") .. " - " .. (specName or "?")
        return color and color:WrapTextInColorCode(text) or text
    end)
    -- SetupMenu 시점에 기본 선택 텍스트(특성명만)가 먼저 찍히므로, 커스텀 텍스트로 즉시 재생성
    self.specDD:GenerateMenu()

    -- 주문 목록 (스크롤 없음, 고정 높이)
    -- 툴팁 나인슬라이스 테두리 (테두리는 템플릿 원본 색, 배경만 SoftBlack 반투명)
    self.listBG = CreateFrame("Frame", nil, self, "TooltipBackdropTemplate")
    local bg = dodo.Colors.PrimarySoft.SoftBlack
    self.listBG:SetBackdropColor(bg.r, bg.g, bg.b, 0.5)
    self.listBG:SetPoint("TOPLEFT", self, "TOPLEFT", 37, -36 - CST_HEADER_H)
    self.listBG:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", -30, 4)

    -- 컬럼 헤더 (목록 박스 TOP 바로 위, dodoQOL 99 ETC/PlayerMemo.lua 방식)
    -- 폭은 cst_init_row 열 위치 기준 (박스 안쪽 여백 6 포함: spellID 218 / 카테고리 294)
    -- WhoFrameColumn_SetWidth가 GetName().."Middle" 전역 조회 → 전역 이름 필요
    local col_name = CreateFrame("Button", "dodoCSTColName", self, "WhoFrameColumnHeaderTemplate")
    col_name:SetPoint("BOTTOMLEFT", self.listBG, "TOPLEFT", 2, -2)
    col_name:SetText("주문명")
    WhoFrameColumn_SetWidth(col_name, 220)

    local col_id = CreateFrame("Button", "dodoCSTColSpellID", self, "WhoFrameColumnHeaderTemplate")
    col_id:SetPoint("LEFT", col_name, "RIGHT", -2, 0)
    col_id:SetText("spellID")
    WhoFrameColumn_SetWidth(col_id, 78)

    local col_group = CreateFrame("Button", "dodoCSTColGroup", self, "WhoFrameColumnHeaderTemplate")
    col_group:SetPoint("LEFT", col_id, "RIGHT", -2, 0)
    col_group:SetText("카테고리")
    WhoFrameColumn_SetWidth(col_group, 120)

    self.content = CreateFrame("Frame", nil, self)
    self.content:SetPoint("TOPLEFT", self.listBG, "TOPLEFT", 6, -6)
    self.content:SetPoint("BOTTOMRIGHT", self.listBG, "BOTTOMRIGHT", -6, 6)
    self.content:SetFrameLevel(self.listBG:GetFrameLevel() + 1)

    self.rows = {}
    self.addRow = cst_create_add_row(self.content)
end

function dodoCSTSpellListMixin:Update()
    if not self.content then return end
    local rows = cst_build_rows(_cst_spec_id)
    for i, data in ipairs(rows) do
        local row = self.rows[i]
        if not row then
            row = CreateFrame("Frame", nil, self.content)
            row:SetHeight(CST_ROW_H)
            row:SetPoint("TOPLEFT", self.content, "TOPLEFT", 0, -(i - 1) * CST_ROW_H)
            row:SetPoint("RIGHT", self.content, "RIGHT")
            self.rows[i] = row
        end
        cst_init_row(row, data)
        row:Show()
    end
    for i = #rows + 1, #self.rows do
        self.rows[i]:Hide()
    end

    -- 주문 추가 줄: 마지막 주문 바로 아래 (특성 변경/목록 갱신 시 입력 모드 해제)
    local addRow = self.addRow
    addRow:ClearAllPoints()
    addRow:SetPoint("TOPLEFT", self.content, "TOPLEFT", 0, -#rows * CST_ROW_H)
    addRow:SetPoint("RIGHT", self.content, "RIGHT")
    if addRow.editing then cst_add_set_editing(addRow, false) end
end

function dodo.CombatGetPreviewTab()
    return _preview_ref and _preview_ref._current_tab or 1
end

function dodo.CombatSetTabChangeFn(fn)
    _tab_change_fn = fn
end
