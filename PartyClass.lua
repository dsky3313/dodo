------------------------------
-- 테이블
------------------------------
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
-- PartyClss UI
------------------------------
local initPartyClass = CreateFrame("Frame", "MyPartyStatusBG", UIParent, "BackdropTemplate")
initPartyClass:SetSize(542, 212) 
initPartyClass:SetPoint("TOPLEFT", PVEFrame, "BOTTOMLEFT", 20, 2)
initPartyClass:SetFrameStrata("LOW")
NineSliceUtil.ApplyLayoutByName(initPartyClass, "ButtonFrameTemplateNoPortrait")

initPartyClass.TitleText = initPartyClass:CreateFontString(nil, "OVERLAY", "GameFontNormal")
initPartyClass.TitleText:SetPoint("TOPRIGHT", initPartyClass, "TOPRIGHT", -40, -5)
initPartyClass.TitleText:SetText("파티 유틸리티 현황")
initPartyClass.TitleText:SetTextColor(1, 0.82, 0)

initPartyClass.Background = initPartyClass:CreateTexture(nil, "BACKGROUND")
initPartyClass.Background:SetPoint("TOPLEFT", 6, -2); initPartyClass.Background:SetPoint("BOTTOMRIGHT", -2, 2)
initPartyClass.Background:SetAtlas("UI-DialogBox-Background-Dark")
initPartyClass.Background:SetAlpha(0.7)

initPartyClass.ClassIcons = {}
local ICON_SIZE, CLASS_ICON_SIZE = 30, 30
local X_GAP, Y_GAP, MAX_ROWS = 240, 2, 4
local START_X, START_Y = 25, -42

for i, data in ipairs(UtilTable) do
    local PartyUtilIcon = CreateFrame("Frame", nil, initPartyClass)
    PartyUtilIcon:SetSize(ICON_SIZE, ICON_SIZE)
    local col, row = math.floor((i - 1) / MAX_ROWS), (i - 1) % MAX_ROWS
    PartyUtilIcon:SetPoint("TOPLEFT", initPartyClass, "TOPLEFT", START_X + (col * X_GAP), START_Y - (row * (ICON_SIZE + Y_GAP + 10)))

    -- [UTIL 아이콘] 중복 생성 제거 및 위치 조정
    PartyUtilIcon.icon = PartyUtilIcon:CreateTexture(nil, "ARTWORK")
    PartyUtilIcon.icon:SetTexture(data.iconID)
    PartyUtilIcon.icon:SetPoint("TOPLEFT", 2, -2)
    PartyUtilIcon.icon:SetPoint("BOTTOMRIGHT", -2, 2)

    -- [UTIL 테두리] Class와 동일하게 수정
    PartyUtilIcon.border = PartyUtilIcon:CreateTexture(nil, "OVERLAY")
    PartyUtilIcon.border:SetAtlas("UI-HUD-ActionBar-IconFrame")
    PartyUtilIcon.border:SetAllPoints()

    -- [UTIL 이름]
    PartyUtilIcon.text = PartyUtilIcon:CreateFontString(nil, "OVERLAY", "GameFontNormalMed2Outline")
    PartyUtilIcon.text:SetPoint("LEFT", PartyUtilIcon, "RIGHT", 5, 0)
    PartyUtilIcon.text:SetText(data.name)
    PartyUtilIcon.text:SetTextColor(1, 1, 1)
    PartyUtilIcon.text:SetTextColor(1, 0.82, 0)

    local count = 0
    for _, classInfo in ipairs(ClassTable) do
        local isMatch = (data.type == "dispell" and classInfo.dispell[data.key]) or (data.type ~= "dispell" and classInfo[data.key])
        if isMatch then
            local ClassIcon = CreateFrame("Frame", nil, PartyUtilIcon)
            ClassIcon:SetSize(CLASS_ICON_SIZE, CLASS_ICON_SIZE)
            -- 이름 텍스트(nameText) 자리를 비워주기 위해 간격 60 적용
            ClassIcon:SetPoint("LEFT", PartyUtilIcon, "RIGHT", 60 + (count * (CLASS_ICON_SIZE + 5)), 0)
            ClassIcon.classID = classInfo.id
            count = count + 1

            -- [CLASS 아이콘] 하나만 생성하여 b.icon으로 참조 가능하게 함
            ClassIcon.icon = ClassIcon:CreateTexture(nil, "ARTWORK")
            ClassIcon.icon:SetTexture(classInfo.iconID)
            ClassIcon.icon:SetPoint("TOPLEFT", 2, -2)
            ClassIcon.icon:SetPoint("BOTTOMRIGHT", -2, 2)

            -- [CLASS 테두리]
            ClassIcon.border = ClassIcon:CreateTexture(nil, "OVERLAY")
            ClassIcon.border:SetAtlas("UI-HUD-ActionBar-IconFrame")
            ClassIcon.border:SetAllPoints()

            -- [CLASS 이름 텍스트]
            ClassIcon.text = ClassIcon:CreateFontString(nil, "OVERLAY", "SystemFont_Outline_Small")
            ClassIcon.text:SetPoint("TOP", ClassIcon, "BOTTOM", 0, 5)
            ClassIcon.text:SetText(classInfo.name)

            table.insert(initPartyClass.ClassIcons, ClassIcon)
        end
    end
