------------------------------
-- 테이블
------------------------------
difficultyTable = {
    dungeon = {{label="일반", value="1"}, {label="영웅", value="2"}, {label="신화", value="23"}},
    raid = {{label="일반", value="14"}, {label="영웅", value="15"}, {label="신화", value="16"}},
    legacy = {{label="10인", value="3"}, {label="25인", value="4"}},
}

local tonumber, unpack, pairs, ipairs = tonumber, unpack, pairs, ipairs
local GetDungeonDifficultyID = GetDungeonDifficultyID
local GetRaidDifficultyID = GetRaidDifficultyID
local GetLegacyRaidDifficultyID = GetLegacyRaidDifficultyID
local SetDungeonDifficultyID = SetDungeonDifficultyID
local SetRaidDifficultyID = SetRaidDifficultyID
local SetLegacyRaidDifficultyID = SetLegacyRaidDifficultyID
local UnitIsGroupLeader = UnitIsGroupLeader
local IsInGroup, IsInRaid, IsInInstance = IsInGroup, IsInRaid, IsInInstance

local buttons = { dungeon = {}, raid = {}, legacy = {} }
local NORMAL_COLOR = {1, 0.82, 0}
local SELECTED_COLOR = {1, 1, 1}
local btn_select = "UI-Frame-DastardlyDuos-Bar-Frame-gold"
local btn_highlight = "glues-characterSelect-nameBG"

------------------------------
-- 디스플레이
------------------------------
local difficultyFrame = CreateFrame("Frame", "DifficultySelector", UIParent, "DefaultPanelBaseTemplate")
difficultyFrame:SetSize(230, 124)
difficultyFrame:SetPoint("TOPLEFT", 5, -5)
difficultyFrame:EnableMouse(true)

difficultyFrame.bg = CreateFrame("Frame", nil, difficultyFrame, "FlatPanelBackgroundTemplate")
difficultyFrame.bg:SetFrameLevel(difficultyFrame:GetFrameLevel() - 1)
difficultyFrame.bg:SetPoint("TOPLEFT", 7, -18)
difficultyFrame.bg:SetPoint("BOTTOMRIGHT", -3, 3)

difficultyFrame.NineSlice.Text = difficultyFrame.NineSlice:CreateFontString(nil, "OVERLAY", "GameFontNormal")
difficultyFrame.NineSlice.Text:SetPoint("TOP", 0, -5)
difficultyFrame.NineSlice.Text:SetText("인스턴스 난이도 설정")

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

local row1 = CreateCategoryRow(difficultyFrame, -25, "던전")
for i, data in ipairs(difficultyTable.dungeon) do CreateDifficultyButton(row1, "dungeon", i, data) end

local row2 = CreateCategoryRow(difficultyFrame, -55, "공격대")
for i, data in ipairs(difficultyTable.raid) do CreateDifficultyButton(row2, "raid", i, data) end

local row3 = CreateCategoryRow(difficultyFrame, -85, "낭만")
for i, data in ipairs(difficultyTable.legacy) do CreateDifficultyButton(row3, "legacy", i, data) end

local resetBtn = CreateFrame("Button", nil, difficultyFrame.NineSlice, "SquareIconButtonTemplate")
resetBtn:SetSize(30, 30)
resetBtn:SetPoint("TOPRIGHT", difficultyFrame, "TOPRIGHT", 4, 4)
resetBtn.Icon:SetAtlas("UI-RefreshButton")
resetBtn:SetFrameLevel(difficultyFrame.NineSlice:GetFrameLevel() + 10)

------------------------------
-- 동작
------------------------------

-- 활성조건 (전투 체크 삭제)
local function checkPermission()
    local inInstance, instanceType = IsInInstance()
    if inInstance and instanceType ~= "none" then return false end
    return (not IsInGroup() and not IsInRaid()) or UnitIsGroupLeader("player")
end

