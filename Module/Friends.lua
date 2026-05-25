-- ==============================
-- Inspired
-- ==============================
-- dodo_Friends (Custom Module)

-- ==============================
-- 설정 및 테이블
-- ==============================
---@diagnostic disable: lowercase-global, param-type-mismatch, redundant-parameter, undefined-field, undefined-global
local addonName, dodo = ...
local module = {}
dodo:RegisterModule("Friends", module)

local Colors = dodo.Colors -- 엔진

-- 로컬라이즈된 클래스명 → 토큰 맵
local localizedClassMap = {}
if LOCALIZED_CLASS_NAMES_MALE then
    for token, name in pairs(LOCALIZED_CLASS_NAMES_MALE) do
        if type(name) == "string" and name ~= "" then localizedClassMap[name] = token end
    end
end
if LOCALIZED_CLASS_NAMES_FEMALE then
    for token, name in pairs(LOCALIZED_CLASS_NAMES_FEMALE) do
        if type(name) == "string" and name ~= "" and not localizedClassMap[name] then localizedClassMap[name] = token end
    end
end

-- ==============================
-- 캐싱
-- ==============================
local C_BattleNet = C_BattleNet
local C_ClassColor = C_ClassColor
local C_CreatureInfo = C_CreatureInfo
local C_FriendList = C_FriendList
local floor = math.floor
local format = string.format
local GetQuestDifficultyColor = GetQuestDifficultyColor
local hooksecurefunc = hooksecurefunc
local ipairs = ipairs
local min = math.min
local pairs = pairs
local pcall = pcall
local select = select
local strsplit = strsplit
local tostring = tostring
local type = type

-- 극비 성능 최적화용 핫패스(Hot Path) 캐시 테이블
local classHexCache = {}
local levelCache = {}
local realmCache = {}

-- ==============================
-- 유틸리티
-- ==============================
local function rgb_to_hex(r, g, b)
    if not r or not g or not b then return nil end
    return format("%02x%02x%02x", min(255, floor(r * 255 + 0.5)), min(255, floor(g * 255 + 0.5)), min(255, floor(b * 255 + 0.5)))
end

local function wrap_color(text, r, g, b)
    if not text or text == "" then return text end
    local hex = rgb_to_hex(r, g, b)
    if not hex then return text end
    return "|cff" .. hex .. text .. "|r"
end

local function wrap_color_by_hex(text, hex)
    if not text or text == "" or not hex then return text end
    return "|cff" .. hex .. text .. "|r"
end

local function get_class_color_from_token(token)
    if not token or token == "" then return nil end
    local colorObj = (Colors and Colors.Class[token]) or (C_ClassColor and C_ClassColor.GetClassColor and C_ClassColor.GetClassColor(token))
    if colorObj and colorObj.r then return colorObj.r, colorObj.g, colorObj.b end
    return nil
end

local function resolve_class_token(class_token, class_id, localized_name)
    if type(class_token) == "string" and class_token ~= "" then
        local token = localizedClassMap[class_token] or class_token:upper()
        if get_class_color_from_token(token) then return token end
    end
    if class_id and C_CreatureInfo and C_CreatureInfo.GetClassInfo then
        local info = C_CreatureInfo.GetClassInfo(class_id)
        if info and info.classFile and get_class_color_from_token(info.classFile) then return info.classFile end
    end
    if type(localized_name) == "string" then
        local token = localizedClassMap[localized_name]
        if token and get_class_color_from_token(token) then return token end
    end
    return nil
end

-- 성능 최적화: 클래스별 HEX 색상 코드 캐싱 (GC 쓰레기 방지)
local function get_class_color_hex(class_token, class_id, localized_name)
    local token = resolve_class_token(class_token, class_id, localized_name)
    if not token then return nil end

    local cached = classHexCache[token]
    if cached then return cached end

    local colorObj = Colors and Colors.Class[token]
    if colorObj and colorObj.colorStr then
        local hex = colorObj.colorStr:sub(5)
        classHexCache[token] = hex
        return hex
    end

    local r, g, b = get_class_color_from_token(token)
    if r then
        local hex = rgb_to_hex(r, g, b)
        classHexCache[token] = hex
        return hex
    end
    return nil
end

-- 성능 최적화: 레벨별 색상 텍스트 캐싱 (GC 쓰레기 방지)
local function format_level(level)
    if not level or level <= 0 then return nil end

    local cached = levelCache[level]
    if cached then return cached end

    local text = wrap_color(tostring(level), 1, 0.82, 0)
    levelCache[level] = text
    return text
end

-- 성능 최적화: 서버명 정규식 치환 캐싱 (GC 및 무거운 연산 방지)
local function clean_realm(realm)
    if type(realm) ~= "string" then return nil end

    local cached = realmCache[realm]
    if cached then return cached end

    local cleaned = realm:gsub("%(%*%)", ""):gsub("%*$", ""):gsub("^%s+", ""):gsub("%s+$", "")
    cleaned = cleaned ~= "" and cleaned or nil
    realmCache[realm] = cleaned
    return cleaned
end

local function build_location_text(area, realm)
    local areaText = (type(area) == "string" and area ~= "") and area or nil
    local cleaned = clean_realm(realm)
    if areaText and cleaned then return areaText .. " - " .. cleaned end
    return areaText or cleaned or nil
end

