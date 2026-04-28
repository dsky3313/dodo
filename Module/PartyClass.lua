-- ==============================
-- Inspired
-- ==============================
-- 

-- ==============================
-- 설정 및 테이블
-- ==============================
---@diagnostic disable: lowercase-global, undefined-field, undefined-global
local addonName, dodo = ...
dodoDB = dodoDB or {}
local IconLib = dodo.IconLib

local ClassTable = {
    -- { id = 6, name = "죽기", iconID = 625998, dispell = { curse = false, disease = false, magic = false, poison = false }, bl = false, br = true, buff = false },
    { id = 1, name = "전사", iconID = 626008, dispell = {}, buff = 6673 },
    { id = 2, name = "성기사", iconID = 626003, dispell = { disease = 213644, poison = 213644 }, br = 391054 },
    { id = 3, name = "사냥꾼", iconID = 626000, dispell = { poison = 459517 }, bl = 272678 },
    { id = 4, name = "도적", iconID = 626005, dispell = {}, buff = 381637 },
    { id = 5, name = "사제", iconID = 626004, dispell = { disease = 213634, magic = 32375 }, buff = 21562 },
    { id = 6, name = "죽기", iconID = 625998, dispell = {}, br = 61999 },
    { id = 7, name = "주술사", iconID = 626006, dispell = { curse = 77130, poison = 383013 }, bl = 32182 },
    { id = 8, name = "마법사", iconID = 626001, dispell = { curse = 475 }, bl = 80353 },
    { id = 9, name = "흑마", iconID = 626007, dispell = { magic = 119905 }, br = 20707 },
    { id = 10, name = "수도사", iconID = 626002, dispell = { disease = 218164, poison = 218164 }, buff = 113746 },
    { id = 11, name = "드루", iconID = 625999, dispell = { curse = 2782, poison = 2782 }, br = 20484 },
    { id = 12, name = "악사", iconID = 1260827, dispell = {}, buff = 255260 },
    { id = 13, name = "기원사", iconID = 4574311, dispell = { poison = 365585 }, bl = 390386 },
}

local UtilTable = {
    { iconID = 132108, name = "독해제", key = "poison", type = "dispell" },
    { iconID = 136066, name = "마법해제", key = "magic", type = "dispell" },
    { iconID = 136140, name = "저주해제", key = "curse", type = "dispell" },
    { iconID = 132100, name = "질병해제", key = "disease", type = "dispell" },
    { iconID = 136012, name = "블러드", key = "bl", type = "util" },
    { iconID = 136080, name = "전부", key = "br", type = "util" },
    { iconID = 136243, name = "시너지", key = "buff", type = "util" },
}

-- ==============================
-- 캐싱
-- ==============================
-- 함수
local CreateFrame = CreateFrame
local GetInstanceInfo = GetInstanceInfo
local GetNumGroupMembers = GetNumGroupMembers
local IsInRaid = IsInRaid
local UnitClass = UnitClass
local ipairs = ipairs
local wipe = wipe

-- 변수
local C_Timer = C_Timer
local PVEFrame = PVEFrame
local UIParent = UIParent

local function isIns()                                   -- 인스확인
    local _, instanceType, difficultyID = GetInstanceInfo()
    return (difficultyID == 8 or instanceType == "raid") -- 1 일반 / 8 쐐기 / raid 레이드
end

local activeIDs = {}
local iconsCreated = false

-- ==============================
-- 디스플레이 (프레임)
-- ==============================
local partyClassFrame = CreateFrame("Frame", "PartyClassFrame", UIParent, "DefaultPanelBaseTemplate")
partyClassFrame:SetSize(542, 214)
partyClassFrame:SetPoint("TOPLEFT", PVEFrame, "BOTTOMLEFT", 20, 2)
partyClassFrame:SetFrameStrata("MEDIUM")
partyClassFrame:Hide()

partyClassFrame.NineSlice.Text = partyClassFrame.NineSlice:CreateFontString(nil, "OVERLAY", "GameFontNormal")
partyClassFrame.NineSlice.Text:SetPoint("TOPRIGHT", partyClassFrame, "TOPRIGHT", -80, -5)
partyClassFrame.NineSlice.Text:SetText("파티 클래스 현황")

partyClassFrame.Background = partyClassFrame:CreateTexture(nil, "BACKGROUND")
partyClassFrame.Background:SetAtlas("collections-background-tile")
partyClassFrame.Background:SetPoint("TOPLEFT", 6, -2)
partyClassFrame.Background:SetPoint("BOTTOMRIGHT", -2, 2)

partyClassFrame.ClassIcons = {}

