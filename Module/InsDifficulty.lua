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

local currentDiff = { dungeon = 0, raid = 0, legacy = 0 }
local buttons = { dungeon = {}, raid = {}, legacy = {} }

-- 전방 선언
local checkPermission
local UpdateUIStatus
local OnDifficultyClick
local InsDifficulty
local UpdateEventRegistration
local CreateUI

local function isIns() -- 인스확인
    local _, instanceType, difficultyID = GetInstanceInfo()
    return (difficultyID == 8 or instanceType == "raid") -- 1 일반 / 8 쐐기 / raid 레이드
end

-- ==============================
-- 디스플레이
-- ==============================
local function CreateCategoryRow(parent, yOffset, titleText)
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

local function CreateDifficultyButton(parentRow, category, index, data)
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

local difficultyFrame
local resetBtn

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
    if checkPermission() then
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

CreateUI = function()
    if difficultyFrame then return end

    local anchorFrame
    if dodo.EditMode then
        anchorFrame = dodo.EditMode:GetSystem("InsDifficulty")
    end

    -- dodo.UI 표준 포트레이트 패널로 전환 (닫기 버튼 숨김 옵션 true 전달)
    difficultyFrame = dodo.UI:CreatePortraitPanel("DifficultySelector", "인스턴스 난이도", true)
    difficultyFrame:SetSize(230, 124)
    
    difficultyFrame:ClearAllPoints()
    if anchorFrame then
        difficultyFrame:SetPoint("CENTER", anchorFrame, "CENTER", 0, 0)
    else
        difficultyFrame:SetPoint("TOPLEFT", 5, -5)
    end
    difficultyFrame:EnableMouse(true)

    -- 순정 Bg 제거 (FlatPanelBackgroundTemplate을 쓸 것이므로)
    if difficultyFrame.Bg then
        difficultyFrame.Bg:Hide()
    end

    -- FlatPanelBackgroundTemplate 배경 설정
    difficultyFrame.Background = CreateFrame("Frame", nil, difficultyFrame, "FlatPanelBackgroundTemplate")
    difficultyFrame.Background:SetFrameLevel(difficultyFrame:GetFrameLevel() - 1)
    difficultyFrame.Background:SetPoint("TOPLEFT", 7, -18)
    difficultyFrame.Background:SetPoint("BOTTOMRIGHT", -3, 3)

    local row1 = CreateCategoryRow(difficultyFrame, -25, "던전")
    for i, data in ipairs(dodo.difficultyTable.dungeon) do CreateDifficultyButton(row1, "dungeon", i, data) end

    local row2 = CreateCategoryRow(difficultyFrame, -55, "공격대")
    for i, data in ipairs(dodo.difficultyTable.raid) do CreateDifficultyButton(row2, "raid", i, data) end

    local row3 = CreateCategoryRow(difficultyFrame, -85, "낭만")
    for i, data in ipairs(dodo.difficultyTable.legacy) do CreateDifficultyButton(row3, "legacy", i, data) end

    -- 닫기 버튼이 없으므로 새로고침 버튼을 타이틀바 맨 우측 끝(TOPRIGHT, -6, -2)에 노출되게 배치 (가려짐 방지)
    local titleContainer = difficultyFrame.TitleContainer or difficultyFrame
    resetBtn = CreateFrame("Button", nil, titleContainer, "SquareIconButtonTemplate")
    resetBtn:SetSize(22, 22)
    resetBtn:SetPoint("TOPRIGHT", titleContainer, "TOPRIGHT", -6, -2)
    resetBtn.Icon:SetAtlas("UI-RefreshButton")
    resetBtn:SetFrameLevel(50)

    -- 버튼 스크립트 연결
    for _, group in pairs(buttons) do
        for _, btn in pairs(group) do
            btn:SetScript("OnClick", OnDifficultyClick)
            btn:SetScript("OnEnter", on_btn_enter)
            btn:SetScript("OnLeave", on_btn_leave)
        end
    end

    resetBtn:SetScript("OnClick", on_reset_click)
end

-- ==============================
-- 동작
-- ==============================
local initInsDifficulty -- 전방 선언 (이벤트 등록/해제용)

checkPermission = function()
    if isIns() then return false end
    return (not IsInGroup() and not IsInRaid()) or UnitIsGroupLeader("player")
end

