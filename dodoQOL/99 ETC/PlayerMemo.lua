-- ==============================
-- Inspired
-- ==============================
-- GlobalIgnoreList (IceyPop)

-- ==============================
-- 설정 및 테이블
-- ==============================
---@diagnostic disable: lowercase-global, param-type-mismatch, redundant-parameter, undefined-field, undefined-global
local dodo = _G.dodo
dodoDB = dodoDB or {}

-- ==============================
-- 캐싱
-- ==============================
-- 함수
local CreateFrame        = CreateFrame
local GetNumGroupMembers = GetNumGroupMembers
local GetRealmName       = GetRealmName
local IsInRaid           = IsInRaid
local math_max           = math.max
local pairs              = pairs
local PlaySound          = PlaySound
local StaticPopup_Show   = StaticPopup_Show
local UnitExists         = UnitExists
local UnitIsUnit         = UnitIsUnit
local UnitName           = UnitName
local wipe               = wipe

-- 변수
local C_LFGList          = C_LFGList
local C_Timer            = C_Timer
local issecretvalue      = issecretvalue or function() return false end
local string_format      = string.format
local table_concat       = table.concat
local table_insert       = table.insert
local table_sort         = table.sort

-- ==============================
-- 네임스페이스
-- ==============================
dodo.PlayerMemo = dodo.PlayerMemo or {}
local PM = dodo.PlayerMemo

-- ==============================
-- 팝업
-- ==============================
StaticPopupDialogs["DODO_PLAYER_MEMO_WARN"] = {
    text           = "%s",
    button1        = "확인",
    timeout        = 0,
    whileDead      = true,
    hideOnEscape   = 1,
    preferredIndex = 3,
}


-- ==============================
-- 코어 API
-- ==============================
function PM.Add(name, note)
    if not name or name == "" then return end
    dodoDB.playerMemoList = dodoDB.playerMemoList or {}
    dodoDB.playerMemoList[name] = { note = note or "", date = date("%Y-%m-%d") }
    if PM.RefreshUI then PM.RefreshUI() end
    if PM.TriggerPartyCheck then PM.TriggerPartyCheck() end
    PlaySound(113, "Master")
    local note_str = (note and note ~= "") and note or "(없음)"
    local col = "|c" .. dodo.Colors.CharacterFrame.Enchant.hex
    print(col .. "[dodo]|r 플레이어 메모를 추가했습니다.")
    print(string_format(col .. "이름|r : %s", name))
    print(string_format(col .. "메모|r : %s", note_str))
end

function PM.Remove(key)
    if not key then return end
    if dodoDB.playerMemoList then
        dodoDB.playerMemoList[key] = nil
    end
    if PM.RefreshUI then PM.RefreshUI() end
end

-- ==============================
-- 파티 경고
-- ==============================
local last_warned_set   = {}
local cur_set           = {}
local new_lines         = {}
local check_party_pending = false

local function check_party_impl()
    check_party_pending = false
    if dodoDB.enablePlayerMemo == false then return end
    local list = dodoDB.playerMemoList
    if not list then return end

    local num = GetNumGroupMembers()
    if not num or num == 0 then
        wipe(last_warned_set)
        return
    end

    local prefix = IsInRaid() and "raid" or "party"
    wipe(cur_set)
    wipe(new_lines)

    for i = 1, num do
        local unit = prefix .. i
        if UnitExists(unit) and not UnitIsUnit(unit, "player") then
            local name, realm = UnitName(unit)
            if name and not issecretvalue(name) then
                realm = (realm and realm ~= "") and realm or GetRealmName()
                local key_full  = name .. "-" .. realm
                local key_short = name
                local used_key  = list[key_full] and key_full
                               or list[key_short] and key_short
                if used_key then
                    local entry = list[used_key]
                    cur_set[used_key] = true
                    if not last_warned_set[used_key] then
                        local note_str = (entry.note and entry.note ~= "") and entry.note or "(없음)"
                        table_insert(new_lines, "이름: " .. used_key .. "\n메모: " .. note_str)
                    end
                end
            end
        end
    end

    wipe(last_warned_set)
    for k in pairs(cur_set) do last_warned_set[k] = true end

    if #new_lines > 0 then
        StaticPopup_Show("DODO_PLAYER_MEMO_WARN",
            "메모된 플레이어가 파티에 있습니다!\n\n"
            .. table_concat(new_lines, "\n\n"))
    end
