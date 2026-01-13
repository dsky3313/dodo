------------------------------
-- 테이블
------------------------------
local addonName, ns = ...

local function isIns() -- 인스확인
    local _, instanceType, difficultyID = GetInstanceInfo()
    return (difficultyID == 1 or instanceType == "raid") -- 1 일반 / 8 쐐기
end

local ClassTable = {
    { id = 6, name = "죽기", iconID = 625998, dispell = { curse = false, disease = false, magic = false, poison = false }, bl = false, br = true, buff = false },
    { id = 11, name = "드루", iconID = 625999, dispell = { curse = true, disease = false, magic = false, poison = true }, bl = false, br = true, buff = false },
    { id = 3, name = "사냥꾼", iconID = 626000, dispell = { curse = false, disease = false, magic = false, poison = false }, bl = true, br = false, buff = false },
    { id = 8, name = "마법사", iconID = 626001, dispell = { curse = true, disease = false, magic = false, poison = false }, bl = true, br = false, buff = false },
    { id = 10, name = "수도사", iconID = 626002, dispell = { curse = false, disease = true, magic = false, poison = true }, bl = false, br = false, buff = true },
    { id = 2, name = "성기사", iconID = 626003, dispell = { curse = false, disease = true, magic = true, poison = true }, bl = false, br = true, buff = false },
    { id = 5, name = "사제", iconID = 626004, dispell = { curse = false, disease = true, magic = true, poison = false }, bl = false, br = false, buff = true },
    { id = 4, name = "도적", iconID = 626005, dispell = { curse = false, disease = false, magic = false, poison = false }, bl = false, br = false, buff = true },
    { id = 7, name = "주술사", iconID = 626006, dispell = { curse = true, disease = false, magic = false, poison = false }, bl = true, br = false, buff = false },
    { id = 9, name = "흑마", iconID = 626007, dispell = { curse = false, disease = false, magic = true, poison = false }, bl = false, br = true, buff = false },
    { id = 1, name = "전사", iconID = 626008, dispell = { curse = false, disease = false, magic = false, poison = false }, bl = false, br = false, buff = true },
    { id = 12, name = "악사", iconID = 1260827, dispell = { curse = false, disease = false, magic = false, poison = false }, bl = false, br = false, buff = true },
    { id = 13, name = "기원사", iconID = 4574311, dispell = { curse = false, disease = false, magic = false, poison = true }, bl = true, br = false, buff = false },
}

local UtilTable = {
    { iconID = 132108, name = "독해제", key = "poison", type = "dispell" },
    { iconID = 136066, name = "마법해제", key = "magic", type = "dispell" },
    { iconID = 136140, name = "저주해제", key = "curse", type = "dispell" },
    { iconID = 132100, name = "질병해제", key = "disease", type = "dispell" },
    { iconID = 136012, name = "블러드", key = "bl", type = "util" },
    { iconID = 136080, name = "전부", key = "br", type = "util" },
    { iconID = 136243, name = "시너지", key = "buff", type = "util" }
}

------------------------------
-- 디스플레이
------------------------------
local initPartyClass = _G["PartyClassFrame"]
initPartyClass.ClassIcons = {}

