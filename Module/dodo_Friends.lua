-- dodo_Friends.lua

local addonName = "dodo_Friends"

-- dodoDB 네임스페이스 (기존 dodo 애드온과 공유 예정)
dodoDB = dodoDB or {}
dodoDB.Friends = dodoDB.Friends or {}
local db = dodoDB.Friends

-- ------------------------------------------------------------
-- 캐싱
-- ------------------------------------------------------------
local format       = string.format
local floor        = math.floor
local min          = math.min
local select       = select
local strsplit     = strsplit
local ipairs       = ipairs
local UnitFullName = UnitFullName
local GetRealmName = GetRealmName
local GetQuestDifficultyColor = GetQuestDifficultyColor

-- 로컬라이즈된 클래스명 → 토큰 맵 (한국어 등 대응)
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

-- 플레이어 렐름명 캐싱
local playerRealmNormalized
local function NormalizeRealm(realm)
	if type(realm) ~= "string" then return nil end
	local normalized = realm:gsub("[%s%-']", ""):lower()
	return normalized ~= "" and normalized or nil
end

local function InitPlayerRealm()
	local realm = GetRealmName and GetRealmName()
	if (not realm or realm == "") and UnitFullName then
		realm = select(2, UnitFullName("player"))
	end
	if realm and realm ~= "" then
		playerRealmNormalized = NormalizeRealm(realm)
	end
end

-- ------------------------------------------------------------
-- 유틸리티
-- ------------------------------------------------------------
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
	if CUSTOM_CLASS_COLORS then
		local c = CUSTOM_CLASS_COLORS[token]
		if c and c.r then return c.r, c.g, c.b end
	end
	if RAID_CLASS_COLORS then
		local c = RAID_CLASS_COLORS[token]
		if c and c.r then return c.r, c.g, c.b end
	end
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
	if not GetQuestDifficultyColor then return tostring(level) end
	local color = GetQuestDifficultyColor(level)
	if not color then return tostring(level) end
	return WrapColor(tostring(level), color.r, color.g, color.b)
end

local function CleanRealm(realm)
	if type(realm) ~= "string" then return nil end
	local cleaned = realm:gsub("%(%*%)", ""):gsub("%*$", ""):gsub("^%s+", ""):gsub("%s+$", "")
	return cleaned ~= "" and cleaned or nil
end

local function BuildLocationText(area, realm)
	local areaText = (type(area) == "string" and area ~= "") and area or nil
	local realmText = nil

	local cleaned = CleanRealm(realm)
	if cleaned then
		-- 같은 렐름도 표시 (숨김옵션 없음)
		realmText = cleaned
	end

	if areaText and realmText then return ("%s - %s"):format(areaText, realmText) end
	return areaText or realmText or nil
end

-- ------------------------------------------------------------
-- 즐겨찾기 별 앵커 조정
-- ------------------------------------------------------------
local function AdjustFavoriteAnchor(button)
	local favorite = button and (button.Favorite or button.favorite)
	if not favorite then return end
	if not favorite.IsShown or not favorite:IsShown() then return end
	if not button.status then return end

	favorite:ClearAllPoints()
	favorite:SetPoint("TOP", button.status, "BOTTOM", -1, 1)
end

-- ------------------------------------------------------------
-- 버튼 장식
-- ------------------------------------------------------------
local function DecorateWoWFriend(button)
	local nameFont = button and button.name
	local infoFont = button and button.info
	if not nameFont then return end
	if not C_FriendList or not C_FriendList.GetFriendInfoByIndex then return end

	local id = button.id
	if not id then return end

	local info = C_FriendList.GetFriendInfoByIndex(id)
	if not info or not info.name then return end

	-- 이름 / 렐름 분리
	local baseName, realm = strsplit("-", info.name, 2)
	baseName = baseName or info.name

	-- 레벨
	local levelText = FormatLevel(info.level)

	-- 클래스 색상
	local isConnected = info.connected == true
	local nameColored = baseName
	if isConnected then
		local r, g, b = GetClassColor(
			info.classTag or info.classFileName or info.classFile or info.classToken,
			info.classID,
			info.className or info.classLocalized or info.class
		)
		if r then
			nameColored = WrapColor(baseName, r, g, b)
		end
	else
		nameColored = WrapColor(baseName, 0.6, 0.6, 0.6)
	end

	-- 이름줄: "캐릭터명 레벨"
	local displayName = nameColored
	if levelText and levelText ~= "" then
		displayName = ("%s %s"):format(nameColored, levelText)
	end
	nameFont:SetText(displayName)

	-- 정보줄: "위치 - 서버 (메모)"
	if infoFont then
		local location = BuildLocationText(info.area, realm)
		local memo = (info.notes and info.notes ~= "") and info.notes or nil
		local infoText
		if location and memo then
			infoText = ("%s | %s"):format(location, memo)
		else
			infoText = location or memo or nil
		end
		infoFont:SetText(infoText or "")
	end

	AdjustFavoriteAnchor(button)
