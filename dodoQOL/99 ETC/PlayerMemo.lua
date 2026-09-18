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
local C_FriendList       = C_FriendList
local C_Timer            = C_Timer
local CreateFrame        = CreateFrame
local GetNumGroupMembers = GetNumGroupMembers
local GetRealmName       = GetRealmName
local IsInRaid           = IsInRaid
local issecretvalue      = issecretvalue or function() return false end
local math_max           = math.max
local pairs              = pairs
local StaticPopup_Show   = StaticPopup_Show
local string_format      = string.format
local table_concat       = table.concat
local table_insert       = table.insert
local table_sort         = table.sort
local UnitExists         = UnitExists
local UnitIsUnit         = UnitIsUnit
local UnitName           = UnitName
local wipe               = wipe

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
    C_FriendList.AddIgnore(name)
    if PM.RefreshUI then PM.RefreshUI() end
end

function PM.Remove(key)
    if not key then return end
    if dodoDB.playerMemoList then
        dodoDB.playerMemoList[key] = nil
    end
    C_FriendList.DelIgnore(key)
    if PM.RefreshUI then PM.RefreshUI() end
end

function PM.IsIgnored(key)
    return key ~= nil
        and dodoDB.playerMemoList ~= nil
        and dodoDB.playerMemoList[key] ~= nil
end

-- ==============================
-- WoW 무시목록 동기화
-- ==============================
local function sync_db_to_wow()
    local list = dodoDB.playerMemoList
    if not list then return end
    local count = C_FriendList.GetNumIgnores() or 0
    local wow_set = {}
    for i = 1, count do
        local n = C_FriendList.GetIgnoreName(i)
        if n then wow_set[n] = true end
    end
    for name in pairs(list) do
        if not wow_set[name] then
            C_FriendList.AddIgnore(name)
        end
    end
end

local function sync_wow_to_db()
    local count = C_FriendList.GetNumIgnores() or 0
    if count == 0 then return end
    dodoDB.playerMemoList = dodoDB.playerMemoList or {}
    for i = 1, count do
        local name = C_FriendList.GetIgnoreName(i)
        if name and not dodoDB.playerMemoList[name] then
            dodoDB.playerMemoList[name] = { note = "", date = date("%Y-%m-%d") }
        end
    end
end

-- ==============================
-- 파티 경고
-- ==============================
local last_warned_set   = {}
local cur_set           = {}   -- 호이스팅: 매 호출 wipe 재사용
local new_lines         = {}   -- 호이스팅: 매 호출 wipe 재사용
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
                        table_insert(new_lines, string_format(
                            "■ %s\n   메모: %s",
                            used_key,
                            (entry.note ~= "" and entry.note) or "(없음)"))
                    end
                end
            end
        end
    end

    wipe(last_warned_set)
    for k in pairs(cur_set) do last_warned_set[k] = true end

    if #new_lines > 0 then
        StaticPopup_Show("DODO_PLAYER_MEMO_WARN",
            "메모된 플레이어가 파티에 있습니다:\n\n"
            .. table_concat(new_lines, "\n\n"))
    end
end

-- 디바운스 진입점: 0.5초 내 중복 발화 묶기
local function check_party_for_memo()
    if not check_party_pending then
        check_party_pending = true
        C_Timer.After(0.5, check_party_impl)
    end
end

-- ==============================
-- UI — 정적 핸들러
-- ==============================
local memo_frame = nil

-- 행: 이름 버튼 클릭 → EditBox 전환
local function row_name_click(self)
    local row = self:GetParent()
    self:Hide()
    row.name_eb:SetText(row.key or "")
    row.name_eb:Show()
    row.name_eb:SetFocus()
end

-- 행: 이름 EditBox Enter 확정 (키 변경 = DB 키 교체 + 차단목록 갱신)
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
        C_FriendList.DelIgnore(old_key)
        C_FriendList.AddIgnore(new_key)
        if PM.RefreshUI then PM.RefreshUI() end
    end
end

-- 행: 이름 EditBox Esc 취소
local function row_name_cancel(self)
    self:ClearFocus()
    self:Hide()
    self:GetParent().name_btn:Show()
end

-- 행: 메모 버튼 클릭 → EditBox 전환
local function row_note_click(self)
    local row = self:GetParent()
    self:Hide()
    row.note_eb:SetText(row._note or "")
    row.note_eb:Show()
    row.note_eb:SetFocus()
end

-- 행: 메모 EditBox Enter 확정
local function row_note_confirm(self)
    local row = self:GetParent()
    local key = row.key
    if key and dodoDB.playerMemoList and dodoDB.playerMemoList[key] then
        dodoDB.playerMemoList[key].note = self:GetText()
        row._note = self:GetText()
    end
    self:ClearFocus()
    self:Hide()
    row.note_btn:Show()
    if PM.RefreshUI then PM.RefreshUI() end
