-- ==============================
-- Inspired
-- ==============================
-- RefineUI (Modules/EncounterAchievements/UI.lua)

-- ==============================
-- 설정 및 테이블
-- ==============================
---@diagnostic disable: lowercase-global, param-type-mismatch, redundant-parameter, undefined-field, undefined-global
local addonName, dodo = ...
dodo.EJAchievements = dodo.EJAchievements or {}
local M = dodo.EJAchievements

-- 상수
local CUSTOM_TAB_ID = 5001
local BLIZZARD_ACHIEVEMENT_ADDON = "Blizzard_AchievementUI"
local ROW_HEIGHT = 49
local ROW_HEIGHT_REWARD = 68
local ICON_PAD_W = 51
local MIN_NAME_W = 156
local BOSS_FILTER_ALL = 0

local NATIVE_TAB_KEYS = { "overviewTab", "lootTab", "bossTab", "modelTab" }

local EMPTY_NO_INSTANCE   = "던전 또는 레이드 인스턴스를 선택하세요."
local EMPTY_NO_RESULTS    = "이 인스턴스의 업적을 찾을 수 없습니다."
local EMPTY_NO_FILTER     = "선택한 보스 필터와 일치하는 업적이 없습니다."
local EMPTY_LOADING       = "업적 로드 중..."
local EMPTY_NO_UI         = "Blizzard_AchievementUI를 사용할 수 없습니다."

-- 로컬 상태
local tab_button = nil
local custom_panel = nil
local is_active = false
local current_instance_id = nil
local pending_refresh_id = nil
local scroll_view_initialized = false
local hooks_installed = false
local boss_filter_instance_id = nil
local boss_filter_options = nil
local boss_filter_map = nil
local selected_boss_encounter_id = nil
local boss_filter_user_selected = false
local achievement_ui_ready = false
local pending_ach_ui_load = false
local display_generation = 0
local instance_overview_was_shown = false
local previous_native_tab = nil
local sticky_active = false
local ef_difficulty = CreateFrame("Frame")

-- forward declarations
local activate_custom_tab
local deactivate_custom_tab
local refresh_content

-- ==============================
-- 캐싱
-- ==============================
local _G = _G
local CreateFrame = CreateFrame
local EJ_GetEncounterInfoByIndex = EJ_GetEncounterInfoByIndex
local EJ_GetInstanceInfo = EJ_GetInstanceInfo
local PlaySound = PlaySound
local SOUNDKIT = SOUNDKIT
local format = string.format
local hooksecurefunc = hooksecurefunc
local ipairs = ipairs
local max = math.max
local pcall = pcall
local tostring = tostring
local type = type

-- ==============================
-- 헬퍼
-- ==============================
local function get_encounter_frames()
    local journal = _G.EncounterJournal
    local encounter = journal and journal.encounter
    local info = encounter and encounter.info
    return journal, encounter, info
end

local function is_achievement_ui_ready()
    return type(_G.AchievementFrame_SelectAchievement) == "function"
        and type(_G.AchievementFrame_ToggleAchievementFrame) == "function"
end

local function ensure_achievement_ui_loaded()
    if is_achievement_ui_ready() then
        achievement_ui_ready = true
        return true
    end
    if type(_G.C_AddOns) == "table" and type(_G.C_AddOns.IsAddOnLoaded) == "function" then
        if not _G.C_AddOns.IsAddOnLoaded(BLIZZARD_ACHIEVEMENT_ADDON) then
            local ok = pcall(_G.C_AddOns.LoadAddOn, BLIZZARD_ACHIEVEMENT_ADDON)
            if not ok then return false end
        end
    end
    achievement_ui_ready = is_achievement_ui_ready()
    return achievement_ui_ready
end

-- ==============================
-- 탭 생성
-- ==============================
local function create_custom_side_tab(infoFrame)
    if tab_button or not infoFrame then return end
    local anchorTab = infoFrame.ModelTab or infoFrame.modelTab
    if not anchorTab then return end

    tab_button = CreateFrame("Button", nil, infoFrame, "EncounterTabTemplate")
    tab_button:SetID(CUSTOM_TAB_ID)
    tab_button.tooltip = _G.ACHIEVEMENTS or "업적"
    tab_button:SetPoint("TOP", anchorTab, "BOTTOM", 0, 2)

    local atlasName = "ShipMissionIcon-Bonus-Map"

    local unselected = tab_button:CreateTexture(nil, "OVERLAY")
    unselected:SetSize(42, 42)
    unselected:SetPoint("CENTER", tab_button, "CENTER", 0, 0)
    unselected:SetAtlas(atlasName)
    unselected:SetVertexColor(0.83, 0.73, 0.58, 0.9)

    local selected = tab_button:CreateTexture(nil, "OVERLAY")
    selected:SetAllPoints(unselected)
    selected:SetAtlas(atlasName)
    selected:SetVertexColor(1, 0.93, 0.66, 1)
    selected:Hide()

    tab_button.unselected = unselected
    tab_button.selected = selected

    tab_button:SetScript("OnClick", function()
        if PlaySound and SOUNDKIT and SOUNDKIT.IG_ABILITY_PAGE_TURN then
            PlaySound(SOUNDKIT.IG_ABILITY_PAGE_TURN)
        end
        activate_custom_tab()
    end)

    tab_button:Show()
