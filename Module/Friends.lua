-- ==============================
-- Inspired
-- ==============================
-- dodo_Friends (Custom Module)

-- ==============================
-- 설정 및 테이블
-- ==============================
---@diagnostic disable: lowercase-global, param-type-mismatch, redundant-parameter, undefined-field, undefined-global
local addonName, dodo = ...
dodoDB = dodoDB or {}


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
-- 캐싱 (Upvalues)
-- ==============================
local format, floor, min, strsplit, type, tostring = string.format, math.floor, math.min, strsplit, type, tostring
local ipairs, pairs = ipairs, pairs
local GetQuestDifficultyColor = GetQuestDifficultyColor
local C_FriendList = C_FriendList
local C_BattleNet = C_BattleNet
local C_ClassColor = C_ClassColor
local C_CreatureInfo = C_CreatureInfo

-- ==============================
-- 유틸리티
-- ==============================
local function RGBToHex(r, g, b)
    if not r or not g or not b then return nil end
    return format("%02x%02x%02x", min(255, floor(r * 255 + 0.5)), min(255, floor(g * 255 + 0.5)), min(255, floor(b * 255 + 0.5)))
end

local function WrapColor(text, r, g, b)
    if not text or text == "" then return text end
    local hex = RGBToHex(r, g, b)
    if not hex then return text end
    return ("|cff%s%s|r"):format(hex, text)
end

local function GetClassColorFromToken(token)
    if not token or token == "" then return nil end
    local colorObj = C_ClassColor and C_ClassColor.GetClassColor and C_ClassColor.GetClassColor(token)
    if colorObj and colorObj.r then return colorObj.r, colorObj.g, colorObj.b end
    return nil
end

local function ResolveClassToken(classToken, classID, localizedName)
    if type(classToken) == "string" and classToken ~= "" then
        local token = localizedClassMap[classToken] or classToken:upper()
        if GetClassColorFromToken(token) then return token end
    end
    if classID and C_CreatureInfo and C_CreatureInfo.GetClassInfo then
        local info = C_CreatureInfo.GetClassInfo(classID)
        if info and info.classFile and GetClassColorFromToken(info.classFile) then return info.classFile end
    end
    if type(localizedName) == "string" then
        local token = localizedClassMap[localizedName]
        if token and GetClassColorFromToken(token) then return token end
    end
    return nil
end

local function GetClassColor(classToken, classID, localizedName)
    local token = ResolveClassToken(classToken, classID, localizedName)
    if not token then return nil end
    return GetClassColorFromToken(token)
end

local function FormatLevel(level)
    if not level or level <= 0 then return nil end
    return WrapColor(tostring(level), 1, 0.82, 0)
end

local function CleanRealm(realm)
    if type(realm) ~= "string" then return nil end
    local cleaned = realm:gsub("%(%*%)", ""):gsub("%*$", ""):gsub("^%s+", ""):gsub("%s+$", "")
    return cleaned ~= "" and cleaned or nil
end

local function BuildLocationText(area, realm)
    local areaText = (type(area) == "string" and area ~= "") and area or nil
    local cleaned = CleanRealm(realm)
    if areaText and cleaned then return ("%s - %s"):format(areaText, cleaned) end
    return areaText or cleaned or nil
end

-- ==============================
-- 동작
-- ==============================
-- 별 위치 옮기기
local function AdjustFavoriteAnchor(button)
    local favorite = button and (button.Favorite or button.favorite)
    if not favorite or not favorite:IsShown() then return end
    if not button.status then return end

    favorite:ClearAllPoints()
    favorite:SetPoint("TOP", button.status, "BOTTOM", -1, 1)
end

-- 친구명 클래스 색상 적용
local function DecorateWoWFriend(button)
    local nameFont, infoFont = button.name, button.info
    if not nameFont or not button.id then return end

    local info = C_FriendList.GetFriendInfoByIndex(button.id)
    if not info or not info.name then return end

    local baseName, realm = strsplit("-", info.name, 2)
    baseName = baseName or info.name

    local levelText = FormatLevel(info.level)
    local nameColored = baseName
    if info.connected then
        local r, g, b = GetClassColor(
            info.classTag or info.classFileName or info.classFile or info.classToken,
            info.classID,
            info.className or info.classLocalized or info.class
        )
        if r then nameColored = WrapColor(baseName, r, g, b) end
    else
        nameColored = WrapColor(baseName, 0.6, 0.6, 0.6)
    end

    local displayName = (levelText and levelText ~= "") and ("%s %s"):format(nameColored, levelText) or nameColored
    nameFont:SetText(displayName)

    if infoFont then
        local location = BuildLocationText(info.area, realm)
        local memo = (info.notes and info.notes ~= "") and info.notes or nil
        infoFont:SetText((location and memo) and ("%s | %s"):format(location, memo) or (location or memo or ""))
    end

    AdjustFavoriteAnchor(button)
end

local function DecorateBNetFriend(button)
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
        local levelText = FormatLevel(gameInfo.characterLevel)
        local r, g, b = GetClassColor(
            gameInfo.classTag or gameInfo.classFile or gameInfo.classToken,
            gameInfo.classID,
            gameInfo.className or gameInfo.classLocalized or gameInfo.class
        )
        if r then charName = WrapColor(charName, r, g, b) end
        if levelText and levelText ~= "" then charName = ("%s %s"):format(charName, levelText) end

        if charName ~= "" then displayName = ("%s | %s"):format(realID, charName) end

        local location = BuildLocationText(gameInfo.areaName, gameInfo.realmDisplayName)
        local memo = (accountInfo.note and accountInfo.note ~= "") and accountInfo.note or nil
        infoText = (location and memo) and ("%s  (%s)"):format(location, memo) or (location or memo or gameInfo.richPresence or "")
    else
        infoText = (gameInfo and gameInfo.richPresence) or accountInfo.note or ""
    end

    if not isOnline then displayName = WrapColor(displayName, 0.6, 0.6, 0.6) end

    nameFont:SetText(displayName)
    if infoFont then infoFont:SetText(infoText) end

    AdjustFavoriteAnchor(button)
end

local function UpdateFriendButton(button)
    if not button or not button.buttonType or dodoDB.useFriends == false then return end
    if button.buttonType == FRIENDS_BUTTON_TYPE_WOW then
        DecorateWoWFriend(button)
    elseif button.buttonType == FRIENDS_BUTTON_TYPE_BNET then
        DecorateBNetFriend(button)
    end
end

-- ==============================
-- 초기화 및 이벤트
-- ==============================
local hookInstalled = false
local function EnsureHook()
    if hookInstalled or not FriendsFrame_UpdateFriendButton then return end
    hooksecurefunc("FriendsFrame_UpdateFriendButton", UpdateFriendButton)
    hookInstalled = true
end

local function Refresh()
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

local initFriends = CreateFrame("Frame")
initFriends:RegisterEvent("ADDON_LOADED")
initFriends:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == addonName then
        dodoDB = dodoDB or {}
        self:RegisterEvent("PLAYER_LOGIN")
        self:UnregisterEvent("ADDON_LOADED")
    elseif event == "PLAYER_LOGIN" then
        if dodoDB.useFriends ~= false then
            EnsureHook()
            Refresh()
        end
        self:UnregisterAllEvents()
        self:SetScript("OnEvent", nil)
    end
end)

-- 외부 노출
dodo.UpdateFriends = Refresh