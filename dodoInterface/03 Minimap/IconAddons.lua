-- ==============================
-- Inspired
-- ==============================
-- HidingBar (https://www.curseforge.com/wow/addons/hidingbar)

-- ==============================
-- 설정 및 테이블
-- ==============================
---@diagnostic disable: lowercase-global, param-type-mismatch, redundant-parameter, undefined-field, undefined-global
local dodo = _G.dodo
dodoDB = dodoDB or {}

local Config = {
    defaultPoint         = "TOPRIGHT",
    defaultRelativeTo    = "MinimapCluster",
    defaultRelativePoint = "BOTTOMRIGHT",
    defaultX             = -4,
    defaultY             = -1,
    defaultPadding       = -3, -- 바 아이콘 간격
    buttonSize           = 32,
    flyoutCols           = 5,  -- 그리드 아이콘 행 개수
    flyoutGap            = 2,  -- 그리드 아이콘 간격

    sortOrder = {
        ["ExpansionLandingPageMinimapButton"] = 1,
        ["dodoGreatVaultButton"]              = 2,
        ["dodoAddonManagerButton"]            = 3,
        ["NotEvenClose"]                      = 4,
        ["SimulationCraft"]                   = 5,
        ["NSRT"]                              = 6,
        ["Plater"]                            = 97,
        ["MythicDungeonTools"]                = 98,
        ["BugSack"]                           = 99,
    },
    hideSet = {
        ["RaiderIO"] = true,
    },
}

local IGNORE_EXACT = {
    ["MinimapBackdrop"]                 = true,
    ["MinimapZoomIn"]                   = true,
    ["MinimapZoomOut"]                  = true,
    ["GameTimeFrame"]                   = true,
    ["AddonCompartmentFrame"]           = true,
    ["PlumberLandingPageMinimapButton"] = true,  -- 확장팩 버튼 대체용
}
local IGNORE_CONTAINS = { "Minimap.ZoomIn", "Minimap.ZoomOut", "MinimapCluster.Tracking" }

-- 지도 핀/POI 프레임 제외 (Inspired by EllesmereUI)
local PIN_PATTERNS = { "^HandyNotes", "^TomTom", "^HereBeDragons", "^Questie", "^GatherMate", "^pin", "^Pin" }

-- Minimap 자식이 아닐 수 있는 자체 버튼
local EXTRA_BUTTONS = { "Narci_MinimapButton" }

-- ==============================
-- 캐싱
-- ==============================
local C_Timer          = C_Timer
local CreateFrame      = CreateFrame
local InCombatLockdown = InCombatLockdown
local ipairs           = ipairs
local math_ceil        = math.ceil
local math_floor       = math.floor
local math_min         = math.min
local pairs            = pairs
local table_insert     = table.insert
local table_remove     = table.remove
local table_sort       = table.sort
local LibStub          = LibStub
local UIParent         = UIParent

-- ==============================
-- 로컬 상태
-- ==============================
local bar_frame         = nil
local init_frame        = CreateFrame("Frame")
local collected_buttons = {}
local buttons_by_name   = {}
local ticker_obj        = nil
local last_child_count  = 0

local original_parent = {}
local original_points = {}
local original_strata = {}

-- 애드온이 의도한 표시 상태 (false면 그리드에서 제외)
local addon_visible  = {}
local suppress_track = false

-- 숨김 컨테이너 (hideSet 버튼용)
local hidden_frame = CreateFrame("Frame")
hidden_frame:Hide()

local ldb  = nil
local ldbi = nil

local vault_btn = nil

local mgr_btn        = nil
local flyout_frame   = nil
local flyout_elapsed = 0

-- ==============================
-- 기능: 원래 위치로 복구
-- ==============================
local function restore_button(btn)
    if not btn then return end
    local parent = original_parent[btn]
    if parent then btn:SetParent(parent) end

    -- 그리드에서 올린 strata 복구 (LibDBIcon은 strata 고정 상태)
    local strata = original_strata[btn]
    if strata and btn:GetFrameStrata() ~= strata then
        if btn.SetFixedFrameStrata then btn:SetFixedFrameStrata(false) end
        btn:SetFrameStrata(strata)
        if btn.SetFixedFrameStrata then btn:SetFixedFrameStrata(true) end
    end

    local name = btn:GetName()
    -- LibDBIcon 버튼은 라이브러리에 위치 복구 위임 (minimapPos 각도 기반)
    if name and name:find("LibDBIcon10_", 1, true) and ldbi then
        btn:ClearAllPoints()
        ldbi:Show(name:sub(13))
        return
    end
    -- 비-LibDBIcon 버튼: 저장된 원래 SetPoint로 복구
    btn:ClearAllPoints()
    local pts = original_points[btn]
    if pts and pts[1] then
        btn:SetPoint(pts[1], pts[2], pts[3], pts[4], pts[5])
    end
end

-- ==============================
-- 기능: 정렬 기준
-- ==============================
local function sort_buttons(a, b)
    local name_a  = a:GetName() or ""
    local name_b  = b:GetName() or ""
    local addon_a = name_a:find("LibDBIcon10_", 1, true) and name_a:sub(13) or name_a
    local addon_b = name_b:find("LibDBIcon10_", 1, true) and name_b:sub(13) or name_b
    local order_a = Config.sortOrder[addon_a] or 999
    local order_b = Config.sortOrder[addon_b] or 999
    if order_a ~= order_b then return order_a < order_b end
    return name_a < name_b
end

-- ==============================
-- 기능: 아이콘 모음 그리드 배치 (Inspired by EllesmereUI)
-- ==============================
local function place_in_flyout(btn, index, size, gap)
    local cols = Config.flyoutCols
    local col  = index % cols
    local row  = math_floor(index / cols)

    btn:SetParent(flyout_frame)
    -- LibDBIcon이 strata/level 고정해둠: 풀고 패널 위로 올린 뒤 다시 고정
    if btn.SetFixedFrameStrata then btn:SetFixedFrameStrata(false) end
    if btn.SetFixedFrameLevel then btn:SetFixedFrameLevel(false) end
    btn:SetFrameStrata("DIALOG")
    btn:SetFrameLevel(flyout_frame:GetFrameLevel() + 5)
    if btn.SetFixedFrameStrata then btn:SetFixedFrameStrata(true) end
    if btn.SetFixedFrameLevel then btn:SetFixedFrameLevel(true) end

    suppress_track = true
    btn:Show()
    suppress_track = false
    btn:ClearAllPoints()
    btn:SetSize(size, size)
    btn:SetPoint("TOPLEFT", flyout_frame, "TOPLEFT", gap + col * (size + gap), -(gap + row * (size + gap)))
end

-- ==============================
-- 기능: 레이아웃 정렬
-- ==============================
local function update_layout()
    if not bar_frame then return end
    if InCombatLockdown() then return end
    if dodoDB.enableInterface == false or dodoDB.useIconAddons == false then return end

    local size    = Config.buttonSize
    local padding = Config.defaultPadding

    table_sort(collected_buttons, sort_buttons)

    local prev       = nil
    local count      = 0
    local grid_count = 0
    local gap        = Config.flyoutGap

    for _, btn in ipairs(collected_buttons) do
        local name      = btn:GetName()
        local addon_key = name and (name:find("LibDBIcon10_", 1, true) and name:sub(13) or name)

        if Config.hideSet[addon_key] then
            btn:SetParent(hidden_frame)
            btn:Hide()
        elseif Config.sortOrder[addon_key] then
            btn:SetParent(bar_frame)
            btn:Show()
            btn:ClearAllPoints()
            btn:SetSize(size, size)
            if not prev then
                btn:SetPoint("TOPLEFT", bar_frame, "TOPLEFT", padding, -padding)
            else
                btn:SetPoint("LEFT", prev, "RIGHT", padding, 0)
            end
            prev  = btn
            count = count + 1
        elseif flyout_frame and addon_visible[btn] ~= false then
            place_in_flyout(btn, grid_count, size, gap)
            grid_count = grid_count + 1
        end
    end

    if flyout_frame then
        local cols = math_min(grid_count, Config.flyoutCols)
        local rows = math_ceil(grid_count / Config.flyoutCols)
        flyout_frame:SetSize(cols * (size + gap) + gap, rows * (size + gap) + gap)
        flyout_frame.count = grid_count
        if grid_count == 0 then flyout_frame:Hide() end
    end

    if count == 0 then
        bar_frame:Hide()
    else
        bar_frame:Show()
        bar_frame:SetSize((size + padding) * count + padding, size + padding * 2)
    end
end

-- ==============================
-- 기능: 버튼 추가 / 제거
-- ==============================
local function is_ignored(name)
    if not name then return true end
    if IGNORE_EXACT[name] then return true end
    for _, v in ipairs(IGNORE_CONTAINS) do
        if name:find(v, 1, true) then return true end
    end
    for _, v in ipairs(PIN_PATTERNS) do
        if name:find(v) then return true end
    end
    return false
end

-- 애드온 자체 Show/Hide만 추적 (우리 호출은 suppress_track으로 제외)
local function on_btn_show(self)
    if not suppress_track then addon_visible[self] = true end
end

local function on_btn_hide(self)
    if not suppress_track then addon_visible[self] = false end
end

local function add_button(btn, name)
    if not btn then return end
    name = name or btn:GetName()
    if not name or buttons_by_name[name] then return end
    if is_ignored(name) then return end

    if not original_parent[btn] then
        original_parent[btn] = btn:GetParent()
        local pts = {}
        for i = 1, btn:GetNumPoints() do
            pts[i] = { btn:GetPoint(i) }
        end
        original_points[btn] = pts[1]
        original_strata[btn] = btn:GetFrameStrata()

        addon_visible[btn] = btn:IsShown()
        hooksecurefunc(btn, "Show", on_btn_show)
        hooksecurefunc(btn, "Hide", on_btn_hide)
    end

    buttons_by_name[name] = btn
    table_insert(collected_buttons, btn)
end

local function remove_button(btn, name)
    if not btn then return end
    name = name or btn:GetName()
    if not name then return end

    if buttons_by_name[name] then
        buttons_by_name[name] = nil
        for i, v in ipairs(collected_buttons) do
            if v == btn then
                table_remove(collected_buttons, i)
                break
            end
        end
        restore_button(btn)
    end
end

-- ==============================
-- 기능: 버튼 수집
-- ==============================
local function grab_db_icon_buttons()
    if ldbi and ldbi.objects then
        for name, btn in pairs(ldbi.objects) do
            if btn then
                add_button(btn, "LibDBIcon10_" .. name)
            end
        end
    end
end

local function scan_minimap_children()
    local count = Minimap:GetNumChildren()
    if count == last_child_count then return end
    last_child_count = count

    -- EUI 방식: LibDBIcon + 이름 있는 Button (숫자로 끝나는 이름, 너비 20 미만 제외)
    local children = { Minimap:GetChildren() }
    for _, child in ipairs(children) do
        local name = child:GetName()
        if name and name:find("LibDBIcon10_", 1, true) then
            local addon_key = name:sub(13)
            if addon_key and addon_key ~= "" then
                add_button(child, name)
            end
        elseif name and child:IsObjectType("Button") and not name:find("%d$")
            and (child:GetWidth() or 0) >= 20 then
            add_button(child, name)
        end
    end
end

local function refresh_all_buttons()
    if InCombatLockdown() then return end

    grab_db_icon_buttons()
    scan_minimap_children()

    local exp_btn = ExpansionLandingPageMinimapButton
    if exp_btn then
        add_button(exp_btn, "ExpansionLandingPageMinimapButton")
    end

    if vault_btn then
        add_button(vault_btn, "dodoGreatVaultButton")
    end

    if mgr_btn then
        add_button(mgr_btn, "dodoAddonManagerButton")
    end

    for _, name in ipairs(EXTRA_BUTTONS) do
        local btn = _G[name]
        if btn then add_button(btn, name) end
    end

    update_layout()
end

-- ==============================
-- 기능: 위대한 금고 버튼 (Inspired by EllesmereUI)
-- ==============================
local VAULT_ROWS = {
    { label = "레이드", type = 3 },  -- Enum.WeeklyRewardChestThresholdType.Raid
    { label = "쐐기",   type = 1 },  -- Activities
    { label = "월드",   type = 6 },  -- World
}

local function sort_activities(a, b)
    if a.index ~= b.index then return (a.index or 0) < (b.index or 0) end
    return (a.threshold or 0) < (b.threshold or 0)
end

local function vault_cell(info, is_raid)
    if not info or not info.threshold or info.threshold <= 0 then return "|cff949494-|r" end
    local progress  = info.progress or 0
    local threshold = info.threshold
    if progress >= threshold then
        if not is_raid and (info.level or 0) > 0 then
            return "|cff2dcb59+" .. info.level .. "|r"
        end
        return ("|cff2dcb59%d/%d|r"):format(progress, threshold)
    elseif progress > 0 then
        return ("|cffcf9736%d/%d|r"):format(progress, threshold)
    end
    return ("|cff949494%d/%d|r"):format(progress, threshold)
end

local function toggle_vault()
    if not C_AddOns.IsAddOnLoaded("Blizzard_WeeklyRewards") then
        C_AddOns.LoadAddOn("Blizzard_WeeklyRewards")
    end
    -- 원본(WeeklyRewards_ShowUI)처럼 UIPanel로 열기: ESC 닫기 지원
    local vault = WeeklyRewardsFrame
    if not vault then return end
    if vault:IsShown() then
        HideUIPanel(vault)
    else
        ShowUIPanel(vault, true)
    end
end

local function vault_on_enter(self)
    GameTooltip:SetOwner(self, "ANCHOR_BOTTOMLEFT")
    GameTooltip:AddLine("위대한 금고")
    for _, row in ipairs(VAULT_ROWS) do
        local acts  = C_WeeklyRewards.GetActivities(row.type) or {}
        table_sort(acts, sort_activities)
        local is_raid = row.type == 3
        local cells = vault_cell(acts[1], is_raid) .. "  " .. vault_cell(acts[2], is_raid) .. "  " .. vault_cell(acts[3], is_raid)
        GameTooltip:AddDoubleLine(row.label, cells, 0.81, 0.59, 0.21)
    end
    GameTooltip:Show()
end

local function vault_on_leave(self)
    GameTooltip:Hide()
end

local function create_vault_button()
    if vault_btn or not C_WeeklyRewards then return end
    -- 원래 부모를 hidden_frame으로: 비활성 시 restore_button이 여기로 되돌려 숨김
    vault_btn = CreateFrame("Button", "dodoGreatVaultButton", hidden_frame)
    vault_btn:SetSize(Config.buttonSize, Config.buttonSize)

    local icon = vault_btn:CreateTexture(nil, "ARTWORK")
    icon:SetAtlas("greatVault-whole-normal")
    icon:SetPoint("CENTER")
    icon:SetSize(24 * 105 / 108, 24)  -- 원본 105x108 비율
    vault_btn.icon = icon

    local hl = vault_btn:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAtlas("greatVault-whole-normal")
    hl:SetAllPoints(icon)
    hl:SetBlendMode("ADD")
    hl:SetAlpha(0.6)

    vault_btn:SetScript("OnEnter", vault_on_enter)
    vault_btn:SetScript("OnLeave", vault_on_leave)
    vault_btn:SetScript("OnClick", toggle_vault)
end

-- ==============================
-- 기능: 애드온 프로필 (Inspired by SimpleAddonManager)
-- ==============================
-- dodoDB.addonProfiles[이름] = { addons = { [애드온이름] = true } }
local function get_profiles()
    dodoDB.addonProfiles = dodoDB.addonProfiles or {}
    return dodoDB.addonProfiles
end

local function get_sorted_keys(t)
    local list = {}
    for k in pairs(t) do list[#list + 1] = k end
    table_sort(list)
    return list
end

-- 현재 캐릭터의 활성 애드온 (애드온 목록 "모두" 변경도 현재 캐릭터에 반영됨)
local function snapshot_addons()
    local addons = {}
    local guid   = UnitGUID("player")
    for i = 1, C_AddOns.GetNumAddOns() do
        if C_AddOns.GetAddOnEnableState(i, guid) > Enum.AddOnEnableState.None then
            addons[C_AddOns.GetAddOnInfo(i)] = true
        end
    end
    return addons
end

-- mode: "load" 전부 끄고 켜기 / "enable" 추가로 켜기 / "disable" 프로필 애드온 끄기
-- character: nil = 모든 캐릭터
local function apply_profile(name, mode, character)
    local profile = get_profiles()[name]
    if not profile then return end

    if mode == "load" then C_AddOns.DisableAllAddOns(character) end
    for addon in pairs(profile.addons) do
        if C_AddOns.DoesAddOnExist(addon) and not addon:find("^dodo") then
            if mode == "disable" then
                C_AddOns.DisableAddOn(addon, character)
            else
                C_AddOns.EnableAddOn(addon, character)
            end
        end
    end
    -- dodo 계열은 항상 유지
    for i = 1, C_AddOns.GetNumAddOns() do
        if C_AddOns.GetAddOnInfo(i):find("^dodo") then C_AddOns.EnableAddOn(i, character) end
    end
end

-- ==============================
-- 기능: 애드온 목록 프로필 버튼
-- ==============================
local profile_btn = nil

local function get_edit_box(dialog)
    return dialog.GetEditBox and dialog:GetEditBox() or dialog.editBox
end

-- 애드온 목록 드롭다운 선택 캐릭터 (모두 = nil, 기본값 = 현재 캐릭터)
local function get_list_character()
    local dropdown = AddonList and AddonList.Dropdown
    local text = dropdown and dropdown.Text and dropdown.Text:GetText()
    if text == ALL then return nil end
    return UnitGUID("player")
end

-- 목록 체크박스만 변경: 확인 = 저장+리로드, 취소 = 원복 (블리자드 흐름)
local function apply_in_list(name, mode)
    apply_profile(name, mode, get_list_character())
    AddonList_Update()
end

local function on_menu_load(name)    apply_in_list(name, "load")    end
local function on_menu_enable(name)  apply_in_list(name, "enable")  end
local function on_menu_disable(name) apply_in_list(name, "disable") end

local function on_menu_save(name)
    StaticPopup_Show("DODO_ADDON_PROFILE_SAVE", name, nil, name)
end

local function on_menu_rename(name)
    StaticPopup_Show("DODO_ADDON_PROFILE_RENAME", name, nil, name)
end

local function on_menu_delete(name)
    StaticPopup_Show("DODO_ADDON_PROFILE_DELETE", name, nil, name)
end

local function on_menu_new()
    StaticPopup_Show("DODO_ADDON_PROFILE_NEW")
end

local function list_profile_menu(owner, root)
    root:CreateTitle("애드온 프로필")
    local profiles = get_profiles()
    local names    = get_sorted_keys(profiles)
    for _, name in ipairs(names) do
        local addons = get_sorted_keys(profiles[name].addons)
        local sub    = root:CreateButton(name)

        local list = sub:CreateButton(#addons .. "개 애드온")
        list:SetScrollMode(400)
        for _, addon in ipairs(addons) do
            list:CreateTitle(addon)
        end
        sub:CreateDivider()
        sub:CreateButton("불러오기", on_menu_load, name)
        sub:CreateButton("애드온 켜기", on_menu_enable, name)
        sub:CreateButton("애드온 끄기", on_menu_disable, name)
        sub:CreateDivider()
        sub:CreateButton("현재 상태로 저장", on_menu_save, name)
        sub:CreateButton("이름 바꾸기", on_menu_rename, name)
        sub:CreateButton("삭제", on_menu_delete, name)
    end
    if #names > 0 then root:CreateDivider() end
    root:CreateButton("새 프로필 만들기", on_menu_new)
end

local function on_profile_btn_click(self)
    MenuUtil.CreateContextMenu(self, list_profile_menu)
end

-- 팝업 핸들러
local function on_accept_new(dialog)
    local name = strtrim(get_edit_box(dialog):GetText() or "")
    if name == "" then return end
    local profiles = get_profiles()
    if profiles[name] then
        print("|cff00ccffdodo|r: 이미 있는 프로필 이름입니다 - " .. name)
        return
    end
    profiles[name] = { addons = snapshot_addons() }
end

local function on_accept_rename(dialog, old_name)
    local name = strtrim(get_edit_box(dialog):GetText() or "")
    local profiles = get_profiles()
    if name == "" or name == old_name or not profiles[old_name] then return end
    if profiles[name] then
        print("|cff00ccffdodo|r: 이미 있는 프로필 이름입니다 - " .. name)
        return
    end
    profiles[name]     = profiles[old_name]
    profiles[old_name] = nil
end

local function on_show_rename(dialog, old_name)
    local edit = get_edit_box(dialog)
    edit:SetText(old_name or "")
    edit:HighlightText()
end

local function on_enter_new(edit_box)
    local dialog = edit_box:GetParent()
    on_accept_new(dialog)
    dialog:Hide()
end

local function on_enter_rename(edit_box, data)
    local dialog = edit_box:GetParent()
    on_accept_rename(dialog, data or dialog.data)
    dialog:Hide()
end

local function on_escape_edit(edit_box)
    edit_box:GetParent():Hide()
end

local function on_accept_save(dialog, name)
    local profile = get_profiles()[name]
    if profile then profile.addons = snapshot_addons() end
end

local function on_accept_delete(dialog, name)
    get_profiles()[name] = nil
end

StaticPopupDialogs["DODO_ADDON_PROFILE_NEW"] = {
    text                   = "새 프로필 이름 (현재 애드온 상태 저장)",
    button1                = ACCEPT,
    button2                = CANCEL,
    hasEditBox             = true,
    OnAccept               = on_accept_new,
    EditBoxOnEnterPressed  = on_enter_new,
    EditBoxOnEscapePressed = on_escape_edit,
    timeout                = 0,
    whileDead              = true,
    hideOnEscape           = true,
}

StaticPopupDialogs["DODO_ADDON_PROFILE_RENAME"] = {
    text                   = "'%s' 프로필의 새 이름",
    button1                = ACCEPT,
    button2                = CANCEL,
    hasEditBox             = true,
    OnShow                 = on_show_rename,
    OnAccept               = on_accept_rename,
    EditBoxOnEnterPressed  = on_enter_rename,
    EditBoxOnEscapePressed = on_escape_edit,
    timeout                = 0,
    whileDead              = true,
    hideOnEscape           = true,
}

StaticPopupDialogs["DODO_ADDON_PROFILE_SAVE"] = {
    text         = "'%s' 프로필에 현재 애드온 상태를 저장할까요?",
    button1      = YES,
    button2      = NO,
    OnAccept     = on_accept_save,
    timeout      = 0,
    whileDead    = true,
    hideOnEscape = true,
}

StaticPopupDialogs["DODO_ADDON_PROFILE_DELETE"] = {
    text         = "'%s' 프로필을 삭제할까요?",
    button1      = YES,
    button2      = NO,
    OnAccept     = on_accept_delete,
    timeout      = 0,
    whileDead    = true,
    hideOnEscape = true,
    showAlert    = true,
}

-- 애드온 목록 첫 표시 때 1회 생성
local function on_addon_list_show()
    if not profile_btn then
        profile_btn = CreateFrame("Button", nil, AddonList, "SharedButtonSmallTemplate")
        profile_btn:SetSize(80, 22)
        profile_btn:SetText("프로필")
        profile_btn:SetPoint("RIGHT", AddonList.SearchBox, "LEFT", -10, 0)
        profile_btn:SetScript("OnClick", on_profile_btn_click)
    end
    profile_btn:SetShown(dodoDB.enableInterface ~= false and dodoDB.useIconAddons ~= false)
end

-- ==============================
-- 기능: 애드온 관리 버튼
-- ==============================
local function load_profile(name)
    if not get_profiles()[name] then return end
    apply_profile(name, "load", UnitGUID("player"))
    C_AddOns.SaveAddOns()
    ReloadUI()
end

local function on_accept_load_profile(self, data)
    load_profile(data)
end

StaticPopupDialogs["DODO_LOAD_ADDON_PROFILE"] = {
    text         = "'%s' 프로필을 불러오고 UI를 재시작할까요?",
    button1      = YES,
    button2      = NO,
    OnAccept     = on_accept_load_profile,
    timeout      = 0,
    whileDead    = true,
    hideOnEscape = true,
}

local function confirm_load_profile(name)
    StaticPopup_Show("DODO_LOAD_ADDON_PROFILE", name, nil, name)
end

local function profile_menu(owner, root)
    root:CreateTitle("애드온 프로필")
    local profiles = dodoDB.addonProfiles
    if not profiles or not next(profiles) then
        root:CreateTitle("|cff808080저장된 프로필 없음|r")
        return
    end
    local names = {}
    for name in pairs(profiles) do names[#names + 1] = name end
    table_sort(names)
    for _, name in ipairs(names) do
        root:CreateButton(name, confirm_load_profile, name)
    end
end

local function toggle_addon_list()
    if AddonList:IsShown() then
        HideUIPanel(AddonList)
    else
        ShowUIPanel(AddonList)
    end
end

local function mgr_on_click(self, button)
    if button == "RightButton" then
        if flyout_frame then flyout_frame:Hide() end
        MenuUtil.CreateContextMenu(self, profile_menu)
    else
        toggle_addon_list()
    end
end

local function mgr_on_enter(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:AddLine("애드온")
    GameTooltip:AddLine("|A:newplayertutorial-icon-mouse-leftbutton:0:0|a 애드온 목록", 1, 1, 1)
    GameTooltip:AddLine("|A:newplayertutorial-icon-mouse-rightbutton:0:0|a 프로필 불러오기", 1, 1, 1)
    GameTooltip:Show()

    if flyout_frame and (flyout_frame.count or 0) > 0 then
        flyout_elapsed = 0
        flyout_frame:Show()
    end
end

local function mgr_on_leave(self)
    GameTooltip:Hide()
end

-- 패널 표시 중에만 동작 (숨김 프레임은 OnUpdate 미호출)
local function flyout_on_update(self, elapsed)
    flyout_elapsed = flyout_elapsed + elapsed
    if flyout_elapsed < 0.2 then return end
    flyout_elapsed = 0
    if not self:IsMouseOver() and not mgr_btn:IsMouseOver() then
        self:Hide()
    end
end

local function create_addon_manager_button()
    if mgr_btn then return end
    -- 원래 부모를 hidden_frame으로: 비활성 시 restore_button이 여기로 되돌려 숨김
    mgr_btn = CreateFrame("Button", "dodoAddonManagerButton", hidden_frame)
    mgr_btn:SetSize(Config.buttonSize, Config.buttonSize)
    mgr_btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")

    -- LibDBIcon 버튼과 같은 둥근 테두리/배경
    local border = mgr_btn:CreateTexture(nil, "OVERLAY")
    border:SetTexture(136430)  -- MiniMap-TrackingBorder
    border:SetSize(50, 50)
    border:SetPoint("TOPLEFT")

    local bg = mgr_btn:CreateTexture(nil, "BACKGROUND")
    bg:SetTexture(136467)  -- UI-Minimap-Background
    bg:SetSize(24, 24)
    bg:SetPoint("CENTER")

    local icon = mgr_btn:CreateTexture(nil, "ARTWORK")
    icon:SetTexture(133740)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    icon:SetPoint("CENTER")
    icon:SetSize(18, 18)
    mgr_btn.icon = icon

    local hl = mgr_btn:CreateTexture(nil, "HIGHLIGHT")
    hl:SetTexture(133740)
    hl:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    hl:SetAllPoints(icon)
    hl:SetBlendMode("ADD")
    hl:SetAlpha(0.6)

    mgr_btn:SetScript("OnClick", mgr_on_click)
    mgr_btn:SetScript("OnEnter", mgr_on_enter)
    mgr_btn:SetScript("OnLeave", mgr_on_leave)

    -- 마우스오버 아이콘 모음 패널
    flyout_frame = CreateFrame("Frame", "dodoAddonFlyoutFrame", UIParent, "BackdropTemplate")
    flyout_frame:SetFrameStrata("DIALOG")
    flyout_frame:SetBackdrop({
        bgFile   = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeSize = 2,
    })
    flyout_frame:SetBackdropColor(0.1, 0.1, 0.1, 0.9)
    flyout_frame:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
    flyout_frame:SetClampedToScreen(true)
    flyout_frame:SetPoint("TOPRIGHT", mgr_btn, "BOTTOMRIGHT", 0, -2)
    flyout_frame:SetSize(1, 1)
    flyout_frame:Hide()
    flyout_frame:SetScript("OnUpdate", flyout_on_update)
end

-- ==============================
-- 기능: UI 생성
-- ==============================
local function create_ui()
    if bar_frame then return end

    bar_frame = CreateFrame("Frame", "dodo_HidingBarFrame", UIParent)
    bar_frame:SetFrameStrata("MEDIUM")
    bar_frame:SetSize(1, 1)
    bar_frame:EnableMouse(false)
    bar_frame:ClearAllPoints()

    local relativeTo = _G[Config.defaultRelativeTo] or UIParent
    bar_frame:SetPoint(Config.defaultPoint, relativeTo, Config.defaultRelativePoint, Config.defaultX, Config.defaultY)
end

local function initialize()
    if dodoDB.useIconAddons == nil then dodoDB.useIconAddons = true end
    create_ui()
    create_vault_button()
    create_addon_manager_button()

    if AddonList then
        AddonList:HookScript("OnShow", on_addon_list_show)
    end

    -- Blizzard 버그 워크어라운드: title 미초기화 시 SetText(nil) 에러 방지
    local exp_btn = ExpansionLandingPageMinimapButton
    if exp_btn and exp_btn.SetTooltip then
        local orig = exp_btn.SetTooltip
        exp_btn.SetTooltip = function(self)
            if self.title then orig(self) end
        end
    end
end

-- ==============================
-- 기능: 활성/비활성 처리
-- ==============================
local function update_visual()
    local is_enabled = dodoDB.enableInterface ~= false and dodoDB.useIconAddons ~= false
    if is_enabled then
        if bar_frame then bar_frame:Show() end
        refresh_all_buttons()
        if not ticker_obj then
            ticker_obj = C_Timer.NewTicker(2.0, refresh_all_buttons)
        end
    else
        if ticker_obj then
            ticker_obj:Cancel()
            ticker_obj = nil
        end
        for _, btn in ipairs(collected_buttons) do
            restore_button(btn)
        end
        collected_buttons = {}
        buttons_by_name   = {}
        if bar_frame then bar_frame:Hide() end
        if flyout_frame then flyout_frame:Hide() end
    end
end

-- ==============================
-- 이벤트 핸들러
-- ==============================
local function on_event(self, event, arg1)
    if event == "ADDON_LOADED" then
        if arg1 == "dodoInterface" then
            dodoDB = dodoDB or {}
        else
            if arg1 == "Blizzard_GarrisonUI" and GarrisonLandingPage and GarrisonLandingPage.SetupCovenantTopPanel then
                -- Blizzard 버그 워크어라운드: 패치 12.0에서 섀도우랜즈 covenantData nil 크래시 방지
                local orig_setup = GarrisonLandingPage.SetupCovenantTopPanel
                GarrisonLandingPage.SetupCovenantTopPanel = function(self, ...)
                    pcall(orig_setup, self, ...)
                end
            end
            refresh_all_buttons()
        end
    elseif event == "PLAYER_LOGIN" then
        ldb  = LibStub and LibStub("LibDataBroker-1.1", true)
        ldbi = LibStub and LibStub("LibDBIcon-1.0", true)

        initialize()
        update_visual()

        if ldb then
            ldb.RegisterCallback("dodoHidingBar", "LibDataBroker_DataObjectCreated", refresh_all_buttons)
        end

        self:UnregisterEvent("PLAYER_LOGIN")
    elseif event == "PLAYER_REGEN_ENABLED" then
        refresh_all_buttons()
    end
end

init_frame:RegisterEvent("ADDON_LOADED")
init_frame:RegisterEvent("PLAYER_LOGIN")
init_frame:RegisterEvent("PLAYER_REGEN_ENABLED")
init_frame:SetScript("OnEvent", on_event)

dodo.UpdateMinimapIconAddonsState = update_visual
