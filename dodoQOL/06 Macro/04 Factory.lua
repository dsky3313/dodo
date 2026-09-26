-- ==============================
-- 설정 및 테이블
-- ==============================
---@diagnostic disable: lowercase-global, param-type-mismatch, redundant-parameter, undefined-field, undefined-global
local dodo = _G.dodo

local BTN_SIZE    = 36
local BTN_GAP     = 10
local PANEL_PAD_X = 16
local PANEL_PAD_Y = 35
local PANEL_ROW_H = BTN_SIZE + 20 + BTN_GAP

-- ==============================
-- 캐싱
-- ==============================
-- 함수
local CreateFrame             = CreateFrame
local InCombatLockdown        = InCombatLockdown
local GetInventoryItemTexture = GetInventoryItemTexture
local GetMacroIndexByName     = GetMacroIndexByName
local ipairs                  = ipairs
local math_max                = math.max
local ShowMacroFrame          = ShowMacroFrame

-- 변수
local C_Spell                 = C_Spell
local C_Timer                 = C_Timer
local CreateMacro             = CreateMacro
local GameTooltip             = GameTooltip
local math_floor              = math.floor
local print                   = print
local string_gsub             = string.gsub
local tonumber                = tonumber

-- ==============================
-- DB 헬퍼
-- ==============================
local function get_db(macro_name)
    dodoDB.macroFactory = dodoDB.macroFactory or {}
    if not dodoDB.macroFactory[macro_name] then
        dodoDB.macroFactory[macro_name] = {}
    end
    return dodoDB.macroFactory[macro_name]
end

-- ==============================
-- 스펠 토큰 치환: macroText 내 {n} → 스펠 이름
-- 스펠 데이터 미캐시 시 nil 반환 + 비동기 로드 요청
-- ==============================
local function resolve_spell_tokens(text, spells)
    if not text then return nil end
    if not spells or not text:find("{%d+}") then return text end
    local missing = false
    local out = text:gsub("{(%d+)}", function(n)
        local id = spells[tonumber(n)]
        if not id then return "{" .. n .. "}" end
        local info = C_Spell.GetSpellInfo(id)
        if info and info.name then return info.name end
        C_Spell.RequestLoadSpellData(id)
        missing = true
        return ""
    end)
    if missing then return nil end
    return out
end

-- ==============================
-- 매크로 아이콘 결정
-- macroIcon → CreateMacro 전용 (없거나 "" → INV_MISC_QUESTIONMARK)
-- icon      → 버튼 표시 전용 (macroIcon 없으면 버튼도 icon 사용)
-- ==============================
local function resolve_macro_icon(def)
    local id = def.macroIcon
    if not id or id == "" or id == "?" then return "INV_MISC_QUESTIONMARK" end
    return id
end

-- ==============================
-- 매크로 바디 생성
-- ==============================
local function build_macro_body(def)
    local db = get_db(def.macroName)

    if def.macroText then
        local fbody = resolve_spell_tokens(def.macroText, def.macroSpells)
        if fbody == nil then return nil end

        local body = ""
        if def.macroshowtooltip ~= nil and db.showTooltip ~= false then
            local tip = resolve_spell_tokens(def.macroshowtooltip, def.macroSpells)
            if tip == nil then return nil end
            body = tip == "" and "#showtooltip\n" or ("#showtooltip " .. tip .. "\n")
        end

        if def.extraBody then
            local extra = def.extraBody(db)
            if extra and extra ~= "" then return body .. fbody .. "\n" .. extra end
        end
        return body .. fbody
    end

    return ""
end

-- ==============================
-- 매크로 정의
-- ==============================

---@class MacroDef
---@field label        string?                   매크로 팩토리버튼 표시 이름 (없으면 macroName 사용)
---@field icon         (string|integer)?         버튼 표시 아이콘 (파일 ID 또는 경로)
---@field macroName    string                    매크로 이름 (GetMacroIndexByName 조회 키)
---@field macroIcon    (string|integer)?         CreateMacro 전용 아이콘 (nil/"?" → ?)
---@field macroshowtooltip string?               #showtooltip 값 (숫자 문자열이면 슬롯 아이콘으로도 사용)
---@field macroSpells  integer[]?                {n} 토큰용 스펠 ID 배열
---@field macroText    string?                   매크로 바디 템플릿 ({n} → spells[n] 이름 치환)
---@field extraBody    (fun(db:table):string)?   DB 기반 동적 추가 바디 생성 함수

