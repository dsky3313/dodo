-- ==============================
-- ColorPicker
-- ==============================
-- Inspired: ColorTools (Muhmiauwau)

---@diagnostic disable: lowercase-global, param-type-mismatch, redundant-parameter, undefined-field, undefined-global
local addonName, dodo = ...
dodoDB = dodoDB or {}

local Config = {
    frame_extend  = 80,   -- ColorPickerFrame 우측 확장 px
    swatch_size   = 32,
    spacer        = 5,
    max_last_used = 30,
    picker_base_h = 210,  -- ColorPickerFrame 기본 높이
    picker_ext_h  = 90,   -- 팔레트 영역 높이
}

-- ==============================
-- 캐싱
-- ==============================
local Checkbox          = Checkbox
local ColorPickerFrame  = ColorPickerFrame
local CreateColor       = CreateColor
local CreateFrame       = CreateFrame
local GameTooltip       = GameTooltip
local MenuUtil          = MenuUtil
local ipairs            = ipairs
local math_ceil         = math.ceil
local math_floor        = math.floor
local math_max          = math.max
local math_min          = math.min
local pairs             = pairs
local string_format     = string.format
local table_concat      = table.concat
local table_insert      = table.insert
local table_remove      = table.remove
local table_sort        = table.sort
local time              = time
local unpack            = unpack

-- ==============================
-- 상태 (모두 local)
-- ==============================
local palettes       = {}   -- [key] = { name, colors, order }
local all_colors     = {}   -- 전체 색상 (설명 매칭용)
local update_running = false
local created        = false

local palette_frame      = nil
local palette_dropdown   = nil
local input_frame        = nil
local swatch_frame       = nil
local hex_original_points = nil  -- HexBox 원본 앵커 저장

local init_frame = CreateFrame("Frame")