-- UI 업데이트
local function UpdateUIStatus(forceCategory, forceValue)
    local inInstance, instanceType = IsInInstance()
    
    -- 인스턴스 체크 (Hide/Show 로직 유지)
    if inInstance and instanceType ~= "none" then
        if difficultyFrame:IsShown() then difficultyFrame:Hide() end
        return
    else
        if not difficultyFrame:IsShown() then difficultyFrame:Show() end
    end

    local hasPermission = checkPermission()
    local currentDifficulty = {
        dungeon = GetDungeonDifficultyID(),
        raid = GetRaidDifficultyID(),
        legacy = GetLegacyRaidDifficultyID()
    }

    for category, group in pairs(buttons) do
        local targetVal = (category == forceCategory) and tonumber(forceValue) or tonumber(currentDifficulty[category])

        for _, btn in pairs(group) do   
            btn:SetEnabled(hasPermission)
            btn:SetAlpha(hasPermission and 1 or 0.5)

            local btnVal = tonumber(btn.value)
            if btnVal and targetVal and (btnVal == targetVal) then
                btn.highlightBg:SetAtlas(btn_select)
                btn.highlightBg:Show()
                btn.text:SetTextColor(unpack(SELECTED_COLOR))
                btn.isSelected = true
            else
                btn.highlightBg:SetAtlas(btn_highlight)
                btn.highlightBg:Hide()
                btn.text:SetTextColor(unpack(NORMAL_COLOR))
                btn.isSelected = false
            end
        end
    end
end

local function OnDifficultyClick(self)
    if not checkPermission() then return end

    local val = tonumber(self.value)
    if self.category == "dungeon" then
        SetDungeonDifficultyID(val)
    elseif self.category == "raid" then 
        SetRaidDifficultyID(val)
    elseif self.category == "legacy" then 
        SetLegacyRaidDifficultyID(val)
    end

    print(string.format("|cff00ff00[알림]|r %s 난이도 변경: |cffffffff[%s]|r", self.category, self.label))
    PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
    UpdateUIStatus(self.category, val)
end

local function SyncDifficultyWithDB()
    if not checkPermission() or not hodoDB then return end

    if hodoDB.useInsDifficultyDungeon and hodoDB.InsDifficultyDungeon then
        SetDungeonDifficultyID(tonumber(hodoDB.InsDifficultyDungeon))
    end
    if hodoDB.useInsDifficultyRaid and hodoDB.InsDifficultyRaid then
        SetRaidDifficultyID(tonumber(hodoDB.InsDifficultyRaid))
    end
    if hodoDB.useInsDifficultyLegacy and hodoDB.InsDifficultyLegacy then
        SetLegacyRaidDifficultyID(tonumber(hodoDB.InsDifficultyLegacy))
    end
    UpdateUIStatus()
end

------------------------------
-- 이벤트
------------------------------
local initInsDifficulty = CreateFrame("Frame")
initInsDifficulty:RegisterEvent("PLAYER_DIFFICULTY_CHANGED")
initInsDifficulty:RegisterEvent("PARTY_LEADER_CHANGED")
initInsDifficulty:RegisterEvent("GROUP_ROSTER_UPDATE")
initInsDifficulty:RegisterEvent("PLAYER_ENTERING_WORLD")
initInsDifficulty:RegisterEvent("ADDON_LOADED")

initInsDifficulty:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == "1hodo" then
        hodoDB = hodoDB or {}
        UpdateUIStatus()
    elseif event == "PLAYER_ENTERING_WORLD" or event == "PARTY_LEADER_CHANGED" then
        SyncDifficultyWithDB()
    else
        UpdateUIStatus()
    end
end)

for _, group in pairs(buttons) do
    for _, btn in pairs(group) do
        btn:SetScript("OnEnter", function(self)
            if not self.isSelected then
                self.highlightBg:SetAtlas(btn_highlight)
                self.highlightBg:Show()
                self.text:SetTextColor(unpack(SELECTED_COLOR))
            end
        end)
        btn:SetScript("OnLeave", function(self)
            if not self.isSelected then
                self.highlightBg:Hide()
                self.text:SetTextColor(unpack(NORMAL_COLOR))
            end
        end)
        btn:SetScript("OnClick", OnDifficultyClick)
    end
end

resetBtn:SetScript("OnClick", function()
    if checkPermission() then
        ResetInstances()
        print("|cff00ff00[알림]|r 모든 인스턴스가 초기화되었습니다.")
        PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
    end
end)

setDifficulty = SyncDifficultyWithDB
UpdateUIStatus()