end

------------------------------
-- PartyClass Func
------------------------------
function UpdateStatus()
    if InCombatLockdown() then return end

    local shouldShow = true
    if not hodoDB or hodoDB.usePartyClass == false then shouldShow = false end
    if not (PVEFrame and PVEFrame:IsShown()) then shouldShow = false end

    local inInstance, inGroup = IsInInstance(), IsInGroup()
    if inInstance or (not inGroup) then shouldShow = false end

    if not shouldShow then
        initPartyClass:Hide()
        return
    end

    initPartyClass:ClearAllPoints()
    initPartyClass:SetPoint("TOPLEFT", PVEFrame, "BOTTOMLEFT", 20, 2)
    initPartyClass:Show()

    -- 현재 파티원 클래스 ID 수집
    local activeIDs = {}
    local _, _, pID = UnitClass("player"); activeIDs[pID] = true
    for i=1, GetNumGroupMembers() do
        local unit = IsInRaid() and "raid"..i or "party"..i
        local _, _, cID = UnitClass(unit); if cID then activeIDs[cID] = true end
    end

    -- 아이콘 상태 업데이트 (흑백/컬러)
    for _, b in ipairs(initPartyClass.ClassIcons) do
        if activeIDs[b.classID] then
            b.icon:SetDesaturated(false) -- 컬러 유지
            b.icon:SetAlpha(1)
            b.text:SetTextColor(1, 1, 1) -- 이름 흰색
            b.border:SetVertexColor(1, 1, 1, 1) -- 테두리 밝게
        else
            b.icon:SetDesaturated(true) -- 흑백 처리
            b.icon:SetAlpha(0.3) -- 더 어둡게
            b.text:SetTextColor(0.5, 0.5, 0.5) -- 이름 회색
            b.border:SetVertexColor(0.5, 0.5, 0.5, 0.5) -- 테두리도 어둡게
        end
    end
end
------------------------------
-- 이벤트
------------------------------
initPartyClass:RegisterEvent("GROUP_ROSTER_UPDATE")
initPartyClass:RegisterEvent("PLAYER_ENTERING_WORLD")
initPartyClass:RegisterEvent("PLAYER_REGEN_ENABLED")
initPartyClass:RegisterEvent("PLAYER_REGEN_DISABLED")
initPartyClass:SetScript("OnEvent", function(self, event)
    UpdateStatus()
end)

if PVEFrame then
    PVEFrame:HookScript("OnShow", UpdateStatus)
    PVEFrame:HookScript("OnHide", UpdateStatus)
end
UpdateStatus()