UpdateUIStatus = function(forceCategory, forceValue)
    local isEnabled = (dodoDB and dodoDB.useInsDifficultyFrame ~= false)
    if not isEnabled or isIns() then
        if difficultyFrame and difficultyFrame:IsShown() then difficultyFrame:Hide() end
        return
    else
        if not difficultyFrame then CreateUI() end
        if not difficultyFrame:IsShown() then difficultyFrame:Show() end
    end

    local hasPermission = checkPermission()
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
                targetVal = dodoDB and tonumber(dodoDB[dbKey])
            end
            if not targetVal then
                targetVal = tonumber(currentDiff[category])
            end
        else
            targetVal = tonumber(currentDiff[category])
        end

        for _, btn in pairs(group) do
            -- Dirty Check: 권한 상태 변경 시에만 업데이트
            if btn._lastPermission ~= hasPermission then
                btn:SetEnabled(hasPermission)
                btn:SetAlpha(hasPermission and 1 or 0.5)
                btn._lastPermission = hasPermission
            end

            -- Dirty Check: 선택 상태 변경 시에만 업데이트
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
    if not checkPermission() then return end
    local val = tonumber(self.value)
    if not val then return end

    local dbKey = "InsDifficulty" .. (self.category == "dungeon" and "Dungeon" or self.category == "raid" and "Raid" or "Legacy")
    if dodoDB then
        dodoDB[dbKey] = val
    end

    if self.category == "dungeon" then
        SetDungeonDifficultyID(val)
    elseif self.category == "raid" then
        SetRaidDifficultyID(val)
    elseif self.category == "legacy" then
        SetLegacyRaidDifficultyID(val)
    end
    PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
    UpdateUIStatus(self.category, val)
end

-- 이벤트 등록 상태 관리: 두 기능 중 하나라도 켜있으면 이벤트 유지
UpdateEventRegistration = function()
    if not initInsDifficulty then return end
    local uiOn = (dodoDB and dodoDB.useInsDifficultyFrame ~= false)
    if uiOn and not isIns() then
        initInsDifficulty:RegisterEvent("PARTY_LEADER_CHANGED")
        initInsDifficulty:RegisterEvent("PLAYER_DIFFICULTY_CHANGED")
    else
        initInsDifficulty:UnregisterEvent("PARTY_LEADER_CHANGED")
        initInsDifficulty:UnregisterEvent("PLAYER_DIFFICULTY_CHANGED")
    end
end

-- 난이도 자동 고정 (Option.lua용)
InsDifficulty = function()
    if not dodoDB then return end
    UpdateEventRegistration()
    if dodoDB.useInsDifficultyFrame == false or not checkPermission() then
        UpdateUIStatus()
        return
    end

    local dungeonVal = tonumber(dodoDB.InsDifficultyDungeon)
    if dungeonVal then
        local current = GetDungeonDifficultyID()
        if not issecretvalue(current) and current ~= dungeonVal then
            SetDungeonDifficultyID(dungeonVal)
        end
    end

    local raidVal = tonumber(dodoDB.InsDifficultyRaid)
    if raidVal then
        local current = GetRaidDifficultyID()
        if not issecretvalue(current) and current ~= raidVal then
            SetRaidDifficultyID(raidVal)
        end
    end

    local legacyVal = tonumber(dodoDB.InsDifficultyLegacy)
    if legacyVal then
        local current = GetLegacyRaidDifficultyID()
        if not issecretvalue(current) and current ~= legacyVal then
            SetLegacyRaidDifficultyID(legacyVal)
        end
    end
    UpdateUIStatus()
end

-- 설정창 표시 토글 (Option.lua용)
InsDifficultyUI = function()
    if not dodoDB then return end
    UpdateEventRegistration()
    UpdateUIStatus()
end

-- 초기 스크립트 할당 루프 제거 (CreateUI로 이동됨)

-- ==============================
-- 이벤트
-- ==============================
local function on_entering_world_timer()
    UpdateEventRegistration()
    InsDifficulty()
end

local function on_event(self, event, arg1)
    if event == "ADDON_LOADED" then
        if arg1 == addonName then
            dodoDB = dodoDB or {}
            self:UnregisterEvent("ADDON_LOADED")
        end
    elseif event == "PLAYER_LOGIN" then
        if dodo.EditMode then
            dodo.EditMode:CreateSystem("InsDifficulty", "인스턴스 난이도", "인스턴스 난이도 설정 창의 위치를 이동합니다.", UIParent, 230, 124, { point = "TOPLEFT", relativeTo = "UIParent", relativePoint = "TOPLEFT", xOfs = 5, yOfs = -5 })
        end
        self:UnregisterEvent("PLAYER_LOGIN")
    elseif event == "PLAYER_ENTERING_WORLD" then
        C_Timer.After(1, on_entering_world_timer)
    elseif event == "PARTY_LEADER_CHANGED" or event == "PLAYER_DIFFICULTY_CHANGED" then
        UpdateUIStatus()
    end
end

initInsDifficulty = CreateFrame("Frame")
initInsDifficulty:RegisterEvent("ADDON_LOADED")
initInsDifficulty:RegisterEvent("PLAYER_LOGIN")
initInsDifficulty:RegisterEvent("PLAYER_ENTERING_WORLD")
initInsDifficulty:SetScript("OnEvent", on_event)


-- ==============================
-- 외부 노출 및 모듈 설정창 등록 (dodoEditModePanel)
-- ==============================
local function get_use_ins_difficulty_frame()
    return dodoDB.useInsDifficultyFrame ~= false
end

local function set_use_ins_difficulty_frame(val)
    dodoDB.useInsDifficultyFrame = val
    InsDifficultyUI()
end

if dodo.RegisterEditModeSetting then
    dodo.RegisterEditModeSetting("편의기능", {
        {
            name = "인스턴스 난이도",
            get = get_use_ins_difficulty_frame,
            set = set_use_ins_difficulty_frame,
        }
    })
end