end

-- ==============================
-- 패널 생성
-- ==============================
local function create_custom_panel(infoFrame)
    if custom_panel or not infoFrame then return end
    local anchor = infoFrame.model or infoFrame.detailsScroll
    if not anchor then return end

    local panel = CreateFrame("Frame", "dodoEncounterAchievementsPanel", infoFrame)
    panel:SetPoint("TOPLEFT", anchor, "TOPLEFT", 0, 0)
    panel:SetPoint("BOTTOMRIGHT", anchor, "BOTTOMRIGHT", 0, 0)
    panel:SetFrameStrata("DIALOG")
    panel:SetFrameLevel((infoFrame:GetFrameLevel() or 1) + 40)
    panel:Hide()

    panel.HeaderText = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    panel.HeaderText:SetPoint("TOPLEFT", panel, "TOPLEFT", 43, -22)
    panel.HeaderText:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -186, -22)
    panel.HeaderText:SetJustifyH("LEFT")
    panel.HeaderText:SetText(_G.ACHIEVEMENTS or "업적")
    panel.HeaderText:SetTextColor(0.902, 0.788, 0.671)

    panel.BossDropdown = CreateFrame("DropdownButton", nil, panel, "WowStyle1DropdownTemplate")
    panel.BossDropdown:SetPoint("TOPRIGHT", infoFrame, "TOPRIGHT", -19, -13)
    panel.BossDropdown:SetWidth(170)

    panel.ScrollBox = CreateFrame("Frame", nil, panel, "WowScrollBoxList")
    panel.ScrollBox:SetPoint("TOPLEFT", panel.HeaderText, "BOTTOMLEFT", -1, -10)
    panel.ScrollBox:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -20, 6)

    panel.ScrollBar = CreateFrame("EventFrame", nil, panel, "MinimalScrollBar")
    panel.ScrollBar:SetPoint("TOPLEFT", panel.ScrollBox, "TOPRIGHT", 5, -4)
    panel.ScrollBar:SetPoint("BOTTOMLEFT", panel.ScrollBox, "BOTTOMRIGHT", 5, 4)
    if panel.ScrollBar.SetHideIfUnscrollable then panel.ScrollBar:SetHideIfUnscrollable(true) end
    if panel.ScrollBar.SetInterpolateScroll then panel.ScrollBar:SetInterpolateScroll(true) end

    panel.EmptyText = panel:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    panel.EmptyText:SetPoint("TOPLEFT", panel.ScrollBox, "TOPLEFT", 18, -18)
    panel.EmptyText:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -34, 18)
    panel.EmptyText:SetJustifyH("CENTER")
    panel.EmptyText:SetJustifyV("MIDDLE")
    panel.EmptyText:SetText(EMPTY_NO_INSTANCE)
    panel.EmptyText:Hide()

    custom_panel = panel
end

-- ==============================
-- OnShow 가드
-- ==============================
-- 커스텀 탭 활성 중 블리자드 프레임이 Show되면 즉시 Hide
local function install_visibility_guards(infoFrame)
    if M._guards_installed or not infoFrame then return end
    M._guards_installed = true

    local function guard(f)
        if not f or not f.HookScript then return end
        f:HookScript("OnShow", function(frame)
            if is_active then frame:Hide() end
        end)
    end

    guard(infoFrame.overviewScroll)
    guard(infoFrame.LootContainer)
    guard(infoFrame.detailsScroll)
    guard(infoFrame.model)
    if infoFrame.overviewScroll then guard(infoFrame.overviewScroll.child) end
    if infoFrame.detailsScroll then guard(infoFrame.detailsScroll.child) end

    local _, enc = get_encounter_frames()
    guard(enc and enc.overviewFrame)
    guard(enc and enc.infoFrame)
    guard(enc and enc.instance)
    guard(infoFrame.difficulty)
    guard(_G.EncounterJournalEncounterFrameInfoDifficulty)
end

-- ==============================
-- 탭 시각 상태
-- ==============================
local function set_tab_selected(sel)
    if not tab_button then return end
    if sel then
        if tab_button.selected then tab_button.selected:Show() end
        if tab_button.unselected then tab_button.unselected:Hide() end
        tab_button:LockHighlight()
    else
        if tab_button.selected then tab_button.selected:Hide() end
        if tab_button.unselected then tab_button.unselected:Show() end
        tab_button:UnlockHighlight()
    end
