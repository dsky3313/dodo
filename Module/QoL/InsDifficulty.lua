-- ==============================
-- Inspired
-- ==============================
-- Clickable Set Difficulty (https://wago.io/W1-rpkkou)

-- ==============================
-- 설정 및 테이블
-- ==============================
---@diagnostic disable: lowercase-global, param-type-mismatch, redundant-parameter, undefined-field, undefined-global
local addonName, dodo = ...
dodoDB = dodoDB or {}

dodo.difficultyTable = {
    dungeon = {
        { label = "일반", value = "1" },
        { label = "영웅", value = "2" },
        { label = "신화", value = "23" }
    },
    raid = {
        { label = "일반", value = "14" },
        { label = "영웅", value = "15" },
        { label = "신화", value = "16" }
    },
    legacy = {
        { label = "10인", value = "3" },
        { label = "25인", value = "4" }
    },
}

-- ==============================
-- 캐싱
-- ==============================
-- 함수
local CreateFrame = CreateFrame
local GetDungeonDifficultyID = GetDungeonDifficultyID
local GetInstanceInfo = GetInstanceInfo
local GetLegacyRaidDifficultyID = GetLegacyRaidDifficultyID
local GetRaidDifficultyID = GetRaidDifficultyID
local IsInGroup = IsInGroup
local IsInRaid = IsInRaid
local PlaySound = PlaySound
local ResetInstances = ResetInstances
local SetDungeonDifficultyID = SetDungeonDifficultyID
local SetLegacyRaidDifficultyID = SetLegacyRaidDifficultyID
local SetRaidDifficultyID = SetRaidDifficultyID
local UnitIsGroupLeader = UnitIsGroupLeader
local ipairs = ipairs
local issecretvalue = issecretvalue
local pairs = pairs
local tonumber = tonumber
local unpack = unpack

-- 변수
local C_ChatInfo = C_ChatInfo
local C_Timer = C_Timer
local NORMAL_COLOR_R, NORMAL_COLOR_G, NORMAL_COLOR_B = 1, 0.82, 0
local SELECTED_COLOR_R, SELECTED_COLOR_G, SELECTED_COLOR_B = 1, 1, 1
local SOUNDKIT = SOUNDKIT
local UIParent = UIParent
local btn_highlight = "glues-characterSelect-nameBG"
local btn_select = "UI-Frame-DastardlyDuos-Bar-Frame-gold"

local current_diff = { dungeon = 0, raid = 0, legacy = 0 }
local buttons = { dungeon = {}, raid = {}, legacy = {} }

-- 전방 선언
local check_permission
local update_ui_status
local on_difficulty_click
local ins_difficulty
local ins_difficulty_ui
local update_event_registration
local create_ui

local function is_ins() -- 인스확인
    local _, instance_type, difficulty_id = GetInstanceInfo()
    return (difficulty_id == 8 or instance_type == "raid") -- 1 일반 / 8 쐐기 / raid 레이드
end

-- ==============================
-- 디스플레이
-- ==============================
local function create_category_row(parent, yOffset, titleText)
    local row = CreateFrame("Frame", nil, parent)
    row:SetSize(220, 35)
    row:SetPoint("TOP", parent, "TOP", 0, yOffset)

    row.bg = row:CreateTexture(nil, "BACKGROUND")
    row.bg:SetAllPoints()
    row.bg:SetAtlas("legionmission-hearts-background")

    row.titleBg = row:CreateTexture(nil, "ARTWORK")
    row.titleBg:SetSize(60, 25)
    row.titleBg:SetPoint("LEFT", 10, 0)
    row.titleBg:SetAtlas("UI-Character-Info-Title")

    row.title = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.title:SetPoint("CENTER", row.titleBg, "CENTER", 0, 0)
    row.title:SetText(titleText)
    return row
end

local function create_difficulty_button(parentRow, category, index, data)
    local label = data.label
    local xOffsets = { ["일반"] = 0, ["영웅"] = 45, ["신화"] = 90, ["10인"] = 20, ["25인"] = 80 }
    local btn = CreateFrame("Button", nil, parentRow)
    btn:SetSize(45, 30)
    btn:SetPoint("LEFT", parentRow, "LEFT", 70 + (xOffsets[label] or 0), 0)
    btn:EnableMouse(true)
    btn:RegisterForClicks("LeftButtonUp")
    btn:SetFrameLevel(parentRow:GetFrameLevel() + 10)

    btn.highlightBg = btn:CreateTexture(nil, "BACKGROUND")
    btn.highlightBg:SetSize(45, 25)
    btn.highlightBg:SetPoint("CENTER", btn, "CENTER", 0, 0)
    btn.highlightBg:Hide()

    btn.text = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    btn.text:SetPoint("CENTER")
    btn.text:SetText(label)

    btn.category = category
    btn.value = data.value
    btn.label = label

    buttons[category][index] = btn
    return btn
end

local difficulty_frame
local reset_btn

local function on_btn_enter(s)
    if not s.isSelected then
        s.highlightBg:SetAtlas(btn_highlight)
        s.highlightBg:Show()
        s.text:SetTextColor(SELECTED_COLOR_R, SELECTED_COLOR_G, SELECTED_COLOR_B)
    end
end

local function on_btn_leave(s)
    if not s.isSelected then
        s.highlightBg:Hide()
        s.text:SetTextColor(NORMAL_COLOR_R, NORMAL_COLOR_G, NORMAL_COLOR_B)
    end
end

local function on_reset_click()
    if check_permission() then
        ResetInstances()
        local msg = "인스턴스 초기화 완료!"
        if IsInGroup() or IsInRaid() then
            C_ChatInfo.SendChatMessage(msg, "PARTY")
        else
            C_ChatInfo.SendChatMessage(msg, "SAY")
        end
        PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
    end
end

create_ui = function()
    if difficulty_frame then return end

    local anchor_frame
    if dodo.EditMode then
        anchor_frame = dodo.EditMode:GetSystem("InsDifficulty")
    end

    -- dodo.UI 표준 포트레이트 패널로 전환 (닫기 버튼 숨김 옵션 true 전달)
    difficulty_frame = dodo.UI:CreatePortraitPanel("DifficultySelector", "인스턴스 난이도", true)
    difficulty_frame:SetFrameStrata("LOW")
    difficulty_frame:SetSize(230, 124)
    
    difficulty_frame:ClearAllPoints()
    if anchor_frame then
        difficulty_frame:SetPoint("CENTER", anchor_frame, "CENTER", 0, 0)
    else
        difficulty_frame:SetPoint("TOPLEFT", 5, -5)
    end
    difficulty_frame:EnableMouse(true)

    -- 순정 Bg 제거 (FlatPanelBackgroundTemplate을 쓸 것이므로)
    if difficulty_frame.Bg then
        difficulty_frame.Bg:Hide()
    end

    -- FlatPanelBackgroundTemplate 배경 설정
    difficulty_frame.Background = CreateFrame("Frame", nil, difficulty_frame, "FlatPanelBackgroundTemplate")
    difficulty_frame.Background:SetFrameLevel(difficulty_frame:GetFrameLevel() - 1)
    difficulty_frame.Background:SetPoint("TOPLEFT", 7, -18)
    difficulty_frame.Background:SetPoint("BOTTOMRIGHT", -3, 3)

    local row1 = create_category_row(difficulty_frame, -25, "던전")
    for i, data in ipairs(dodo.difficultyTable.dungeon) do create_difficulty_button(row1, "dungeon", i, data) end

    local row2 = create_category_row(difficulty_frame, -55, "공격대")
    for i, data in ipairs(dodo.difficultyTable.raid) do create_difficulty_button(row2, "raid", i, data) end

    local row3 = create_category_row(difficulty_frame, -85, "낭만")
    for i, data in ipairs(dodo.difficultyTable.legacy) do create_difficulty_button(row3, "legacy", i, data) end

    -- 닫기 버튼이 없으므로 새로고침 버튼을 타이틀바 맨 우측 끝에 배치 (가려짐 방지)
    reset_btn = CreateFrame("Button", nil, difficulty_frame.NineSlice, "SquareIconButtonTemplate")
    reset_btn:SetSize(30, 30)
    reset_btn:SetPoint("TOPRIGHT", difficulty_frame, "TOPRIGHT", 4, 4)
    reset_btn.Icon:SetAtlas("UI-RefreshButton")
    reset_btn:SetFrameLevel(difficulty_frame.NineSlice:GetFrameLevel() + 10)

    -- 버튼 스크립트 연결
    for _, group in pairs(buttons) do
        for _, btn in pairs(group) do
            btn:SetScript("OnClick", on_difficulty_click)
            btn:SetScript("OnEnter", on_btn_enter)
            btn:SetScript("OnLeave", on_btn_leave)
        end
    end

    reset_btn:SetScript("OnClick", on_reset_click)
end

-- ==============================
-- 동작
-- ==============================
local init_ins_difficulty -- 전방 선언 (이벤트 등록/해제용)

check_permission = function()
    if is_ins() then return false end
    return (not IsInGroup() and not IsInRaid()) or UnitIsGroupLeader("player")
end

update_ui_status = function(force_category, force_val)
    local is_enabled = (dodoDB and dodoDB.useInsDifficultyFrame ~= false)
    if not is_enabled or is_ins() then
        if difficulty_frame and difficulty_frame:IsShown() then difficulty_frame:Hide() end
        return
    else
        if not difficulty_frame then create_ui() end
        if not difficulty_frame:IsShown() then difficulty_frame:Show() end
    end

    local has_permission = check_permission()
    current_diff.dungeon = GetDungeonDifficultyID()
    current_diff.raid = GetRaidDifficultyID()
    current_diff.legacy = GetLegacyRaidDifficultyID()

    for category, group in pairs(buttons) do
        local target_val
        if has_permission then
            if category == force_category then
                target_val = tonumber(force_val)
            else
                local db_key = "InsDifficulty" .. (category == "dungeon" and "Dungeon" or category == "raid" and "Raid" or "Legacy")
                target_val = dodoDB and tonumber(dodoDB[db_key])
            end
            if not target_val then
                target_val = tonumber(current_diff[category])
            end
        else
            target_val = tonumber(current_diff[category])
        end

        for _, btn in pairs(group) do
            -- Dirty Check: 권한 상태 변경 시에만 업데이트
            if btn._lastPermission ~= has_permission then
                btn:SetEnabled(has_permission)
                btn:SetAlpha(has_permission and 1 or 0.5)
                btn._lastPermission = has_permission
            end

            -- Dirty Check: 선택 상태 변경 시에만 업데이트
            local is_selected = (tonumber(btn.value) == target_val)
            if btn._lastSelected ~= is_selected then
                btn.highlightBg:SetAtlas(is_selected and btn_select or btn_highlight)
                btn.highlightBg:SetShown(is_selected)
                if is_selected then
                    btn.text:SetTextColor(SELECTED_COLOR_R, SELECTED_COLOR_G, SELECTED_COLOR_B)
                else
                    btn.text:SetTextColor(NORMAL_COLOR_R, NORMAL_COLOR_G, NORMAL_COLOR_B)
                end
                btn.isSelected = is_selected
                btn._lastSelected = is_selected
            end
        end
    end
end

on_difficulty_click = function(self)
    if not check_permission() then return end
    local val = tonumber(self.value)
    if not val then return end

    local db_key = "InsDifficulty" .. (self.category == "dungeon" and "Dungeon" or self.category == "raid" and "Raid" or "Legacy")
    if dodoDB then
        dodoDB[db_key] = val
    end

    if self.category == "dungeon" then
        SetDungeonDifficultyID(val)
    elseif self.category == "raid" then
        SetRaidDifficultyID(val)
    elseif self.category == "legacy" then
        SetLegacyRaidDifficultyID(val)
    end
    PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
    update_ui_status(self.category, val)
end

-- 이벤트 등록 상태 관리: 두 기능 중 하나라도 켜있으면 이벤트 유지
update_event_registration = function()
    if not init_ins_difficulty then return end
    local ui_on = (dodoDB and dodoDB.useInsDifficultyFrame ~= false)
    if ui_on and not is_ins() then
        init_ins_difficulty:RegisterEvent("PLAYER_ENTERING_WORLD")
        init_ins_difficulty:RegisterEvent("PARTY_LEADER_CHANGED")
        init_ins_difficulty:RegisterEvent("PLAYER_DIFFICULTY_CHANGED")
    else
        init_ins_difficulty:UnregisterEvent("PLAYER_ENTERING_WORLD")
        init_ins_difficulty:UnregisterEvent("PARTY_LEADER_CHANGED")
        init_ins_difficulty:UnregisterEvent("PLAYER_DIFFICULTY_CHANGED")
    end
end

-- 난이도 자동 고정 (Option.lua용)
ins_difficulty = function()
    if not dodoDB then return end
    update_event_registration()
    if dodoDB.useInsDifficultyFrame == false or not check_permission() then
        update_ui_status()
        return
    end

    local dungeon_val = tonumber(dodoDB.InsDifficultyDungeon)
    if dungeon_val then
        local current = GetDungeonDifficultyID()
        if not issecretvalue(current) and current ~= dungeon_val then
            SetDungeonDifficultyID(dungeon_val)
        end
    end

    local raid_val = tonumber(dodoDB.InsDifficultyRaid)
    if raid_val then
        local current = GetRaidDifficultyID()
        if not issecretvalue(current) and current ~= raid_val then
            SetRaidDifficultyID(raid_val)
        end
    end

    local legacy_val = tonumber(dodoDB.InsDifficultyLegacy)
    if legacy_val then
        local current = GetLegacyRaidDifficultyID()
        if not issecretvalue(current) and current ~= legacy_val then
            SetLegacyRaidDifficultyID(legacy_val)
        end
    end
    update_ui_status()
end

ins_difficulty_ui = function()
    if not dodoDB then return end
    update_event_registration()
    update_ui_status()
end

-- ==============================
-- 이벤트
-- ==============================
local function on_entering_world_timer()
    update_event_registration()
    ins_difficulty()
end

local function on_event(self, event, arg1)
    if event == "ADDON_LOADED" then
        if arg1 == addonName then
            dodoDB = dodoDB or {}
            self:UnregisterEvent("ADDON_LOADED")
        end
    elseif event == "PLAYER_LOGIN" then
        if dodoDB.useInsDifficultyFrame == nil then dodoDB.useInsDifficultyFrame = true end
        if dodo.EditMode then
            dodo.EditMode:CreateSystem("InsDifficulty", "인스턴스 난이도", "인스턴스 난이도", UIParent, 230, 124, { point = "TOPLEFT", relativeTo = "UIParent", relativePoint = "TOPLEFT", xOfs = 5, yOfs = -5 }, nil, function() return dodoDB and dodoDB.useInsDifficultyFrame ~= false end)
        end
        update_event_registration()
        self:UnregisterEvent("PLAYER_LOGIN")
    elseif event == "PLAYER_ENTERING_WORLD" then
        C_Timer.After(1, on_entering_world_timer)
    elseif event == "PARTY_LEADER_CHANGED" or event == "PLAYER_DIFFICULTY_CHANGED" then
        update_ui_status()
    end
end

init_ins_difficulty = CreateFrame("Frame")
init_ins_difficulty:RegisterEvent("ADDON_LOADED")
init_ins_difficulty:RegisterEvent("PLAYER_LOGIN")
init_ins_difficulty:RegisterEvent("PLAYER_ENTERING_WORLD")
init_ins_difficulty:SetScript("OnEvent", on_event)


-- ==============================
-- 외부 노출 및 모듈 설정창 등록 (dodoEditModePanel)
-- ==============================
local function get_use_ins_difficulty_frame()
    return dodoDB.useInsDifficultyFrame ~= false
end

local function set_use_ins_difficulty_frame(val)
    dodoDB.useInsDifficultyFrame = val
    ins_difficulty_ui()
end

if dodo.RegisterEditModeModuleSetting then
    dodo.RegisterEditModeModuleSetting("편의기능", {
        {
            name = "인스턴스 난이도",
            get = get_use_ins_difficulty_frame,
            set = set_use_ins_difficulty_frame,
        }
    })
end