-- ==============================
-- Inspired
-- ==============================
-- Enhance QoL (https://www.curseforge.com/wow/addons/eqol)

-- ==============================
-- 설정 및 테이블
-- ==============================
---@diagnostic disable: lowercase-global, param-type-mismatch, redundant-parameter, undefined-field, undefined-global
local addonName, dodo = ...
dodoDB = dodoDB or {}

-- 로컬라이즈된 클래스명 → 토큰 맵
local localized_class_map = {}
if LOCALIZED_CLASS_NAMES_MALE then
    for token, name in pairs(LOCALIZED_CLASS_NAMES_MALE) do
        if type(name) == "string" and name ~= "" then localized_class_map[name] = token end
    end
end
if LOCALIZED_CLASS_NAMES_FEMALE then
    for token, name in pairs(LOCALIZED_CLASS_NAMES_FEMALE) do
        if type(name) == "string" and name ~= "" and not localized_class_map[name] then localized_class_map[name] = token end
    end
end

-- ==============================
-- 캐싱 (Upvalues)
-- ==============================
-- ABC 순 정렬
local BNET_CLIENT_WOW = BNET_CLIENT_WOW
local C_BattleNet = C_BattleNet
local Checkbox = Checkbox
local C_ClassColor = C_ClassColor
local C_CreatureInfo = C_CreatureInfo
local C_FriendList = C_FriendList
local floor = math.floor
local format = string.format
local FRIENDS_BUTTON_TYPE_BNET = FRIENDS_BUTTON_TYPE_BNET
local FRIENDS_BUTTON_TYPE_WOW = FRIENDS_BUTTON_TYPE_WOW
local FriendsFrame_UpdateFriendButton = FriendsFrame_UpdateFriendButton
local GameTooltip = GameTooltip
local GetClassColor = GetClassColor
local GetGuildInfo = GetGuildInfo
local GetGuildRosterInfo = GetGuildRosterInfo
local GetGuildRosterMOTD = GetGuildRosterMOTD
local GetNumGuildMembers = GetNumGuildMembers
local ipairs = ipairs
local issecretvalue = issecretvalue or function() return false end
local min = math.min
local pairs = pairs
local strsplit = strsplit
local table_insert = table.insert
local table_sort = table.sort
local ToggleGuildFrame = ToggleGuildFrame
local tostring = tostring
local type = type
local UIParent = UIParent
local wipe = wipe

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
    return ("|cff%s%s|r"):format(hex, text)
end

local function get_class_color_from_token(token)
    if not token or token == "" then return nil end
    local color_obj = C_ClassColor and C_ClassColor.GetClassColor and C_ClassColor.GetClassColor(token)
    if color_obj and color_obj.r then return color_obj.r, color_obj.g, color_obj.b end
    return nil
end

local function resolve_class_token(class_token, class_id, localized_name)
    if type(class_token) == "string" and class_token ~= "" then
        local token = localized_class_map[class_token] or class_token:upper()
        if get_class_color_from_token(token) then return token end
    end
    if class_id and C_CreatureInfo and C_CreatureInfo.GetClassInfo then
        local info = C_CreatureInfo.GetClassInfo(class_id)
        if info and info.classFile and get_class_color_from_token(info.classFile) then return info.classFile end
    end
    if type(localized_name) == "string" then
        local token = localized_class_map[localized_name]
        if token and get_class_color_from_token(token) then return token end
    end
    return nil
end

local function get_class_color(class_token, class_id, localized_name)
    local token = resolve_class_token(class_token, class_id, localized_name)
    if not token then return nil end
    return get_class_color_from_token(token)
end

local function format_level(level)
    if not level or level <= 0 then return nil end
    return wrap_color(tostring(level), 1, 0.82, 0)
end

local function clean_realm(realm)
    if type(realm) ~= "string" then return nil end
    local cleaned = realm:gsub("%(%*%)", ""):gsub("%*$", ""):gsub("^%s+", ""):gsub("%s+$", "")
    return cleaned ~= "" and cleaned or nil
end

local function build_location_text(area, realm)
    local area_text = (type(area) == "string" and area ~= "") and area or nil
    local cleaned = clean_realm(realm)
    if area_text and cleaned then return ("%s - %s"):format(area_text, cleaned) end
    return area_text or cleaned or nil
end

-- ==============================
-- 동작
-- ==============================
-- 별 위치 옮기기
local function adjust_favorite_anchor(button)
    local favorite = button and (button.Favorite or button.favorite)
    if not favorite or not favorite:IsShown() then return end
    if not button.status then return end

    favorite:ClearAllPoints()
    favorite:SetPoint("TOP", button.status, "BOTTOM", -1, 1)
end

-- 친구명 클래스 색상 적용
local function decorate_wow_friend(button)
    local name_font, info_font = button.name, button.info
    if not name_font or not button.id then return end

    local info = C_FriendList.GetFriendInfoByIndex(button.id)
    if not info or not info.name then return end

    local base_name, realm = strsplit("-", info.name, 2)
    base_name = base_name or info.name

    local level_text = format_level(info.level)
    local name_colored = base_name
    if info.connected then
        local r, g, b = get_class_color(
            info.classTag or info.classFileName or info.classFile or info.classToken,
            info.classID,
            info.className or info.classLocalized or info.class
        )
        if r then name_colored = wrap_color(base_name, r, g, b) end
    else
        name_colored = wrap_color(base_name, 0.6, 0.6, 0.6)
    end

    local display_name = (level_text and level_text ~= "") and ("%s %s"):format(name_colored, level_text) or name_colored
    name_font:SetText(display_name)

    if info_font then
        local location = build_location_text(info.area, realm)
        local memo = (info.notes and info.notes ~= "") and info.notes or nil
        info_font:SetText((location and memo) and ("%s | %s"):format(location, memo) or (location or memo or ""))
    end

    adjust_favorite_anchor(button)
end

local function decorate_bnet_friend(button)
    local name_font, info_font = button.name, button.info
    if not name_font or not button.id then return end

    local account_info = C_BattleNet.GetFriendAccountInfo(button.id)
    if not account_info then return end

    local game_info = account_info.gameAccountInfo
    local is_online = game_info and game_info.isOnline
    local real_id = account_info.accountName or (account_info.battleTag and account_info.battleTag:match("^[^#]+")) or ""

    local display_name, info_text = real_id, ""

    if game_info and game_info.clientProgram == BNET_CLIENT_WOW then
        local char_name = game_info.characterName or ""
        local level_text = format_level(game_info.characterLevel)
        local r, g, b = get_class_color(
            game_info.classTag or game_info.classFile or game_info.classToken,
            game_info.classID,
            game_info.className or game_info.classLocalized or game_info.class
        )
        if r then char_name = wrap_color(char_name, r, g, b) end
        if level_text and level_text ~= "" then char_name = ("%s %s"):format(char_name, level_text) end

        if char_name ~= "" then display_name = ("%s | %s"):format(real_id, char_name) end

        local location = build_location_text(game_info.areaName, game_info.realmDisplayName)
        local memo = (account_info.note and account_info.note ~= "") and account_info.note or nil
        info_text = (location and memo) and ("%s  (%s)"):format(location, memo) or (location or memo or game_info.richPresence or "")
    else
        info_text = (game_info and game_info.richPresence) or account_info.note or ""
    end

    if not is_online then display_name = wrap_color(display_name, 0.6, 0.6, 0.6) end

    name_font:SetText(display_name)
    if info_font then info_font:SetText(info_text) end

    adjust_favorite_anchor(button)
end

local function update_friend_button(button)
    if not button or not button.buttonType or dodoDB.useFriends == false then return end
    if button.buttonType == FRIENDS_BUTTON_TYPE_WOW then
        decorate_wow_friend(button)
    elseif button.buttonType == FRIENDS_BUTTON_TYPE_BNET then
        decorate_bnet_friend(button)
    end
end

-- ==============================
-- 초기화 및 이벤트
-- ==============================
local hook_installed = false
local function ensure_hook()
    if hook_installed or not FriendsFrame_UpdateFriendButton then return end
    hooksecurefunc("FriendsFrame_UpdateFriendButton", update_friend_button)
    hook_installed = true
end

local function refresh_friends()
    if dodoDB.useFriends ~= false then
        ensure_hook()
    end
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

local function on_event(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == addonName then
        dodoDB = dodoDB or {}
        self:RegisterEvent("PLAYER_LOGIN")
        self:UnregisterEvent("ADDON_LOADED")
    elseif event == "PLAYER_LOGIN" then
        if dodoDB.useFriends ~= false then
            ensure_hook()
            refresh_friends()
        end
        self:UnregisterAllEvents()
        self:SetScript("OnEvent", nil)
    end
end

local init_friends = CreateFrame("Frame")
init_friends:RegisterEvent("ADDON_LOADED")
init_friends:SetScript("OnEvent", on_event)

-- ==============================
-- 설정 등록
-- ==============================
dodo.OptionRegistrations = dodo.OptionRegistrations or {}
dodo.OptionRegistrations["인터페이스.편의기능"] = dodo.OptionRegistrations["인터페이스.편의기능"] or {}
table.insert(dodo.OptionRegistrations["인터페이스.편의기능"], function(category)
    Checkbox(category, "useFriends", "친구창+", "친구 목록에 클래스 색상 및 추가 정보를 표시합니다.", true, function()
        refresh_friends()
    end)
end)