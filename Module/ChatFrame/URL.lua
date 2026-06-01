-- ==============================
-- 설정 및 테이블
-- ==============================
---@diagnostic disable: lowercase-global, param-type-mismatch, redundant-parameter, undefined-field, undefined-global
local addonName, dodo = ...
dodoDB = dodoDB or {}
dodo.DB = dodo.DB or dodoDB

local Config = {
    urlPatterns = {
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
    },
    urlTrailing = {
        ["."] = true, [","] = true, [";"] = true, [":"] = true,
        ["!"] = true, ["?"] = true, [")"] = true,
        ["\""] = true, ["'"] = true, ["]"] = true, ["}"] = true,
    }
}

-- ==============================
-- 캐싱
-- ==============================
local ButtonFrameTemplate_HidePortrait = ButtonFrameTemplate_HidePortrait
local C_Timer = C_Timer
local ChatFrame_AddMessageEventFilter = ChatFrame_AddMessageEventFilter
local ChatFrame_RemoveMessageEventFilter = ChatFrame_RemoveMessageEventFilter
local CreateFrame = CreateFrame
local IsControlKeyDown = IsControlKeyDown
local UIParent = UIParent
local hooksecurefunc = hooksecurefunc
local ipairs = ipairs
local issecretvalue = issecretvalue or function() return false end
local tostring = tostring
local type = type

-- ==============================
-- URL 파싱 및 복사 프레임 제어
-- ==============================
local function split_trailing_url_punctuation(url)
    url = tostring(url or "")
    local trailing = ""
    while #url > 0 do
        local c = url:sub(-1)
        if Config.urlTrailing[c] then
            trailing = c .. trailing
            url = url:sub(1, -2)
        else
            break
        end
    end
    return url, trailing
end

local function format_url(url)
    local actual_url, trailing = split_trailing_url_punctuation(url)
    actual_url = actual_url:gsub("%%", "%%%%")
    return "|cff149bfd|Hurl:" .. actual_url .. "|h[" .. actual_url .. "]|h|r" .. trailing
end

local function create_url_copy_frame()
    if dodo.URLCopyFrame then return dodo.URLCopyFrame end
    local f = CreateFrame("Frame", "dodoChatURLCopyFrame", UIParent, "PortraitFrameTemplate")
    ButtonFrameTemplate_HidePortrait(f)

    f:SetSize(300, 80)
    f:SetPoint("TOP", UIParent, "TOP", 0, -150)
    f:SetFrameStrata("DIALOG")
    f:Hide()

    f.TitleContainer.TitleText:SetText("URL 복사 (Ctrl+C)")

    local eb = CreateFrame("EditBox", nil, f, "InputBoxTemplate")
    eb:SetPoint("BOTTOMLEFT", 25, 15)
    eb:SetPoint("BOTTOMRIGHT", -15, 15)
    eb:SetHeight(24)
    eb:SetAutoFocus(true)
    eb:SetScript("OnEscapePressed", function() f:Hide() end)
    eb:SetScript("OnEnterPressed", function() f:Hide() end)
    eb:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)

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

local function handle_hyperlink_click(link, text, button, chatFrame)
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

hooksecurefunc("SetItemRef", handle_hyperlink_click)

local function on_set_item_ref(_, ...)
    handle_hyperlink_click(...)
end
if EventRegistry and EventRegistry.RegisterCallback then
    EventRegistry:RegisterCallback("SetItemRef", on_set_item_ref)
end

-- ==============================
-- 대화 이벤트 필터링
-- ==============================
local function filter_message(self, event, msg, author, ...)
    if not dodo.DB.enableChatModule or issecretvalue(msg) then return false, msg, author, ... end

    if dodo.DB.useLinkURLs and type(msg) == "string" and not msg:find("|H") then
        if msg:find("%.") or msg:find("://") or msg:find("www") then
            for _, pattern in ipairs(Config.urlPatterns) do
                msg = msg:gsub(pattern, format_url)
            end
        end
    end

    return false, msg, author, ...
end

local function apply_chat_filters(enabled)
    local filterEvents = {
        "CHAT_MSG_CHANNEL", "CHAT_MSG_GUILD", "CHAT_MSG_OFFICER", "CHAT_MSG_PARTY",
        "CHAT_MSG_PARTY_LEADER", "CHAT_MSG_RAID", "CHAT_MSG_RAID_LEADER",
        "CHAT_MSG_INSTANCE_CHAT", "CHAT_MSG_INSTANCE_CHAT_LEADER", "CHAT_MSG_SAY",
        "CHAT_MSG_YELL", "CHAT_MSG_WHISPER", "CHAT_MSG_BN_WHISPER",
    }
    for _, eventName in ipairs(filterEvents) do
        if enabled then
            ChatFrame_AddMessageEventFilter(eventName, filter_message)
        else
            ChatFrame_RemoveMessageEventFilter(eventName, filter_message)
        end
    end
end

-- ==============================
-- 상태 업데이트 및 초기화
-- ==============================
local function update_state()
    local is_enabled = (dodo.DB and dodo.DB.enableChatModule ~= false and dodo.DB.useLinkURLs ~= false)
    apply_chat_filters(is_enabled)
end

dodo.UpdateChatURLState = update_state

local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:SetScript("OnEvent", function(self, event)
    if dodo.DB.useLinkURLs == nil then dodo.DB.useLinkURLs = true end
    update_state()
    self:UnregisterAllEvents()
end)

-- ==============================
-- 설정 등록
-- ==============================
if dodo.RegisterEditModeSystemSetting then
    dodo.RegisterEditModeSystemSetting(Enum.EditModeSystem.ChatFrame, {
        {
            name = "URL 링크화",
            get = function() return dodo.DB and dodo.DB.useLinkURLs ~= false end,
            set = function(checked)
                if dodo.DB then dodo.DB.useLinkURLs = checked end
                update_state()
            end,
            disabled = function() return dodo.DB and dodo.DB.enableChatModule == false end,
        }
    })
end
