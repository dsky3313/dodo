------------------------------
-- 테이블
------------------------------
local addonName, ns = ...

local function isIns() -- 인스확인
    local _, instanceType, difficultyID = GetInstanceInfo()
    return (difficultyID == 8 or instanceType == "raid") -- 1 일반 / 8 쐐기
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
local partyClassFrame = CreateFrame("Frame", "PartyClassFrame", UIParent, "DefaultPanelBaseTemplate")
partyClassFrame:SetSize(542, 212)
partyClassFrame:SetPoint("TOPLEFT", PVEFrame, "BOTTOMLEFT", 20, 2)
partyClassFrame:SetFrameStrata("LOW")


partyClassFrame.NineSlice.Text = partyClassFrame.NineSlice:CreateFontString(nil, "OVERLAY", "GameFontNormal")
partyClassFrame.NineSlice.Text:SetPoint("TOPRIGHT", partyClassFrame, "TOPRIGHT", -40, -5)
partyClassFrame.NineSlice.Text:SetText("파티 클래스 현황")

partyClassFrame.Background = partyClassFrame:CreateTexture(nil, "BACKGROUND")
partyClassFrame.Background:SetAtlas("UI-DialogBox-Background-Dark")
partyClassFrame.Background:SetAlpha(0.7)
partyClassFrame.Background:SetPoint("TOPLEFT", 6, -2)
partyClassFrame.Background:SetPoint("BOTTOMRIGHT", -2, 2)

partyClassFrame.ClassIcons = {}

partyClassFrame:Hide()

local function CreateIcon()
    local iconSize, iconSizeClass = 30, 30
    local xGap, maxRow = 240, 4
    local startX, startY = 25, -42

    for i, data in ipairs(UtilTable) do
        local partyUtilityIcon = CreateFrame("Frame", nil, partyClassFrame)
        partyUtilityIcon:SetSize(iconSize, iconSize)
        local col, row = math.floor((i - 1) / maxRow), (i - 1) % maxRow
        partyUtilityIcon:SetPoint("TOPLEFT", partyClassFrame, "TOPLEFT", startX + (col * xGap), startY - (row * (iconSize + 12)))

        partyUtilityIcon.icon = partyUtilityIcon:CreateTexture(nil, "ARTWORK")
        partyUtilityIcon.icon:SetTexture(data.iconID)
        partyUtilityIcon.icon:SetPoint("TOPLEFT", 2, -2)
        partyUtilityIcon.icon:SetPoint("BOTTOMRIGHT", -2, 2)

        partyUtilityIcon.border = partyUtilityIcon:CreateTexture(nil, "OVERLAY")
        partyUtilityIcon.border:SetAtlas("UI-HUD-ActionBar-IconFrame")
        partyUtilityIcon.border:SetAllPoints()

        partyUtilityIcon.nameText = partyUtilityIcon:CreateFontString(nil, "OVERLAY", "GameFontNormalMed2Outline")
        partyUtilityIcon.nameText:SetPoint("LEFT", partyUtilityIcon, "RIGHT", 5, 0)
        partyUtilityIcon.nameText:SetText(data.name)
        partyUtilityIcon.nameText:SetTextColor(1, 0.82, 0)

        local count = 0
        for _, classInfo in ipairs(ClassTable) do
            local isMatch = (data.type == "dispell" and classInfo.dispell[data.key]) or (data.type ~= "dispell" and classInfo[data.key])
            if isMatch then
                local partyClassIcon = CreateFrame("Frame", nil, partyUtilityIcon)
                partyClassIcon:SetSize(iconSizeClass, iconSizeClass)
                partyClassIcon:SetPoint("LEFT", partyUtilityIcon, "RIGHT", 60 + (count * (iconSizeClass + 5)), 0)
                partyClassIcon.classID = classInfo.id
                count = count + 1

                partyClassIcon.icon = partyClassIcon:CreateTexture(nil, "ARTWORK")
                partyClassIcon.icon:SetTexture(classInfo.iconID)
                partyClassIcon.icon:SetPoint("TOPLEFT", 2, -2)
                partyClassIcon.icon:SetPoint("BOTTOMRIGHT", -2, 2)

                partyClassIcon.border = partyClassIcon:CreateTexture(nil, "OVERLAY")
                partyClassIcon.border:SetAtlas("UI-HUD-ActionBar-IconFrame")
                partyClassIcon.border:SetAllPoints()

                partyClassIcon.text = partyClassIcon:CreateFontString(nil, "OVERLAY", "SystemFont_Outline_Small")
                partyClassIcon.text:SetPoint("TOP", partyClassIcon, "BOTTOM", 0, 5)
                partyClassIcon.text:SetText(classInfo.name)

                table.insert(partyClassFrame.ClassIcons, partyClassIcon)
            end
        end
    end
end

------------------------------
-- 동작
------------------------------
function PartyClass()
    if isIns() then
        partyClassFrame:Hide()
        return
    end

    local isEnabled = hodoDB.usePartyClass ~= false -- 기본값 true
    local usePartyClass = not (hodoDB and hodoDB.usePartyClass == false)
    local pveShown = PVEFrame and PVEFrame:IsShown()

    if not (isEnabled and usePartyClass and pveShown) then
        partyClassFrame:Hide()
        return
    end

    partyClassFrame:Show()

    local activeIDs = {} -- 파티 데이터 수집
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

    for _, b in ipairs(partyClassFrame.ClassIcons) do -- 아이콘 색상 업데이트
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
local initPartyClass = CreateFrame("Frame")
initPartyClass:RegisterEvent("ADDON_LOADED")
initPartyClass:RegisterEvent("PLAYER_ENTERING_WORLD")

initPartyClass:SetScript("OnEvent", function(self, event, arg1)
    if event == "PLAYER_ENTERING_WORLD" then
        C_Timer.After(0.5, function()
            if isIns() then
                self:UnregisterEvent("GROUP_ROSTER_UPDATE")
                partyClassFrame:Hide()
            else
                self:RegisterEvent("GROUP_ROSTER_UPDATE")
                if #partyClassFrame.ClassIcons == 0 then CreateIcon() end
                PartyClass()
            end
        end)
    elseif event == "ADDON_LOADED" and arg1 == addonName then
        if PVEFrame then
            PVEFrame:HookScript("OnShow", PartyClass)
            PVEFrame:HookScript("OnHide", PartyClass)
        end
        if #partyClassFrame.ClassIcons == 0 then CreateIcon() end
    else
        if not isIns() then
            PartyClass()
        end
    end
end)

ns.PartyClass = PartyClass