end

local function check_party_for_memo()
    if not check_party_pending then
        check_party_pending = true
        C_Timer.After(0.5, check_party_impl)
    end
end
PM.TriggerPartyCheck = check_party_for_memo

-- ==============================
-- UI — 정적 핸들러
-- ==============================
local memo_frame = nil

local function row_name_click(self)
    local row = self:GetParent()
    self:Hide()
    row.name_eb:SetText(row.key or "")
    row.name_eb:Show()
    row.name_eb:SetFocus()
end

local function row_name_confirm(self)
    local row     = self:GetParent()
    local old_key = row.key
    local new_key = self:GetText()
    self:ClearFocus()
    self:Hide()
    row.name_btn:Show()
    if new_key ~= "" and new_key ~= old_key
            and dodoDB.playerMemoList and dodoDB.playerMemoList[old_key] then
        dodoDB.playerMemoList[new_key] = dodoDB.playerMemoList[old_key]
        dodoDB.playerMemoList[old_key] = nil
        if PM.RefreshUI then PM.RefreshUI() end
        if PM.TriggerPartyCheck then PM.TriggerPartyCheck() end
    end
end

local function row_name_cancel(self)
    self:ClearFocus()
    self:Hide()
    self:GetParent().name_btn:Show()
end

local function row_note_click(self)
    local row = self:GetParent()
    self:Hide()
    row.note_eb:SetText(row._note or "")
    row.note_eb:Show()
    row.note_eb:SetFocus()
end

local function row_note_confirm(self)
    local row = self:GetParent()
    local key = row.key
    local text = self:GetText()
    if key and dodoDB.playerMemoList and dodoDB.playerMemoList[key] then
        dodoDB.playerMemoList[key].note = text
        row._note = text
    end
    self:ClearFocus()
    self:Hide()
    row.note_btn:Show()
    if PM.RefreshUI then PM.RefreshUI() end
end

local function row_note_cancel(self)
    self:ClearFocus()
    self:Hide()
    self:GetParent().note_btn:Show()
end

local function row_del_click(self)
    local row = self:GetParent()
    if row.key then PM.Remove(row.key) end
end

local function eb_focus_gained(self)
    if self._ph then self._ph:Hide() end
end

local function eb_focus_lost(self)
    if self._ph and self:GetText() == "" then self._ph:Show() end
end

local function name_input_enter(self)
    self:ClearFocus()
    local b = self:GetParent()
    if b.note_input then b.note_input:SetFocus() end
end

local function do_add_from_bottom(b)
    local name = b.name_input:GetText()
    local note = b.note_input:GetText()
    if not name or name:match("^%s*$") then return end
    PM.Add(name, note)
    b.name_input:SetText("")
    b.note_input:SetText("")
    if b._ph_name then b._ph_name:Show() end
    if b._ph_note then b._ph_note:Show() end
    b.name_input:ClearFocus()
    b.note_input:ClearFocus()
end

local function add_btn_click(self)
    do_add_from_bottom(self:GetParent())
end

local function note_input_enter(self)
    self:ClearFocus()
    do_add_from_bottom(self:GetParent())
end

