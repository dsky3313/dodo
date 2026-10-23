---@diagnostic disable: lowercase-global, undefined-field, undefined-global
local dodo = _G.dodo
dodoDB = dodoDB or {}

local CreateFrame = CreateFrame
local C_Spell = C_Spell
local ipairs = ipairs

local _preview_ref = nil

-- 현재 특성 추적 목록이 없을 때 쓰는 샘플 (전사 기준)
local SAMPLE_SPELLS = {
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

local function cfg(key)
    local v = dodoDB and dodoDB[key]
    if v == nil then return dodo.CST_DEFAULTS[key] end
    return v
end

-- 01 Core create_icon()과 동일 구조 (아이콘 + 테두리 + 스택)
local function create_preview_icon(parent)
    local f = CreateFrame("Frame", nil, parent)
    f.icon = f:CreateTexture(nil, "BACKGROUND")
    f.icon:SetTexCoord(0.1, 0.9, 0.1, 0.9)
    f.border = f:CreateTexture(nil, "ARTWORK")
    f.border:SetAtlas("UI-HUD-ActionBar-IconFrame")
    f.border:SetAllPoints(f)
    return f
end

dodoCursorSpellTrackerPreviewMixin = {}

dodoCursorSpellTrackerPreviewMixin.GetExtent = function()
    return 200
end

function dodoCursorSpellTrackerPreviewMixin:OnLoad()
    _preview_ref = self

    -- NineSlice 내부 영역, 범위 밖으로 나간 아이콘은 잘라냄
    local area = CreateFrame("Frame", nil, self)
    area:SetPoint("TOPLEFT", self, "TOPLEFT", 8, -40)
    area:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", -8, 8)
    area:SetClipsChildren(true)
    self.area = area

    self.cursor = area:CreateTexture(nil, "OVERLAY")
    -- 커서 핫스팟(텍스처 좌상단)을 미리보기 영역 정중앙에
    self.cursor:SetPoint("TOPLEFT", area, "CENTER", -10, 10)

    self.icons = {}
    self.row_counts = { 0, 0 }
end

function dodoCursorSpellTrackerPreviewMixin:Update()
    if not self.area then return end

    -- 크기별 커서 아틀라스 (Cursor_Point_32/48/64/96/128)
    local cursorPx, cursorSize = get_cursor_size()
    self.cursor:SetAtlas("Cursor_Point_" .. cursorPx)
    self.cursor:SetSize(cursorSize, cursorSize)

    local list = dodo.CursorSpellTrackerGetActiveSpells and dodo.CursorSpellTrackerGetActiveSpells()
    if not list or #list == 0 then list = SAMPLE_SPELLS end

    local size = cfg("cursorSpellTrackerIconSize")
    local step = size + cfg("cursorSpellTrackerIconGap")
    local rowStep = size + cfg("cursorSpellTrackerRowGap")
    local twoRows = cfg("cursorSpellTrackerRowCount") == "2"
    local rowByGroup = dodo.CST_ROW_BY_GROUP
    -- 01 Core 레이아웃과 동일: 홀더 CENTER = 커서 + 오프셋, 아이콘 LEFT를 홀더에 붙임
    local hx = cfg("cursorSpellTrackerX")
    local hy = cfg("cursorSpellTrackerY")
    local counts = self.row_counts
    counts[1], counts[2] = 0, 0

    for i, entry in ipairs(list) do
        local f = self.icons[i] or create_preview_icon(self.area)
        self.icons[i] = f
        local row = twoRows and rowByGroup[entry.group] or 1
        f:SetSize(size, size)
        local margin = math.max(2, size * 0.07)
        f.icon:ClearAllPoints()
        f.icon:SetPoint("TOPLEFT", f, "TOPLEFT", margin, -margin)
        f.icon:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -margin, margin)
        f.icon:SetTexture(C_Spell.GetSpellTexture(entry.spellID))
        f:ClearAllPoints()
        f:SetPoint("LEFT", self.cursor, "TOPLEFT", hx + counts[row] * step, hy + (row - 1) * rowStep)
        counts[row] = counts[row] + 1
        f:Show()
    end
    for i = #list + 1, #self.icons do
        self.icons[i]:Hide()
    end
end

dodo.CursorSpellTrackerRefreshPreview = function()
    if _preview_ref and _preview_ref.Update then _preview_ref:Update() end
end