---@type MacroDef[]
local COMBAT_DEFS = {
    {
        label     = "주시",
        icon      = 1033497,
        macroName = "주시",
        macroIcon = 1033497,
        macroText = "/focus [@target,harm,nodead][]\n/tm [@target,harm,nodead][] ~1",
    },
    {
        label     = "차단",
        icon      = 132219,
        macroName = "차단",
        macroIcon = "",
        macroshowtooltip = "스킬명",
        macroText = "/use [@focus,harm][harm]스킬명",
    },
    {
        label     = "대상",
        icon      = 236179,
        macroName = "대상",
        macroIcon = 236179,
        macroText = "/tar 맹독의 심장\n/tar 역병비늘 비명꾼\n/tar 약화된 파멸비늘\n/tar 용암 토템\n/tar 기근의 입상\n/tar 치유의 해일 토템",
    },
    {
        label     = "징",
        icon      = 236188,
        macroName = "징",
        macroIcon = 236188,
        macroText = "인스턴스를 인식해서 자동으로 변경됩니다.",
    },
}

---@type MacroDef[]
local GENERAL_DEFS = {
    {
        label        = "치유물약",
        icon         = 134756,
        macroName    = "치물",
        macroIcon    = "",
        macroshowtooltip = "농축된 실버문 생명력 물약",
        macroText    = "/use 생명석\n/use 농축된 실버문 생명력 물약",
    },
    {
        label        = "딜물약",
        icon         = 236314,
        macroName    = "딜물",
        macroIcon    = "",
        macroshowtooltip = "",
        macroText    = "/use 무모함의 물약\n/use 빛의 잠재력",
    },
    {
        label        = "음식",
        icon         = 134029,
        macroName    = "만회",
        macroIcon    = "",
        macroshowtooltip = "item:113509",
        macroSpells  = {1231418},
        macroText    = "/use {1}\n/use 창조된 마나 찐빵",
    },
    {
        label        = "장신구1",
        icon         = "Interface\\Icons\\inv_jewelry_trinketpvp_01",
        macroName    = "장식1",
        macroIcon    = "",
        macroshowtooltip = "13",
        macroText    = "/use 13",
    },
    {
        label        = "장신구2",
        icon         = "Interface\\Icons\\inv_jewelry_trinketpvp_02",
        macroName    = "장식2",
        macroIcon    = "",
        macroshowtooltip = "14",
        macroText    = "/use 14",
    },
    {
        label        = "초읽기",
        icon         = 237538,
        macroName    = "초읽기",
        macroIcon    = 237538,
        macroText    = [[/run local _,t=GetInstanceInfo()local s=5 if SecureCmdOptionParse("[btn:2]")then s=0 elseif t=="raid"then s=10 end C_PartyInfo.DoCountdown(s)]],
    },
}

-- ==============================
-- 패널 UI
-- ==============================
local panel       = nil
local all_buttons = {}

local poll_elapsed = 0
local poll_frame   = CreateFrame("Frame")

local function on_poll_update(_, dt)
    poll_elapsed = poll_elapsed + dt
    if poll_elapsed < 2 then return end
    poll_elapsed = 0
    for _, btn in ipairs(all_buttons) do
        if btn._refreshState then btn._refreshState() end
        if btn._refreshIcon  then btn._refreshIcon()  end
    end
end