end

local function clear_native_tab_selection()
    local _, _, infoFrame = get_encounter_frames()
    if not infoFrame then return end
    for _, key in ipairs(NATIVE_TAB_KEYS) do
        local t = infoFrame[key]
        if t then
            if t.selected then t.selected:Hide() end
            if t.unselected then t.unselected:Show() end
            if t.UnlockHighlight then t:UnlockHighlight() end
        end
    end
end

-- ==============================
-- 블리자드 콘텐츠 숨김 / 복구
-- ==============================
local function hide_native_content()
    local _, enc, info = get_encounter_frames()
    if not info then return end

    -- BG/leftShadow/rightShadow는 종이 배경으로 유지
    if info.model and info.model.dungeonBG then info.model.dungeonBG:Hide() end
    if info.overviewScroll then info.overviewScroll:Hide() end
    if info.LootContainer then
        info.LootContainer:Hide()
        if info.LootContainer.classClearFilter then info.LootContainer.classClearFilter:Hide() end
    end
    if info.detailsScroll then info.detailsScroll:Hide() end
    if info.model then info.model:Hide() end
    if info.overviewScroll and info.overviewScroll.child then info.overviewScroll.child:Hide() end
    if info.detailsScroll and info.detailsScroll.child then info.detailsScroll.child:Hide() end
    if enc and enc.overviewFrame then enc.overviewFrame:Hide() end
    if enc and enc.infoFrame then enc.infoFrame:Hide() end
    if enc and enc.instance then enc.instance:Hide() end
    if _G.InstanceFrameBG then _G.InstanceFrameBG:Hide() end
    if type(_G.EncounterJournal_HideCreatures) == "function" then _G.EncounterJournal_HideCreatures() end
    if info.encounterTitle then info.encounterTitle:Hide() end
    if info.difficulty then info.difficulty:Hide() end
    if _G.EncounterJournalEncounterFrameInfoDifficulty then _G.EncounterJournalEncounterFrameInfoDifficulty:Hide() end
end

local function show_native_content()
    local journal, enc, info = get_encounter_frames()
    if not journal or not enc or not info then return end

    -- 종이 배경/그림자는 모든 탭 공통이므로 항상 복구
    if info.BG then info.BG:Show() end
    if info.leftShadow then info.leftShadow:Show() end
    if info.rightShadow then info.rightShadow:Show() end

    -- 탭별 콘텐츠 프레임은 무조건 Show — 실제 노출 여부는 부모(overviewScroll/
    -- detailsScroll/model)의 Show/Hide(EncounterJournal_SetTab이 관리)에 종속됨
    if info.overviewScroll and info.overviewScroll.child then info.overviewScroll.child:Show() end
    if info.detailsScroll and info.detailsScroll.child then info.detailsScroll.child:Show() end
    if enc.overviewFrame then enc.overviewFrame:Show() end
    if enc.infoFrame then enc.infoFrame:Show() end
    if info.model and info.model.dungeonBG then info.model.dungeonBG:Show() end

    -- enc.instance(던전 대문)는 "보스 미선택(인스턴스 개요)" 상태일 때만 복원.
    -- 보스가 선택된 상태(journal.encounterID 존재)면 Blizzard가 ClearDetails로
    -- 이미 hide 처리하므로 건드리지 않음 (enc.overviewFrame과 동시 노출 방지).
    if instance_overview_was_shown and not journal.encounterID then
        if enc.instance then enc.instance:Show() end
        if _G.InstanceFrameBG then _G.InstanceFrameBG:Show() end
    end
    instance_overview_was_shown = false

    local has_visible = (info.overviewScroll and info.overviewScroll:IsShown())
        or (info.detailsScroll and info.detailsScroll:IsShown())
        or (info.LootContainer and info.LootContainer:IsShown())
        or (info.model and info.model:IsShown())
    if has_visible then return end

    if type(_G.EncounterJournal_SetTab) == "function" then
        -- info.tab은 activate_custom_tab이 4(modelTab)로 점유해둔 값이라
        -- 업적 탭 진입 전 실제로 활성이던 native 탭(previous_native_tab)을 우선 사용
        local native_tab = type(previous_native_tab) == "number" and previous_native_tab
        if not native_tab then native_tab = type(info.tab) == "number" and info.tab end
        if not native_tab then
            local ot = info.OverviewTab or info.overviewTab
            if ot then native_tab = ot:GetID() end
        end
        if type(native_tab) == "number" then
            _G.EncounterJournal_SetTab(native_tab)
        end
    end
    previous_native_tab = nil
end