end

-- 행: 메모 EditBox Esc 취소
local function row_note_cancel(self)
    self:ClearFocus()
    self:Hide()
    self:GetParent().note_btn:Show()
end

-- 행: 삭제 버튼
local function row_del_click(self)
    local row = self:GetParent()
    if row.key then PM.Remove(row.key) end
end

-- 입력창 공통: 포커스 획득 시 placeholder 숨김
local function eb_focus_gained(self)
    if self._ph then self._ph:Hide() end
end

-- 입력창 공통: 포커스 해제 시 빈 경우 placeholder 표시
local function eb_focus_lost(self)
    if self._ph and self:GetText() == "" then self._ph:Show() end
end

-- 하단: 이름 Enter → 메모 입력창으로 포커스 이동
local function name_input_enter(self)
    self:ClearFocus()
    local b = self:GetParent()
    if b.note_input then b.note_input:SetFocus() end
end

-- 하단: 추가 버튼 / 메모 Enter → 공통 추가 로직
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
-- UI — refresh (memo_frame 저장 후 참조)
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

    -- 항목 수가 행 풀 크기 초과 시 행 동적 추가
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
-- UI — 빌드 (FriendsFrame 로드 후 1회)
-- ==============================
local function build_ui()
    if memo_frame then return end

    local frame = dodo.UI:CreateButtonPanel("dodo_PlayerMemoFrame", "플레이어 메모", false, true)
    frame:SetSize(385, 424)
    frame:SetFrameLevel(555)
    frame:SetPoint("TOPLEFT", FriendsFrame, "TOPRIGHT", 2, 0)
    frame:Hide()
    memo_frame = frame

    local inset = frame.Inset

    -- 컬럼 헤더 (Inset TOPLEFT 기준 BOTTOMLEFT 앵커 → 헤더가 Inset 바로 위에 위치)
    local col_name = CreateFrame("Button", "dodo_PMColName", frame, "WhoFrameColumnHeaderTemplate")
    col_name:SetPoint("BOTTOMLEFT", inset, "TOPLEFT", 4, 0)
    col_name:SetText("이름-서버")
    WhoFrameColumn_SetWidth(col_name, 150)

    local col_note = CreateFrame("Button", "dodo_PMColNote", frame, "WhoFrameColumnHeaderTemplate")
    col_note:SetPoint("LEFT", col_name, "RIGHT", -2, 0)
    col_note:SetText("메모")
    WhoFrameColumn_SetWidth(col_note, 200)

    local scroll = frame.Scroll

    -- 행 높이(ROW_H) 기준으로 1틱 = 1행 스크롤
    local ROW_H    = 22
    scroll:SetPanExtent(ROW_H)

    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(348, 1)
    scroll:SetScrollChild(content)
    local MAX_ROWS = 20
    local rows     = {}

    -- 행 생성 클로저 (동적 확장 시 재사용)
    local function make_row(i)
        local row = CreateFrame("Frame", nil, content)
        row:SetSize(348, ROW_H)
        row:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -(i - 1) * ROW_H)
        row:Hide()
        row._note = ""

        if i % 2 == 0 then
            local bg = row:CreateTexture(nil, "BACKGROUND")
            bg:SetAllPoints()
            bg:SetColorTexture(1, 1, 1, 0.03)
        end

        local name_btn = CreateFrame("Button", nil, row)
        name_btn:SetPoint("LEFT", row, "LEFT", 10, 0)
        name_btn:SetSize(148, ROW_H)
        local name_label = name_btn:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        name_label:SetPoint("LEFT",  name_btn, "LEFT",  0, 0)
        name_label:SetPoint("RIGHT", name_btn, "RIGHT", 0, 0)
        name_label:SetJustifyH("LEFT")
        name_btn:SetFontString(name_label)
        name_btn:SetScript("OnClick", row_name_click)
        row.name_btn = name_btn

        local name_eb = CreateFrame("EditBox", nil, row, "InputBoxTemplate")
        name_eb:SetPoint("LEFT", row, "LEFT", 10, 0)
        name_eb:SetSize(140, ROW_H)
        name_eb:SetAutoFocus(false)
        name_eb:SetScript("OnEnterPressed", row_name_confirm)
        name_eb:SetScript("OnEscapePressed",  row_name_cancel)
        name_eb:SetScript("OnEditFocusLost", row_name_cancel)
        name_eb:Hide()
        row.name_eb = name_eb

        local note_btn = CreateFrame("Button", nil, row)
        note_btn:SetPoint("LEFT", row, "LEFT", 150, 0)
        note_btn:SetSize(176, ROW_H)
        local note_label = note_btn:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        note_label:SetPoint("LEFT",  note_btn, "LEFT",  2,  0)
        note_label:SetPoint("RIGHT", note_btn, "RIGHT", -2, 0)
        note_label:SetJustifyH("LEFT")
        note_btn:SetFontString(note_label)
        note_btn:SetScript("OnClick", row_note_click)
        row.note_btn = note_btn

        local note_eb = CreateFrame("EditBox", nil, row, "InputBoxTemplate")
        note_eb:SetPoint("LEFT", row, "LEFT", 150, 0)
        note_eb:SetSize(176, ROW_H)
        note_eb:SetAutoFocus(false)
        note_eb:SetScript("OnEnterPressed", row_note_confirm)
        note_eb:SetScript("OnEscapePressed",  row_note_cancel)
        note_eb:SetScript("OnEditFocusLost", row_note_cancel)
        note_eb:Hide()
        row.note_eb = note_eb

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

    -- memo_frame에 데이터 저장 (refresh_ui가 참조)
    frame._rows        = rows
    frame._content     = content
    frame._row_h       = ROW_H
    frame._sorted_keys = {}
    frame._make_row    = make_row

    -- 하단 입력 영역
    local bottom = CreateFrame("Frame", nil, frame)
    bottom:SetPoint("BOTTOMLEFT",  frame, "BOTTOMLEFT",   9, 4)
    bottom:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT",  -6, 4)
    bottom:SetHeight(21)

    local add_btn = CreateFrame("Button", nil, bottom, "UIPanelButtonNoTooltipTemplate")
    add_btn:SetSize(80, 21)
    add_btn:SetPoint("RIGHT", bottom, "RIGHT", 0, 0)
    add_btn:SetText("추가")

    local name_input = CreateFrame("EditBox", nil, bottom, "InputBoxTemplate")
    name_input:SetSize(130, 18)
    name_input:SetPoint("LEFT", bottom, "LEFT", 6, 0)
    name_input:SetAutoFocus(false)
    name_input:SetMaxLetters(100)

    local note_input = CreateFrame("EditBox", nil, bottom, "InputBoxTemplate")
    note_input:SetPoint("LEFT",  bottom,   "LEFT",  150, 0)
    note_input:SetPoint("RIGHT", add_btn,  "LEFT",   -4, 0)
    note_input:SetHeight(21)
    note_input:SetAutoFocus(false)
    note_input:SetMaxLetters(200)

    -- placeholder
    local ph_name = bottom:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    ph_name:SetPoint("LEFT", name_input, "LEFT", 6, 0)
    ph_name:SetText("이름-서버")

    local ph_note = bottom:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    ph_note:SetPoint("LEFT", note_input, "LEFT", 6, 0)
    ph_note:SetText("메모 (선택)")

    -- 정적 핸들러 연결
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

    -- bottom에 입력창 참조 저장 (정적 핸들러가 GetParent()로 접근)
    bottom.name_input = name_input
    bottom.note_input = note_input
    bottom._ph_name   = ph_name
    bottom._ph_note   = ph_note

    -- FriendsFrame 연동
    FriendsFrame:HookScript("OnShow", function()
        if dodoDB.enablePlayerMemo ~= false then
            frame:Show()
            refresh_ui()
        end
    end)
    FriendsFrame:HookScript("OnHide", function()
        frame:Hide()
    end)

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
            -- FriendsFrame 늦게 로드될 경우 대비
            if not memo_frame and FriendsFrame then
                build_ui()
            end
        end

    elseif event == "PLAYER_LOGIN" then
        if FriendsFrame then
            build_ui()
            self:UnregisterEvent("ADDON_LOADED")
        end
        -- Blizzard_SocialUI 미로드 시 ADDON_LOADED 유지
        sync_db_to_wow()
        check_party_for_memo()
        self:UnregisterEvent("PLAYER_LOGIN")

    elseif event == "IGNORELIST_UPDATE" then
        sync_wow_to_db()
        if PM.RefreshUI then PM.RefreshUI() end

    elseif event == "GROUP_ROSTER_UPDATE" then
        check_party_for_memo()

    elseif event == "PLAYER_ENTERING_WORLD" then
        wipe(last_warned_set)
        check_party_for_memo()
    end
end

init_frame:RegisterEvent("ADDON_LOADED")
init_frame:RegisterEvent("PLAYER_LOGIN")
init_frame:RegisterEvent("IGNORELIST_UPDATE")
init_frame:RegisterEvent("GROUP_ROSTER_UPDATE")
init_frame:RegisterEvent("PLAYER_ENTERING_WORLD")
init_frame:SetScript("OnEvent", on_event)