end

local function DecorateBNetFriend(button)
	if not C_BattleNet or not C_BattleNet.GetFriendAccountInfo then return end
	local nameFont = button and button.name
	local infoFont = button and button.info
	if not nameFont then return end

	local id = button.id
	if not id then return end

	local accountInfo = C_BattleNet.GetFriendAccountInfo(id)
	if not accountInfo then return end

	local gameInfo = accountInfo.gameAccountInfo
	local isOnline = gameInfo and gameInfo.isOnline == true

	-- BattleTag에서 # 앞 이름만 추출
	local realID = accountInfo.accountName
		or (accountInfo.battleTag and accountInfo.battleTag:match("^[^#]+"))
		or ""

	local displayName = realID
	local infoText = ""

	if gameInfo and gameInfo.clientProgram == BNET_CLIENT_WOW then
		local charName = gameInfo.characterName or ""
		local levelText = FormatLevel(gameInfo.characterLevel)
		local r, g, b = GetClassColor(
			gameInfo.classTag or gameInfo.classFile or gameInfo.classToken,
			gameInfo.classID,
			gameInfo.className or gameInfo.classLocalized or gameInfo.class
		)
		if r then charName = WrapColor(charName, r, g, b) end
		if levelText and levelText ~= "" then
			charName = ("%s %s"):format(charName, levelText)
		end

		-- "BattleTag | 캐릭터명 레벨"
		if charName ~= "" then
			displayName = ("%s | %s"):format(realID, charName)
		end

		local location = BuildLocationText(gameInfo.areaName, gameInfo.realmDisplayName)
		local memo = (accountInfo.note and accountInfo.note ~= "") and accountInfo.note or nil
		if location and memo then
			infoText = ("%s  (%s)"):format(location, memo)
		else
			infoText = location or memo or gameInfo.richPresence or ""
		end
	else
		-- WoW 이외 클라이언트
		if gameInfo and gameInfo.richPresence then
			infoText = gameInfo.richPresence
		else
			infoText = accountInfo.note or ""
		end
	end

	if not isOnline then
		displayName = WrapColor(displayName, 0.6, 0.6, 0.6)
	end

	nameFont:SetText(displayName)
	if infoFont then infoFont:SetText(infoText) end

	AdjustFavoriteAnchor(button)
end

local function UpdateFriendButton(button)
	if not button or not button.buttonType then return end
	if button.buttonType == FRIENDS_BUTTON_TYPE_WOW then
		DecorateWoWFriend(button)
	elseif button.buttonType == FRIENDS_BUTTON_TYPE_BNET then
		DecorateBNetFriend(button)
	end
end

-- ------------------------------------------------------------
-- 후킹
-- ------------------------------------------------------------
local hookInstalled = false
local function EnsureHook()
	if hookInstalled then return end
	if type(FriendsFrame_UpdateFriendButton) ~= "function" then return end
	hooksecurefunc("FriendsFrame_UpdateFriendButton", UpdateFriendButton)
	hookInstalled = true
end

local function Refresh()
	if not C_FriendList or not C_FriendList.GetNumFriends then return end
	local ok = pcall(C_FriendList.GetNumFriends)
	if not ok then return end

	if FriendsList_UpdateFriends then
		FriendsList_UpdateFriends()
	elseif FriendsFrame_UpdateFriends then
		FriendsFrame_UpdateFriends()
	elseif FriendsFrame and FriendsFrame.ScrollBox and FriendsFrame.ScrollBox.Update then
		FriendsFrame.ScrollBox:Update()
	end
end

-- ------------------------------------------------------------
-- 초기화
-- ------------------------------------------------------------
local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function(self, event, arg1)
	if event == "ADDON_LOADED" and arg1 == addonName then
		dodoDB = dodoDB or {}
		dodoDB.Friends = dodoDB.Friends or {}
		db = dodoDB.Friends
	elseif event == "PLAYER_LOGIN" then
		InitPlayerRealm()
		EnsureHook()
		Refresh()
	end
end)