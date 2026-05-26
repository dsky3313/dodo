-- ==============================
-- Inspired
-- ==============================
-- dodo UI Party Class Status

-- ==============================
-- 설정 및 테이블
-- ==============================
---@diagnostic disable: lowercase-global, param-type-mismatch, redundant-parameter, undefined-field, undefined-global
local addonName, dodo = ...
local module = {}
dodo:RegisterModule("PartyClass", module)

local LibIcon = dodo.LibIcon

local ClassTable = {
    -- { id = 6, name = "죽기", iconID = 625998, dispell = { curse = false, disease = false, magic = false, poison = false }, bl = false, br = true, buff = false }, -- 템플릿. 삭제 X.
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
    { iconID = 132108, name = "|cffffd100독해제|r", key = "poison", type = "dispell" },
    { iconID = 136066, name = "|cffffd100마법해제|r", key = "magic", type = "dispell" },
    { iconID = 136140, name = "|cffffd100저주해제|r", key = "curse", type = "dispell" },
    { iconID = 132100, name = "|cffffd100질병해제|r", key = "disease", type = "dispell" },
    { iconID = 136012, name = "|cffffd100블러드|r", key = "bl", type = "util" },
    { iconID = 136080, name = "|cffffd100전부|r", key = "br", type = "util" },
    { iconID = 136243, name = "|cffffd100시너지|r", key = "buff", type = "util" },
}

-- ==============================
-- 캐싱
-- ==============================
local C_Timer = C_Timer
local CreateFrame = CreateFrame
local GetInstanceInfo = GetInstanceInfo -- (사용처 없음, 기존 코드 유지 규칙에 따라 유지)
local GetNumGroupMembers = GetNumGroupMembers
local IsInRaid = IsInRaid
local PVEFrame = PVEFrame
local UIParent = UIParent
local UnitClass = UnitClass
local ipairs = ipairs
local math_floor = math.floor
local pairs = pairs
local table_insert = table.insert
local wipe = wipe

-- ==============================
-- 프레임 및 이벤트
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

local activeIDs = {}
local iconsCreated = false

-- ==============================
-- 기능 1: 파티 클래스 현황
-- ==============================
-- 헬퍼: 텍스트 및 Vertex 색상 안전하게 설정
local function set_color_from_table(obj, r, g, b, a, is_vertex)
    if not obj then return end
    if is_vertex then
        obj:SetVertexColor(r, g, b, a or 1)
    else
        obj:SetTextColor(r, g, b, a or 1)
    end
end

-- 아이콘 동적 생성 함수
local function create_icons_if_needed()
    if iconsCreated then return end
    
    local iconSize = 30
    local xGap, maxRow = 270, 4
    local startX, startY = 20, -38

    for i, data in ipairs(UtilTable) do
        local col, row = math_floor((i - 1) / maxRow), (i - 1) % maxRow
        local utilName = "PartyUtilIcon_" .. data.key
        local partyUtilityIcon = LibIcon:Create(utilName, partyClassFrame, { iconsize = { iconSize, iconSize } })
        
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
                local partyClassIcon = LibIcon:Create(classIconName, partyUtilityIcon, { iconsize = { iconSize, iconSize } })
                
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
                table_insert(partyClassFrame.ClassIcons, partyClassIcon)
                count = count + 1
            end
        end
    end
    iconsCreated = true
end

-- UI 갱신 동작 함수
local function actual_update_ui()
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
    for i = 1, #partyClassFrame.ClassIcons do
        local b = partyClassFrame.ClassIcons[i]
        local isActive = activeIDs[b.classID]
        local val = isActive and 1 or 0.5
        
        b.icon:SetDesaturated(not isActive)
        b.icon:SetAlpha(val)
        set_color_from_table(b.Name, val, val, val)
        set_color_from_table(b.normalTexture, val, val, val, val, true)
    end
end

local function update_ui()
    dodo.Profile("PartyClass_update_ui", actual_update_ui)
end

-- 기능 반영 (dodo 표준)
local function actual_update_feature()
    local isEnabled = (dodo.DB and dodo.DB.enablePartyClassModule ~= false)
    local pveShown = PVEFrame and PVEFrame:IsShown()

    if isEnabled and pveShown then
        create_icons_if_needed()
        partyClassFrame:Show()
        update_ui()
    else
        partyClassFrame:Hide()
    end
end

local function update_feature()
    dodo.Profile("PartyClass_update_feature", actual_update_feature)
end

-- 모듈 On/Off 상태 및 이벤트 연동 제어
local function update_module_state()
    local isEnabled = (dodo.DB and dodo.DB.enablePartyClassModule ~= false)
    local pveShown = PVEFrame and PVEFrame:IsShown()

    -- PVEFrame 가시성 및 모듈 상태가 참일 때만 GROUP_ROSTER_UPDATE 이벤트 감지 등록 (최적화)
    if isEnabled and pveShown then
        partyClassFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
    else
        partyClassFrame:UnregisterEvent("GROUP_ROSTER_UPDATE")
    end
    update_feature()
end

partyClassFrame:SetScript("OnEvent", function(self, event)
    dodo.Profile("PartyClass_OnEvent_"..tostring(event), function()
        if event == "GROUP_ROSTER_UPDATE" then
            update_ui()
        end
    end)
end)

-- ==============================
-- 초기화
-- ==============================
local function initialize()
    if dodo.DB and dodo.DB.enablePartyClassModule == nil then
        dodo.DB.enablePartyClassModule = false
    end
end

-- ==============================
-- 모듈 생명주기
-- ==============================
local pveHooked = false
local isInitialized = false
function module:OnEnable()
    initialize()
    update_module_state()

    if isInitialized then return end
    isInitialized = true

    -- 로드 직후 CPU 피크 방지 지연 실행
    local initFrame = CreateFrame("Frame")
    initFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    initFrame:SetScript("OnEvent", function(self, event)
        if event == "PLAYER_ENTERING_WORLD" then
            C_Timer.After(0.5, update_module_state)
            self:UnregisterAllEvents()
        end
    end)

    if PVEFrame and not pveHooked then
        PVEFrame:HookScript("OnShow", update_module_state)
        PVEFrame:HookScript("OnHide", update_module_state)
        pveHooked = true
    end

    -- dodoEditModePanel 내부에 세부 설정 주입
    if dodo.RegisterEditModeSetting then
        dodo.RegisterEditModeSetting("편의기능", {
            {
                name = "파티 클래스 현황",
                get = function() return dodo.DB and dodo.DB.enablePartyClassModule or false end,
                set = function(checked)
                    if dodo.DB then 
                        dodo.DB.enablePartyClassModule = checked 
                    end
                    update_module_state()
                end
            }
        })
    end
end