local function CreateIcon()
    local ICON_SIZE, CLASS_ICON_SIZE = 30, 30
    local X_GAP, Y_GAP, MAX_ROWS = 240, 2, 4
    local START_X, START_Y = 25, -42

    for i, data in ipairs(UtilTable) do
        local PartyUtilIcon = CreateFrame("Frame", nil, initPartyClass)
        PartyUtilIcon:SetSize(ICON_SIZE, ICON_SIZE)
        local col, row = math.floor((i - 1) / MAX_ROWS), (i - 1) % MAX_ROWS
        PartyUtilIcon:SetPoint("TOPLEFT", initPartyClass, "TOPLEFT", START_X + (col * X_GAP), START_Y - (row * (ICON_SIZE + Y_GAP + 10)))

        -- 유틸아이콘
        PartyUtilIcon.icon = PartyUtilIcon:CreateTexture(nil, "ARTWORK")
        PartyUtilIcon.icon:SetTexture(data.iconID)
        PartyUtilIcon.icon:SetPoint("TOPLEFT", 2, -2)
        PartyUtilIcon.icon:SetPoint("BOTTOMRIGHT", -2, 2)

        PartyUtilIcon.border = PartyUtilIcon:CreateTexture(nil, "OVERLAY")
        PartyUtilIcon.border:SetAtlas("UI-HUD-ActionBar-IconFrame")
        PartyUtilIcon.border:SetAllPoints()

        PartyUtilIcon.text = PartyUtilIcon:CreateFontString(nil, "OVERLAY", "GameFontNormalMed2Outline")
        PartyUtilIcon.text:SetPoint("LEFT", PartyUtilIcon, "RIGHT", 5, 0)
        PartyUtilIcon.text:SetText(data.name)
        PartyUtilIcon.text:SetTextColor(1, 1, 1)
        PartyUtilIcon.text:SetTextColor(1, 0.82, 0)

        local count = 0
        for _, classInfo in ipairs(ClassTable) do
            local isMatch = (data.type == "dispell" and classInfo.dispell[data.key]) or (data.type ~= "dispell" and classInfo[classInfo.id] or classInfo[data.key])
            isMatch = (data.type == "dispell" and classInfo.dispell[data.key]) or (data.type ~= "dispell" and classInfo[data.key])
            if isMatch then -- 클래스 아이콘
                local ClassIcon = CreateFrame("Frame", nil, PartyUtilIcon)
                ClassIcon:SetSize(CLASS_ICON_SIZE, CLASS_ICON_SIZE)
                ClassIcon:SetPoint("LEFT", PartyUtilIcon, "RIGHT", 60 + (count * (CLASS_ICON_SIZE + 5)), 0)
                ClassIcon.classID = classInfo.id
                count = count + 1

                ClassIcon.icon = ClassIcon:CreateTexture(nil, "ARTWORK")
                ClassIcon.icon:SetTexture(classInfo.iconID)
                ClassIcon.icon:SetPoint("TOPLEFT", 2, -2)
                ClassIcon.icon:SetPoint("BOTTOMRIGHT", -2, 2)

                ClassIcon.border = ClassIcon:CreateTexture(nil, "OVERLAY")
                ClassIcon.border:SetAtlas("UI-HUD-ActionBar-IconFrame")
                ClassIcon.border:SetAllPoints()

                ClassIcon.text = ClassIcon:CreateFontString(nil, "OVERLAY", "SystemFont_Outline_Small")
                ClassIcon.text:SetPoint("TOP", ClassIcon, "BOTTOM", 0, 5)
                ClassIcon.text:SetText(classInfo.name)

                table.insert(initPartyClass.ClassIcons, ClassIcon)
            end
        end
    end
end

------------------------------
-- 동작
------------------------------
function PartyClass()
    if isIns() then
        initPartyClass:Hide()
        return
    end
    local isEnabled = true
    if hodoDB and hodoDB.useMyKey == false then isEnabled = false end

    local shouldShow = true
    if not isEnabled then shouldShow = false end
    if not hodoDB or hodoDB.usePartyClass == false then shouldShow = false end
    if not (PVEFrame and PVEFrame:IsShown()) then shouldShow = false end

    if isIns() then shouldShow = false end

    if not shouldShow then
        initPartyClass:Hide()
        return
    end

    initPartyClass:Show()

    local activeIDs = {}
    local _, _, pID = UnitClass("player")
    if pID then activeIDs[pID] = true end

    local numMembers = GetNumGroupMembers()
    if numMembers > 0 then
        for i=1, numMembers do
            local unit = IsInRaid() and "raid"..i or "party"..i
            local _, _, cID = UnitClass(unit)
            if cID then activeIDs[cID] = true end
        end
    end

    for _, b in ipairs(initPartyClass.ClassIcons) do
        if activeIDs[b.classID] then
            b.icon:SetDesaturated(false)
            b.icon:SetAlpha(1)
            b.text:SetTextColor(1, 1, 1)
            b.border:SetVertexColor(1, 1, 1, 1)
        else
            b.icon:SetDesaturated(true)
            b.icon:SetAlpha(0.3)
            b.text:SetTextColor(0.5, 0.5, 0.5)
            b.border:SetVertexColor(0.5, 0.5, 0.5, 0.5)
        end
    end
end
------------------------------
-- 이벤트
------------------------------
initPartyClass:RegisterEvent("PLAYER_ENTERING_WORLD")
initPartyClass:RegisterEvent("GROUP_ROSTER_UPDATE")

initPartyClass:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_ENTERING_WORLD" then
        C_Timer.After(0.5, function()
            if isIns() then
                initPartyClass:UnregisterEvent("GROUP_ROSTER_UPDATE")
            else
                initPartyClass:RegisterEvent("GROUP_ROSTER_UPDATE")
            end

            if #initPartyClass.ClassIcons == 0 then
                CreateIcon()
            end
            PartyClass()
        end)
    else
        PartyClass()
    end
end)

if PVEFrame then
    PVEFrame:HookScript("OnShow", PartyClass)
    PVEFrame:HookScript("OnHide", PartyClass)
end

if #initPartyClass.ClassIcons == 0 then CreateIcon() end
PartyClass()