local function create_macro_button(parent, def, ox, oy)
    local btn = CreateFrame("Button", nil, parent)
    btn:SetSize(BTN_SIZE, BTN_SIZE)
    btn:SetPoint("TOPLEFT", parent, "TOPLEFT", ox, oy)

    local margin = math_max(2, BTN_SIZE * 0.07)
    local tex = btn:CreateTexture(nil, "BACKGROUND")
    tex:SetPoint("TOPLEFT",     btn, "TOPLEFT",      margin, -margin)
    tex:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -margin,  margin)
    tex:SetTexCoord(0.1, 0.9, 0.1, 0.9)
    tex:SetTexture(def.icon or resolve_macro_icon(def))
    btn._tex = tex

    local normalTex = btn:CreateTexture(nil, "OVERLAY")
    normalTex:SetAtlas("UI-HUD-ActionBar-IconFrame")
    normalTex:SetAllPoints(btn)

    local hoverTex = btn:CreateTexture(nil, "HIGHLIGHT")
    hoverTex:SetAtlas("UI-HUD-ActionBar-IconFrame-Mouseover")
    hoverTex:SetAlpha(0.5)
    hoverTex:SetBlendMode("ADD")
    hoverTex:SetAllPoints(btn)

    local lbl = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    lbl:SetPoint("TOP", btn, "BOTTOM", 0, -2)
    lbl:SetWidth(50)
    lbl:SetWordWrap(false)
    lbl:SetJustifyH("CENTER")
    lbl:SetText((def.label or def.macroName):gsub("\n", " "))

    local function refresh_state()
        local exists = GetMacroIndexByName(def.macroName) ~= 0
        tex:SetDesaturated(exists)
        btn._isGray = exists
    end
    btn._refreshState = refresh_state
    refresh_state()

    local function refresh_icon()
        local icon
        if def.macroshowtooltip then
            local slot = tonumber(def.macroshowtooltip)
            if slot then icon = GetInventoryItemTexture("player", slot) end
        end
        tex:SetTexture(icon or def.icon or resolve_macro_icon(def))
    end
    btn._refreshIcon = refresh_icon
    refresh_icon()

    btn:SetScript("OnEnter", function(self)
        local status = self._isGray and "|cff888888이미 생성됨|r" or "|cff888888클릭하여 생성|r"
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:ClearLines()
        GameTooltip:AddLine((def.label or def.macroName):gsub("\n", " "), 1, 1, 1)
        GameTooltip:AddLine(status)
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    btn:SetScript("OnClick", function(self)
        if self._isGray then return end
        if InCombatLockdown() then
            print("|cffff4444[MacroFactory]|r 전투 중에는 매크로를 생성할 수 없습니다.")
            return
        end
        local body = build_macro_body(def)
        if body == nil then
            C_Timer.After(0.5, function()
                local retry_body = build_macro_body(def)
                if retry_body then
                    CreateMacro(def.macroName, resolve_macro_icon(def), retry_body, nil)
                    refresh_state(); refresh_icon()
                    C_Timer.After(0.1, function() if not InCombatLockdown() then ShowMacroFrame() end end)
                else
                    print("|cffff4444[MacroFactory]|r 스펠 데이터를 불러오는 중입니다. 잠시 후 다시 시도해주세요.")
                end
            end)
            return
        end
        CreateMacro(def.macroName, resolve_macro_icon(def), body, nil)
        refresh_state(); refresh_icon()
        C_Timer.After(0.1, function() if not InCombatLockdown() then ShowMacroFrame() end end)
    end)

    return btn
end

local function create_section_header(parent, text, x, y)
    local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    fs:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    fs:SetTextColor(1, 0.82, 0, 1)
    fs:SetText(text)
    return fs
end

local function build_panel()
    local col_gap  = 20
    local header_h = 18
    local combat_col_width = #COMBAT_DEFS * (BTN_SIZE + BTN_GAP)
    local right_x  = PANEL_PAD_X + combat_col_width + (#COMBAT_DEFS > 0 and col_gap or 0)
    local total_h  = PANEL_PAD_Y + header_h + PANEL_ROW_H + PANEL_PAD_Y

    panel = dodo.UI:CreatePortraitPanel("MacroFactoryPanel", "매크로 생성", true, true)
    panel:SetHeight(total_h)
    panel:SetPoint("TOPLEFT",  MacroFrame, "BOTTOMLEFT",  -4, 0)
    panel:SetPoint("TOPRIGHT", MacroFrame, "BOTTOMRIGHT", 0, 0)
    panel:SetFrameStrata("DIALOG")

    local icon_y = -PANEL_PAD_Y - header_h

    if #COMBAT_DEFS > 0 then
        create_section_header(panel, "전투 매크로", PANEL_PAD_X, -PANEL_PAD_Y)
        for i, def in ipairs(COMBAT_DEFS) do
            all_buttons[#all_buttons + 1] = create_macro_button(panel, def,
                PANEL_PAD_X + (i - 1) * (BTN_SIZE + BTN_GAP),
                icon_y)
        end
    end

    create_section_header(panel, "공용 매크로", right_x, -PANEL_PAD_Y)
    for i, def in ipairs(GENERAL_DEFS) do
        all_buttons[#all_buttons + 1] = create_macro_button(panel, def,
            right_x + (i - 1) * (BTN_SIZE + BTN_GAP),
            icon_y)
    end

    panel:SetScript("OnShow", function()
        poll_elapsed = 0
        poll_frame:SetScript("OnUpdate", on_poll_update)
    end)
    panel:SetScript("OnHide", function()
        poll_frame:SetScript("OnUpdate", nil)
    end)
end

-- ==============================
-- 훅 설치
-- ==============================
local factory_hooks_installed = false

local function refresh_all_buttons()
    for _, btn in ipairs(all_buttons) do
        if btn._refreshState then btn._refreshState() end
        if btn._refreshIcon  then btn._refreshIcon()  end
    end
end

local function install_factory_hooks()
    if factory_hooks_installed or not MacroFrame then return end
    factory_hooks_installed = true
    hooksecurefunc("DeleteMacro", refresh_all_buttons)
    hooksecurefunc("CreateMacro", refresh_all_buttons)
    MacroFrame:HookScript("OnShow", function()
        if dodoDB and dodoDB.enableMacro == false then return end
        if not panel then build_panel() end
        refresh_all_buttons()
        panel:Show()
    end)
    MacroFrame:HookScript("OnHide", function()
        if panel then panel:Hide() end
    end)
    if MacroFrame:IsShown() and not (dodoDB and dodoDB.enableMacro == false) then
        if not panel then build_panel() end
        refresh_all_buttons()
        panel:Show()
    end
end

dodo.Macro.InstallFactoryHooks = install_factory_hooks
dodo.Macro.ShowPanel = function()
    if not panel then build_panel() end
    refresh_all_buttons()
    panel:Show()
end
dodo.Macro.HidePanel = function()
    if panel then panel:Hide() end
end
