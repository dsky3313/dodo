-- ==============================
-- Inspired
-- ==============================
-- KeystoneGroupList (https://www.curseforge.com/wow/addons/keystonegrouplist)
-- Party Keystones TSU (https://wago.io/wLeguLKq-)

-- ==============================
-- 설정 및 테이블
-- ==============================
---@diagnostic disable: lowercase-global, param-type-mismatch, redundant-parameter, undefined-field, undefined-global
local addonName, dodo = ...
local module = {}
dodo:RegisterModule("Keystone", module)

local IconLib = dodo.LibIcon
local LibEditMode = LibStub and LibStub("LibEditMode", true)

local Config = {
    -- 크기 및 간격 기본값 설정
    countSize   = 16,     -- 단수(숫자) 폰트 크기
    rowSpacing  = 4,      -- 줄 간격 (아이콘 사이 거리)
    textXOffset = 4,      -- 텍스트 가로 위치 (아이콘과의 거리)
    nameYOffset = -10,    -- 캐릭터 이름 세로 위치
    mapYOffset  = 2,      -- 던전 이름 세로 위치
    frameStrata = "LOW",  -- 프레임 계층
}

local DungeonPorts = {
    -- WoL
    [556] = 1254555, -- 사론의 구덩이

    -- CATA
    [438] = 410080, -- 소용돌이 누각
    [456] = 424142, -- 파도의 왕좌
    [507] = 445424, -- 그림 바톨
    [548] = 445424, -- 그림 바톨

    -- MoP
    [2]   = 131204, -- 옥룡사

    -- WoD
    [161] = 159898, -- 하늘탑
    [165] = 159899, -- 어둠달 지하묘지
    [166] = 159900, -- 상록숲
    [168] = 159901, -- 상록숲
    [169] = 159896, -- 강철 선착장

    -- Legion
    [198] = 424163, -- 어둠심장 숲
    [199] = 424153, -- 검은 떼까마귀 요새
    [200] = 393764, -- 용맹의 전당
    [206] = 410078, -- 넬타리온의 둥지
    [210] = 393766, -- 별의 궁전
    [227] = 393768, -- 카라잔 하층
    [234] = 393768, -- 카라잔 상층
    [239] = 1254551, -- 삼두정의 권좌

    -- BfA
    [244] = 424187, -- 아탈다자르
    [245] = 410071, -- 자유지대
    [247] = {467553, 467555}, -- 왕노다지 광산
    [248] = 424167, -- 웨이크레스트 저택
    [251] = 410074, -- 썩은굴
    [353] = {445418, 464256}, -- 보랄러스 공성전
    [369] = 373274, -- 메카곤
    [370] = 373274, -- 메카곤
    [476] = 464122, -- 보랄러스 공성전

    -- SL
    [375] = 354464, -- 티르너 사이드의 안개
    [376] = 354462, -- 죽음의 상흔
    [377] = 354463, -- 역병 몰락지
    [378] = 354465, -- 속죄의 전당
    [379] = 354468, -- 저편
    [380] = 354466, -- 승천의 보루
    [381] = 354469, -- 핏빛 심연
    [382] = 354467, -- 고통의 투기장
    [391] = 367416, -- 타자베쉬
    [392] = 367416, -- 타자베쉬

    -- DF
    [399] = 393256, -- 루비 생명의 루비
    [400] = 393262, -- 노쿠드 공격대
    [401] = 393279, -- 하늘빛 보관소
    [402] = 393273, -- 알게타르 대학
    [403] = 393222, -- 울다만
    [404] = 393276, -- 넬타루스
    [405] = 393267, -- 담쟁이가죽 골짜기
    [406] = 393283, -- 주입의 전당
    [463] = 424197, -- 무한의 여명
    [464] = 424197, -- 무한의 여명

    -- TWW
    [499] = 445444, -- 신성한 협곡의 수도원
    [500] = 445443, -- 부화장
    [501] = 445269, -- 바위금고
    [502] = 445416, -- 실타래의 도시
    [503] = 445417, -- 아라카라
    [504] = 445441, -- 어둠불꽃 동굴
    [505] = 445414, -- 새벽의 인도자호
    [506] = 445440, -- 양조장
    [525] = 1216786, -- 수문
    [542] = 1237215, -- 알다니

    -- MN / Season
    [9001] = 1283720, 
    [9002] = 1283721, 
    [9003] = 1283722, 
    [9004] = 1283723, 
    [9005] = 464120,
    [557] = 1254400, -- 첨탑
    [558] = 1254572, -- 정원
    [559] = 1254563, -- 제나스
    [560] = 1254559, -- 동굴
}

-- ==============================
-- 캐싱
-- ==============================
local _G = _G
local CreateFrame = CreateFrame
local GetNumSubgroupMembers = GetNumSubgroupMembers
local InCombatLockdown = InCombatLockdown
local IsInGroup = IsInGroup
local IsInRaid = IsInRaid
local RegisterStateDriver = RegisterStateDriver
local UnitClass = UnitClass
local UnitInParty = UnitInParty
local UnitIsUnit = UnitIsUnit
local UnitName = UnitName
local UnitFactionGroup = UnitFactionGroup
local GetRealmName = GetRealmName
local IsPlayerSpell = IsPlayerSpell
local SendChatMessage = SendChatMessage
local tonumber = tonumber
local type = type
local wipe = wipe
local pairs = pairs
local ipairs = ipairs
local table_insert = table.insert
local table_sort = table.sort

local C_ChallengeMode = C_ChallengeMode
local C_ChatInfo = C_ChatInfo
local C_MythicPlus = C_MythicPlus
local C_Timer = C_Timer
local NORMAL_FONT_COLOR = NORMAL_FONT_COLOR
local RAID_CLASS_COLORS = RAID_CLASS_COLORS
local UIParent = UIParent

-- ==============================
-- 모듈 내부 전역 변수
-- ==============================
dodo.Prefix = "WA-KeyStGrList"
dodo.PartyData = {} -- 파티 쐐기돌 저장 데이터
dodo.IsChallengeActive = false
dodo.NeedUpdate = false
dodo.NeedVisibilityUpdate = false

local openRaidLib = nil
local libKeystone = nil
local libKeystoneTable = {}

local MainFrame = nil
local Rows = {}
local uiList = {} -- 핫패스 내 GC 방지용 임시 정렬 리스트 테이블

-- 스로틀링을 위한 상태 보관 변수
local isRosterTimerActive = false
local isUpdateTimerActive = false
local isMyKeystoneTimerActive = false

-- 정렬용 로컬 헬퍼 함수 (클로저 생성 방지)
local function sort_by_level(a, b)
    return a.level > b.level
end

local function GetFactionPortID(mapID)
    local port = DungeonPorts[mapID]
    if type(port) == "table" then 
        return UnitFactionGroup("player") == "Horde" and port[2] or port[1] 
    end
    return port
end

local function GetPlayerFullName(unit)
    local name, realm = UnitName(unit)
    if not name then return nil end
    if not realm or realm == "" then realm = GetRealmName() end
    return name .. "-" .. realm
end

-- ==============================
-- 기능 1: 표시 가시성 및 조건 업데이트
-- ==============================
local function update_visibility_condition()
    if InCombatLockdown() then
        dodo.NeedVisibilityUpdate = true
        return
    end
    dodo.NeedVisibilityUpdate = false

    local condition = "[combat] hide; [group:raid] hide; "
    if dodo.IsChallengeActive then 
        condition = condition .. "hide;" 
    else 
        local showSolo = dodo.DB and dodo.DB.useSoloKeystone ~= false
        if showSolo then
            condition = condition .. "[group:party] show; show;"
        else
            condition = condition .. "[group:party] show; hide;"
        end
    end
    RegisterStateDriver(MainFrame, "visibility", condition)
end

-- ==============================
-- 기능 2: 외부 애드온 데이터 동기화 (Details!)
-- ==============================
local function read_from_details()
    local lib = _G.LibStub and _G.LibStub("LibOpenRaid-1.0", true)
    if not lib or not lib.GetAllKeystonesInfo then return end
    
    local allInfo = lib.GetAllKeystonesInfo()
    local numMembers = GetNumSubgroupMembers()
    
    for i = 1, numMembers do
        local unitName, realm = UnitName("party" .. i)
        if unitName then
            local full = (realm and realm ~= "") and (unitName .. "-" .. realm) or unitName
            local info = allInfo[full] or allInfo[unitName]
            if info then
                local mapID = info.challengeMapID or 0
                local level = info.level or 0
                if mapID > 0 and level > 0 then
                    dodo.PartyData[unitName] = { unit = "party" .. i, name = unitName, mapID = mapID, level = level }
                end
            end
        end
    end
end

-- ==============================
-- 기능 3: 파티원 UI 렌더링
-- ==============================
local function render_party_ui()
    if InCombatLockdown() then
        dodo.NeedUpdate = true
        return
    end
    dodo.NeedUpdate = false

    local showSolo = dodo.DB and dodo.DB.useSoloKeystone ~= false
    if IsInRaid() then return end
    if not IsInGroup() and not showSolo then return end

    wipe(uiList) -- 가비지 누적 방지를 위해 static 테이블 재사용
    local numMembers = GetNumSubgroupMembers()
    local isInGroup = IsInGroup()
    
    for keyName, data in pairs(dodo.PartyData) do
        local inParty = false
        
        if isInGroup then
            if UnitIsUnit("player", data.name) or UnitInParty(data.name) then
                inParty = true
            else
                for j = 1, numMembers do
                    if UnitName("party"..j) == data.name then
                        inParty = true
                        break
                    end
                end
            end
        else
            if UnitIsUnit("player", data.name) then
                inParty = true
            end
        end

        if inParty then
            table_insert(uiList, data)
        else
            dodo.PartyData[keyName] = nil
        end
    end
    
    table_sort(uiList, sort_by_level) -- 최상단 comparator 헬퍼 활용

    local configIconSize = (dodo.DB and dodo.DB.keystoneIconSize) or 40

    for i = 1, 5 do
        local row = Rows[i]
        local data = uiList[i]
        if data then
            local isNoLib = (data.mapID == nil or data.mapID == 0 or data.level == 0)
            
            if isNoLib then
                row.portBtn:ApplyConfig({
                    type = "spell",
                    id = 4352494,
                    icon = 4352494,
                    isAction = false,
                    label = "",
                    useTooltip = false,
                    outline = true,
                    cooldownSize = 12,
                    framestrata = Config.frameStrata,
                })
                row.portBtn.Count:SetText("")
                row.portBtn.icon:SetDesaturated(true)
                row.portBtn:SetAttribute("type", nil)
                row.noPort:Hide()
                row.noLib:Show()
            else
                local mapName, _, _, mapTexture = C_ChallengeMode.GetMapUIInfo(data.mapID)
                local portID = GetFactionPortID(data.mapID)
                
                row.portBtn:ApplyConfig({
                    type = "spell",
                    id = portID,
                    icon = mapTexture,
                    isAction = true,
                    label = "",
                    useTooltip = true,
                    outline = true,
                    cooldownSize = 12,
                    framestrata = Config.frameStrata,
                })
                row.portBtn.Count:SetText(data.level)
                row.noLib:Hide()
                row.mapName:SetText(mapName or "")

                if portID and IsPlayerSpell(portID) then
                    row.noPort:Hide()
                    row.portBtn.icon:SetDesaturated(false)
                else
                    row.noPort:Show()
                    row.portBtn.icon:SetDesaturated(true)
                    row.portBtn:SetAttribute("type", nil)
                end
            end

            local _, class = UnitClass(data.unit or data.name)
            local classColor = class and RAID_CLASS_COLORS[class] or NORMAL_FONT_COLOR
            row.name:SetText(data.name)
            row.name:SetTextColor(classColor.r, classColor.g, classColor.b)
            row:Show()
        else
            row:Hide()
        end
    end
end

-- ==============================
-- 기능 4: 설정 값 동적 적용
-- ==============================
local function update_feature()
    local configIconSize = (dodo.DB and dodo.DB.keystoneIconSize) or 40
    local configFontSize = (dodo.DB and dodo.DB.keystoneFontSize) or 12

    local rowHeight = configIconSize + Config.rowSpacing
    local frameWidth = 200
    MainFrame:SetSize(frameWidth, 220)

    local font, _, flags = Rows[1].name:GetFont()
    if not font then font = _G.STANDARD_TEXT_FONT or "Fonts\\bKAI00M.ttf" end

    for i = 1, 5 do
        local row = Rows[i]
        row:SetSize(frameWidth, rowHeight)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", MainFrame, "TOPLEFT", 0, -(i-1) * rowHeight)

        row.portBtn:SetSize(configIconSize, configIconSize)
        row.portBtn:RescaleIcon()

        row.name:SetFont(font, configFontSize + 1, "OUTLINE")
        row.mapName:SetFont(font, configFontSize - 1, flags)
        row.noPort:SetFont(font, 12, "OUTLINE")
        row.noLib:SetFont(font, configFontSize - 1, flags)

        row.portBtn.Count:SetFont(font, Config.countSize, "OUTLINE")
        row.portBtn.Count:SetTextColor(1, 0.82, 0)
        row.portBtn.Count:ClearAllPoints()
        row.portBtn.Count:SetPoint("BOTTOMRIGHT", row.portBtn, "BOTTOMRIGHT", -2, 2)

        row.name:ClearAllPoints()
        row.name:SetPoint("TOPLEFT", row.portBtn, "TOPRIGHT", Config.textXOffset, Config.nameYOffset)
        row.mapName:ClearAllPoints()
        row.mapName:SetPoint("BOTTOMLEFT", row.portBtn, "BOTTOMRIGHT", Config.textXOffset, Config.mapYOffset)
    end

    render_party_ui()
end

-- ==============================
-- 기능 5: 쐐기돌 업데이트 및 방송
-- ==============================
local function update_my_keystone()
    local mapID = C_MythicPlus.GetOwnedKeystoneChallengeMapID()
    local level = C_MythicPlus.GetOwnedKeystoneLevel()

    if mapID and level then
        local myName = UnitName("player")
        dodo.PartyData[myName] = { unit = "player", name = myName, mapID = mapID, level = level }
        local msg = "KSGL:Send:" .. mapID .. ":" .. level .. ":0:0"
        if IsInGroup() then 
            C_ChatInfo.SendAddonMessage(dodo.Prefix, msg, "PARTY") 
        end
    end
    render_party_ui()
end

-- 스로틀링 래핑 함수들 (매번 타이머를 생성하지 않고 단일 타이머 보장)
local function update_my_keystone_throttled()
    if isMyKeystoneTimerActive then return end
    isMyKeystoneTimerActive = true
    C_Timer.After(0.5, function()
        isMyKeystoneTimerActive = false
        update_my_keystone()
    end)
end

local function render_party_ui_throttled()
    if isUpdateTimerActive then return end
    isUpdateTimerActive = true
    C_Timer.After(0.2, function()
        isUpdateTimerActive = false
        render_party_ui()
    end)
end

-- ==============================
-- 모듈 On/Off 활성화 상태 제어
-- ==============================
local function update_module_state()
    local enabled = (dodo.DB and dodo.DB.enableKeystoneModule ~= false)

    if not enabled then
        MainFrame:Hide()
        MainFrame:UnregisterAllEvents()
        
        if LibEditMode and LibEditMode.frameSelections and LibEditMode.frameSelections[MainFrame] then
            LibEditMode.frameSelections[MainFrame]:Hide()
        end
    else
        MainFrame:Show()
        
        MainFrame:RegisterEvent("BAG_UPDATE_DELAYED")
        MainFrame:RegisterEvent("SPELL_UPDATE_COOLDOWN")
        MainFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
        MainFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
        MainFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
        MainFrame:RegisterEvent("CHAT_MSG_ADDON")
        MainFrame:RegisterEvent("CHALLENGE_MODE_START")
        MainFrame:RegisterEvent("CHALLENGE_MODE_COMPLETED")
        MainFrame:RegisterEvent("CHALLENGE_MODE_RESET")
        MainFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
        
        update_feature()
        update_visibility_condition()
        
        if LibEditMode and LibEditMode:IsInEditMode() and LibEditMode.frameSelections and LibEditMode.frameSelections[MainFrame] then
            LibEditMode.frameSelections[MainFrame]:ShowHighlighted()
        end
    end
end

dodo.UpdateKeystoneModuleState = update_module_state
dodo.KeystoneApplyFeature = update_feature

-- ==============================
-- 초기화 및 UI 생성
-- ==============================
local function create_ui()
    if MainFrame then return end

    MainFrame = CreateFrame("Frame", "dodo_KeystoneMainFrame", UIParent, "BackdropTemplate")
    MainFrame:SetSize(200, 220)
    MainFrame:SetFrameStrata(Config.frameStrata)

    -- 편집 모드 위치 불러오기
    local savedX = (dodo.DB and dodo.DB.keystoneX) or 20
    local savedY = (dodo.DB and dodo.DB.keystoneY) or -140
    local savedPoint = (dodo.DB and dodo.DB.keystonePoint) or "TOPLEFT"
    MainFrame:SetPoint(savedPoint, UIParent, savedPoint, savedX, savedY)

    for i = 1, 5 do
        local row = CreateFrame("Frame", "dodo_KeystoneRow"..i, MainFrame, "BackdropTemplate")
        
        row.portBtn = IconLib:Create("dodo_KeystoneRowPortBtn"..i, row, {
            isAction = true, 
            iconsize = {40, 40}
        })
        row.portBtn:SetPoint("LEFT", row, "LEFT", 2, 0)

        row.name = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        row.name:SetPoint("TOPLEFT", row.portBtn, "TOPRIGHT", 10, -2)
        row.name:SetJustifyH("LEFT")

        row.noPort = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        row.noPort:SetPoint("TOP", row.portBtn, "BOTTOM", 0, -1)
        row.noPort:SetTextColor(1, 0, 0)
        row.noPort:SetText("미개방")

        row.mapName = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        row.mapName:SetPoint("BOTTOMLEFT", row.portBtn, "BOTTOMRIGHT", 10, 2)
        row.mapName:SetJustifyH("LEFT")

        row.noLib = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        row.noLib:SetPoint("BOTTOMLEFT", row.portBtn, "BOTTOMRIGHT", 10, 2)
        row.noLib:SetJustifyH("LEFT")
        row.noLib:SetTextColor(1, 0, 0)
        row.noLib:SetText("라이브러리 미사용")
        row.noLib:Hide()

        row:Hide()
        Rows[i] = row
    end
end

local function initialize()
    if dodo.DB then
        if dodo.DB.enableKeystoneModule == nil then dodo.DB.enableKeystoneModule = true end
        if dodo.DB.useSoloKeystone == nil then dodo.DB.useSoloKeystone = true end
        if dodo.DB.useKeyRoll == nil then dodo.DB.useKeyRoll = true end
        if dodo.DB.keystoneIconSize == nil then dodo.DB.keystoneIconSize = 40 end
        if dodo.DB.keystoneFontSize == nil then dodo.DB.keystoneFontSize = 12 end
    end

    create_ui()

    if not C_ChatInfo.IsAddonMessagePrefixRegistered(dodo.Prefix) then
        C_ChatInfo.RegisterAddonMessagePrefix(dodo.Prefix)
    end
    if not C_ChatInfo.IsAddonMessagePrefixRegistered("AstralKeys") then
        C_ChatInfo.RegisterAddonMessagePrefix("AstralKeys")
    end

    -- 라이브러리 연결 (Details! 연동 포함)
    openRaidLib = _G.LibStub and _G.LibStub("LibOpenRaid-1.0", true)
    libKeystone = _G.LibStub and _G.LibStub("LibKeystone", true)

    if openRaidLib then
        local cbHandle = {}
        openRaidLib.RegisterCallback(cbHandle, "KeystoneUpdate", function()
            if not InCombatLockdown() then
                read_from_details()
                render_party_ui_throttled()
            else
                dodo.NeedUpdate = true
            end
        end)
    end

    if libKeystone then
        local function OnLibKeystoneUpdate(keyLevel, keyMap, playerRating, playerName, channel)
            if channel == "PARTY" then
                local charName = playerName:match("([^%-]+)") or playerName
                if keyMap and keyLevel and keyMap > 0 and keyLevel > 0 then
                    dodo.PartyData[charName] = { unit = charName, name = charName, mapID = keyMap, level = keyLevel }
                    dodo.NeedUpdate = true
                    if not InCombatLockdown() then 
                        render_party_ui_throttled() 
                    end
                end
            end
        end
        libKeystone.Register(libKeystoneTable, OnLibKeystoneUpdate)
    end
end

-- ==============================
-- 프레임 이벤트 처리
-- ==============================
local function OnEvent(self, event, ...)
    if event == "BAG_UPDATE_DELAYED" then
        if not IsInRaid() then 
            update_my_keystone_throttled() 
        end

    elseif event == "SPELL_UPDATE_COOLDOWN" then
        for i = 1, 5 do
            if Rows[i] and Rows[i].portBtn then 
                Rows[i].portBtn:UpdateStatus() 
            end
        end

    elseif event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA" then
        local activeLevel = C_ChallengeMode.GetActiveKeystoneInfo()
        dodo.IsChallengeActive = (activeLevel and activeLevel > 0)
        update_visibility_condition()
        if not IsInRaid() then
            C_Timer.After(0.5, function()
                update_my_keystone()
                if IsInGroup() then
                    read_from_details()
                end
                render_party_ui()
            end)
        end

    elseif event == "GROUP_ROSTER_UPDATE" then
        update_visibility_condition()
        if IsInGroup() and not IsInRaid() then
            if isRosterTimerActive then return end
            isRosterTimerActive = true
            C_Timer.After(0.5, function()
                isRosterTimerActive = false
                update_my_keystone()
                
                for i = 1, GetNumSubgroupMembers() do
                    local name = UnitName("party" .. i)
                    if name then
                        if not dodo.PartyData[name] then
                            dodo.PartyData[name] = { unit = "party" .. i, name = name, mapID = 0, level = 0 }
                        end
                    end
                end
                
                if openRaidLib and openRaidLib.RequestKeystoneDataFromParty then
                    openRaidLib.RequestKeystoneDataFromParty()
                end
                if libKeystone then
                    libKeystone.Request("PARTY")
                end
                
                read_from_details()
                render_party_ui()
                
                -- 라이브러리 대기 2초 후 재시도
                C_Timer.After(2, function()
                    read_from_details()
                    render_party_ui()
                end)
            end)
        else
            local myName = UnitName("player")
            local myData = dodo.PartyData[myName]
            wipe(dodo.PartyData) -- GC 방지를 위해 wipe 활용
            if myData then
                dodo.PartyData[myName] = myData
            end
            render_party_ui()
        end

    elseif event == "CHAT_MSG_ADDON" then
        local prefix, text, channel, sender = ...

        if prefix == dodo.Prefix and sender ~= GetPlayerFullName("player") then
            local msgType = text:match("KSGL:(%a+):")
            if msgType == "Send" then
                local mapID = tonumber(text:match("KSGL:.-:(%d+):"))
                local level = tonumber(text:match("KSGL:.-:%d+:(%d+):"))
                local senderName = sender:match("([^%-]+)") or sender
                if mapID and level then
                    local data = { unit = senderName, name = senderName, mapID = mapID, level = level }
                    if channel == "PARTY" then
                        dodo.PartyData[senderName] = data
                        render_party_ui_throttled()
                    end
                end
            elseif msgType == "Request" then
                update_my_keystone()
            end

        elseif prefix == "AstralKeys" and sender ~= GetPlayerFullName("player") then
            local msgType, content = text:match("^(%w+)%s+(.+)")
            if msgType and (string.sub(msgType, 1, 7) == "updateV" or string.sub(msgType, 1, 4) == "sync") then
                for chunk in content:gmatch("[^_]+") do
                    local fullName, mapID, level = chunk:match("^([^:]+):[^:]+:(%d+):(%d+)")
                    if fullName and mapID and level then
                        local charName = fullName:match("([^%-]+)") or fullName
                        mapID = tonumber(mapID)
                        level = tonumber(level)

                        if mapID and level and mapID > 0 and level > 0 then
                            local data = { unit = charName, name = charName, mapID = mapID, level = level, source = "Astral" }
                            if channel == "PARTY" or channel == "RAID" then
                                dodo.PartyData[charName] = data
                                dodo.NeedUpdate = true
                                if not InCombatLockdown() then 
                                    render_party_ui_throttled() 
                                end
                            end
                        end
                    end
                end
            end
        end

    elseif event == "CHALLENGE_MODE_START" then
        dodo.IsChallengeActive = true
        update_visibility_condition()

    elseif event == "CHALLENGE_MODE_COMPLETED" or event == "CHALLENGE_MODE_RESET" then
        dodo.IsChallengeActive = false
        update_visibility_condition()
        C_Timer.After(2, update_my_keystone)

        if event == "CHALLENGE_MODE_COMPLETED" and dodo.DB and dodo.DB.useKeyRoll ~= false then
            C_Timer.After(5, function()
                if IsInGroup() then
                    SendChatMessage("돌 굴리세요!", "YELL")
                end
            end)
        end

    elseif event == "PLAYER_REGEN_ENABLED" then
        if dodo.NeedVisibilityUpdate then update_visibility_condition() end
        if dodo.NeedUpdate then render_party_ui() end
    end
end

-- ==============================
-- 모듈 생명주기
-- ==============================
function module:OnEnable()
    initialize()
    update_module_state()

    -- 이벤트 바인딩
    MainFrame:SetScript("OnEvent", OnEvent)

    -- LibEditMode 등록 및 설정
    MainFrame.editModeName = "dodo 쐐기돌 목록"
    if LibEditMode then
        LibEditMode:AddFrame(
            MainFrame,
            function(f, layoutName, point, x, y)
                if dodo.DB then
                    dodo.DB.keystoneX = x
                    dodo.DB.keystoneY = y
                    dodo.DB.keystonePoint = point
                end
                update_feature()
            end,
            {
                point = "TOPLEFT",
                x = 20,
                y = -120,
            },
            "dodo 쐐기돌 목록"
        )

        LibEditMode:AddFrameSettings(MainFrame, {
            {
                kind = LibEditMode.SettingType.Slider,
                name = "아이콘 크기",
                desc = "쐐기돌 아이콘의 크기를 설정합니다.",
                default = 40,
                minValue = 24,
                maxValue = 60,
                valueStep = 2,
                get = function() 
                    return (dodo.DB and dodo.DB.keystoneIconSize) or 40 
                end,
                set = function(_, newValue)
                    if dodo.DB then 
                        dodo.DB.keystoneIconSize = newValue 
                    end
                    update_feature()
                end,
            },
            {
                kind = LibEditMode.SettingType.Slider,
                name = "글꼴 크기",
                desc = "캐릭터 및 던전명 글꼴 크기를 설정합니다.",
                default = 12,
                minValue = 8,
                maxValue = 20,
                valueStep = 1,
                get = function() 
                    return (dodo.DB and dodo.DB.keystoneFontSize) or 12 
                end,
                set = function(_, newValue)
                    if dodo.DB then 
                        dodo.DB.keystoneFontSize = newValue 
                    end
                    update_feature()
                end,
            },
            {
                kind = LibEditMode.SettingType.Checkbox,
                name = "내 돌 항상 표시",
                desc = "파티 미가입 상태에서도 내 쐐기돌을 표시합니다.",
                default = true,
                get = function() 
                    return dodo.DB and dodo.DB.useSoloKeystone ~= false 
                end,
                set = function(_, newValue)
                    if dodo.DB then 
                        dodo.DB.useSoloKeystone = newValue 
                    end
                    update_visibility_condition()
                    render_party_ui()
                end,
            },
            {
                kind = LibEditMode.SettingType.Checkbox,
                name = "완료 시 주사위 굴리기 알림",
                desc = "쐐기돌 완료 시 파티에 주사위 굴리기를 외칩니다.",
                default = true,
                get = function() 
                    return dodo.DB and dodo.DB.useKeyRoll ~= false 
                end,
                set = function(_, newValue)
                    if dodo.DB then 
                        dodo.DB.useKeyRoll = newValue 
                    end
                end,
            },
        })

        LibEditMode:RegisterCallback("enter", function()
            local isEnabled = (dodo.DB and dodo.DB.enableKeystoneModule ~= false)
            if isEnabled then
                MainFrame:Show()
                -- Mock 상태 테스트 노출
                for i = 1, 5 do
                    local row = Rows[i]
                    row.portBtn:ApplyConfig({
                        type = "spell",
                        id = 159898,
                        icon = 1042079,
                        isAction = false,
                        label = "",
                        useTooltip = false,
                        outline = true,
                        cooldownSize = 12,
                        framestrata = Config.frameStrata,
                    })
                    row.portBtn.Count:SetText("10")
                    row.portBtn.icon:SetDesaturated(false)
                    row.noPort:Hide()
                    row.noLib:Hide()
                    row.mapName:SetText("하늘탑 (테스트)")
                    row.name:SetText("파티원" .. i)
                    row.name:SetTextColor(1, 0.82, 0)
                    row:Show()
                end
            end
        end)

        LibEditMode:RegisterCallback("exit", function()
            local isEnabled = (dodo.DB and dodo.DB.enableKeystoneModule ~= false)
            if isEnabled then
                render_party_ui()
            else
                MainFrame:Hide()
            end
        end)
    end

    -- dodoEditModePanel 내 세부 설정 주입 (마스터 토글만)
    if dodo.RegisterEditModeSetting then
        dodo.RegisterEditModeSetting("편의기능", {
            {
                name = "쐐기돌 목록 표시",
                get = function() 
                    return dodo.DB and dodo.DB.enableKeystoneModule ~= false 
                end,
                set = function(checked)
                    if dodo.DB then 
                        dodo.DB.enableKeystoneModule = checked 
                    end
                    update_module_state()
                end
            },
            { isSpacer = true }
        })
    end

end