-- 아이콘 동적 생성 함수
local function CreateIconsIfNeeded()
    if iconsCreated then return end
    
    local iconSize = 30
    local xGap, maxRow = 270, 4
    local startX, startY = 20, -38

    for i, data in ipairs(UtilTable) do
        local col, row = math.floor((i - 1) / maxRow), (i - 1) % maxRow
        local utilName = "PartyUtilIcon_" .. data.key
        local partyUtilityIcon = IconLib:Create(utilName, partyClassFrame, { iconsize = { iconSize, iconSize } })
        
        partyUtilityIcon:SetPoint("TOPLEFT", partyClassFrame, "TOPLEFT", startX + (col * xGap), startY - (row * (iconSize + 12)))
        partyUtilityIcon:ApplyConfig({
            type = "macro",
            icon = data.iconID,
            label = data.name,
            fontsize = 10,
            fontposition = { "TOP", partyUtilityIcon, "BOTTOM", 0, 3 },
            useTooltip = false,
        })

        local count = 0
        for _, classInfo in ipairs(ClassTable) do
            local actualSpellID = (data.type == "dispell" and classInfo.dispell[data.key]) or
                                 (data.type ~= "dispell" and classInfo[data.key])
            if actualSpellID then
                local classIconName = "PartyClassIcon_" .. data.key .. "_" .. classInfo.id
                local partyClassIcon = IconLib:Create(classIconName, partyUtilityIcon, { iconsize = { iconSize, iconSize } })
                
                partyClassIcon:SetPoint("LEFT", partyUtilityIcon, "RIGHT", 10 + (count * (iconSize + 5)), 0)
                partyClassIcon:ApplyConfig({
                    type = "spell",
                    id = actualSpellID,
                    icon = classInfo.iconID,
                    label = classInfo.name,
                    fontsize = 10,
                    fontposition = { "TOP", partyClassIcon, "BOTTOM", 0, 3 },
                    useTooltip = true,
                })

                partyClassIcon.classID = classInfo.id
                partyClassIcon.text = partyClassIcon.Name
                partyClassIcon.border = partyClassIcon.normalTexture
                table.insert(partyClassFrame.ClassIcons, partyClassIcon)
                count = count + 1
            end
        end
    end
    iconsCreated = true
end

-- ==============================
-- 동작
-- ==============================
local function UpdateUI()
    if not partyClassFrame:IsShown() then return end
    
    wipe(activeIDs)
    -- 플레이어 본인
    local _, _, pID = UnitClass("player")
    if pID then activeIDs[pID] = true end

    -- 파티원
    local numMembers = GetNumGroupMembers()
    if numMembers > 0 then
        local inRaid = IsInRaid()
        for i = 1, numMembers do
            local unit = inRaid and "raid" .. i or "party" .. i
            local _, _, cID = UnitClass(unit)
            if cID then activeIDs[cID] = true end
        end
    end

    -- 모든 아이콘 상태 업데이트
    for _, b in ipairs(partyClassFrame.ClassIcons) do
        local isActive = activeIDs[b.classID]
        b.icon:SetDesaturated(not isActive)
        b.icon:SetAlpha(isActive and 1 or 0.5)
        b.text:SetTextColor(isActive and 1 or 0.5, isActive and 1 or 0.5, isActive and 1 or 0.5)
        b.border:SetVertexColor(isActive and 1 or 0.5, isActive and 1 or 0.5, isActive and 1 or 0.5, isActive and 1 or 0.5)
    end
end

-- 최종 호출 함수 (가시성 판단 및 업데이트)
local function PartyClass()
    if isIns() then
        partyClassFrame:Hide()
        return
    end

    local isEnabled = (dodoDB and dodoDB.usePartyClass ~= false)
    local pveShown = PVEFrame and PVEFrame:IsShown()

    if isEnabled and pveShown then
        CreateIconsIfNeeded() -- 필요할 때만 아이콘 생성
        partyClassFrame:Show()
        UpdateUI()
    else
        partyClassFrame:Hide()
    end
end

-- ==============================
-- 이벤트
-- ==============================
local initPartyClass = CreateFrame("Frame")

local function UpdateEventRegistration()
    if not initPartyClass then return end
    
    local isEnabled = (dodoDB and dodoDB.usePartyClass ~= false)
    local inInstance = isIns()

    -- 기능이 켜져 있고 인스턴스가 아닐 때만 이벤트 등록
    if isEnabled and not inInstance then
        partyClassFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
    else
        partyClassFrame:UnregisterEvent("GROUP_ROSTER_UPDATE")
    end
    PartyClass() -- 상태에 따른 즉시 업데이트
end

-- 파티원 변경 시 UI 업데이트
partyClassFrame:SetScript("OnEvent", function(self, event)
    if event == "GROUP_ROSTER_UPDATE" then
        UpdateUI()
    end
end)

-- 초기화 및 지역 이동 감지
initPartyClass:RegisterEvent("ADDON_LOADED")
initPartyClass:RegisterEvent("PLAYER_ENTERING_WORLD")
initPartyClass:SetScript("OnEvent", function(self, event, arg1)
    if event == "PLAYER_ENTERING_WORLD" then
        C_Timer.After(0.5, UpdateEventRegistration)
    elseif event == "ADDON_LOADED" and arg1 == addonName then
        if PVEFrame then
            PVEFrame:HookScript("OnShow", PartyClass)
            PVEFrame:HookScript("OnHide", PartyClass)
        end
        -- 아이콘 생성은 여기서 하지 않고 첫 표시 시점으로 미룸(로드 최적화)
    end
end)

-- ==============================
-- 외부 노출 (Option.lua용)
-- ==============================
dodo.PartyClass = UpdateEventRegistration