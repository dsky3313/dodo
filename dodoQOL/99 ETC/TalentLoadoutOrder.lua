-- ==============================
-- Inspired
-- ==============================
-- Reorder Talent Loadouts (https://www.curseforge.com/wow/addons/reorder-talent-loadouts)

-- ==============================
-- 설정 및 테이블
-- ==============================
---@diagnostic disable: lowercase-global, param-type-mismatch, redundant-parameter, undefined-field, undefined-global
local dodo = _G.dodo
dodoDB = dodoDB or {}

-- ==============================
-- 캐싱
-- ==============================
local C_AddOns = C_AddOns
local C_Timer = C_Timer
local CreateFrame = CreateFrame
local GetCursorPosition = GetCursorPosition
local GetTime = GetTime
local ipairs = ipairs
local IsMouseButtonDown = IsMouseButtonDown
local Menu = Menu
local pairs = pairs
local PlaySound = PlaySound
local PlayerUtil = PlayerUtil
local SOUNDKIT = SOUNDKIT
local table_insert = table.insert
local table_remove = table.remove
local table_sort = table.sort
local UIParent = UIParent
local UnitGUID = UnitGUID
local wipe = wipe

local gold = (dodo.Colors and dodo.Colors.Primary and dodo.Colors.Primary.Gold) or { r = 1, g = 0.82, b = 0 }

local CLICK_BLOCK_TIME = 0.2 -- 드롭 직후 클릭(로드아웃 선택) 무시 시간

-- ==============================
-- 상태
-- ==============================
local rows = {}          -- 현재 열린 메뉴의 로드아웃 버튼 → configID
local row_list = {}      -- 드래그 시작 시 위→아래 정렬한 버튼 목록
local drag_id = nil      -- 드래그 중인 configID
local drag_btn = nil
local drop_pos = nil     -- 넣을 위치 (1 ~ #row_list + 1)
local dropped_at = 0
local marker = nil
local apply_pending = false
local show_hooked = false

local pump = CreateFrame("Frame")
local events = CreateFrame("Frame")

local function is_enabled()
    return dodoDB.useTalentLoadoutOrder ~= false
end

local function get_load_system()
    local tf = PlayerSpellsFrame and PlayerSpellsFrame.TalentsFrame
    if not tf or not tf.LoadSystem then return nil end
    if tf.IsInspecting and tf:IsInspecting() then return nil end
    return tf.LoadSystem
end

-- ==============================
-- 저장 (dodoDB.talentLoadoutOrder[GUID][specID] = { configID, ... })
-- ==============================
local function get_saved(create)
    local guid = UnitGUID("player")
    local spec_id = PlayerUtil.GetCurrentSpecID()
    if not guid or not spec_id then return nil end
    local db = dodoDB.talentLoadoutOrder
    if not db then
        if not create then return nil end
        db = {}
        dodoDB.talentLoadoutOrder = db
    end
    db[guid] = db[guid] or (create and {}) or nil
    local char = db[guid]
    if not char then return nil end
    if create and not char[spec_id] then char[spec_id] = {} end
    return char[spec_id], char, spec_id
end

-- 보이는 순서 저장. 지금 목록에 없는 기존 저장 항목은 뒤에 붙여 유지
local function save_order(list)
    local old, char, spec_id = get_saved(true)
    if not char then return end
    local seen, order = {}, {}
    for _, id in ipairs(list) do
        order[#order + 1] = id
        seen[id] = true
    end
    for _, id in ipairs(old) do
        if not seen[id] then order[#order + 1] = id end
    end
    char[spec_id] = order
end

-- ==============================
-- 저장 순서 적용
-- ==============================
-- 저장된 항목은 순위대로, 새 로드아웃은 원래 순서 유지하며 뒤로 (초보자 빌드가 맨 끝이면 그대로 끝)
-- 주의: talentsFrame.configIDs는 건드리지 않음 (taint → 로드아웃 목록 깨짐). possibleSelections만 수정
local function apply_saved_order()
    apply_pending = false
    if not is_enabled() or drag_id then return end
    local ls = get_load_system()
    local list = ls and ls.possibleSelections
    if not list or #list <= 1 then return end
    local saved = get_saved(false)
    if not saved or #saved == 0 then return end

    local rank = {}
    for i, id in ipairs(saved) do rank[id] = i end
    local base = #saved
    local key = {}
    for i, id in ipairs(list) do key[id] = rank[id] or (base + i) end

    local sorted = {}
    for i, id in ipairs(list) do sorted[i] = id end
    table_sort(sorted, function(a, b) return key[a] < key[b] end)

    local changed = false
    for i = 1, #list do
        if list[i] ~= sorted[i] then
            list[i] = sorted[i]
            changed = true
        end
    end
    if not changed then return end

    local dd = ls.GetDropdown and ls:GetDropdown()
    if dd and dd.IsMenuOpen and dd:IsMenuOpen() and dd.GenerateMenu then dd:GenerateMenu() end
end

local function schedule_apply()
    if apply_pending then return end
    apply_pending = true
    C_Timer.After(0.25, apply_saved_order)
end

-- ==============================
-- 드래그
-- ==============================
local function by_top(a, b)
    return (a:GetTop() or 0) > (b:GetTop() or 0)
end

local function get_marker()
    if not marker then
        -- 메뉴(FULLSCREEN_DIALOG)보다 위에 그려야 함
        marker = CreateFrame("Frame", nil, UIParent)
        marker:SetFrameStrata("TOOLTIP")
        marker:SetHeight(2)
        local tex = marker:CreateTexture(nil, "OVERLAY")
        tex:SetAllPoints()
        tex:SetColorTexture(gold.r, gold.g, gold.b, 1)
    end
    return marker
end

-- 커서 높이 → 넣을 위치. 메뉴에서 멀리 벗어나면 nil
local function update_drop_pos()
    local n = #row_list
    local first, last = row_list[1], row_list[n]
    local left, right = first:GetLeft(), first:GetRight()
    local top, bottom = first:GetTop(), last:GetBottom()
    local line = get_marker()
    if not left or not bottom then
        drop_pos = nil
        line:Hide()
        return
    end

    local scale = UIParent:GetEffectiveScale()
    local x, y = GetCursorPosition()
    x, y = x / scale, y / scale
    if x < left - 100 or x > right + 100 or y > top + 50 or y < bottom - 50 then
        drop_pos = nil
        line:Hide()
        return
    end

    local pos = n + 1
    for i = 1, n do
        local _, cy = row_list[i]:GetCenter()
        if cy and y > cy then
            pos = i
            break
        end
    end
    drop_pos = pos

    line:ClearAllPoints()
    local ref = row_list[pos] or last
    local edge = row_list[pos] and "TOP" or "BOTTOM"
    line:SetPoint("LEFT", ref, edge .. "LEFT", 0, 0)
    line:SetPoint("RIGHT", ref, edge .. "RIGHT", 0, 0)
    line:Show()
end

local function finish_drag()
    if not drag_id then return end
    local id, pos = drag_id, drop_pos
    pump:SetScript("OnUpdate", nil)
    if drag_btn then drag_btn:SetAlpha(1) end
    if marker then marker:Hide() end
    drag_id, drag_btn, drop_pos = nil, nil, nil
    dropped_at = GetTime()

    local ls = get_load_system()
    local list = ls and ls.possibleSelections
    if not pos or not list then return end

    local from
    for i, v in ipairs(list) do
        if v == id then from = i break end
    end
    if not from or pos == from or pos == from + 1 then return end

    table_remove(list, from)
    table_insert(list, pos > from and pos - 1 or pos, id)
    save_order(list)
    PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)

    -- UpdateSelectionOptions 호출 금지 (taint). 블리자드 메뉴 생성기로 다시 그림
    local dd = ls.GetDropdown and ls:GetDropdown()
    if dd and dd.GenerateMenu then dd:GenerateMenu() end
end

local function on_pump_update()
    if not IsMouseButtonDown("LeftButton") then
        finish_drag()
    else
        update_drop_pos()
    end
end

local function on_drag_start(self)
    local id = rows[self]
    if not id or drag_id or not is_enabled() then return end
    wipe(row_list)
    for btn in pairs(rows) do
        if btn:IsShown() then row_list[#row_list + 1] = btn end
    end
    if #row_list <= 1 then return end
    table_sort(row_list, by_top)

    drag_id, drag_btn = id, self
    self:SetAlpha(0.4)
    update_drop_pos()
    pump:SetScript("OnUpdate", on_pump_update)
end

-- ==============================
-- 메뉴 연동
-- ==============================
local function can_select()
    return not drag_id and (GetTime() - dropped_at) > CLICK_BLOCK_TIME
end

-- 메뉴 버튼은 재사용 + InitializeFrame에서 OnMouseDown이 덮어써짐 → 매번 드래그 등록/스크립트 재설정
local function on_row_init(button, description)
    rows[button] = description:GetData()
    button:RegisterForDrag("LeftButton")
    button:SetScript("OnDragStart", on_drag_start)
    button:SetScript("OnDragStop", finish_drag)
end

local function on_menu_closed()
    finish_drag()
    wipe(rows)
end

local function on_modify_menu(_, root_description)
    if not is_enabled() then return end
    local ls = get_load_system()
    if not ls or not ls.possibleSelections then return end

    local is_loadout = {}
    for _, id in ipairs(ls.possibleSelections) do is_loadout[id] = true end

    wipe(rows)
    root_description:AddMenuReleasedCallback(on_menu_closed)
    for _, desc in root_description:EnumerateElementDescriptions() do
        local data = desc.GetData and desc:GetData()
        if data and is_loadout[data] then
            desc:SetCanSelect(can_select)
            desc:AddInitializer(on_row_init)
        end
    end
end

-- 블리자드 공식 메뉴 수정 API (해제 불가 → 콜백 안에서 토글 체크)
Menu.ModifyMenu("MENU_CLASS_TALENT_PROFILE", on_modify_menu)

-- ==============================
-- 이벤트
-- ==============================
local APPLY_EVENTS = {
    "PLAYER_ENTERING_WORLD",
    "ZONE_CHANGED_NEW_AREA",
    "TRAIT_CONFIG_LIST_UPDATED",
    "ACTIVE_PLAYER_SPECIALIZATION_CHANGED",
}

-- 특성창 열릴 때 바로 저장 순서로
local function hook_talents_frame()
    if show_hooked or not (PlayerSpellsFrame and PlayerSpellsFrame.TalentsFrame) then return end
    show_hooked = true
    PlayerSpellsFrame.TalentsFrame:HookScript("OnShow", schedule_apply)
end

local function update_visual()
    if is_enabled() then
        events:RegisterEvent("ADDON_LOADED")
        for _, ev in ipairs(APPLY_EVENTS) do events:RegisterEvent(ev) end
        if C_AddOns.IsAddOnLoaded("Blizzard_PlayerSpells") then
            hook_talents_frame()
            schedule_apply()
        end
    else
        events:UnregisterAllEvents()
        finish_drag()
    end
end
dodo.TalentLoadoutOrderUpdateVisual = update_visual

local function on_event(self, event, arg1)
    if event == "PLAYER_LOGIN" then
        self:UnregisterEvent("PLAYER_LOGIN")
        update_visual()
    elseif event == "ADDON_LOADED" then
        if arg1 == "Blizzard_PlayerSpells" then
            hook_talents_frame()
            schedule_apply()
        end
    else
        schedule_apply()
    end
end

events:RegisterEvent("PLAYER_LOGIN")
events:SetScript("OnEvent", on_event)