-- ==============================
-- LFG 파싱 헬퍼
-- ==============================
local function parse_lfg_leader(leader_name)
    if not leader_name or leader_name == "" then return nil, nil end
    local list = dodoDB.playerMemoList
    if not list then return nil, nil end
    local name, realm = leader_name:match("^(.+)-(.+)$")
    if not name then
        name  = leader_name
        realm = GetRealmName()
    end
    local key_full = name .. "-" .. realm
    local used_key = list[key_full] and key_full or list[name] and name
    if not used_key then return nil, nil end
    return used_key, list[used_key]
end

-- ==============================
-- LFG 훅
-- ==============================
local function lfg_update(self)
    if not C_LFGList.HasSearchResultInfo(self.resultID) then return end
    local info = C_LFGList.GetSearchResultInfo(self.resultID)
    if not info or not info.leaderName then return end
    local used_key = parse_lfg_leader(info.leaderName)
    if used_key and self.Name then
        self.Name:SetTextColor(RED_FONT_COLOR.r, RED_FONT_COLOR.g, RED_FONT_COLOR.b)
    end
end

local function lfg_tooltip(self)
    if not C_LFGList.HasSearchResultInfo(self.resultID) then return end
    local info = C_LFGList.GetSearchResultInfo(self.resultID)
    if not info or not info.leaderName then return end
    local used_key, entry = parse_lfg_leader(info.leaderName)
    if not used_key then return end
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("|cffff4444메모된 플레이어|r")
    if entry.note and entry.note ~= "" then
        GameTooltip:AddLine("|cff69ccf0" .. entry.note)
    end
    GameTooltip:Show()
end

-- ==============================
-- 우클릭 메뉴 훅
-- ==============================
local function unit_menu_handler(owner, root, contextData)
    local name, server = UnitName(contextData.unit)
    if not name or issecretvalue(name) then return end
    local realm    = (server and server ~= "") and server or GetRealmName()
    local key_full = name .. "-" .. realm
    local list     = dodoDB.playerMemoList
    local used_key = list and (list[key_full] and key_full or list[name] and name)
    root:CreateDivider()
    root:CreateTitle("dodo")
    root:CreateButton(used_key and "메모 편집" or "메모 추가", function()
        local cur_list = dodoDB.playerMemoList
        local cur_key  = cur_list and (cur_list[key_full] and key_full or cur_list[name] and name)
        local note     = cur_key and cur_list[cur_key].note or ""
        PM.OpenAndFill(key_full, note)
    end)
end

local function hook_menus()
    Menu.ModifyMenu("MENU_UNIT_PLAYER",       unit_menu_handler)
    Menu.ModifyMenu("MENU_UNIT_PARTY",        unit_menu_handler)
    Menu.ModifyMenu("MENU_UNIT_RAID_PLAYER",  unit_menu_handler)
    Menu.ModifyMenu("MENU_UNIT_ENEMY_PLAYER", unit_menu_handler)
    hooksecurefunc("LFGListSearchEntry_Update",  lfg_update)
    hooksecurefunc("LFGListSearchEntry_OnEnter", lfg_tooltip)
end

