-- ==============================
-- Inspired
-- ==============================
-- Chattynator (https://www.curseforge.com/wow/addons/chattynator)
-- Guild Button (https://wago.io/Cx_wsXks4)

-- ==============================
-- 설정 및 테이블
-- ==============================
---@diagnostic disable: lowercase-global, param-type-mismatch, redundant-parameter, undefined-field, undefined-global
local addonName, dodo = ...
dodoDB = dodoDB or {}

-- ==============================
-- 캐싱
-- ==============================
local ButtonFrameTemplate_HidePortrait = ButtonFrameTemplate_HidePortrait
local C_Timer = C_Timer
local ChatFrame_AddMessageEventFilter = ChatFrame_AddMessageEventFilter
local CreateFrame = CreateFrame
local GameTooltip = GameTooltip
local GetClassColor = GetClassColor
local GetGuildInfo = GetGuildInfo
local GetGuildRosterInfo = GetGuildRosterInfo
local GetGuildRosterMOTD = GetGuildRosterMOTD
local GetNumGuildMembers = GetNumGuildMembers
local hooksecurefunc = hooksecurefunc
local IsControlKeyDown = IsControlKeyDown
local NUM_CHAT_WINDOWS = NUM_CHAT_WINDOWS
local ToggleGuildFrame = ToggleGuildFrame
local UIParent = UIParent
local _G = _G
local ipairs = ipairs
local pairs = pairs
local table_insert = table.insert
local table_sort = table.sort
local tostring = tostring
local type = type
local issecretvalue = issecretvalue or function() return false end

-- ==============================
-- 프레임 및 이벤트 핸들러 정의
-- ==============================
local GuildButton
local GuildButtonText
local GuildButtonTexture

-- ==============================
-- 기능 1: 링크 복사
-- ==============================
local URL_PATTERNS = {
    "^(%a[%w+.-]+://[^%s|]+)",
    "%f[%S](%a[%w+.-]+://[^%s|]+)",
    "^(www%.[-%w_%%]+%.(%a%a+)/[^%s|]+)",
    "%f[%S](www%.[-%w_%%]+%.(%a%a+)/[^%s|]+)",
    "^(www%.[-%w_%%]+%.(%a%a+))",
    "%f[%S](www%.[-%w_%%]+%.(%a%a+))",
    "^(%w[%w%._-]+%.(%a%a+)/[^%s|]+)",
    "%f[%S](%w[%w%._-]+%.(%a%a+)/[^%s|]+)",
    "^(%w[%w%._-]+%.(%a%a+))",
    "%f[%S](%w[%w%._-]+%.(%a%a+))",
}

local URL_TRAILING = {
    ["."] = true, [","] = true, [";"] = true, [":"] = true,
    ["!"] = true, ["?"] = true, [")"] = true,
    ["\""] = true, ["'"] = true, ["]"] = true, ["}"] = true,
}

local function split_trailing_url_punctuation(url)
    url = tostring(url or "")
    local trailing = ""
    while #url > 0 do
        local c = url:sub(-1)
        if URL_TRAILING[c] then
            trailing = c .. trailing
            url = url:sub(1, -2)
        else
            break
        end
    end
    return url, trailing
end

local function format_url(url)
    local actualURL, trailing = split_trailing_url_punctuation(url)
    actualURL = actualURL:gsub("%%", "%%%%") -- % 이스케이프
    return "|cff149bfd|Hurl:" .. actualURL .. "|h[" .. actualURL .. "]|h|r" .. trailing
end

local function create_url_copy_frame()
    if dodo.URLCopyFrame then return dodo.URLCopyFrame end
    local f = CreateFrame("Frame", "dodoChatURLCopyFrame", UIParent, "PortraitFrameTemplate")
    ButtonFrameTemplate_HidePortrait(f)

    f:SetSize(300, 80)
    f:SetPoint("TOP", UIParent, "TOP", 0, -150)
    f:SetFrameStrata("DIALOG")
    f:Hide()

    -- 제목
    f.TitleContainer.TitleText:SetText("URL 복사 (Ctrl+C)")

    -- 입력창 (InputBoxTemplate)
    local eb = CreateFrame("EditBox", nil, f, "InputBoxTemplate")
    eb:SetPoint("BOTTOMLEFT", 25, 15)
    eb:SetPoint("BOTTOMRIGHT", -15, 15)
    eb:SetHeight(24)
    eb:SetAutoFocus(true)
    eb:SetScript("OnEscapePressed", function() f:Hide() end)
    eb:SetScript("OnEnterPressed", function() f:Hide() end)
    eb:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)

    -- Ctrl+C 누르면 자동으로 닫히게 설정 (가비지 프리: 정적 함수 참조)
    local function hide_frame() f:Hide() end
    eb:SetScript("OnKeyDown", function(self, key)
        if IsControlKeyDown() and key == "C" then
            C_Timer.After(0.1, hide_frame)
        end
    end)
    f.EditBox = eb

    dodo.URLCopyFrame = f
    return f
end

-- 하이퍼링크 클릭 핸들러
local function OnHyperlinkClick(link, text, button, chatFrame)
    if type(link) == "string" and link:sub(1, 4) == "url:" then
        local url = link:sub(5):gsub("||", "|")
        local f = create_url_copy_frame()
        f.EditBox:SetText(url)
        f:Show()
        f.EditBox:SetFocus()
        f.EditBox:HighlightText()
        return true
    end
end

-- SetItemRef 훅 (기본 UI 클릭 처리)
hooksecurefunc("SetItemRef", OnHyperlinkClick)

-- EventRegistry 훅 (가비지 프리: 정적 함수 참조)
local function on_set_item_ref(_, ...)
    OnHyperlinkClick(...)
end
if EventRegistry and EventRegistry.RegisterCallback then
    EventRegistry:RegisterCallback("SetItemRef", on_set_item_ref)
end

-- ==============================
-- 기능 2: 채널명 단축 및 메시지 필터링
-- ==============================
local channelAbbreviations = {
    ["공개"] = "공개",
    ["거래"] = "거래",
    ["수비"] = "수비",
    ["파티"] = "파티",
    ["공격대"] = "공",
    ["인스턴스"] = "인스",
    ["길드"] = "길",
    ["공지"] = "공",
}

local channelCache = {} -- 채널명 단축 결과 캐싱

local function shorten_channel_match(chan, name)
    if channelCache[name] then 
        return "|Hchannel:" .. chan .. "|h[" .. channelCache[name] .. "]|h" 
    end

    for full, short in pairs(channelAbbreviations) do
        if name:find(full) then
            channelCache[name] = short
            return "|Hchannel:" .. chan .. "|h[" .. short .. "]|h"
        end
    end

    local index = name:match("^(%d+)%.")
    if index then
        channelCache[name] = index
        return "|Hchannel:" .. chan .. "|h[" .. index .. "]|h"
    end

    channelCache[name] = name
    return "|Hchannel:" .. chan .. "|h[" .. name .. "]|h"
end

local function shorten_channels(text)
    if not text or not dodo.DB.enableChatModule or not dodo.DB.useShortenChannels or type(text) ~= "string" or issecretvalue(text) then 
        return text 
    end
    return text:gsub("|Hchannel:(.-)|h%[(.-)%]|h", shorten_channel_match)
end

local function FilterMessage(self, event, msg, author, ...)
    if not dodo.DB.enableChatModule or issecretvalue(msg) then return false, msg, author, ... end

    -- URL 링크화
    if dodo.DB.useLinkURLs and type(msg) == "string" and not msg:find("|H") then
        if msg:find("%.") or msg:find("://") or msg:find("www") then
            for _, pattern in ipairs(URL_PATTERNS) do
                msg = msg:gsub(pattern, format_url)
            end
        end
    end

    return false, msg, author, ...
end

-- 하이퍼링크 마우스오버 툴팁 핸들러 (가비지 프리: 정적 함수로 분리)
local function on_hyperlink_enter(self, linkData)
    if not linkData:find("^url:") then
        GameTooltip:SetOwner(self, "ANCHOR_CURSOR")
        GameTooltip:SetHyperlink(linkData)
        GameTooltip:Show()
    end
end
local function on_hyperlink_leave()
    GameTooltip:Hide()
end

local function on_hyperlink_click(self, link, text, button)
    if dodo.DB.enableChatModule then
        OnHyperlinkClick(link, text, button, self)
    end
end

local function style_chat_frames()
    for i = 1, NUM_CHAT_WINDOWS do
        local frame = _G["ChatFrame"..i]
        if frame then
            if not dodo.DB.enableChatModule then
                -- 순정 상태로 폰트 및 그림자 스타일 롤백
                local font, size = frame:GetFont()
                frame:SetFont(font, size or 14, "")
                frame:SetShadowOffset(1, -1)
                frame:SetShadowColor(0, 0, 0, 0.6)
                if frame.UpdateFont then
                    frame:UpdateFont()
                end
            else
                frame:SetHyperlinksEnabled(true)
                local name = frame:GetName()
                local eb = _G[name.."EditBox"]
                if eb then
                    eb:SetAltArrowKeyMode(false)
                end

                -- 그림자 설정
                if dodo.DB.useFontShadow then
                    frame:SetShadowOffset(1, -1)
                    frame:SetShadowColor(0, 0, 0, 0.8)
                else
                    frame:SetShadowOffset(0, 0)
                    frame:SetShadowColor(0, 0, 0, 0)
                end

                -- 폰트 크기 및 외곽선 설정
                local font = frame:GetFont()
                local size = dodo.DB.fontSize or 13
                local flags = dodo.DB.useFontOutline and "OUTLINE" or ""
                frame:SetFont(font, size, flags)

                if frame.UpdateFont then
                    frame:UpdateFont()
                end
            end

            -- 하이퍼링크 마우스오버 툴팁 설정 (1회만 등록)
            if not frame.dodoHyperlinkHooked then
                frame.dodoHyperlinkHooked = true
                frame:SetScript("OnHyperlinkEnter", on_hyperlink_enter)
                frame:SetScript("OnHyperlinkLeave", on_hyperlink_leave)
            end

            -- 하이퍼링크 클릭 훅킹
            if not frame.OldOnHyperlinkClickHooked then
                frame.OldOnHyperlinkClickHooked = true
                frame:HookScript("OnHyperlinkClick", on_hyperlink_click)
            end

            -- 채널명 축약 훅킹
            if not frame.OldAddMessage then
                frame.OldAddMessage = frame.AddMessage
                frame.AddMessage = function(self, text, ...)
                    return self:OldAddMessage(shorten_channels(text), ...)
                end
            end
        end
    end
end

-- ==============================
-- 기능 4: 길드버튼
-- ==============================
local function escape_member_note(note)
    return note == nil and "" or "(" .. note .. ")"
end

local function set_guild_button_text()
    if not GuildButton then return end
    local _, numOnlineMembers = GetNumGuildMembers()
    if GuildButtonText == nil then
        GuildButtonText = GuildButton:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        GuildButtonText:SetPoint("BOTTOM", 0, 0)
    end
    GuildButtonText:SetText(numOnlineMembers)
    GuildButtonText:SetHeight(9)
end

local function HideTooltip()
    GameTooltip:Hide()
end

local function ShowTooltip()
    if not GuildButton then return end
    local guildName, _ = GetGuildInfo('player')
    local total, online = GetNumGuildMembers()
    local textColorR, textColorG, textColorB, textColorA = 1, 1, 1, 1
    GameTooltip:SetOwner(GuildButton, "ANCHOR_RIGHT")

    -- Title
    GameTooltip:AddDoubleLine(guildName, online..'/'..total, textColorR, textColorG, textColorB, textColorR, textColorG, textColorB)
    GameTooltip:AddLine(' ')

    -- Guild Message of the Day
    local guildMessage = GetGuildRosterMOTD()
    if guildMessage ~= '' then
        GameTooltip:AddLine(guildMessage, textColorR, textColorG, textColorB, textColorA)
        GameTooltip:AddLine(' ')
    end

    -- 접속 멤버 인덱스 추출
    local tempMembers = {}
    for i = 1, total do
        local memberName, _, _, _, _, _, _, _, isMemberConnected = GetGuildRosterInfo(i)
        if memberName and isMemberConnected then
            table_insert(tempMembers, i)
        end
    end

    -- 정렬 (가비지 프리: 정적 함수로 분리)
    local function sort_by_name(a, b)
        return GetGuildRosterInfo(a) < GetGuildRosterInfo(b)
    end
    table_sort(tempMembers, sort_by_name)

    -- 출력
    local shownCount = 0
    for _, i in ipairs(tempMembers) do
        shownCount = shownCount + 1
        if shownCount > 50 then
            GameTooltip:AddLine('...', online - 50, textColorR, textColorG, textColorB, textColorA)
            break
        end

        local memberName, _, _, _, _, memberZone, memberNote, _, _, _, memberClass = GetGuildRosterInfo(i)
        local cr, cg, cb, _ = GetClassColor(memberClass)
        GameTooltip:AddDoubleLine(memberName .. " " .. escape_member_note(memberNote), memberZone, cr, cg, cb, textColorR, textColorG, textColorB)
    end
    GameTooltip:Show()
end

local function OnGuildButtonClick(self, button)
    ToggleGuildFrame()
end

local function OnGuildRosterUpdate()
    set_guild_button_text()
end

local function create_guild_button()
    if GuildButton then return end

    GuildButton = CreateFrame("Button", "SmartMicroMenuGuildButton", UIParent)
    GuildButton:SetFrameStrata("LOW")
    GuildButton:SetPoint("TOP", "QuickJoinToastButton", "BOTTOM", 0, 0)
    GuildButton:SetWidth(32)
    GuildButton:SetHeight(32)

    GuildButtonTexture = GuildButton:CreateTexture(nil, "BACKGROUND")
    GuildButtonTexture:SetAtlas("quickjoin-button-friendslist-up")
    GuildButtonTexture:SetAllPoints(GuildButton)
    GuildButtonTexture:SetVertexColor(0,1,0)
    GuildButton.texture = GuildButtonTexture

    GuildButton:RegisterEvent("GUILD_ROSTER_UPDATE")
    GuildButton:SetScript("OnEvent", OnGuildRosterUpdate)
    GuildButton:SetScript("OnEnter",  ShowTooltip)
    GuildButton:SetScript("OnLeave",  HideTooltip)
    GuildButton:SetScript("OnMouseUp", OnGuildButtonClick)

    set_guild_button_text()
end

-- ==============================
-- 모듈 On/Off 활성화 상태 제어
-- ==============================
local function update_module_state()
    local isEnabled = (dodo.DB.enableChatModule and dodo.DB.useGuildButton ~= false)
    if GuildButton then
        GuildButton:SetShown(isEnabled)
        GuildButton:SetAlpha(isEnabled and 1 or 0)
    end
end

-- ==============================
-- 초기화
-- ==============================
local function create_ui()
    create_guild_button()
end

local function initialize()
    -- 기본 설정값 초기화 (enable[모듈명]Module, use[기능명] 표준 규격 준수)
    dodo.DB.enableChatModule = (dodo.DB.enableChatModule ~= false)
    dodo.DB.useShortenChannels = (dodo.DB.useShortenChannels ~= false)
    dodo.DB.useLinkURLs = (dodo.DB.useLinkURLs ~= false)
    dodo.DB.useFontOutline = (dodo.DB.useFontOutline ~= false)
    dodo.DB.useFontShadow = (dodo.DB.useFontShadow == true)
    dodo.DB.fontSize = dodo.DB.fontSize or 13
    dodo.DB.useGuildButton = (dodo.DB.useGuildButton ~= false)

    create_ui()
end

local function update_feature()
    style_chat_frames()
end

-- ==============================
-- 외부 노출
-- ==============================
local function update_chat_module_state()
    update_feature()
    update_module_state()
end

dodo.UpdateChatModuleState = update_chat_module_state

-- ==============================
-- 이벤트 및 자동 초기화
-- ==============================
local isInitialized = false
local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("ADDON_LOADED")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == addonName then
        dodoDB = dodoDB or {}
        dodo.DB = dodo.DB or dodoDB
    elseif event == "PLAYER_LOGIN" then
        dodo.DB = dodo.DB or dodoDB or {}

        initialize()
        update_feature()
        update_module_state()

        if isInitialized then return end
        isInitialized = true

        if dodo.DB.enableChatModule then
            local events = {
                "CHAT_MSG_CHANNEL",
                "CHAT_MSG_GUILD",
                "CHAT_MSG_OFFICER",
                "CHAT_MSG_PARTY",
                "CHAT_MSG_PARTY_LEADER",
                "CHAT_MSG_RAID",
                "CHAT_MSG_RAID_LEADER",
                "CHAT_MSG_INSTANCE_CHAT",
                "CHAT_MSG_INSTANCE_CHAT_LEADER",
                "CHAT_MSG_SAY",
                "CHAT_MSG_YELL",
                "CHAT_MSG_WHISPER",
                "CHAT_MSG_BN_WHISPER",
            }
            for _, eventName in ipairs(events) do
                ChatFrame_AddMessageEventFilter(eventName, FilterMessage)
            end

            -- 마우스휠 스크롤 추가 (가비지 프리: 정적 함수로 분리)
            local function on_mouse_wheel(selfScroll, delta)
                if delta > 0 then
                    if IsControlKeyDown() then selfScroll:ScrollToTop() else selfScroll:ScrollUp() end
                else
                    if IsControlKeyDown() then selfScroll:ScrollToBottom() else selfScroll:ScrollDown() end
                end
            end
            for i = 1, NUM_CHAT_WINDOWS do
                local frame = _G["ChatFrame"..i]
                if frame then
                    frame:SetScript("OnMouseWheel", on_mouse_wheel)
                    frame:EnableMouseWheel(true)
                end
            end
        end



        if dodo.RegisterEditModeSetting then
            dodo.RegisterEditModeSetting("인터페이스", {
                {
                    name = "대화창",
                    get = function() return dodo.DB and dodo.DB.enableChatModule ~= false end,
                    set = function(checked)
                        if dodo.DB then dodo.DB.enableChatModule = checked end
                        update_chat_module_state()
                    end
                }
            })
        end
    end
end)

