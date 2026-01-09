------------------------------------------------------------
-- 1. 데이터 및 설정 테이블
------------------------------------------------------------
local difficultyTable = {
    dungeon = {{label="일반", value="1"}, {label="영웅", value="2"}, {label="신화", value="23"}},
    raid = {{label="일반", value="14"}, {label="영웅", value="15"}, {label="신화", value="16"}},
    legacy = {{label="10인", value="3"}, {label="25인", value="4"}},
}

local buttons = { dungeon = {}, raid = {}, legacy = {} }
-- 자동 설정 및 초기화에 사용될 기본 인덱스 (신화, 신화, 25인)
local defaultDifficulty = { dungeon = 3, raid = 3, legacy = 2 }

------------------------------------------------------------
-- 2. UI 생성 (디스플레이)
------------------------------------------------------------
local difficultyFrame = CreateFrame("Frame", "DifficultySelector", UIParent, "DefaultPanelBaseTemplate")
difficultyFrame:SetSize(230, 124)
difficultyFrame:SetPoint("TOPLEFT", 5, -5)
difficultyFrame:EnableMouse(true)

-- 배경 레이어
difficultyFrame.bg = CreateFrame("Frame", nil, difficultyFrame, "FlatPanelBackgroundTemplate")
difficultyFrame.bg:SetFrameLevel(difficultyFrame:GetFrameLevel() - 1)
difficultyFrame.bg:SetPoint("TOPLEFT", 7, -18)
difficultyFrame.bg:SetPoint("BOTTOMRIGHT", -3, 3)

-- 제목
difficultyFrame.NineSlice.Text = difficultyFrame.NineSlice:CreateFontString(nil, "OVERLAY", "GameFontNormal")
difficultyFrame.NineSlice.Text:SetPoint("TOP", 0, -5)
difficultyFrame.NineSlice.Text:SetText("인스턴스 난이도 설정")

-- 행
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

-- 난이도
local function CreateDifficultyButton(parentRow, category, index, data)
    local label = data.label
    local xOffsets = { ["일반"] = 5, ["영웅"] = 42, ["신화"] = 90, ["10인"] = 20, ["25인"] = 80 }
    local btn = CreateFrame("Button", nil, parentRow)
    btn:SetSize(45, 25)
    btn:SetPoint("LEFT", parentRow, "LEFT", 70 + (xOffsets[label] or 0), 0)
    btn:EnableMouse(true)
    btn:RegisterForClicks("LeftButtonUp")
    btn:SetFrameLevel(parentRow:GetFrameLevel() + 10)

    btn.highlightBg = btn:CreateTexture(nil, "BACKGROUND")
    btn.highlightBg:SetAllPoints()
    btn.highlightBg:Hide()

    btn.text = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    btn.text:SetPoint("CENTER")
    btn.text:SetText(label)

    btn.category = category
    btn.index = index
    btn.value = data.value
    btn.label = label

    buttons[category][index] = btn
    return btn
end

-- UI 객체 실제 생성
local row1 = CreateCategoryRow(difficultyFrame, -25, "던전")
for i, data in ipairs(difficultyTable.dungeon) do CreateDifficultyButton(row1, "dungeon", i, data) end

local row2 = CreateCategoryRow(difficultyFrame, -55, "공격대")
for i, data in ipairs(difficultyTable.raid) do CreateDifficultyButton(row2, "raid", i, data) end

local row3 = CreateCategoryRow(difficultyFrame, -85, "낭만")
for i, data in ipairs(difficultyTable.legacy) do CreateDifficultyButton(row3, "legacy", i, data) end

-- 리셋 버튼
local resetBtn = CreateFrame("Button", nil, difficultyFrame.NineSlice, "SquareIconButtonTemplate")
resetBtn:SetSize(30, 30)
resetBtn:SetPoint("TOPRIGHT", difficultyFrame, "TOPRIGHT", 4, 4)
resetBtn.Icon:SetAtlas("UI-RefreshButton")
resetBtn:SetFrameLevel(difficultyFrame.NineSlice:GetFrameLevel() + 10)

------------------------------------------------------------
-- 3. 기능 함수 (로직)
------------------------------------------------------------

-- 파장확인
local function checkPermission()
    return (not IsInGroup() and not IsInRaid()) or UnitIsGroupLeader("player")
end