-- ==============================
-- 유틸 (LibLodash 대체)
-- ==============================
local function tbl_filter(t, fn)
    local r = {}
    for i, v in ipairs(t) do
        if fn(v, i) then r[#r + 1] = v end
    end
    return r
end

local function tbl_map(t, fn)
    local r = {}
    for i, v in ipairs(t) do r[i] = fn(v, i) end
    return r
end

local function is_valid_color(c)
    return c and type(c) == "table" and c.r and c.g and c.b
end

local function extract_rgba(c)
    return { c.r, c.g, c.b, c.a or 1 }
end

local function sort_by_desc(colors)
    table_sort(colors, function(a, b) return tostring(a.description) < tostring(b.description) end)
    return colors
end

-- ==============================
-- 팔레트 데이터 생성
-- ==============================
local function build_all_colors()
    all_colors = {}
    for key, pal in pairs(palettes) do
        if key ~= "lastUsedColors" then
            for _, color in ipairs(pal.colors) do
                local pname = pal.name
                local desc  = color.description
                if key == "favoriteColors" then pname = "즐겨찾기"; desc = nil end
                all_colors[#all_colors + 1] = {
                    name  = desc and string_format("%s - %s", pname, desc) or pname,
                    color = CreateColor(unpack(color.color)),
                }
            end
        end
    end
end

local function init_palettes()
    dodoDB.colorPickerLastUsed = dodoDB.colorPickerLastUsed or {}

    palettes["lastUsedColors"] = { name = "최근 사용", colors = dodoDB.colorPickerLastUsed, order = 1 }

    -- 클래스 색상
    local sorted_cls = {}
    for k, v in pairs(LOCALIZED_CLASS_NAMES_MALE or {}) do
        sorted_cls[#sorted_cls + 1] = { key = k, value = v }
    end
    table_sort(sorted_cls, function(a, b) return a.value < b.value end)
    local cls_colors = {}
    for idx, cls in ipairs(sorted_cls) do
        local c = dodo.Colors.Class[cls.key]
        if c then
            cls_colors[#cls_colors + 1] = { sort = idx, description = cls.value, color = { c.r, c.g, c.b, 1 } }
        end
    end
    palettes["classColors"] = { name = "클래스", colors = cls_colors, order = 2 }

    -- 자원 색상 (Colors.Power 선언 순서 유지)
    local power_order = { "Mana", "Rage", "Focus", "Energy", "RunicPower", "Chi", "HolyPower", "SoulShards", "Essence", "RuneBlood", "RuneFrost", "RuneUnholy" }
    local pw_colors = {}
    for idx, k in ipairs(power_order) do
        local v = dodo.Colors.Power[k]
        if v then
            pw_colors[#pw_colors + 1] = { sort = idx, description = k, color = { v.r, v.g, v.b, 1 } }
        end
    end
    palettes["powerBarColor"] = { name = "자원", colors = pw_colors, order = 3 }

    -- 무지개 색상 (ETC 테이블 선언 순서 유지)
    local rainbow_order = { "SoftRed", "SoftOrange", "SoftYellow", "SoftGreen", "SoftCyan", "SoftBlue", "SoftPurple", "SoftPink" }
    local rainbow = {}
    for idx, k in ipairs(rainbow_order) do
        local v = dodo.Colors.ETC[k]
        if v then
            rainbow[#rainbow + 1] = { sort = idx, description = k, color = { v.r, v.g, v.b, 1 } }
        end
    end
    palettes["rainbowColors"] = { name = "무지개", colors = rainbow, order = 4 }

    build_all_colors()
end

-- ==============================
-- 색상 버튼 이벤트
-- ==============================
local function color_btn_click(self)
    ColorPickerFrame.Content.ColorPicker:SetColorRGB(unpack(self.btn_color))
    if ColorPickerFrame.hasOpacity then
        ColorPickerFrame.Content.ColorPicker:SetColorAlpha(self.btn_color[4])
    end
end

local function color_btn_enter(self)
    if not self.btn_desc or self.btn_desc == "" then return end
    GameTooltip:SetOwner(ColorPickerFrame, "ANCHOR_CURSOR_RIGHT", 35, 0)
    GameTooltip:SetText(self.btn_desc, 1, 1, 1, 1, 1)
    GameTooltip:Show()
end

local function color_btn_leave()
    GameTooltip:Hide()
end

-- ==============================
-- 색상 버튼 풀
-- ==============================
local function make_color_button(parent)
    local btn = CreateFrame("Button", nil, parent)
    btn:SetSize(Config.swatch_size, Config.swatch_size)
    btn:RegisterForClicks("LeftButtonDown")
    btn:SetScript("OnClick",  color_btn_click)
    btn:SetScript("OnEnter",  color_btn_enter)
    btn:SetScript("OnLeave",  color_btn_leave)

    local bg = btn:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetAtlas("colorpicker-checkerboard")
    bg:SetTexCoord(0, 1, 0, 0.25)

    local tex = btn:CreateTexture(nil, "ARTWORK")
    tex:SetAllPoints()
    btn.ColorTex = tex

    local hl = btn:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    hl:SetColorTexture(1, 1, 1, 0.2)

    return btn
end

local function create_btn_pool(parent)
    local pool = { active = {}, inactive = {}, _parent = parent }

    function pool:Acquire()
        local btn = table_remove(self.inactive) or make_color_button(self._parent)
        self.active[btn] = true
        btn:Show()
        return btn
    end

    function pool:Release(btn)
        self.active[btn] = nil
        btn:Hide()
        btn:ClearAllPoints()
        self.inactive[#self.inactive + 1] = btn
    end

    function pool:ReleaseAll()
        for btn in pairs(self.active) do self:Release(btn) end
    end

    return pool
end

-- ==============================
-- 팔레트 ScrollFrame
-- ==============================
local function get_swatch_desc(selected, v)
    if v.description then return v.description end
    if selected == "lastUsedColors" then
        local cur     = CreateColor(unpack(v.color))
        local matches = tbl_filter(all_colors, function(c) return c.color:IsEqualTo(cur) end)
        if #matches == 0 then return "" end
        local out = {}
        for _, m in ipairs(matches) do
            out[#out + 1] = m.name
        end
        return table_concat(out, "\n")
    end
    return ""
end

local function palette_do_refresh(self)
    self.pool:ReleaseAll()

    local selected = palette_dropdown and palette_dropdown.selected or "lastUsedColors"
    local pal      = palettes[selected]
    local colors   = pal and pal.colors or {}

    if selected ~= "lastUsedColors" then
        table_sort(colors, function(a, b)
            return (tonumber(a.sort) or 0) < (tonumber(b.sort) or 0)
        end)
    end

    local ss     = Config.swatch_size + Config.spacer
    local cols   = self.cols or 8
    local height = math_max(ss * 2, math_ceil(#colors / cols) * ss)
    self.contents:SetHeight(height)
    self.no_text:SetShown(#colors == 0)

    for k, v in ipairs(colors) do
        if v and v.color then
            local btn = self.pool:Acquire()
            local row = math_floor((k - 1) / cols)
            local col = (k - 1) - row * cols
            btn:SetPoint("TOPLEFT", self.contents, "TOPLEFT", col * ss, -row * ss)
            btn.ColorTex:SetColorTexture(unpack(v.color))
            btn.btn_color = v.color
            btn.btn_desc  = get_swatch_desc(selected, v)
        end
    end
end

local function palette_do_set_width(self, w)
    local ss = Config.swatch_size + Config.spacer
    self:SetWidth(w)
    self.contents:SetWidth(w)
    self:SetHeight(ss * 2)
    self.cols = math_floor(w / ss) - 1
    palette_do_refresh(self)
end

local function create_palette_frame()
    local sf = CreateFrame("ScrollFrame", nil, ColorPickerFrame)
    sf:SetPoint("BOTTOMLEFT",  ColorPickerFrame, "BOTTOMLEFT",   23, 44)
    sf:SetPoint("BOTTOMRIGHT", ColorPickerFrame, "BOTTOMRIGHT", -33, 44)
    sf:EnableMouseWheel(true)
    sf:SetScript("OnMouseWheel", function(self, delta)
        local current = self:GetVerticalScroll()
        local max     = self:GetVerticalScrollRange()
        self:SetVerticalScroll(math_max(0, math_min(max, current - delta * 20)))
    end)

    local contents = CreateFrame("Frame", nil, sf)
    contents:SetPoint("TOPLEFT")
    contents:SetPoint("BOTTOMRIGHT")
    sf:SetScrollChild(contents)
    sf.contents = contents

    local no_text = contents:CreateFontString(nil, "ARTWORK", "SystemFont_Med3")
    no_text:SetText("색상 없음")
    no_text:SetPoint("TOP", contents, "TOP", 0, -((Config.swatch_size + Config.spacer) - 7))
    sf.no_text = no_text

    sf.pool      = create_btn_pool(contents)
    sf.cols      = 8
    sf.refresh   = palette_do_refresh
    sf.set_width = palette_do_set_width

    palette_frame = sf
end

-- ==============================
-- 팔레트 드롭다운
-- ==============================
local function setup_dropdown(dd)
    dd:SetSelectionTranslator(function(sel)
        local p = palettes[sel.data]
        return p and p.name or sel.data
    end)

    local items = {}
    for key, p in pairs(palettes) do
        items[#items + 1] = { order = p.order, key = key, name = p.name }
    end
    table_sort(items, function(a, b) return a.order < b.order end)

    MenuUtil.CreateRadioMenu(dd,
        function(value) return value == dd.selected end,
        function(value)
            dd.selected = value
            dodoDB.colorPickerSelected = value
            if palette_frame then palette_frame:refresh() end
        end,
        unpack(tbl_map(items, function(e) return { e.name, e.key } end))
    )

    dd:RegisterCallback(DropdownButtonMixin.Event.OnMenuOpen, function()
        if dd.menu then dd.menu:SetFrameStrata("TOOLTIP") end
    end)
end

local function create_dropdown()
    local dd = CreateFrame("DropdownButton", nil, ColorPickerFrame, "WowStyle1DropdownTemplate")
    dd:SetSize(160, 25)
    dd:SetPoint("TOPRIGHT", ColorPickerFrame, "TOPRIGHT", -20, -139)
    dd.selected = dodoDB.colorPickerSelected or "lastUsedColors"
    setup_dropdown(dd)
    palette_dropdown = dd
end

-- ==============================
-- 수치 입력 EditBox
-- ==============================
local function input_apply(self, mode, ch, value)
    update_running = true
    local cp = ColorPickerFrame.Content.ColorPicker
    if mode == "RGB" then
        local r, g, b = cp:GetColorRGB()
        local t = { R = r, G = g, B = b }
        t[ch] = value / 255
        cp:SetColorRGB(t.R, t.G, t.B)
    elseif mode == "HSV" then
        local h, s, v = cp:GetColorHSV()
        local t = { H = h, S = s, V = v }
        t[ch] = ch ~= "H" and value / 100 or value
        cp:SetColorHSV(t.H, t.S, t.V)
    elseif mode == "ALPHA" then
        cp:SetColorAlpha(value / 100)
    end
    update_running = false
end

local function input_update_all(f)
    local cp       = ColorPickerFrame.Content.ColorPicker
    local r, g, b  = cp:GetColorRGB()
    local h, s, v  = cp:GetColorHSV()
    local a        = cp:GetColorAlpha()
    local vals     = { R = r*255, G = g*255, B = b*255, H = h, S = s*100, V = v*100, A = a*100 }
    for _, eb in ipairs(f.inputs) do
        local val = vals[eb.ch] or 0
        eb:SetNumber(math_floor(math_max(0, val)))
    end
end

local function eb_on_escape(self)
    self:ClearFocus()
    self:GetParent():apply(self.mode, self.ch, self:GetNumber())
end

local function eb_on_focus_lost(self)
    self:HighlightText(self:GetNumLetters())
    self:GetParent():apply(self.mode, self.ch, self:GetNumber())
end

local function eb_on_enter(self)
    self:ClearFocus()
    self:GetParent():apply(self.mode, self.ch, self:GetNumber())
end

local function eb_on_focus_gained(self)
    self:HighlightText(0, self:GetNumLetters())
end

local function make_editbox(parent, mode, ch, label, anchor, x, y)
    local eb = CreateFrame("EditBox", nil, parent, "InputBoxInstructionsTemplate")
    eb:SetSize(45, 22)
    eb:SetPoint(anchor, parent, anchor, x, y)
    eb:SetAutoFocus(false)
    eb:SetNumeric(true)
    eb:SetMaxLetters(3)
    eb:SetTextInsets(16, 0, 0, 0)
    eb.mode = mode
    eb.ch   = ch

    if eb.Instructions then
        eb.Instructions:SetText(label)
        eb.Instructions:ClearAllPoints()
        eb.Instructions:SetPoint("TOPLEFT",     eb, "TOPLEFT",     16, 0)
        eb.Instructions:SetPoint("BOTTOMRIGHT", eb, "BOTTOMRIGHT",  0, 0)
    end

    eb:SetScript("OnEscapePressed",   eb_on_escape)
    eb:SetScript("OnEnterPressed",    eb_on_enter)
    eb:SetScript("OnEditFocusGained", eb_on_focus_gained)
    eb:SetScript("OnEditFocusLost",   eb_on_focus_lost)
    return eb
end

local function create_input_frame()
    local f = CreateFrame("Frame", nil, ColorPickerFrame)
    f:SetSize(100, 100)
    f:SetPoint("TOPRIGHT", ColorPickerFrame, "TOPRIGHT", -20, -61)
    f.inputs = {}
    f.apply  = input_apply

    --  mode    ch    label  anchor       x    y
    local defs = {
        { "RGB",   "R", "R", "TOPLEFT",   0,    0  },
        { "RGB",   "G", "G", "TOPLEFT",   0,  -25  },
        { "RGB",   "B", "B", "TOPLEFT",   0,  -50  },
        { "ALPHA", "A", "A", "TOPLEFT",  -55, -50  },
        { "HSV",   "H", "H", "TOPRIGHT",  0,    0  },
        { "HSV",   "S", "S", "TOPRIGHT",  0,  -25  },
        { "HSV",   "V", "V", "TOPRIGHT",  0,  -50  },
    }
    for _, d in ipairs(defs) do
        local eb = make_editbox(f, d[1], d[2], d[3], d[4], d[5], d[6])
        f.inputs[#f.inputs + 1] = eb
    end

    -- ColorPicker 색상 변경 시 입력창 동기화
    ColorPickerFrame.Content.ColorPicker:HookScript("OnColorSelect", function()
        if update_running then return end
        if not (dodoDB and dodoDB.enableColorPicker ~= false) then return end
        input_update_all(f)
    end)
    f:SetScript("OnShow", function() input_update_all(f) end)

    -- HexBox 원본 앵커 저장 후 위치 재조정
    local hex = ColorPickerFrame.Content.HexBox
    hex_original_points = {}
    for i = 1, hex:GetNumPoints() do
        local point, rel, relPoint, x, y = hex:GetPoint(i)
        hex_original_points[i] = { point, rel, relPoint, x, y }
    end
    hex:ClearAllPoints()
    hex:SetPoint("TOPLEFT", ColorPickerFrame.Content, "TOPRIGHT", -40, -35)

    input_frame = f
end

-- ==============================
-- 현재/이전 색상 스와치
-- ==============================
local function mini_swatch_click(self)
    if self.is_current then return end
    local r, g, b = ColorPickerFrame:GetPreviousValues()
    ColorPickerFrame.Content.ColorPicker:SetColorRGB(r, g, b)
end

local function create_swatch_frame()
    local f = CreateFrame("Frame", nil, ColorPickerFrame)
    f:SetSize(47, 50)
    f:SetPoint("TOPLEFT", ColorPickerFrame.Content, "TOPRIGHT", -100, -37)

    for i = 1, 2 do
        local btn = CreateFrame("Button", nil, f)
        btn:SetSize(47, 25)
        btn:SetPoint("TOPLEFT", f, "TOPLEFT", 0, i == 1 and 0 or -25)
        btn:RegisterForClicks("LeftButtonDown")
        btn.is_current = (i == 1)
        btn:SetScript("OnClick", mini_swatch_click)
    end

    swatch_frame = f
end

-- ==============================
-- ColorPickerFrame 후킹
-- ==============================
local function on_picker_show(self)
    local enabled = dodoDB and dodoDB.enableColorPicker ~= false
    ColorPickerFrame:UnregisterEvent("GLOBAL_MOUSE_DOWN")

    if not enabled then
        self:SetWidth(self.hasOpacity and 388 or 331)
        self:SetHeight(Config.picker_base_h)
        self.Content:SetPoint("BOTTOMRIGHT", ColorPickerFrame, "BOTTOMRIGHT", 0, 0)
        return
    end

    local extend = Config.frame_extend
    self.Content:SetPoint("BOTTOMRIGHT", ColorPickerFrame, "BOTTOMRIGHT", -extend, 0)
    local w = (self.hasOpacity and 388 or 331) + extend
    self:SetWidth(w)
    self:SetHeight(Config.picker_base_h + Config.picker_ext_h)

    if palette_frame then palette_frame:set_width(w) end
end

local function on_okay_click()
    if not (dodoDB and dodoDB.enableColorPicker ~= false) then return end
    local r, g, b = ColorPickerFrame:GetColorRGB()
    local color   = { r, g, b, 1 }

    dodoDB.colorPickerLastUsed = dodoDB.colorPickerLastUsed or {}
    local last = dodoDB.colorPickerLastUsed

    table_insert(last, 1, { sort = time(), color = color })
    while #last > Config.max_last_used do table_remove(last, #last) end

    palettes["lastUsedColors"].colors = last
end

-- ==============================
-- UI 생성 (최초 1회)
-- ==============================
local function create_ui()
    if created then return end
    created = true

    ColorPickerFrame:SetHeight(Config.picker_base_h + Config.picker_ext_h)
    ColorPickerFrame:HookScript("OnShow", on_picker_show)
    ColorPickerFrame.Footer.OkayButton:HookScript("OnClick", on_okay_click)

    create_palette_frame()
    create_dropdown()
    create_input_frame()
    create_swatch_frame()
end

local function update_visibility()
    if not created then return end
    local on = dodoDB and dodoDB.enableColorPicker ~= false
    if palette_frame    then palette_frame:SetShown(on)    end
    if palette_dropdown then palette_dropdown:SetShown(on) end
    if input_frame      then input_frame:SetShown(on)      end
    if swatch_frame     then swatch_frame:SetShown(on)     end

    local hex = ColorPickerFrame.Content.HexBox
    hex:ClearAllPoints()
    if on then
        hex:SetPoint("TOPLEFT", ColorPickerFrame.Content, "TOPRIGHT", -40, -35)
    elseif hex_original_points then
        for _, p in ipairs(hex_original_points) do
            hex:SetPoint(p[1], p[2], p[3], p[4], p[5])
        end
    end
end

-- ==============================
-- 이벤트 핸들러
-- ==============================
local function on_event(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == addonName then
        dodoDB = dodoDB or {}
    elseif event == "PLAYER_LOGIN" then
        if dodoDB.enableColorPicker == nil then dodoDB.enableColorPicker = true end
        dodoDB.colorPickerSelected = dodoDB.colorPickerSelected or "lastUsedColors"

        init_palettes()

        if dodoDB.enableColorPicker then create_ui() end

        self:UnregisterEvent("PLAYER_LOGIN")
        self:UnregisterEvent("ADDON_LOADED")
    end
end

init_frame:RegisterEvent("ADDON_LOADED")
init_frame:RegisterEvent("PLAYER_LOGIN")
init_frame:SetScript("OnEvent", on_event)

-- ==============================
-- 설정 등록
-- ==============================
dodo.OptionRegistrations = dodo.OptionRegistrations or {}
dodo.OptionRegistrations["인터페이스.편의기능"] = dodo.OptionRegistrations["인터페이스.편의기능"] or {}
table_insert(dodo.OptionRegistrations["인터페이스.편의기능"], function(category)
    Checkbox(category, "enableColorPicker", "색상 팔레트", "색상 선택기에 팔레트, 수치 입력 패널을 추가합니다.", true, function(checked)
        if checked and not created then
            init_palettes()
            create_ui()
        end
        update_visibility()
    end)
end)
