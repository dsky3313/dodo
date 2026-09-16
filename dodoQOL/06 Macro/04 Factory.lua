---@diagnostic disable: lowercase-global, param-type-mismatch, redundant-parameter, undefined-field, undefined-global
local dodo = _G.dodo

local C_Spell                 = C_Spell
local C_Timer                 = C_Timer
local CreateFrame             = CreateFrame
local CreateMacro             = CreateMacro
local GameTooltip             = GameTooltip
local GetInventoryItemTexture = GetInventoryItemTexture
local GetMacroIndexByName     = GetMacroIndexByName
local InCombatLockdown        = InCombatLockdown
local ShowMacroFrame          = ShowMacroFrame
local ipairs                  = ipairs
local math_ceil               = math.ceil
local math_floor              = math.floor
local math_max                = math.max
local print                   = print
local select                  = select
local string_gsub             = string.gsub
local table_concat            = table.concat
local tonumber                = tonumber

-- ======================================================================
-- 상수
-- ======================================================================
local BTN_SIZE    = 36
local BTN_GAP     = 4
local PANEL_PAD_X = 16
local PANEL_PAD_Y = 30
local PANEL_ROW_H = BTN_SIZE + 20 + BTN_GAP

-- ======================================================================
-- DB 헬퍼
-- ======================================================================
local function get_db(macro_name)
    dodoDB.macroFactory = dodoDB.macroFactory or {}
    if not dodoDB.macroFactory[macro_name] then
        dodoDB.macroFactory[macro_name] = {}
    end
    return dodoDB.macroFactory[macro_name]
end

-- ======================================================================
-- 스펠 토큰 치환: fixedBody 내 {n} → 스펠 이름
-- 스펠 데이터 미캐시 시 nil 반환 + 비동기 로드 요청
-- ======================================================================
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

-- ======================================================================
-- 매크로 아이콘 결정
-- ======================================================================
local function resolve_macro_icon(def)
    if def.macroIcon then return def.macroIcon end
    if def.spells and def.fixedBody and not def.fixedTooltip then
        local tex = def.spells[1] and C_Spell.GetSpellTexture(def.spells[1])
        if tex then return tex end
    end
    return "INV_MISC_QUESTIONMARK"
end

-- ======================================================================
-- 매크로 바디 생성
-- ======================================================================
local function build_macro_body(def)
    local db = get_db(def.name)

    if def.fixedBody then
        local fbody = resolve_spell_tokens(def.fixedBody, def.spells)
        if fbody == nil then return nil end

        local body = ""
        if db.showTooltip ~= false and def.fixedTooltip then
            local tip = resolve_spell_tokens(def.fixedTooltip, def.spells)
            if tip == nil then return nil end
            body = "#showtooltip " .. tip .. "\n"
        elseif db.showTooltip ~= false then
            body = "#showtooltip\n"
        end

        if def.extraBody then
            local extra = def.extraBody(db)
            if extra and extra ~= "" then return body .. fbody .. "\n" .. extra end
        end
        return body .. fbody
    end

    return ""
end

-- ======================================================================
-- 매크로 정의
-- ======================================================================
local COMBAT_DEFS = {
    {
        name      = "주시",
        icon      = "Interface\\Icons\\ability_hunter_focusedaim",
        label     = "주시",
        fixedBody = "/focus [@target,harm,nodead][]\n/tm [@target,harm,nodead][] ~1",
    },
}

local GENERAL_DEFS = {
    {
        name         = "MF_Potion",
        icon         = "Interface\\Icons\\inv_potion_54",
        label        = "물약",
        fixedBody    = "/use item:245898\n/use item:245897\n/use item:241308\n/use item:241309\n/use item:245902\n/use item:245903\n/use item:241288\n/use item:241289",
        fixedTooltip = "item:245898",
    },
    {
        name         = "MF_Health",
        icon         = "Interface\\Icons\\inv_potion_131",
        label        = "체력/회복",
        spells       = {1231418},
        fixedBody    = "/stopcasting\n/cast [nocombat] {1}\n/use [combat] item:271884\n/use [combat] item:271883\n/use [combat] item:241304\n/use [combat] item:241305",
        fixedTooltip = "item:271884",
    },
    {
        name         = "MF_Food",
        icon         = "Interface\\Icons\\inv_misc_food_73cinnamonroll",
        label        = "음식",
        fixedBody    = "/use item:113509\n/use item:260262\n/use item:260263\n/use item:260264\n/use item:242297\n/use item:260260\n/use item:1226196\n/use item:242299\n/use item:242301\n/use item:242298\n/use item:260259",
        fixedTooltip = "item:113509",
    },
    {
        name         = "MF_Trinket1",
        icon         = "Interface\\Icons\\inv_jewelry_trinketpvp_01",
        label        = "장신구1",
        fixedBody    = "/use 13",
        fixedTooltip = "13",
    },
    {
        name         = "MF_Trinket2",
        icon         = "Interface\\Icons\\inv_jewelry_trinketpvp_02",
        label        = "장신구2",
        fixedBody    = "/use 14",
        fixedTooltip = "14",
    },
    {
        name      = "MF_Focus",
        icon      = "Interface\\Icons\\ability_hunter_focusedaim",
        macroIcon = 236203,
        label     = "포커스",
        fixedBody = "/focus [@mouseover,exists,nodead] []",
    },
}