-- ==============================
-- 보스 드롭다운
-- ==============================
local function build_boss_filter_options()
    local options, map = {}, {}
    local all_label = _G.ALL or "All"
    options[1] = { encounterID = BOSS_FILTER_ALL, label = all_label, token = "" }
    map[BOSS_FILTER_ALL] = true

    if type(EJ_GetEncounterInfoByIndex) ~= "function" then return options, map end

    local i = 1
    while true do
        local name, _, eid = EJ_GetEncounterInfoByIndex(i)
        if type(eid) ~= "number" or eid <= 0 then break end
        local label = (type(name) == "string" and name ~= "") and name or format("Boss %d", i)
        options[#options + 1] = {
            encounterID = eid,
            label = label,
            token = M.normalize_token and M.normalize_token(label) or label:lower(),
        }
        map[eid] = true
        i = i + 1
    end
    return options, map
end

local function ensure_boss_filter(instanceID)
    if boss_filter_instance_id ~= instanceID then
        boss_filter_instance_id = instanceID
        boss_filter_options = nil
        boss_filter_map = nil
        selected_boss_encounter_id = nil
        boss_filter_user_selected = false
    end

    if not boss_filter_options or #boss_filter_options == 0 then
        boss_filter_options, boss_filter_map = build_boss_filter_options()
    end

    -- 현재 보스 페이지를 기본 선택으로
    local journal = _G.EncounterJournal
    local eid = journal and journal.encounterID
    local default_eid = (type(eid) == "number" and eid > 0 and boss_filter_map[eid]) and eid or BOSS_FILTER_ALL

    if not boss_filter_map[selected_boss_encounter_id] then
        selected_boss_encounter_id = default_eid
    elseif not boss_filter_user_selected and selected_boss_encounter_id ~= default_eid then
        selected_boss_encounter_id = default_eid
    end
end

local function get_selected_boss_option()
    if not boss_filter_options then return nil end
    for _, opt in ipairs(boss_filter_options) do
        if opt.encounterID == selected_boss_encounter_id then return opt end
    end
    return boss_filter_options[1]
end

local setup_boss_dropdown

local function update_dropdown_text()
    -- WowStyle1DropdownTemplate은 IsSelected 기반으로 텍스트 자동 갱신
    -- SetupMenu 재호출로 선택 상태 반영
    setup_boss_dropdown()
end

setup_boss_dropdown = function()
    if not custom_panel or not custom_panel.BossDropdown then return end
    local dd = custom_panel.BossDropdown
    if not dd.SetupMenu then return end

    local options = boss_filter_options or {}
    dd:SetupMenu(function(_, root)
        root:SetTag("MENU_DODO_EJ_BOSS_FILTER")
        for _, opt in ipairs(options) do
            local eid = opt.encounterID
            root:CreateRadio(opt.label,
                function() return selected_boss_encounter_id == eid end,
                function()
                    selected_boss_encounter_id = eid
                    boss_filter_user_selected = true
                    update_dropdown_text()
                    if refresh_content then refresh_content() end
                end)
        end
    end)
end

