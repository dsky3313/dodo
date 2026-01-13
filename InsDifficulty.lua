local addonName, ns = ...

------------------------------
-- 1. 테이블 및 데이터
------------------------------
-- 인스턴스 확인 (통합 로직)
local function isIns()
    local _, instanceType, difficultyID = GetInstanceInfo()
    -- 1: 일반 던전, raid: 공격대, none: 필드 제외 나머지는 특수 인스턴스(수정 불가)로 취급
    return not (difficultyID == 1 or instanceType == "raid" or instanceType == "none")
end

local difficultyTable = {
    dungeon = {{label="일반", value="1"}, {label="영웅", value="2"}, {label="신화", value="23"}},
    raid = {{label="일반", value="14"}, {label="영웅", value="15"}, {label="신화", value="16"}},
    legacy = {{label="10인", value="3"}, {label="25인", value="4"}},
}

local NORMAL_COLOR, SELECTED_COLOR = {1, 0.82, 0}, {1, 1, 1}
local btn_select, btn_highlight = "UI-Frame-DastardlyDuos-Bar-Frame-gold", "glues-characterSelect-nameBG"
local buttons = { dungeon = {}, raid = {}, legacy = {} }

local frame = DifficultyFrame
local resetBtn = frame.resetBtn

------------------------------
-- 2. 디스플레이 (프레임 생성)
------------------------------
local OnDifficultyClick 

local function CreateDifficultyButton(parentRow, category, index, data)
    local xOffsets = { ["일반"] = 0, ["영웅"] = 45, ["신화"] = 90, ["10인"] = 20, ["25인"] = 80 }
    local btn = CreateFrame("Button", nil, parentRow)
    btn:SetSize(45, 30)
    btn:SetPoint("LEFT", parentRow, "LEFT", 70 + (xOffsets[data.label] or 0), 0)
    
    -- 버튼이 행(Row) 배경보다 위에 오도록 설정
    btn:SetFrameLevel(parentRow:GetFrameLevel() + 5)

    btn.highlightBg = btn:CreateTexture(nil, "BACKGROUND")
    btn.highlightBg:SetSize(45, 25); btn.highlightBg:SetPoint("CENTER"); btn.highlightBg:Hide()

    btn.text = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    btn.text:SetPoint("CENTER"); btn.text:SetText(data.label)

    btn.category, btn.value, btn.label = category, data.value, data.label
    buttons[category][index] = btn

    btn:SetScript("OnClick", function(self) OnDifficultyClick(self) end)
    btn:SetScript("OnEnter", function(s) 
        if not s.isSelected then s.highlightBg:SetAtlas(btn_highlight) s.highlightBg:Show() s.text:SetTextColor(unpack(SELECTED_COLOR)) end 
    end)
    btn:SetScript("OnLeave", function(s) 
        if not s.isSelected then s.highlightBg:Hide() s.text:SetTextColor(unpack(NORMAL_COLOR)) end 
    end)
    return btn
end

-- 행(Row) 생성 및 계층 지정
local rows = {
    dungeon = CreateFrame("Frame", nil, frame, "DifficultyRowTemplate"),
    raid = CreateFrame("Frame", nil, frame, "DifficultyRowTemplate"),
    legacy = CreateFrame("Frame", nil, frame, "DifficultyRowTemplate")
}

-- 행이 메인 프레임 배경(bg)보다 위로 오도록 설정
local rowLevel = frame:GetFrameLevel() + 10
for _, row in pairs(rows) do row:SetFrameLevel(rowLevel) end

rows.dungeon:SetPoint("TOP", frame, "TOP", 0, -25); rows.dungeon.title:SetText("던전")
rows.raid:SetPoint("TOP", frame, "TOP", 0, -55); rows.raid.title:SetText("공격대")
rows.legacy:SetPoint("TOP", frame, "TOP", 0, -85); rows.legacy.title:SetText("낭만")

-- 버튼 생성
for cat, dataList in pairs(difficultyTable) do
    for i, data in ipairs(dataList) do CreateDifficultyButton(rows[cat], cat, i, data) end
end

------------------------------
-- 3. 동작 (기능 로직)
------------------------------
local function checkPermission()
    if isIns() then return false end
    return (not IsInGroup() and not IsInRaid()) or UnitIsGroupLeader("player")
end

local function UpdateUIStatus(forceCategory, forceValue)
    -- 인스턴스 안이면 UI 숨김 처리
    if isIns() then 
        if frame:IsShown() then frame:Hide() end 
        return 
    else 
        if not frame:IsShown() then frame:Show() end 
    end

    local hasPermission = checkPermission()
    local currentDiff = {
        dungeon = GetDungeonDifficultyID(),
        raid = GetRaidDifficultyID(),
        legacy = GetLegacyRaidDifficultyID()
    }

    for cat, group in pairs(buttons) do
        local targetVal = (cat == forceCategory) and tonumber(forceValue) or tonumber(currentDiff[cat])
        for _, btn in pairs(group) do
            btn:SetEnabled(hasPermission)
            btn:SetAlpha(hasPermission and 1 or 0.5)

            local isSelected = tonumber(btn.value) == targetVal
            btn.highlightBg:SetAtlas(isSelected and btn_select or btn_highlight)
            btn.highlightBg:SetShown(isSelected)
            btn.text:SetTextColor(unpack(isSelected and SELECTED_COLOR or NORMAL_COLOR))
            btn.isSelected = isSelected
        end
    end
end

OnDifficultyClick = function(self)
    if not checkPermission() then return end
    local val = tonumber(self.value)
    if self.category == "dungeon" then SetDungeonDifficultyID(val)
    elseif self.category == "raid" then SetRaidDifficultyID(val)
    elseif self.category == "legacy" then SetLegacyRaidDifficultyID(val) end
    
    PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
    UpdateUIStatus(self.category, val)
end

resetBtn:SetScript("OnClick", function()
    if checkPermission() then
        ResetInstances()
        print("|cff00ff00[알림]|r 모든 인스턴스가 초기화되었습니다.")
    end
end)

------------------------------
-- 4. 이벤트 및 초기화
------------------------------
local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_ENTERING_WORLD")
ev:RegisterEvent("ADDON_LOADED")

ev:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == addonName then
        UpdateUIStatus()
    else
        UpdateUIStatus()
    end
end)

-- 실행 시점 즉시 업데이트
UpdateUIStatus()
ns.UpdateDifficultyUI = UpdateUIStatus