-- ==============================
-- UI — refresh
-- ==============================
local function refresh_ui()
    if not memo_frame or not memo_frame:IsShown() then return end
    local rows    = memo_frame._rows
    local content = memo_frame._content
    local ROW_H   = memo_frame._row_h
    local keys    = memo_frame._sorted_keys

    dodoDB.playerMemoList = dodoDB.playerMemoList or {}
    wipe(keys)
    for k in pairs(dodoDB.playerMemoList) do
        table_insert(keys, k)
    end
    table_sort(keys)

    local make_row = memo_frame._make_row
    for i = #rows + 1, #keys do
        rows[i] = make_row(i)
    end

    content:SetHeight(math_max(1, #keys * ROW_H))

    for i, row in ipairs(rows) do
        local key = keys[i]
        if key then
            local entry = dodoDB.playerMemoList[key]
            row.key   = key
            row._note = entry.note or ""
            row.name_btn:SetText(key)
            row.name_eb:Hide()
            row.name_btn:Show()
            row.note_btn:SetText(
                row._note ~= "" and row._note or "|cff888888(메모 없음)|r")
            row.note_eb:Hide()
            row.note_btn:Show()
            row:Show()
        else
            row.key = nil
            row:Hide()
        end
    end
end

PM.RefreshUI = refresh_ui

-- ==============================
-- PM.OpenAndFill
-- ==============================
function PM.OpenAndFill(name, note)
    if not memo_frame then return end
    PanelTemplates_SetTab(FriendsFrame, 5)
    if FriendsFrame:IsShown() then
        FriendsFrame_Update()
    else
        ShowUIPanel(FriendsFrame)
    end
    local ni = memo_frame._name_input
    local nn = memo_frame._note_input
    if ni then
        ni:SetText(name or "")
        if ni._ph then ni._ph:SetShown(not name or name == "") end
    end
    if nn then
        nn:SetText(note or "")
        if nn._ph then nn._ph:SetShown(not note or note == "") end
        nn:SetFocus()
    end
end

-- ==============================
-- UI — FriendsFrame_Update 훅 핸들러 (정적)
-- ==============================
local function on_friends_frame_update()
    if PanelTemplates_GetSelectedTab(FriendsFrame) == 5 then
        FriendsFrame:SetTitle("메모")
        FriendsTabHeader:Hide()
        FriendsFrameInset:Hide()
        ButtonFrameTemplate_HideButtonBar(FriendsFrame)
        FriendsFrame_ShowSubFrame("dodo_PlayerMemoPanel")
        refresh_ui()
    end
end

-- ==============================
-- UI — 빌드 (FriendsFrame 로드 후 1회)
-- ==============================
local function build_ui()
    if memo_frame then return end

    -- ── 탭5 등록 ──────────────────────────────────────────────────────────
    dodo.UI:AddFriendsFrameTab("메모", 5, 30, 30)

    -- ── FRIENDSFRAME_SUBFRAMES 등록 (다른 탭 선택 시 자동 Hide) ──────────
    table_insert(FRIENDSFRAME_SUBFRAMES, "dodo_PlayerMemoPanel")

    -- ── 메모 패널 (FriendsFrame 자식, WHO탭 Inset 위치와 동일) ─────────────
    local panel = CreateFrame("Frame", "dodo_PlayerMemoPanel", FriendsFrame, "InsetFrameTemplate")
    panel:SetPoint("TOPLEFT", FriendsFrame, "TOPLEFT", 4, -83)
    panel:SetPoint("BOTTOMRIGHT", FriendsFrame, "BOTTOMRIGHT", -6, 26)
    panel:Hide()
    memo_frame = panel

    -- ── 컬럼 헤더 (패널 TOP 바로 위) ──────────────────────────────────────
    local col_name = CreateFrame("Button", "dodo_PMColName", panel, "WhoFrameColumnHeaderTemplate")
    col_name:SetPoint("BOTTOMLEFT", panel, "TOPLEFT", 0, 0)
    col_name:SetText("이름")
    WhoFrameColumn_SetWidth(col_name, 150)

    local col_note = CreateFrame("Button", "dodo_PMColNote", panel, "WhoFrameColumnHeaderTemplate")
    col_note:SetPoint("LEFT", col_name, "RIGHT", -2, 0)
    col_note:SetText("메모")
    WhoFrameColumn_SetWidth(col_note, 207)

    -- ── 스크롤 ────────────────────────────────────────────────────────────
    local scroll = CreateFrame("ScrollFrame", nil, panel, "WowScrollBox")
    scroll:SetPoint("TOPLEFT",     panel, "TOPLEFT",      4,  -4)
    scroll:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -22,  2)

    local bar = CreateFrame("EventFrame", nil, panel, "MinimalScrollBar")
    bar:SetPoint("TOPLEFT",    scroll, "TOPRIGHT",    5, -4)
    bar:SetPoint("BOTTOMLEFT", scroll, "BOTTOMRIGHT", 5,  2)
    ScrollUtil.InitScrollFrameWithScrollBar(scroll, bar)

    local ROW_H = 22

    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(350, 1)
    scroll:SetScrollChild(content)

    local MAX_ROWS = 20
    local rows     = {}

    local function make_row(i)
        local row = CreateFrame("Frame", nil, content)
        row:SetSize(350, ROW_H)
        row:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -(i - 1) * ROW_H)
        row:Hide()
        row._note = ""

        if i % 2 == 0 then
            local bg = row:CreateTexture(nil, "BACKGROUND")
            bg:SetAllPoints()
            bg:SetColorTexture(1, 1, 1, 0.03)
        end

        -- 이름 버튼
        local name_btn = CreateFrame("Button", nil, row)
        name_btn:SetPoint("LEFT", row, "LEFT", 4, 0)
        name_btn:SetSize(145, ROW_H)
        local name_label = name_btn:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        name_label:SetPoint("LEFT",  name_btn, "LEFT",  0, 0)
        name_label:SetPoint("RIGHT", name_btn, "RIGHT", 0, 0)
        name_label:SetJustifyH("LEFT")
        name_btn:SetFontString(name_label)
        name_btn:SetScript("OnClick", row_name_click)
        row.name_btn = name_btn

        local name_eb = CreateFrame("EditBox", nil, row, "InputBoxTemplate")
        name_eb:SetPoint("LEFT", row, "LEFT", 4, 0)
        name_eb:SetSize(137, ROW_H)
        name_eb:SetAutoFocus(false)
        name_eb:SetScript("OnEnterPressed", row_name_confirm)
        name_eb:SetScript("OnEscapePressed",  row_name_cancel)
        name_eb:SetScript("OnEditFocusLost", row_name_cancel)
        name_eb:Hide()
        row.name_eb = name_eb

        -- 메모 버튼
        local note_btn = CreateFrame("Button", nil, row)
        note_btn:SetPoint("LEFT", row, "LEFT", 151, 0)
        note_btn:SetSize(180, ROW_H)
        local note_label = note_btn:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        note_label:SetPoint("LEFT",  note_btn, "LEFT",  2,  0)
        note_label:SetPoint("RIGHT", note_btn, "RIGHT", -2, 0)
        note_label:SetJustifyH("LEFT")
        note_btn:SetFontString(note_label)
        note_btn:SetScript("OnClick", row_note_click)
        row.note_btn = note_btn

        local note_eb = CreateFrame("EditBox", nil, row, "InputBoxTemplate")
        note_eb:SetPoint("LEFT", row, "LEFT", 151, 0)
        note_eb:SetSize(180, ROW_H)
        note_eb:SetAutoFocus(false)
        note_eb:SetScript("OnEnterPressed", row_note_confirm)
        note_eb:SetScript("OnEscapePressed",  row_note_cancel)
        note_eb:SetScript("OnEditFocusLost", row_note_cancel)
        note_eb:Hide()
        row.note_eb = note_eb

        -- 삭제 버튼
        local del_btn = CreateFrame("Button", nil, row, "UIPanelCloseButton")
        del_btn:SetSize(16, 16)
        del_btn:SetPoint("RIGHT", row, "RIGHT", -2, 0)
        del_btn:SetScript("OnClick", row_del_click)
        row.del_btn = del_btn

        return row
    end

    for i = 1, MAX_ROWS do
        rows[i] = make_row(i)
    end

    panel._rows        = rows
    panel._content     = content
    panel._row_h       = ROW_H
    panel._sorted_keys = {}
    panel._make_row    = make_row

    -- ── 하단 입력 영역 ─────────────────────────────────────────────────────
    local bottom = CreateFrame("Frame", nil, panel)
    bottom:SetPoint("BOTTOMLEFT",  FriendsFrame, "BOTTOMLEFT",   9, 4)
    bottom:SetPoint("BOTTOMRIGHT", FriendsFrame, "BOTTOMRIGHT",  -6, 4)
    bottom:SetHeight(21)

    local add_btn = CreateFrame("Button", nil, bottom, "UIPanelButtonNoTooltipTemplate")
    add_btn:SetSize(80, 21)
    add_btn:SetPoint("RIGHT", bottom, "RIGHT", 0, 0)
    add_btn:SetText("추가")

    local name_input = CreateFrame("EditBox", nil, bottom, "InputBoxTemplate")
    name_input:SetSize(140, 18)
    name_input:SetPoint("LEFT", bottom, "LEFT", 0, 0)
    name_input:SetAutoFocus(false)
    name_input:SetMaxLetters(100)

    local note_input = CreateFrame("EditBox", nil, bottom, "InputBoxTemplate")
    note_input:SetPoint("LEFT",  bottom,  "LEFT",  156, 0)
    note_input:SetPoint("RIGHT", add_btn, "LEFT",   -2, 0)
    note_input:SetHeight(21)
    note_input:SetAutoFocus(false)
    note_input:SetMaxLetters(200)

    local ph_name = bottom:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    ph_name:SetPoint("LEFT", name_input, "LEFT", 6, 0)
    ph_name:SetText("이름-서버")

    local ph_note = bottom:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    ph_note:SetPoint("LEFT", note_input, "LEFT", 6, 0)
    ph_note:SetText("메모 (선택)")

    name_input._ph = ph_name
    note_input._ph = ph_note
    name_input:SetScript("OnEditFocusGained", eb_focus_gained)
    name_input:SetScript("OnEditFocusLost",   eb_focus_lost)
    name_input:SetScript("OnEnterPressed",    name_input_enter)
    name_input:SetScript("OnTabPressed",      name_input_enter)
    note_input:SetScript("OnEditFocusGained", eb_focus_gained)
    note_input:SetScript("OnEditFocusLost",   eb_focus_lost)
    note_input:SetScript("OnEnterPressed",    note_input_enter)
    add_btn:SetScript("OnClick", add_btn_click)

    bottom.name_input = name_input
    bottom.note_input = note_input
    bottom._ph_name   = ph_name
    bottom._ph_note   = ph_note

    panel._name_input = name_input
    panel._note_input = note_input
    panel._ph_name    = ph_name
    panel._ph_note    = ph_note

    -- ── FriendsFrame_Update 후킹 ────────────────────────────────────────
    hooksecurefunc("FriendsFrame_Update", on_friends_frame_update)
