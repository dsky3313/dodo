-- ==============================
-- Inspired
-- ==============================
-- Clickable Set Difficulty (https://wago.io/W1-rpkkou)

-- ==============================
-- 설정 및 테이블
-- ==============================
---@diagnostic disable: lowercase-global, param-type-mismatch, redundant-parameter, undefined-field, undefined-global
local addonName, dodo = ...
local module = {}
dodo:RegisterModule("InsDifficulty", module)

local LibEditMode = LibStub and LibStub("LibEditMode", true)

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
-- 프레임 및 이벤트 핸들러 정의
-- ==============================
local buttons = { dungeon = {}, raid = {}, legacy = {} }
local currentDiff = { dungeon = 0, raid = 0, legacy = 0 }
local difficultyFrame
local initInsDifficulty
local resetBtn

-- ==============================
-- 캐싱
-- ==============================
local C_ChatInfo = C_ChatInfo
local C_Timer = C_Timer
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
local SOUNDKIT = SOUNDKIT
local UIParent = UIParent
local UnitIsGroupLeader = UnitIsGroupLeader
local ipairs = ipairs
local issecretvalue = issecretvalue or function() return false end
local pairs = pairs
local tonumber = tonumber
local unpack = unpack

local NORMAL_COLOR_R, NORMAL_COLOR_G, NORMAL_COLOR_B = 1, 0.82, 0
local SELECTED_COLOR_R, SELECTED_COLOR_G, SELECTED_COLOR_B = 1, 1, 1
local btn_highlight = "glues-characterSelect-nameBG"
local btn_select = "UI-Frame-DastardlyDuos-Bar-Frame-gold"

local function is_ins() -- 인스확인
    local _, instanceType, difficultyID = GetInstanceInfo()
    return (difficultyID == 8 or instanceType == "raid") -- 1 일반 / 8 쐐기 / raid 레이드
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

local check_permission
local update_ui_status
local OnDifficultyClick
local ins_difficulty
local update_event_registration

check_permission = function()
    if is_ins() then return false end
    return (not IsInGroup() and not IsInRaid()) or UnitIsGroupLeader("player")
end

update_ui_status = function(forceCategory, forceValue)
    local isEnabled = (dodo.DB and dodo.DB.enableInsDifficultyModule ~= false)
    if not isEnabled or is_ins() then
        if difficultyFrame and difficultyFrame:IsShown() then difficultyFrame:Hide() end
        return
    else
        if difficultyFrame and not difficultyFrame:IsShown() then difficultyFrame:Show() end
    end

    local hasPermission = check_permission()
    currentDiff.dungeon = GetDungeonDifficultyID()
    currentDiff.raid = GetRaidDifficultyID()
    currentDiff.legacy = GetLegacyRaidDifficultyID()

    for category, group in pairs(buttons) do
        local targetVal
        if hasPermission then
            if category == forceCategory then
                targetVal = tonumber(forceValue)
            else
                local dbKey = "InsDifficulty" .. (category == "dungeon" and "Dungeon" or category == "raid" and "Raid" or "Legacy")
                targetVal = dodo.DB and tonumber(dodo.DB[dbKey])
            end
            if not targetVal then
                targetVal = tonumber(currentDiff[category])
            end
        else
            targetVal = tonumber(currentDiff[category])
        end

        for _, btn in pairs(group) do
            if btn._lastPermission ~= hasPermission then
                btn:SetEnabled(hasPermission)
                btn:SetAlpha(hasPermission and 1 or 0.5)
                btn._lastPermission = hasPermission
            end

            local isSelected = (tonumber(btn.value) == targetVal)
            if btn._lastSelected ~= isSelected then
                btn.highlightBg:SetAtlas(isSelected and btn_select or btn_highlight)
                btn.highlightBg:SetShown(isSelected)
                if isSelected then
                    btn.text:SetTextColor(SELECTED_COLOR_R, SELECTED_COLOR_G, SELECTED_COLOR_B)
                else
                    btn.text:SetTextColor(NORMAL_COLOR_R, NORMAL_COLOR_G, NORMAL_COLOR_B)
                end
                btn.isSelected = isSelected
                btn._lastSelected = isSelected
            end
        end
    end
end

OnDifficultyClick = function(self)
    if not check_permission() then return end
    local val = tonumber(self.value)
    if not val then return end

    local dbKey = "InsDifficulty" .. (self.category == "dungeon" and "Dungeon" or self.category == "raid" and "Raid" or "Legacy")
    if dodo.DB then
        dodo.DB[dbKey] = val
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

update_event_registration = function()
    if not initInsDifficulty then return end
    local uiOn = (dodo.DB and dodo.DB.enableInsDifficultyModule ~= false)
    if uiOn and not is_ins() then
        initInsDifficulty:RegisterEvent("PARTY_LEADER_CHANGED")
        initInsDifficulty:RegisterEvent("PLAYER_DIFFICULTY_CHANGED")
    else
        initInsDifficulty:UnregisterEvent("PARTY_LEADER_CHANGED")
        initInsDifficulty:UnregisterEvent("PLAYER_DIFFICULTY_CHANGED")
    end
end

ins_difficulty = function()
    if not dodo.DB then return end
    update_event_registration()
    
    if dodo.DB.enableInsDifficultyModule == false or not check_permission() then
        update_ui_status()
        return
    end

    local dungeonVal = tonumber(dodo.DB.InsDifficultyDungeon)
    if dungeonVal then
        local current = GetDungeonDifficultyID()
        if not issecretvalue(current) and current ~= dungeonVal then
            SetDungeonDifficultyID(dungeonVal)
        end
    end

    local raidVal = tonumber(dodo.DB.InsDifficultyRaid)
    if raidVal then
        local current = GetRaidDifficultyID()
        if not issecretvalue(current) and current ~= raidVal then
            SetRaidDifficultyID(raidVal)
        end
    end

    local legacyVal = tonumber(dodo.DB.InsDifficultyLegacy)
    if legacyVal then
        local current = GetLegacyRaidDifficultyID()
        if not issecretvalue(current) and current ~= legacyVal then
            SetLegacyRaidDifficultyID(legacyVal)
        end
    end
    update_ui_status()
end

local function update_module_state()
    update_event_registration()
    update_ui_status()
end

dodo.UpdateInsDifficultyModuleState = update_module_state

-- ==============================
-- 초기화
-- ==============================
local function create_ui()
    if difficultyFrame then return end

    difficultyFrame = CreateFrame("Frame", "DifficultySelector", UIParent, "DefaultPanelBaseTemplate")
    difficultyFrame:SetSize(230, 124)
    if dodo.DB and dodo.DB.insDifficultyX and dodo.DB.insDifficultyY then
        difficultyFrame:SetPoint(dodo.DB.insDifficultyPoint or "TOPLEFT", UIParent, dodo.DB.insDifficultyPoint or "TOPLEFT", dodo.DB.insDifficultyX, dodo.DB.insDifficultyY)
    else
        difficultyFrame:SetPoint("TOPLEFT", 5, -5)
    end
    difficultyFrame:EnableMouse(true)

    difficultyFrame.NineSlice.Text = difficultyFrame.NineSlice:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    difficultyFrame.NineSlice.Text:SetPoint("TOP", 0, -5)
    difficultyFrame.NineSlice.Text:SetText("인스턴스 난이도 설정")

    difficultyFrame.Background = CreateFrame("Frame", nil, difficultyFrame, "FlatPanelBackgroundTemplate")
    difficultyFrame.Background:SetFrameLevel(difficultyFrame:GetFrameLevel() - 1)
    difficultyFrame.Background:SetPoint("TOPLEFT", 7, -18)
    difficultyFrame.Background:SetPoint("BOTTOMRIGHT", -3, 3)

    local row1 = create_category_row(difficultyFrame, -25, "던전")
    for i, data in ipairs(dodo.difficultyTable.dungeon) do create_difficulty_button(row1, "dungeon", i, data) end

    local row2 = create_category_row(difficultyFrame, -55, "공격대")
    for i, data in ipairs(dodo.difficultyTable.raid) do create_difficulty_button(row2, "raid", i, data) end

    local row3 = create_category_row(difficultyFrame, -85, "낭만")
    for i, data in ipairs(dodo.difficultyTable.legacy) do create_difficulty_button(row3, "legacy", i, data) end

    resetBtn = CreateFrame("Button", nil, difficultyFrame.NineSlice, "SquareIconButtonTemplate")
    resetBtn:SetSize(30, 30)
    resetBtn:SetPoint("TOPRIGHT", difficultyFrame, "TOPRIGHT", 4, 4)
    resetBtn.Icon:SetAtlas("UI-RefreshButton")
    resetBtn:SetFrameLevel(difficultyFrame.NineSlice:GetFrameLevel() + 10)

    -- 버튼 스크립트 연결
    for _, group in pairs(buttons) do
        for _, btn in pairs(group) do
            btn:SetScript("OnClick", OnDifficultyClick)
            btn:SetScript("OnEnter", function(s)
                if not s.isSelected then
                    s.highlightBg:SetAtlas(btn_highlight)
                    s.highlightBg:Show()
                    s.text:SetTextColor(SELECTED_COLOR_R, SELECTED_COLOR_G, SELECTED_COLOR_B)
                end
            end)
            btn:SetScript("OnLeave", function(s)
                if not s.isSelected then
                    s.highlightBg:Hide()
                    s.text:SetTextColor(NORMAL_COLOR_R, NORMAL_COLOR_G, NORMAL_COLOR_B)
                end
            end)
        end
    end

    resetBtn:SetScript("OnClick", function()
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
    end)

    initInsDifficulty = CreateFrame("Frame")
end

local function initialize()
    create_ui()
end

local function update_feature()
    ins_difficulty()
end

-- ==============================
-- 모듈 생명주기
-- ==============================
function module:OnEnable()
    initialize()
    update_feature()
    update_module_state()

    -- LibEditMode 등록
    difficultyFrame.editModeName = "dodo 인스턴스 난이도"
    if LibEditMode then
        LibEditMode:AddFrame(
            difficultyFrame,
            function(frame, layoutName, point, x, y)
                if dodo.DB then
                    dodo.DB.insDifficultyX = x
                    dodo.DB.insDifficultyY = y
                    dodo.DB.insDifficultyPoint = point
                end
            end,
            {
                point = "TOPLEFT",
                x = 5,
                y = -5,
            },
            "dodo 인스턴스 난이도"
        )
    end

    initInsDifficulty:RegisterEvent("PLAYER_ENTERING_WORLD")
    local function delayed_init()
        update_event_registration()
        ins_difficulty()
    end

    local function on_init_event(self, event, arg1)
        if event == "PLAYER_ENTERING_WORLD" then
            C_Timer.After(1, delayed_init)
        elseif event == "PARTY_LEADER_CHANGED" or event == "PLAYER_DIFFICULTY_CHANGED" then
            update_ui_status()
        end
    end

    initInsDifficulty:SetScript("OnEvent", on_init_event)

    if LibEditMode then
        local function on_editmode_enter()
            local isEnabled = (dodo.DB and dodo.DB.enableInsDifficultyModule ~= false)
            if isEnabled then
                difficultyFrame:Show()
            end
        end

        local function on_editmode_exit()
            update_ui_status()
        end

        LibEditMode:RegisterCallback("enter", on_editmode_enter)
        LibEditMode:RegisterCallback("exit", on_editmode_exit)
    end

    if dodo.RegisterEditModeSetting then
        dodo.RegisterEditModeSetting("편의기능", {
            {
                name = "난이도 설정창",
                get = function() return dodo.DB and dodo.DB.enableInsDifficultyModule ~= false end,
                set = function(checked)
                    if dodo.DB then dodo.DB.enableInsDifficultyModule = checked end
                    update_module_state()
                end
            }
        })
    end
end