-- ==============================
-- 외부 노출 및 설정 동적 등록 (Option.lua 연동)
-- ==============================
local SettingsPanel = SettingsPanel
local CreateSettingsListSectionHeaderInitializer = CreateSettingsListSectionHeaderInitializer
local Checkbox = Checkbox
local Slider = Slider

dodo.OptionRegistrations = dodo.OptionRegistrations or {}
dodo.OptionRegistrations["interface"] = dodo.OptionRegistrations["interface"] or {}
table.insert(dodo.OptionRegistrations["interface"], function(category)
    local layout = SettingsPanel:GetLayout(category)
    if not layout then return end

    layout:AddInitializer(CreateSettingsListSectionHeaderInitializer("대화창 설정"))
    Checkbox(category, "enableChatModule", "대화창 모듈 활성화", "채널명 단축, 링크 복사, 길드원 버튼 등 대화창 편의 기능을 활성화합니다.", true, dodo.UpdateChatModuleState)
    Checkbox(category, "useShortenChannels", "채널명 축약", "대화창 채널명을 숫자로 축약합니다 (예: [1. 공개] -> [1]).", true, dodo.UpdateChatModuleState)
    Checkbox(category, "useLinkURLs", "URL 링크화", "채팅창에 웹 주소가 나오면 클릭해서 복사할 수 있는 링크로 변환합니다.", true, dodo.UpdateChatModuleState)
    Checkbox(category, "useGuildButton", "길드 버튼 표시", "길드원 현황 및 길드창 바로가기 버튼을 추가합니다.", true, dodo.UpdateChatModuleState)
    Checkbox(category, "useFontOutline", "글씨 외곽선 적용", "채팅창 폰트에 외곽선을 입혀 가독성을 높입니다.", true, dodo.UpdateChatModuleState)
    Checkbox(category, "useFontShadow", "글씨 그림자 적용", "채팅창 폰트에 그림자를 적용합니다.", false, dodo.UpdateChatModuleState)
    Slider(category, "fontSize", "글씨 크기", "채팅창 글씨 크기를 설정합니다.", 10, 18, 1, 13, "Integer", dodo.UpdateChatModuleState)
end)