-- ======================================================================
-- 패널 UI
-- ======================================================================
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
    tex:SetTexture(def.macroIcon or def.icon)
    btn._tex = tex

    local normalTex = btn:CreateTexture(nil, "OVERLAY")
    normalTex:SetAtlas("UI-HUD-ActionBar-IconFrame")
    normalTex:SetAllPoints(btn)

    local hoverTex = btn:CreateTexture(nil, "HIGHLIGHT")
    hoverTex:SetAtlas("UI-HUD-ActionBar-IconFrame-Mouseover")
    hoverTex:SetAlpha(0.5)
    hoverTex:SetBlendMode("ADD")
    hoverTex:SetAllPoints(btn)

    local lbl = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    lbl:SetPoint("TOP", btn, "BOTTOM", 0, -2)
    lbl:SetWidth(BTN_SIZE + BTN_GAP - 2)
    lbl:SetWordWrap(false)
    lbl:SetJustifyH("CENTER")
    lbl:SetText((def.label or def.name):gsub("\n", " "))

    local function refresh_state()
        local exists = GetMacroIndexByName(def.name) ~= 0
        tex:SetDesaturated(exists)
        btn._isGray = exists
    end
    btn._refreshState = refresh_state
    refresh_state()

    local function refresh_icon()
        local icon
        if def.fixedTooltip then
            local slot = tonumber(def.fixedTooltip)
            if slot then icon = GetInventoryItemTexture("player", slot) end
        end
        tex:SetTexture(icon or def.macroIcon or def.icon)
    end
    btn._refreshIcon = refresh_icon
    refresh_icon()

    btn:SetScript("OnEnter", function(self)
        local status = self._isGray and "|cff888888이미 생성됨|r" or "|cff888888클릭하여 생성|r"
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:ClearLines()
        GameTooltip:AddLine((def.label or def.name):gsub("\n", " "), 1, 1, 1)
        GameTooltip:AddLine(status)
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function(self)
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
                    CreateMacro(def.name, resolve_macro_icon(def), retry_body, nil)
                    refresh_state(); refresh_icon()
                    C_Timer.After(0.1, function() if not InCombatLockdown() then ShowMacroFrame() end end)
                else
                    print("|cffff4444[MacroFactory]|r 스펠 데이터를 불러오는 중입니다. 잠시 후 다시 시도해주세요.")
                end
            end)
            return
        end
        CreateMacro(def.name, resolve_macro_icon(def), body, nil)
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
    if panel then panel:Hide(); panel = nil end
    all_buttons = {}

    local col_gap  = 20
    local header_h = 18
    local combat_col_width = #COMBAT_DEFS * (BTN_SIZE + BTN_GAP)
    local right_x  = PANEL_PAD_X + combat_col_width + (#COMBAT_DEFS > 0 and col_gap or 0)

    local total_h = PANEL_PAD_Y + header_h + PANEL_ROW_H + PANEL_PAD_Y

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

-- ======================================================================
-- 훅 설치
-- ======================================================================
local factory_hooks_installed = false

local function install_factory_hooks()
    if factory_hooks_installed or not MacroFrame then return end
    factory_hooks_installed = true
    MacroFrame:HookScript("OnShow", function()
        if dodoDB and dodoDB.enableMacro == false then return end
        build_panel()
        panel:Show()
    end)
    MacroFrame:HookScript("OnHide", function()
        if panel then panel:Hide() end
    end)
    if MacroFrame:IsShown() and not (dodoDB and dodoDB.enableMacro == false) then
        build_panel()
        panel:Show()
    end
end

dodo.Macro.InstallFactoryHooks = install_factory_hooks
dodo.Macro.ShowPanel = function()
    build_panel()
    if panel then panel:Show() end
end
dodo.Macro.HidePanel = function()
    if panel then panel:Hide() end
end
