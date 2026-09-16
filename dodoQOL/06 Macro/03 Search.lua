---@diagnostic disable: lowercase-global, undefined-field, undefined-global
local dodo = _G.dodo

local C_Spell     = C_Spell
local C_SpellBook = C_SpellBook
local CreateFrame = CreateFrame
local Enum        = Enum
local GetFileIDFromPath = GetFileIDFromPath
local next        = next
local pcall       = pcall
local string_find  = string.find
local string_gsub  = string.gsub
local string_lower = string.lower
local tonumber    = tonumber
local tostring    = tostring
local type        = type

-- ======================================================================
-- 스펠 아이콘 키워드 맵
-- ======================================================================
local spell_icon_keyword_map = {}
local icon_path_fileid_cache = {}
local icon_fileid_probe_tex  = nil

local function add_icon_keyword(icon, keyword)
    if not icon or not keyword or keyword == "" then return end
    local normalized = string_lower(keyword)
    local current = spell_icon_keyword_map[icon]
    if not current then
        spell_icon_keyword_map[icon] = normalized
        return
    end
    if not string_find(current, normalized, 1, true) then
        spell_icon_keyword_map[icon] = current .. "\n" .. normalized
    end
end

local function rebuild_spell_icon_keyword_map()
    spell_icon_keyword_map = {}
    if not C_SpellBook or not Enum or not Enum.SpellBookSpellBank then return end

    local count = C_SpellBook.GetNumSpellBookSkillLines and C_SpellBook.GetNumSpellBookSkillLines() or 0
    for i = 1, count do
        local info = C_SpellBook.GetSpellBookSkillLineInfo(i)
        if info then
            for j = 1, info.numSpellBookItems do
                local slot = info.itemIndexOffset + j
                local icon = C_SpellBook.GetSpellBookItemTexture(slot, Enum.SpellBookSpellBank.Player)
                local name, sub_name = C_SpellBook.GetSpellBookItemName(slot, Enum.SpellBookSpellBank.Player)
                add_icon_keyword(icon, name)
                add_icon_keyword(icon, sub_name)
            end
        end
    end
end

-- ======================================================================
-- 아이콘 FileID 변환 (경로 → 숫자, 2단계 폴백)
-- ======================================================================
local function get_icon_fileid(icon)
    if not icon then return nil end
    if type(icon) == "number" then return icon end
    if type(icon) ~= "string" then return nil end

    local cached = icon_path_fileid_cache[icon]
    if cached ~= nil then return cached end

    local file_id = nil

    if GetFileIDFromPath then
        local variants = {
            icon,
            string_gsub(icon, "\\", "/"),
            string_lower(icon),
            string_lower(string_gsub(icon, "\\", "/")),
        }
        for i = 1, #variants do
            local ok, result = pcall(GetFileIDFromPath, variants[i])
            if ok and result and result > 0 then file_id = result; break end
        end
    end

    if not file_id then
        if not icon_fileid_probe_tex then
            local f = CreateFrame("Frame")
            icon_fileid_probe_tex = f:CreateTexture(nil, "ARTWORK")
        end
        local ok = pcall(icon_fileid_probe_tex.SetTexture, icon_fileid_probe_tex, icon)
        if ok and icon_fileid_probe_tex.GetTextureFileID then
            local id = icon_fileid_probe_tex:GetTextureFileID()
            if id and id > 0 then file_id = id end
        end
        icon_fileid_probe_tex:SetTexture(nil)
    end

    icon_path_fileid_cache[icon] = file_id or false
    return file_id
end