-- ==============================
-- 기능 1: 친구창+
-- ==============================
-- 별 위치 옮기기
local function adjust_favorite_anchor(button)
    local favorite = button and (button.Favorite or button.favorite)
    if not favorite or not favorite:IsShown() then return end
    if not button.status then return end

    favorite:ClearAllPoints()
    favorite:SetPoint("TOP", button.status, "BOTTOM", -1, 1)
end

-- 친구명 클래스 색상 적용 (WoW 친구)
local function decorate_wow_friend(button)
    local nameFont, infoFont = button.name, button.info
    if not nameFont or not button.id then return end

    local info = C_FriendList.GetFriendInfoByIndex(button.id)
    if not info or not info.name then return end

    local baseName, realm = strsplit("-", info.name, 2)
    baseName = baseName or info.name

    local levelText = format_level(info.level)
    local nameColored = baseName
    if info.connected then
        local hex = get_class_color_hex(
            info.classTag or info.classFileName or info.classFile or info.classToken,
            info.classID,
            info.className or info.classLocalized or info.class
        )
        if hex then nameColored = wrap_color_by_hex(baseName, hex) end
    else
        nameColored = "|cff999999" .. baseName .. "|r"
    end

    local displayName = levelText and (nameColored .. " " .. levelText) or nameColored
    nameFont:SetText(displayName)

    if infoFont then
        local location = build_location_text(info.area, realm)
        local memo = (info.notes and info.notes ~= "") and info.notes or nil
        infoFont:SetText((location and memo) and (location .. " | " .. memo) or (location or memo or ""))
    end

    adjust_favorite_anchor(button)
end

-- 친구명 클래스 색상 적용 (배틀넷 친구)
local function decorate_bnet_friend(button)
    local nameFont, infoFont = button.name, button.info
    if not nameFont or not button.id then return end

    local accountInfo = C_BattleNet.GetFriendAccountInfo(button.id)
    if not accountInfo then return end

    local gameInfo = accountInfo.gameAccountInfo
    local isOnline = gameInfo and gameInfo.isOnline
    local realID = accountInfo.accountName or (accountInfo.battleTag and accountInfo.battleTag:match("^[^#]+")) or ""

    local displayName, infoText = realID, ""

    if gameInfo and gameInfo.clientProgram == BNET_CLIENT_WOW then
        local charName = gameInfo.characterName or ""
        local levelText = format_level(gameInfo.characterLevel)
        local hex = get_class_color_hex(
            gameInfo.classTag or gameInfo.classFile or gameInfo.classToken,
            gameInfo.classID,
            gameInfo.className or gameInfo.classLocalized or gameInfo.class
        )
        if hex then charName = wrap_color_by_hex(charName, hex) end
        if levelText and levelText ~= "" then charName = charName .. " " .. levelText end

        if charName ~= "" then displayName = realID .. " | " .. charName end

        local location = build_location_text(gameInfo.areaName, gameInfo.realmDisplayName)
        local memo = (accountInfo.note and accountInfo.note ~= "") and accountInfo.note or nil
        infoText = (location and memo) and (location .. "  (" .. memo .. ")") or (location or memo or gameInfo.richPresence or "")
    else
        infoText = (gameInfo and gameInfo.richPresence) or accountInfo.note or ""
    end

    if not isOnline then displayName = "|cff999999" .. displayName .. "|r" end

    nameFont:SetText(displayName)
    if infoFont then infoFont:SetText(infoText) end

    adjust_favorite_anchor(button)
end

-- 훅에서 호출되는 라우터 함수
local function update_friend_button(button)
    if not button or not button.buttonType or not dodo.DB or dodo.DB.enableFriendsModule == false then return end
    if button.buttonType == FRIENDS_BUTTON_TYPE_WOW then
        decorate_wow_friend(button)
    elseif button.buttonType == FRIENDS_BUTTON_TYPE_BNET then
        decorate_bnet_friend(button)
    end
end

-- ==============================
-- 초기화 및 이벤트
-- ==============================
local hookInstalled = false
local function ensure_hook()
    if hookInstalled or not FriendsFrame_UpdateFriendButton then return end
    hooksecurefunc("FriendsFrame_UpdateFriendButton", update_friend_button)
    hookInstalled = true
end

local function refresh()
    if not C_FriendList or not C_FriendList.GetNumFriends then return end
    if not pcall(C_FriendList.GetNumFriends) then return end

    if FriendsList_UpdateFriends then
        FriendsList_UpdateFriends()
    elseif FriendsFrame_UpdateFriends then
        FriendsFrame_UpdateFriends()
    elseif FriendsFrame and FriendsFrame.ScrollBox and FriendsFrame.ScrollBox.Update then
        FriendsFrame.ScrollBox:Update()
    end
end

local function initialize()
    if dodo.DB and dodo.DB.enableFriendsModule == nil then
        dodo.DB.enableFriendsModule = false
    end
end

-- ==============================
-- 모듈 생명주기
-- ==============================
local isInitialized = false
function module:OnEnable()
    initialize()

    if dodo.DB and dodo.DB.enableFriendsModule ~= false then
        ensure_hook()
        refresh()
    end

    if isInitialized then return end
    isInitialized = true

    -- dodoEditModePanel 내부에 세부 설정 주입
    if dodo.RegisterEditModeSetting then
        dodo.RegisterEditModeSetting("편의기능", {
            {
                name = "친구창",
                get = function() return dodo.DB and dodo.DB.enableFriendsModule or false end,
                set = function(checked)
                    if dodo.DB then 
                        dodo.DB.enableFriendsModule = checked 
                    end
                    if checked then
                        ensure_hook()
                    end
                    refresh()
                end
            }
        })
    end
end