-- [UI 상태 업데이트] 아틀라스 이동 및 버튼 활성화 제어
local function UpdateUIStatus(forceCategory, forceValue)
    local hasPermission = checkPermission()
    local currentDiffs = {
        dungeon = GetDungeonDifficultyID(),
        raid = GetRaidDifficultyID(),
        legacy = GetLegacyRaidDifficultyID()
    }

    -- 리셋 버튼 시각화
    resetBtn:SetAlpha(hasPermission and 1 or 0.4)
    resetBtn:EnableMouse(hasPermission)
    resetBtn.Icon:SetDesaturated(not hasPermission)

    -- 카테고리별 버튼 순회
    for category, group in pairs(buttons) do
        for index, btn in pairs(group) do
            -- 권한에 따른 클릭 허용 여부
            btn:SetEnabled(hasPermission)
            btn:SetAlpha(hasPermission and 1 or 0.5)

            -- 현재 설정된 난이도 판단 (강제 값 우선 반영으로 딜레이 제거)
            local currentVal = (category == forceCategory and forceValue) and forceValue or currentDiffs[category]
            
            if tonumber(btn.value) == tonumber(currentVal) then
                btn.highlightBg:SetAtlas("UI-Frame-DastardlyDuos-Bar-Frame-gold")
                btn.highlightBg:Show()
                btn.text:SetTextColor(1, 1, 1) -- 선택된 상태는 흰색
                btn.isSelected = true
            else
                btn.highlightBg:SetAtlas("glues-characterSelect-nameBG")
                btn.highlightBg:Hide()
                btn.text:SetTextColor(1, 0.82, 0) -- 기본 금색 계열
                btn.isSelected = false
            end
        end
    end
end

-- [동작] 버튼 클릭 시 난이도 변경
local function OnDifficultyClick(self)
    if not checkPermission() then return end

    if self.category == "dungeon" then SetDungeonDifficultyID(tonumber(self.value))
    elseif self.category == "raid" then SetRaidDifficultyID(tonumber(self.value))
    elseif self.category == "legacy" then SetLegacyRaidDifficultyID(tonumber(self.value)) end
    
    print(string.format("|cff00ff00[알림]|r %s 난이도 변경: |cffffffff[%s]|r", self.category, self.label))
    PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
    
    -- 즉시 아틀라스 이동
    UpdateUIStatus(self.category, self.value)
end

-- [동작] 초기화 및 자동 설정
local function SetToDefault()
    if not checkPermission() then return end
    SetDungeonDifficultyID(tonumber(difficultyTable.dungeon[defaultDifficulty.dungeon].value))
    SetRaidDifficultyID(tonumber(difficultyTable.raid[defaultDifficulty.raid].value))
    SetLegacyRaidDifficultyID(tonumber(difficultyTable.legacy[defaultDifficulty.legacy].value))
    UpdateUIStatus()
end

------------------------------------------------------------
-- 4. 이벤트 연결 (스크립트 할당)
------------------------------------------------------------

-- 난이도 버튼 이벤트 연결
for category, group in pairs(buttons) do
    for index, btn in pairs(group) do
        btn:SetScript("OnEnter", function(self)
            if not self.isSelected then
                self.highlightBg:SetAtlas("glues-characterSelect-nameBG")
                self.highlightBg:Show()
                self.text:SetTextColor(1, 1, 1)
            end
        end)
        btn:SetScript("OnLeave", function(self)
            if not self.isSelected then
                self.highlightBg:Hide()
                self.text:SetTextColor(1, 0.82, 0)
            end
        end)
        btn:SetScript("OnClick", OnDifficultyClick)
    end
end

-- 리셋 버튼 이벤트 연결
resetBtn:SetScript("OnClick", function()
    if checkPermission() then
        ResetInstances()
        print("|cff00ff00[알림]|r 모든 인스턴스가 초기화되었습니다.")
        PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
    end
end)

-- 시스템 이벤트 프레임
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_DIFFICULTY_CHANGED")
eventFrame:RegisterEvent("PARTY_LEADER_CHANGED")
eventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")

eventFrame:SetScript("OnEvent", function(self, event)
    if event == "PARTY_LEADER_CHANGED" then
        SetToDefault() -- 파티장이 되면 기본값으로 자동 세팅
    else
        UpdateUIStatus() -- 그 외 상태 변화 시 UI만 갱신
    end
end)

-- 실행 시 초기 업데이트
difficultyFrame:SetScript("OnShow", function() UpdateUIStatus() end)
UpdateUIStatus()