-- ======================================================================
-- 아이콘 검색 매칭
-- ======================================================================
local function match_icon(icon, query_lower, query_number)
    if icon == nil then return false end

    if query_number then
        if type(icon) == "number" then
            if icon == query_number or string_find(tostring(icon), query_lower, 1, true) then return true end
        elseif type(icon) == "string" then
            local n = tonumber(icon)
            if n and (n == query_number or string_find(tostring(n), query_lower, 1, true)) then return true end
            local fid = get_icon_fileid(icon)
            if fid and (fid == query_number or string_find(tostring(fid), query_lower, 1, true)) then return true end
        end
    end

    if type(icon) == "string" then
        local il = string_lower(icon)
        if string_find(il, query_lower, 1, true) then return true end
        local short = string_gsub(il, "^interface\\icons\\", "")
        if string_find(short, query_lower, 1, true) then return true end
    elseif type(icon) == "number" then
        if string_find(tostring(icon), query_lower, 1, true) then return true end
    end

    local kw = spell_icon_keyword_map[icon]
    if kw and string_find(kw, query_lower, 1, true) then return true end

    return false
end

-- 정적 버퍼 (매 키입력마다 테이블 생성 방지)
local _bf_seen     = {}
local _bf_filtered = {}

local function bf_add_unique(icon)
    if icon == nil then return end
    local key = (type(icon) == "number") and ("n:" .. tostring(icon)) or ("s:" .. tostring(icon))
    if _bf_seen[key] then return end
    _bf_seen[key] = true
    _bf_filtered[#_bf_filtered + 1] = icon
end

local function build_filtered_icons(popup, query)
    for k in next, _bf_seen do _bf_seen[k] = nil end
    for i = #_bf_filtered, 1, -1 do _bf_filtered[i] = nil end

    if not popup or not popup.iconDataProvider then return {} end

    local query_lower  = string_lower(query)
    local query_number = tonumber(query_lower)

    local total = popup.iconDataProvider:GetNumIcons()
    for i = 1, total do
        local icon = popup.iconDataProvider:GetIconByIndex(i)
        if match_icon(icon, query_lower, query_number) then bf_add_unique(icon) end
    end

    if query_number then
        bf_add_unique(query_number)
        if C_Spell and C_Spell.GetSpellTexture then
            local ok, spell_icon = pcall(C_Spell.GetSpellTexture, query_number)
            if ok and spell_icon then bf_add_unique(spell_icon) end
        end
    end

    local result = {}
    for i = 1, #_bf_filtered do result[i] = _bf_filtered[i] end
    return result
end

-- ======================================================================
-- 아이콘 셀렉터 DataProvider 교체
-- ======================================================================
local function apply_default_provider(popup)
    popup.IconSelector:SetSelectionsDataProvider(
        GenerateClosure(popup.GetIconByIndex, popup),
        GenerateClosure(popup.GetNumIcons, popup)
    )
    popup.IconSelector:UpdateSelections()
end

local function apply_filtered_provider(popup, filtered_icons)
    popup._exFilteredIcons = filtered_icons
    popup.IconSelector:SetSelectionsDataProvider(
        function(i) local l = popup._exFilteredIcons; return l and l[i] or nil end,
        function()  local l = popup._exFilteredIcons; return l and #l or 0    end
    )
    popup.IconSelector:UpdateSelections()
end

local function reevaluate_selection(popup, filtered_icons)
    local sel_tex = popup.BorderBox.SelectedIconArea.SelectedIconButton:GetIconTexture()
    local sel_idx = nil

    if filtered_icons then
        for i = 1, #filtered_icons do
            if filtered_icons[i] == sel_tex then sel_idx = i; break end
        end
    else
        sel_idx = popup:GetIndexOfIcon(sel_tex)
    end

    popup.IconSelector:SetSelectedIndex(sel_idx)
    popup:SetSelectedIconText()
    if sel_idx then popup.IconSelector:ScrollToSelectedIndex() end
end

-- ======================================================================
-- 검색창 생성 및 갱신
-- ======================================================================
local function trim_text(text)
    if not text then return "" end
    text = string_gsub(text, "^%s+", "")
    text = string_gsub(text, "%s+$", "")
    return text
end

local function update_search_box_visual(search_box)
    if not search_box then return end
    if SearchBoxTemplate_OnTextChanged then
        SearchBoxTemplate_OnTextChanged(search_box)
    elseif search_box.Instructions then
        search_box.Instructions:SetShown(search_box:GetText() == "")
    end
end

local function update_hint_text_state(popup)
    if not popup or not popup.BorderBox or not popup.BorderBox.IconSelectionText then return end
    popup.BorderBox.IconSelectionText:Hide()
    popup.BorderBox.IconSelectionText:SetAlpha(0)
end

local function get_search_box(popup)
    if not popup or not popup.BorderBox then return nil end
    if popup.ExMacroEnhSearchBox then return popup.ExMacroEnhSearchBox end

    local sb = CreateFrame("EditBox", nil, popup.BorderBox, "SearchBoxTemplate")
    sb:SetSize(182, 20)
    sb:SetPoint("TOPLEFT", popup.BorderBox.IconSelectorEditBox, "BOTTOMLEFT", 0, -16)
    sb:SetAutoFocus(false)
    if sb.Instructions then sb.Instructions:SetText("스펠명 / 경로 / FileID 검색") end

    popup.ExMacroEnhSearchBox = sb
    return sb
end

local function refresh_icon_search(popup)
    if not popup or not popup.IconSelector or not popup.iconDataProvider then return end

    local sb = get_search_box(popup)
    if not sb then return end

    update_hint_text_state(popup)
    sb:Show()

    local query = trim_text(sb:GetText() or "")
    if query == "" then
        popup._exFilteredIcons = nil
        apply_default_provider(popup)
        reevaluate_selection(popup, nil)
        return
    end

    local filtered = build_filtered_icons(popup, query)
    apply_filtered_provider(popup, filtered)
    reevaluate_selection(popup, filtered)
end

local function setup_search_box_handlers(popup)
    local sb = get_search_box(popup)
    if not sb or sb._exHooked then return end

    sb:SetScript("OnTextChanged", function(self)
        update_search_box_visual(self)
        refresh_icon_search(popup)
    end)
    sb:SetScript("OnEscapePressed", function(self)
        self:SetText("")
        self:ClearFocus()
        refresh_icon_search(popup)
    end)

    sb._exHooked = true
end

-- ======================================================================
-- 훅 설치
-- ======================================================================
local search_hooks_installed = false

local function install_search_hooks()
    if search_hooks_installed or not MacroPopupFrame then return end
    search_hooks_installed = true

    MacroPopupFrame:HookScript("OnShow", function(popup)
        if dodoDB and dodoDB.enableMacro == false then return end
        setup_search_box_handlers(popup)
        update_hint_text_state(popup)
        if popup.ExMacroEnhSearchBox then
            popup.ExMacroEnhSearchBox:SetText("")
            update_search_box_visual(popup.ExMacroEnhSearchBox)
        end
        refresh_icon_search(popup)
    end)

    MacroPopupFrame:HookScript("OnHide", function(popup)
        if popup.ExMacroEnhSearchBox then
            popup.ExMacroEnhSearchBox:SetText("")
            update_search_box_visual(popup.ExMacroEnhSearchBox)
        end
        popup._exFilteredIcons = nil
    end)

    hooksecurefunc(MacroPopupFrame, "Update", function(popup)
        if dodoDB and dodoDB.enableMacro == false then return end
        refresh_icon_search(popup)
    end)
    hooksecurefunc(MacroPopupFrame, "SetIconFilterInternal", function(popup)
        if dodoDB and dodoDB.enableMacro == false then return end
        refresh_icon_search(popup)
    end)
    hooksecurefunc(MacroPopupFrame, "UpdateStateFromCursorType", function(popup)
        if dodoDB and dodoDB.enableMacro == false then return end
        update_hint_text_state(popup)
    end)
end

dodo.Macro.RebuildSpellMap    = rebuild_spell_icon_keyword_map
dodo.Macro.InstallSearchHooks = install_search_hooks