end

-- ==============================
-- 이벤트
-- ==============================
local init_frame = CreateFrame("Frame")

local function on_event(self, event, arg1)
    if event == "ADDON_LOADED" then
        if arg1 == "dodoQOL" then
            dodoDB = dodoDB or {}
            dodoDB.playerMemoList = dodoDB.playerMemoList or {}
        elseif arg1 == "Blizzard_SocialUI" then
            if not memo_frame and FriendsFrame then
                build_ui()
            end
        end

    elseif event == "PLAYER_LOGIN" then
        if FriendsFrame then
            build_ui()
            self:UnregisterEvent("ADDON_LOADED")
        end
        check_party_for_memo()
        hook_menus()
        self:UnregisterEvent("PLAYER_LOGIN")

    elseif event == "GROUP_ROSTER_UPDATE" then
        check_party_for_memo()

    elseif event == "PLAYER_ENTERING_WORLD" then
        wipe(last_warned_set)
        check_party_for_memo()
    end
end

init_frame:RegisterEvent("ADDON_LOADED")
init_frame:RegisterEvent("PLAYER_LOGIN")
init_frame:RegisterEvent("GROUP_ROSTER_UPDATE")
init_frame:RegisterEvent("PLAYER_ENTERING_WORLD")
init_frame:SetScript("OnEvent", on_event)