local function filter_rows_by_boss(rows)
    local opt = get_selected_boss_option()
    if not opt or opt.encounterID == BOSS_FILTER_ALL then return rows end
    local boss_token = opt.token
    if not boss_token or boss_token == "" then return {} end

    local filtered = {}
    local nt = M.normalize_token
    for _, row in ipairs(rows) do
        local src = (row.name or "") .. (row.description or "") .. (row.categoryPath or "")
        local token = nt and nt(src) or src:lower()
        if token:find(boss_token, 1, true) then
            filtered[#filtered + 1] = row
        end
    end
    return filtered
end

-- ==============================
-- 빈 상태
-- ==============================
local function set_empty_state(msg, hide_list)
    if not custom_panel then return end
    if type(msg) == "string" and msg ~= "" then
        custom_panel.EmptyText:SetText(msg)
        custom_panel.EmptyText:Show()
    else
        custom_panel.EmptyText:Hide()
    end
    if hide_list then
        custom_panel.ScrollBox:Hide()
        custom_panel.ScrollBar:Hide()
    else
        custom_panel.ScrollBox:Show()
        custom_panel.ScrollBar:Show()
    end
end

-- ==============================
-- 업적 행 렌더링
-- ==============================
local function shrink_font(fs, by)
    local f, s, fl = fs:GetFont()
    if type(f) == "string" and type(s) == "number" then fs:SetFont(f, max(7, s - by), fl) end
end

local function init_row(button, element_data)
    if not button or type(element_data) ~= "table" then return end
    local row = element_data.row
    local aid = row and row.achievementID
    if type(aid) ~= "number" or aid <= 0 then return end

    local completed = row.completed
    local reward = row.rewardText or ""
    local has_reward = reward ~= ""

    button.achievementID = aid
    button.achievementRow = row
    button:SetHeight(has_reward and ROW_HEIGHT_REWARD or ROW_HEIGHT)

    if not button.InfoIcon then
        -- LootContainer EncounterItemTemplate 레이아웃으로 교체 (icon/name/slot/armorType)
        -- AchievementFullSearchResultsButtonTemplate의 _SearchBarLg(검은 바) 제거
        local normal = button:GetNormalTexture()
        if normal then normal:SetTexture(nil) normal:Hide() end
        local pushed = button:GetPushedTexture()
        if pushed then pushed:SetTexture(nil) pushed:Hide() end
        if button.IconFrame then button.IconFrame:Hide() end
        if button.Icon then button.Icon:Hide() end
        if button.Name then button.Name:Hide() end
        if button.Path then button.Path:Hide() end
        if button.ResultType then button.ResultType:Hide() end

        -- LootContainer 행 배경 (UI-EJ-LootFrame = bosslessTexture, 522972)
        local bg = button:CreateTexture(nil, "BACKGROUND", "UI-EJ-LootFrame")
        bg:ClearAllPoints()
        bg:SetPoint("LEFT", button, "LEFT", 0, 0)
        button.InfoBg = bg

        -- 보상 있을 때 두줄 배경 (UI-EJ-DungeonLootFrame = bossTexture, 522972)
        local bossBg = button:CreateTexture(nil, "BACKGROUND", "UI-EJ-DungeonLootFrame")
        bossBg:ClearAllPoints()
        bossBg:SetPoint("LEFT", button, "LEFT", 0, 0)
        bossBg:Hide()
        button.InfoBossBg = bossBg

        local icon = button:CreateTexture(nil, "OVERLAY")
        icon:SetSize(42, 42)
        icon:SetPoint("TOPLEFT", button, "TOPLEFT", 2, -2)
        button.InfoIcon = icon

        local name = button:CreateFontString(nil, "OVERLAY", "GameFontNormalMed3")
        name:SetJustifyH("LEFT")
        name:SetPoint("TOPLEFT", icon, "TOPRIGHT", 7, -7)
        button.InfoName = name

        local slot = button:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        slot:SetJustifyH("LEFT")
        slot:SetPoint("BOTTOMLEFT", icon, "BOTTOMRIGHT", 7, 3)
        slot:SetHeight(12)
        button.InfoSlot = slot

        local armorClass = button:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        armorClass:SetJustifyH("RIGHT")
        armorClass:SetPoint("BOTTOMRIGHT", name, "TOPLEFT", 264, -32)
        armorClass:SetHeight(12)
        button.InfoArmorClass = armorClass

        local boss = button:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        boss:SetJustifyH("LEFT")
        boss:SetPoint("TOPLEFT", icon, "BOTTOMLEFT", 0, -5)
        boss:SetHeight(12)
        boss:SetTextColor(dodo.Colors.Gold.r, dodo.Colors.Gold.g, dodo.Colors.Gold.b)
        boss:SetShadowOffset(1, -1)
        boss:SetShadowColor(0, 0, 0, 1)
        if boss.SetWordWrap then boss:SetWordWrap(false) end
        button.InfoBoss = boss
    end

    if has_reward then
        button.InfoBg:Hide()
        button.InfoBossBg:Show()
        button.InfoBoss:SetText(reward)
        button.InfoBoss:Show()
    else
        button.InfoBg:Show()
        button.InfoBossBg:Hide()
        button.InfoBoss:SetText("")
        button.InfoBoss:Hide()
    end

    button.InfoName:SetText(row.name or tostring(aid))
    button.InfoIcon:SetTexture(row.icon or 134400)
    button.InfoSlot:SetText(row.categoryPath or "")

    local list_w = custom_panel and custom_panel.ScrollBox and custom_panel.ScrollBox:GetWidth() or 320
    local name_w = max(MIN_NAME_W, list_w - ICON_PAD_W)
    button.InfoName:SetWidth(name_w)
    button.InfoSlot:SetWidth(name_w)
    if button.InfoSlot.SetMaxLines then button.InfoSlot:SetMaxLines(1) end
    if button.InfoSlot.SetWordWrap then button.InfoSlot:SetWordWrap(false) end
    if button.InfoSlot.SetNonSpaceWrap then button.InfoSlot:SetNonSpaceWrap(false) end

    if not button._dodo_fonts_set then
        shrink_font(button.InfoName, 1)
        shrink_font(button.InfoSlot, 2)
        shrink_font(button.InfoArmorClass, 2)
        shrink_font(button.InfoBoss, 1)
        button._dodo_fonts_set = true
    end

    if completed then
        button.InfoArmorClass:SetText(_G.ACHIEVEMENTFRAME_FILTER_COMPLETED or "완료")
        button.InfoArmorClass:SetTextColor(0.78, 0.96, 0.78)
        button.InfoArmorClass:SetShadowOffset(1, -1)
        button.InfoArmorClass:SetShadowColor(0, 0, 0, 1)
        button.InfoName:SetTextColor(0.78, 0.96, 0.78)
        button.InfoName:SetShadowOffset(1, -1)
        button.InfoName:SetShadowColor(0, 0, 0, 1)
        button.InfoSlot:SetTextColor(0.78, 0.96, 0.78)
        button.InfoSlot:SetShadowOffset(1, -1)
        button.InfoSlot:SetShadowColor(0, 0, 0, 1)
    else
        button.InfoArmorClass:SetText(_G.ACHIEVEMENTFRAME_FILTER_INCOMPLETE or "미완료")
        button.InfoArmorClass:SetTextColor(0.95, 0.84, 0.66)
        button.InfoArmorClass:SetShadowOffset(1, -1)
        button.InfoArmorClass:SetShadowColor(0, 0, 0, 1)
        button.InfoName:SetTextColor(0.95, 0.84, 0.66)
        button.InfoName:SetShadowOffset(1, -1)
        button.InfoName:SetShadowColor(0, 0, 0, 1)
        button.InfoSlot:SetTextColor(0.95, 0.84, 0.66)
        button.InfoSlot:SetShadowOffset(1, -1)
        button.InfoSlot:SetShadowColor(0, 0, 0, 1)
    end

    if not button._dodo_wired then
        button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        button:SetScript("OnClick", function(btn, mouse)
            local id = btn.achievementID
            if type(id) ~= "number" or id <= 0 then return end

            if type(_G.IsModifiedClick) == "function" and _G.IsModifiedClick("CHATLINK") then
                local link = type(_G.GetAchievementLink) == "function" and _G.GetAchievementLink(id)
                if link and type(_G.ChatFrameUtil) == "table" and _G.ChatFrameUtil.InsertLink then
                    _G.ChatFrameUtil.InsertLink(link)
                    return
                end
            end

            if not ensure_achievement_ui_loaded() then return end
            local af = _G.AchievementFrame
            if af and not af:IsShown() then
                if type(_G.ShowUIPanel) == "function" then _G.ShowUIPanel(af) end
            elseif not af and type(_G.AchievementFrame_ToggleAchievementFrame) == "function" then
                _G.AchievementFrame_ToggleAchievementFrame(false, false)
            end
            if type(_G.AchievementFrame_SelectAchievement) == "function" then
                _G.AchievementFrame_SelectAchievement(id, true)
            end
        end)
        button:SetScript("OnEnter", function(btn)
            if not btn.achievementID or not _G.GameTooltip then return end
            _G.GameTooltip:SetOwner(btn, "ANCHOR_RIGHT")
            if type(_G.GameTooltip.SetAchievementByID) == "function" then
                _G.GameTooltip:SetAchievementByID(btn.achievementID)
            else
                local link = type(_G.GetAchievementLink) == "function" and _G.GetAchievementLink(btn.achievementID)
                if link and _G.GameTooltip.SetHyperlink then _G.GameTooltip:SetHyperlink(link) end
            end
            _G.GameTooltip:Show()
        end)
        button:SetScript("OnLeave", function()
            if _G.GameTooltip then _G.GameTooltip:Hide() end
        end)
        button._dodo_wired = true
    end
end

local function reset_row(button)
    if not button then return end
    button.achievementID = nil
    button.achievementRow = nil
    if button.InfoBoss then button.InfoBoss:SetText("") button.InfoBoss:Hide() end
    if button.InfoBg then button.InfoBg:Hide() end
    if button.InfoBossBg then button.InfoBossBg:Hide() end
end

-- ==============================
-- ScrollBox 초기화
-- ==============================
local function ensure_scroll_view()
    if scroll_view_initialized then return true end
    if not custom_panel then return false end
    if not is_achievement_ui_ready() then return false end
    if type(_G.ScrollUtil) ~= "table" or type(_G.ScrollUtil.InitScrollBoxListWithScrollBar) ~= "function" then return false end
    if type(_G.CreateScrollBoxListLinearView) ~= "function" then return false end

    local view = _G.CreateScrollBoxListLinearView()
    view:SetElementExtentCalculator(function(dataIndex, elementData)
        local row = elementData and elementData.row
        local reward = row and row.rewardText
        return (reward and reward ~= "") and ROW_HEIGHT_REWARD or ROW_HEIGHT
    end)
    view:SetElementInitializer("AchievementFullSearchResultsButtonTemplate", function(btn, data)
        init_row(btn, data)
    end)
    view:SetElementResetter(function(btn)
        reset_row(btn)
    end)
    view:SetPadding(0, 0, 0, 2, 0)

    local ok = pcall(_G.ScrollUtil.InitScrollBoxListWithScrollBar, custom_panel.ScrollBox, custom_panel.ScrollBar, view)
    if not ok then return false end

    scroll_view_initialized = true
    return true
end

local function populate_rows(rows, instanceID)
    if not custom_panel then return end
    if type(_G.CreateDataProvider) ~= "function" then
        set_empty_state(EMPTY_NO_UI, true)
        return
    end

    local dp = _G.CreateDataProvider()
    for _, row in ipairs(rows) do
        dp:Insert({ row = row, achievementID = row.achievementID })
    end
    custom_panel.ScrollBox:SetDataProvider(dp)

    if custom_panel._last_instance ~= instanceID and custom_panel.ScrollBox.ScrollToBegin then
        custom_panel.ScrollBox:ScrollToBegin()
    end
    custom_panel._last_instance = instanceID
end

-- ==============================
-- 콘텐츠 새로고침
-- ==============================
refresh_content = function()
    if not is_active then return end
    if not custom_panel then return end

    set_tab_selected(true)
    clear_native_tab_selection()
    hide_native_content()

    local instanceID = current_instance_id
    if not instanceID then
        local journal = _G.EncounterJournal
        instanceID = journal and journal.instanceID
    end

    if type(instanceID) ~= "number" or instanceID <= 0 then
        set_empty_state(EMPTY_NO_INSTANCE, true)
        return
    end

    current_instance_id = instanceID

    local _, _, _, _, _, _, _, _, _, _, _, is_raid = EJ_GetInstanceInfo(instanceID)
    local rows, _, is_pending = M.get_cached_rows(instanceID)

    ensure_boss_filter(instanceID)
    setup_boss_dropdown()

    if not rows then
        if not is_pending or pending_refresh_id ~= instanceID then
            pending_refresh_id = instanceID
            M.request_rows(instanceID, is_raid == true, function(done_id)
                if pending_refresh_id == done_id then pending_refresh_id = nil end
                if is_active and current_instance_id == done_id then refresh_content() end
            end)
        end
        set_empty_state(EMPTY_LOADING, true)
        return
    end

    pending_refresh_id = nil
    local total = #rows
    local filtered = filter_rows_by_boss(rows)
    local count = #filtered

    if total == 0 then set_empty_state(EMPTY_NO_RESULTS, true) return end
    if count == 0 then set_empty_state(EMPTY_NO_FILTER, true) return end

    if not ensure_scroll_view() then
        if not achievement_ui_ready then
            if not pending_ach_ui_load
                and type(_G.C_Timer) == "table"
                and type(_G.C_Timer.After) == "function" then
                pending_ach_ui_load = true
                _G.C_Timer.After(0, function()
                    pending_ach_ui_load = false
                    ensure_achievement_ui_loaded()
                    -- AchievementUI 로드 후 캐시 무효화 및 재시도
                    M.reset_caches()
                    if is_active then refresh_content() end
                end)
            end
            set_empty_state(EMPTY_LOADING, true)
        else
            set_empty_state(EMPTY_NO_UI, true)
        end
        return
    end

    set_empty_state(nil, false)
    populate_rows(filtered, instanceID)
end

-- ==============================
-- 탭 활성화 / 비활성화
-- ==============================
activate_custom_tab = function()
    if not tab_button then return end

    local _, enc, infoFrame = get_encounter_frames()
    if not is_active and infoFrame and type(infoFrame.tab) == "number" then
        previous_native_tab = infoFrame.tab
    end
    is_active = true
    sticky_active = true

    instance_overview_was_shown = (enc and enc.instance and enc.instance:IsShown()) and true or false
    if infoFrame then infoFrame.tab = 4 end

    set_tab_selected(true)
    clear_native_tab_selection()
    hide_native_content()

    if custom_panel then
        custom_panel:Show()
        refresh_content()
    end
end

deactivate_custom_tab = function()
    if not is_active then
        set_tab_selected(false)
        if custom_panel then custom_panel:Hide() end
        return
    end

    is_active = false
    pending_refresh_id = nil
    set_tab_selected(false)

    if custom_panel then custom_panel:Hide() end

    M.cancel_pending_builds()
    show_native_content()
end

local function on_difficulty_update()
    if is_active then
        M.reset_caches()
        boss_filter_options = nil
        refresh_content()
    end
end

-- ==============================
-- 훅 설치
-- ==============================
-- EncounterJournal_Display* 함수는 마지막에 "현재 탭 유지" 목적으로
-- info.tab(=4, 업적 활성 중 점유)에 해당하는 modelTab:Click()을 내부적으로 호출해
-- EncounterJournal_SetTab(4)를 재발생시킨다. 이를 사용자가 실제로 모델탭(4)을
-- 클릭한 것과 구분하기 위해, tabID==4인 경우만 다음 프레임으로 판단을 미뤄
-- 같은 프레임에 Display*가 호출됐는지(=내부 호출) 세대 카운터로 확인한다.
-- (전역함수 재할당 없이 hooksecurefunc + C_Timer.After만 사용 — taint 회피)
local function install_hooks()
    if hooks_installed then return end
    hooks_installed = true

    hooksecurefunc("EncounterJournal_SetTab", function(tabID)
        if not is_active then return end
        if tabID ~= 4 then
            sticky_active = false
            deactivate_custom_tab()
            return
        end
        local gen = display_generation
        if type(_G.C_Timer) == "table" and type(_G.C_Timer.After) == "function" then
            _G.C_Timer.After(0, function()
                if is_active and display_generation == gen then
                    sticky_active = false
                    deactivate_custom_tab()
                end
            end)
        end
    end)

    hooksecurefunc("EncounterJournal_DisplayInstance", function(instanceID)
        display_generation = display_generation + 1
        current_instance_id = instanceID
        if is_active then refresh_content() end
    end)

    hooksecurefunc("EncounterJournal_DisplayEncounter", function()
        display_generation = display_generation + 1
        local journal = _G.EncounterJournal
        local iid = journal and journal.instanceID
        if type(iid) == "number" and iid > 0 then
            current_instance_id = iid
        end
        boss_filter_user_selected = false
        if is_active then refresh_content() end
    end)

    local journal = _G.EncounterJournal
    if journal then
        journal:HookScript("OnHide", function()
            current_instance_id = nil
            pending_refresh_id = nil
            M.cancel_pending_builds()
            deactivate_custom_tab()
        end)

        journal:HookScript("OnShow", function()
            if sticky_active and not is_active then
                activate_custom_tab()
            end
        end)

        local enc = journal.encounter
        if enc then
            enc:HookScript("OnShow", function()
                local iid = journal.instanceID
                if type(iid) == "number" and iid > 0 then current_instance_id = iid end
            end)
            enc:HookScript("OnHide", function()
                deactivate_custom_tab()
            end)
        end
    end

    -- 난이도 변경 시 새로고침
    ef_difficulty:SetScript("OnEvent", on_difficulty_update)
end

-- ==============================
-- 업적 데이터 프리로드
-- ==============================
-- 탭 클릭 시 렉 방지: EJ 오픈 시점에 미리 로드
local preload_scheduled = false

local function preload_achievement_data()
    if ensure_achievement_ui_loaded() then
        ensure_scroll_view()
        M.request_graph()
    end
end

-- ==============================
-- 마스터 토글
-- ==============================
function M.SetEnabled(enabled)
    if not tab_button then return end
    if enabled then
        tab_button:Show()
        ef_difficulty:RegisterEvent("EJ_DIFFICULTY_UPDATE")
    else
        tab_button:Hide()
        ef_difficulty:UnregisterEvent("EJ_DIFFICULTY_UPDATE")
        if is_active then
            sticky_active = false
            deactivate_custom_tab()
        end
    end
end

-- ==============================
-- UI 초기화
-- ==============================
local function ensure_ui()
    local _, _, infoFrame = get_encounter_frames()
    if not infoFrame then return false end
    create_custom_side_tab(infoFrame)
    create_custom_panel(infoFrame)
    install_visibility_guards(infoFrame)
    install_hooks()

    if not preload_scheduled then
        preload_scheduled = true
        if type(_G.C_Timer) == "table" and type(_G.C_Timer.After) == "function" then
            _G.C_Timer.After(0, preload_achievement_data)
        else
            preload_achievement_data()
        end
    end

    M.SetEnabled(dodoDB.enableEJAchievements ~= false)

    return tab_button ~= nil and custom_panel ~= nil
end

-- ==============================
-- 이벤트
-- ==============================
local function on_ej_event(_, event, arg1)
    if event == "ADDON_LOADED" then
        if arg1 == "Blizzard_EncounterJournal" then
            ensure_ui()
        elseif arg1 == BLIZZARD_ACHIEVEMENT_ADDON then
            achievement_ui_ready = is_achievement_ui_ready()
            if achievement_ui_ready then
                M.reset_caches()
                scroll_view_initialized = false
                M.request_graph()
                if is_active then refresh_content() end
            end
        end
    elseif event == "PLAYER_LOGIN" then
        ensure_ui()
    end
end

local ef = CreateFrame("Frame")
ef:RegisterEvent("ADDON_LOADED")
ef:RegisterEvent("PLAYER_LOGIN")
ef:SetScript("OnEvent", on_ej_event)

if _G.EncounterJournal then ensure_ui() end

-- ==============================
-- 설정 등록
-- ==============================
local function update_achievements_enabled()
    M.SetEnabled(dodoDB.enableEJAchievements ~= false)
end

dodo.OptionRegistrations = dodo.OptionRegistrations or {}
dodo.OptionRegistrations["인터페이스.모험안내서"] = dodo.OptionRegistrations["인터페이스.모험안내서"] or {}
table.insert(dodo.OptionRegistrations["인터페이스.모험안내서"], function(category)
    Checkbox(category, "enableEJAchievements", "업적 탭 활성화", "모험 안내서에 업적 탭을 추가합니다.", true, update_achievements_enabled)
end)
