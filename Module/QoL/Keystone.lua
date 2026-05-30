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
dodoDB = dodoDB or {}

local Colors = dodo.Colors
local LibIcon = dodo.LibIcon

local Config = {
    defaultX     = 20,
    defaultY     = -140,
    defaultPoint = "TOPLEFT",
    frameStrata = "LOW",

    countSize   = 16,
    rowSpacing  = 4,
    textXOffset = 4,
    nameYOffset = -10,
    mapYOffset  = 2,
}

local dungeon_ports = {
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
-- 캐싱 (알파벳 순 정렬)
-- ==============================
local C_ChallengeMode = C_ChallengeMode
local C_ChatInfo = C_ChatInfo
local C_MythicPlus = C_MythicPlus
local C_Timer = C_Timer
local CreateFrame = CreateFrame
local GetNumSubgroupMembers = GetNumSubgroupMembers
local GetRealmName = GetRealmName
local InCombatLockdown = InCombatLockdown
local IsInGroup = IsInGroup
local IsInRaid = IsInRaid
local IsPlayerSpell = IsPlayerSpell
local NORMAL_FONT_COLOR = NORMAL_FONT_COLOR
local RAID_CLASS_COLORS = RAID_CLASS_COLORS
local RegisterStateDriver = RegisterStateDriver
local SendChatMessage = SendChatMessage
local UnitClass = UnitClass
local UnitFactionGroup = UnitFactionGroup
local UnitInParty = UnitInParty
local UnitIsUnit = UnitIsUnit
local UnitName = UnitName
local UIParent = UIParent
local _G = _G
local ipairs = ipairs
local issecretvalue = issecretvalue
local pairs = pairs
local string_sub = string.sub
local table_insert = table.insert
local table_sort = table.sort
local tonumber = tonumber
local type = type
local wipe = wipe

-- ==============================
-- 모듈 내부 정적 상태 변수 (캡슐화)
-- ==============================
local PREFIX = "WA-KeyStGrList"
local party_data = {}
local is_challenge_active = false
local need_update = false
local need_visibility_update = false

local open_raid_lib = nil
local lib_keystone = nil
local lib_keystone_table = {}

local main_frame = nil
local rows = {}
local ui_list = {}

-- 스로틀링 상태 변수
local is_roster_timer_active = false
local is_update_timer_active = false
local is_my_keystone_timer_active = false

-- ==============================
-- 정렬 및 헬퍼 함수 (비밀값 예외 가드 적용)
-- ==============================
local function sort_by_level(a, b)
    local a_level = a and a.level or 0
    local b_level = b and b.level or 0
    if issecretvalue(a_level) or issecretvalue(b_level) then
        local a_val = issecretvalue(a_level) and 0 or a_level
        local b_val = issecretvalue(b_level) and 0 or b_level
        return a_val > b_val
    end
    return a_level > b_level
end

local function get_faction_port_id(map_id)
    local port = dungeon_ports[map_id]
    if type(port) == "table" then
        return UnitFactionGroup("player") == "Horde" and port[2] or port[1]
    end
    return port
end

local function get_player_full_name(unit)
    local name, realm = UnitName(unit)
    if not name then return nil end
    if not realm or realm == "" then realm = GetRealmName() end
    return name .. "-" .. realm
end

-- ==============================
-- 표시 가시성 및 조건 업데이트
-- ==============================
local function update_visibility_condition()
    if InCombatLockdown() then
        need_visibility_update = true
        return
    end
    need_visibility_update = false

    -- 챌린지 모드 활성화 여부 실시간 자가 보정 (전투 중 이벤트 누락 방어)
    local activeMapID = C_ChallengeMode and C_ChallengeMode.GetActiveChallengeMapID and C_ChallengeMode.GetActiveChallengeMapID()
    local isChallengeReallyActive = (activeMapID and activeMapID > 0) or is_challenge_active

    local condition = "[combat] hide; [group:raid] hide; "
    if isChallengeReallyActive then
        condition = condition .. "hide;"
    else
        local show_solo = dodoDB and dodoDB.useSoloKeystone ~= false
        if show_solo then
            condition = condition .. "[group:party] show; show;"
        else
            condition = condition .. "[group:party] show; hide;"
        end
    end
    RegisterStateDriver(main_frame, "visibility", condition)
end

-- ==============================
-- 외부 애드온 데이터 동기화 (Details!)
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
                    party_data[unitName] = { unit = "party" .. i, name = unitName, mapID = mapID, level = level }
                end
            end
        end
    end
end

-- ==============================
-- 파티원 UI 렌더링 (비밀값 예외 가드 적용)
-- ==============================
local function render_party_ui()
    if InCombatLockdown() then
        need_update = true
        return
    end
    need_update = false

    local show_solo = dodoDB and dodoDB.useSoloKeystone ~= false
    if IsInRaid() then return end
    if not IsInGroup() and not show_solo then return end

    wipe(ui_list)
    local numMembers = GetNumSubgroupMembers()
    local isInGroup = IsInGroup()

    for keyName, data in pairs(party_data) do
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
            table_insert(ui_list, data)
        else
            party_data[keyName] = nil
        end
    end

    table_sort(ui_list, sort_by_level)

    for i = 1, 5 do
        local row = rows[i]
        local data = ui_list[i]
        if data then
            local isNoLib = false
            if data.mapID == nil or issecretvalue(data.mapID) or data.mapID == 0 or data.level == nil or issecretvalue(data.level) or data.level == 0 then
                isNoLib = true
            end

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
                local portID = get_faction_port_id(data.mapID)

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
            local classColor = class and ((Colors and Colors.Class and Colors.Class[class]) or RAID_CLASS_COLORS[class]) or NORMAL_FONT_COLOR
            row.name:SetText(data.name)
            row.name:SetTextColor(classColor.r, classColor.g, classColor.b)
            row:Show()
        else
            row:Hide()
        end
    end
end

-- ==============================
-- 설정 값 동적 적용
-- ==============================
local function update_feature()
    local configIconSize = (dodoDB and dodoDB.keystoneIconSize) or 40
    local configFontSize = (dodoDB and dodoDB.keystoneFontSize) or 12

    local rowHeight = configIconSize + Config.rowSpacing
    local frameWidth = 200
    main_frame:SetSize(frameWidth, 220)

    local font, _, flags = rows[1].name:GetFont()
    if not font then font = _G.STANDARD_TEXT_FONT or "Fonts\\bKAI00M.ttf" end

    for i = 1, 5 do
        local row = rows[i]
        row:SetSize(frameWidth, rowHeight)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", main_frame, "TOPLEFT", 0, -(i-1) * rowHeight)

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
-- 쐐기돌 업데이트 및 방송
-- ==============================
local function update_my_keystone()
    local mapID = C_MythicPlus.GetOwnedKeystoneChallengeMapID()
    local level = C_MythicPlus.GetOwnedKeystoneLevel()

    if mapID and level then
        local myName = UnitName("player")
        party_data[myName] = { unit = "player", name = myName, mapID = mapID, level = level }
        local msg = "KSGL:Send:" .. mapID .. ":" .. level .. ":0:0"
        if IsInGroup() then
            C_ChatInfo.SendAddonMessage(PREFIX, msg, "PARTY")
        end
    end
    render_party_ui()
end

-- 스로틀링 래핑 함수들
local function on_my_keystone_timer()
    is_my_keystone_timer_active = false
    update_my_keystone()
end

local function update_my_keystone_throttled()
    if is_my_keystone_timer_active then return end
    is_my_keystone_timer_active = true
    C_Timer.After(0.5, on_my_keystone_timer)
end

local function on_party_ui_timer()
    is_update_timer_active = false
    render_party_ui()
end

local function render_party_ui_throttled()
    if is_update_timer_active then return end
    is_update_timer_active = true
    C_Timer.After(0.2, on_party_ui_timer)
end

-- ==============================
-- 모듈 On/Off 활성화 상태 제어
-- ==============================
local function update_module_state()
    local enabled = (dodoDB and dodoDB.enableKeystoneModule ~= false)

    if not enabled then
        main_frame:Hide()
        main_frame:UnregisterAllEvents()
    else
        main_frame:Show()

        main_frame:RegisterEvent("BAG_UPDATE_DELAYED")
        main_frame:RegisterEvent("SPELL_UPDATE_COOLDOWN")
        main_frame:RegisterEvent("PLAYER_ENTERING_WORLD")
        main_frame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
        main_frame:RegisterEvent("GROUP_ROSTER_UPDATE")
        main_frame:RegisterEvent("CHAT_MSG_ADDON")
        main_frame:RegisterEvent("CHALLENGE_MODE_START")
        main_frame:RegisterEvent("CHALLENGE_MODE_COMPLETED")
        main_frame:RegisterEvent("CHALLENGE_MODE_RESET")
        main_frame:RegisterEvent("PLAYER_REGEN_ENABLED")
        main_frame:RegisterEvent("PLAYER_REGEN_DISABLED")

        update_feature()
        update_visibility_condition()
    end
end

dodo.UpdateKeystoneModuleState = update_module_state
dodo.KeystoneApplyFeature = update_feature

-- ==============================
-- 초기화 및 UI 생성 (EditMode 연동)
-- ==============================
local function create_ui()
    if main_frame then return end

    local anchorFrame
    if dodo.EditMode then
        anchorFrame = dodo.EditMode:GetSystem("Keystone")
    end

    main_frame = CreateFrame("Frame", "dodo_KeystoneMainFrame", UIParent, "BackdropTemplate")
    main_frame:SetSize(200, 220)
    main_frame:SetFrameStrata(Config.frameStrata)

    -- EditMode 앵커 프레임에 종속되도록 위치 설정
    main_frame:ClearAllPoints()
    if anchorFrame then
        main_frame:SetPoint("CENTER", anchorFrame, "CENTER", 0, 0)
    else
        local savedX = (dodoDB and dodoDB.keystoneX) or Config.defaultX
        local savedY = (dodoDB and dodoDB.keystoneY) or Config.defaultY
        local savedPoint = (dodoDB and dodoDB.keystonePoint) or Config.defaultPoint
        main_frame:SetPoint(savedPoint, UIParent, savedPoint, savedX, savedY)
    end

    for i = 1, 5 do
        local row = CreateFrame("Frame", "dodo_KeystoneRow"..i, main_frame, "BackdropTemplate")

        row.portBtn = LibIcon:Create("dodo_KeystoneRowPortBtn"..i, row, {
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
        rows[i] = row
    end
end

local function initialize()
    if dodoDB then
        if dodoDB.enableKeystoneModule == nil then dodoDB.enableKeystoneModule = true end
        if dodoDB.useSoloKeystone == nil then dodoDB.useSoloKeystone = true end
        if dodoDB.useKeyRoll == nil then dodoDB.useKeyRoll = true end
        if dodoDB.keystoneIconSize == nil then dodoDB.keystoneIconSize = 40 end
        if dodoDB.keystoneFontSize == nil then dodoDB.keystoneFontSize = 12 end
    end

    create_ui()

    if not C_ChatInfo.IsAddonMessagePrefixRegistered(PREFIX) then
        C_ChatInfo.RegisterAddonMessagePrefix(PREFIX)
    end
    if not C_ChatInfo.IsAddonMessagePrefixRegistered("AstralKeys") then
        C_ChatInfo.RegisterAddonMessagePrefix("AstralKeys")
    end

    -- 라이브러리 연결
    open_raid_lib = _G.LibStub and _G.LibStub("LibOpenRaid-1.0", true)
    lib_keystone = _G.LibStub and _G.LibStub("LibKeystone", true)

    local function on_openraid_keystone_update()
        if not InCombatLockdown() then
            read_from_details()
            render_party_ui_throttled()
        else
            need_update = true
        end
    end

    if open_raid_lib then
        local cbHandle = {}
        open_raid_lib.RegisterCallback(cbHandle, "KeystoneUpdate", on_openraid_keystone_update)
    end

    if lib_keystone then
        local function on_lib_keystone_update(keyLevel, keyMap, playerRating, playerName, channel)
            if channel == "PARTY" then
                local charName = playerName:match("([^%-]+)") or playerName
                if keyMap and keyLevel and keyMap > 0 and keyLevel > 0 then
                    party_data[charName] = { unit = charName, name = charName, mapID = keyMap, level = keyLevel }
                    need_update = true
                    if not InCombatLockdown() then
                        render_party_ui_throttled()
                    end
                end
            end
        end
        lib_keystone.Register(lib_keystone_table, on_lib_keystone_update)
    end
end

-- ==============================
-- OnEvent 지연 실행 정적 함수 정의 (가비지 차단)
-- ==============================
local function delayed_entering_world()
    update_my_keystone()
    if IsInGroup() then
        read_from_details()
    end
    render_party_ui()
end

local function delayed_roster_retry()
    read_from_details()
    render_party_ui()
end

local function delayed_roster_update()
    is_roster_timer_active = false
    update_my_keystone()

    local numMembers = GetNumSubgroupMembers()
    for i = 1, numMembers do
        local name = UnitName("party" .. i)
        if name then
            if not party_data[name] then
                party_data[name] = { unit = "party" .. i, name = name, mapID = 0, level = 0 }
            end
        end
    end

    if open_raid_lib and open_raid_lib.RequestKeystoneDataFromParty then
        open_raid_lib.RequestKeystoneDataFromParty()
    end
    if lib_keystone then
        lib_keystone.Request("PARTY")
    end

    read_from_details()
    render_party_ui()

    C_Timer.After(2, delayed_roster_retry)
end

local function delayed_key_roll_msg()
    if IsInGroup() then
        SendChatMessage("돌 굴리세요!", "YELL")
    end
end

-- ==============================
-- 프레임 이벤트 처리
-- ==============================
local function on_event(self, event, ...)
    if event == "BAG_UPDATE_DELAYED" then
        if not IsInRaid() then
            update_my_keystone_throttled()
        end

    elseif event == "SPELL_UPDATE_COOLDOWN" then
        for i = 1, 5 do
            if rows[i] and rows[i].portBtn then
                rows[i].portBtn:UpdateStatus()
            end
        end

    elseif event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA" then
        local activeLevel = C_ChallengeMode.GetActiveKeystoneInfo()
        is_challenge_active = (activeLevel and activeLevel > 0)
        update_visibility_condition()
        if not IsInRaid() then
            C_Timer.After(0.5, delayed_entering_world)
        end

    elseif event == "GROUP_ROSTER_UPDATE" then
        update_visibility_condition()
        if IsInGroup() and not IsInRaid() then
            if is_roster_timer_active then return end
            is_roster_timer_active = true
            C_Timer.After(0.5, delayed_roster_update)
        else
            local myName = UnitName("player")
            local myData = party_data[myName]
            wipe(party_data)
            if myData then
                party_data[myName] = myData
            end
            render_party_ui()
        end

    elseif event == "CHAT_MSG_ADDON" then
        local prefix, text, channel, sender = ...

        if prefix == PREFIX and sender ~= get_player_full_name("player") then
            local msgType = text:match("KSGL:(%a+):")
            if msgType == "Send" then
                local mapID = tonumber(text:match("KSGL:.-:(%d+):"))
                local level = tonumber(text:match("KSGL:.-:%d+:(%d+):"))
                local senderName = sender:match("([^%-]+)") or sender
                if mapID and level then
                    local data = { unit = senderName, name = senderName, mapID = mapID, level = level }
                    if channel == "PARTY" then
                        party_data[senderName] = data
                        render_party_ui_throttled()
                    end
                end
            elseif msgType == "Request" then
                update_my_keystone()
            end

        elseif prefix == "AstralKeys" and sender ~= get_player_full_name("player") then
            local msgType, content = text:match("^(%w+)%s+(.+)")
            if msgType and (string_sub(msgType, 1, 7) == "updateV" or string_sub(msgType, 1, 4) == "sync") then
                for chunk in content:gmatch("[^_]+") do
                    local fullName, mapID, level = chunk:match("^([^:]+):[^:]+:(%d+):(%d+)")
                    if fullName and mapID and level then
                        local charName = fullName:match("([^%-]+)") or fullName
                        mapID = tonumber(mapID)
                        level = tonumber(level)

                        if mapID and level and mapID > 0 and level > 0 then
                            local data = { unit = charName, name = charName, mapID = mapID, level = level, source = "Astral" }
                            if channel == "PARTY" or channel == "RAID" then
                                party_data[charName] = data
                                need_update = true
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
        is_challenge_active = true
        update_visibility_condition()

    elseif event == "CHALLENGE_MODE_COMPLETED" or event == "CHALLENGE_MODE_RESET" then
        is_challenge_active = false
        update_visibility_condition()
        C_Timer.After(2, update_my_keystone)

        if event == "CHALLENGE_MODE_COMPLETED" and dodoDB and dodoDB.useKeyRoll ~= false then
            C_Timer.After(5, delayed_key_roll_msg)
        end

    elseif event == "PLAYER_REGEN_DISABLED" then
        main_frame:Hide()
        main_frame:UnregisterAllEvents()
        main_frame:RegisterEvent("PLAYER_REGEN_ENABLED")

    elseif event == "PLAYER_REGEN_ENABLED" then
        update_module_state()
    end
end

-- ==============================
-- 독립형 모듈 구동 및 로그인 이벤트 리스너
-- ==============================
local init_keystone_frame = CreateFrame("Frame")
init_keystone_frame:RegisterEvent("ADDON_LOADED")
init_keystone_frame:RegisterEvent("PLAYER_LOGIN")
init_keystone_frame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == addonName then
        dodoDB = dodoDB or {}
        self:UnregisterEvent("ADDON_LOADED")
    elseif event == "PLAYER_LOGIN" then
        if dodo.EditMode then
            dodo.EditMode:CreateSystem("Keystone", "쐐기돌 목록", "쐐기돌 목록", UIParent, 200, 220, { point = "TOPLEFT", relativeTo = "UIParent", relativePoint = "TOPLEFT", xOfs = 20, yOfs = -140 }, nil, function() return dodoDB and dodoDB.enableKeystoneModule ~= false end)
        end
        initialize()
        update_module_state()
        main_frame:SetScript("OnEvent", on_event)
        self:UnregisterEvent("PLAYER_LOGIN")
    end
end)

-- dodoEditModePanel 내 세부 설정 주입
if dodo.RegisterEditModeModuleSetting then
    dodo.RegisterEditModeModuleSetting("편의기능", {
        {
            name = "쐐기돌 목록 표시",
            get = function()
                return dodoDB and dodoDB.enableKeystoneModule ~= false
            end,
            set = function(checked)
                if dodoDB then
                    dodoDB.enableKeystoneModule = checked
                end
                update_module_state()
            end
        },
        {
            name = "쐐기돌 굴림 알림",
            get = function()
                return dodoDB and dodoDB.useKeyRoll ~= false
            end,
            set = function(checked)
                if dodoDB then
                    dodoDB.useKeyRoll = checked
                end
            end
        }
    })
end
