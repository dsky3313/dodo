-- ============================================================================
-- dodo: ChatFrame URL (대화창 웹 주소 링크화 및 복사 지원)
-- License: GPLv3 (배포 가능 자유 라이선스)
-- ============================================================================
local addonName, dodo = ...
dodoDB = dodoDB or {}
dodo.DB = dodo.DB or dodoDB

-- 캐싱 및 와우 API 단축
local C_Timer = C_Timer
local ChatFrame_AddMessageEventFilter = ChatFrame_AddMessageEventFilter
local ChatFrame_RemoveMessageEventFilter = ChatFrame_RemoveMessageEventFilter
local CreateFrame = CreateFrame
local IsControlKeyDown = IsControlKeyDown
local IsInInstance = IsInInstance
local issecretvalue = issecretvalue
local UIParent = UIParent
local hooksecurefunc = hooksecurefunc
local ipairs = ipairs
local tostring = tostring
local type = type

-- URL 감지 정규식 패턴 리스트
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

-- 1. URL 뒤쪽에 붙은 부적절한 문장부호 제거
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

-- 2. URL 문자열을 하이퍼링크 포맷으로 마크업
local function format_url(url)
    local actual_url, trailing = split_trailing_url_punctuation(url)
    actual_url = actual_url:gsub("%%", "%%%%") -- 퍼센트 기호 안전 이스케이프
    return "|cff149bfd|Hurl:" .. actual_url .. "|h[" .. actual_url .. "]|h|r" .. trailing
end

-- 3. 헬퍼 함수를 사용한 순정 디자인 복사 팝업 프레임 생성 (Lazy load)
local function get_or_create_url_popup()
    if not dodo.URLCopyFrame then
        -- dodo UI 팩토리의 포트레이트 패널 생성 헬퍼 호출
        local f = dodo.UI:CreatePortraitPanel("dodoChatURLCopyFrame", "URL 복사 (Ctrl+C)")
        f:SetSize(300, 80)
        f:SetPoint("TOP", UIParent, "TOP", 0, -150)
        f:SetFrameStrata("DIALOG")
        f:Hide()

        -- 주소 복사용 에디트박스
        local eb = CreateFrame("EditBox", nil, f, "InputBoxTemplate")
        eb:SetPoint("BOTTOMLEFT", 25, 15)
        eb:SetPoint("BOTTOMRIGHT", -15, 15)
        eb:SetHeight(24)
        eb:SetAutoFocus(true)
        eb:SetScript("OnEscapePressed", function() f:Hide() end)
        eb:SetScript("OnEnterPressed", function() f:Hide() end)
        eb:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)

        -- 복사 단축키(Ctrl+C) 입력 완료 즉시 창 숨김 딜레이
        local function hide_popup() f:Hide() end
        eb:SetScript("OnKeyDown", function(self, key)
            if IsControlKeyDown() and key == "C" then
                C_Timer.After(0.1, hide_popup)
            end
        end)

        f.EditBox = eb
        dodo.URLCopyFrame = f
    end
    return dodo.URLCopyFrame
end

-- 외부 노출 복사 팝업 열기 함수
local function show_url_copy_popup(url)
    local popup = get_or_create_url_popup()
    popup.EditBox:SetText(url)
    popup:Show()
    popup.EditBox:SetFocus()
    popup.EditBox:HighlightText()
end

dodo.ShowURLCopyPopup = show_url_copy_popup

-- 4. 툴팁 링크 클릭 훅 연동
local function handle_hyperlink_click(link, text, button, chatFrame)
    if type(link) == "string" and link:sub(1, 4) == "url:" then
        local url = link:sub(5):gsub("||", "|")
        show_url_copy_popup(url)
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

-- 5. 대화 메시지 속 URL 감지 필터 콜백
local function filter_message(self, event, msg, author, ...)
    if not dodo.DB.enableChatModule or not dodo.DB.useLinkURLs then return false, msg, author, ... end

    -- KString 비밀값 체크 (보안 에러 방지)
    if issecretvalue and (issecretvalue(msg) or (author and issecretvalue(author))) then
        return false, msg, author, ...
    end

    if type(msg) == "string" and not msg:find("|H") then
        if msg:find("%.") or msg:find("://") or msg:find("www") then
            for _, pattern in ipairs(Config.urlPatterns) do
                msg = msg:gsub(pattern, format_url)
            end
        end
    end

    return false, msg, author, ...
end

-- 6. 메시지 이벤트별 링크화 필터 등록/해제 제어
local FILTER_EVENTS = {
    "CHAT_MSG_CHANNEL", "CHAT_MSG_GUILD", "CHAT_MSG_OFFICER", "CHAT_MSG_PARTY",
    "CHAT_MSG_PARTY_LEADER", "CHAT_MSG_RAID", "CHAT_MSG_RAID_LEADER",
    "CHAT_MSG_INSTANCE_CHAT", "CHAT_MSG_INSTANCE_CHAT_LEADER", "CHAT_MSG_SAY",
    "CHAT_MSG_YELL", "CHAT_MSG_WHISPER", "CHAT_MSG_BN_WHISPER",
}

local function apply_chat_filters(enabled)
    for _, eventName in ipairs(FILTER_EVENTS) do
        if enabled then
            ChatFrame_AddMessageEventFilter(eventName, filter_message)
        else
            ChatFrame_RemoveMessageEventFilter(eventName, filter_message)
        end
    end
end

-- 7. 모듈 갱신 라우팅 연동
local function update_state()
    local in_instance = IsInInstance()
    local is_enabled = (dodo.DB and dodo.DB.enableChatModule ~= false and dodo.DB.useLinkURLs ~= false and not in_instance)
    apply_chat_filters(is_enabled)
end

dodo.UpdateChatURLState = update_state

local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
initFrame:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_LOGIN" then
        if dodo.DB.useLinkURLs == nil then dodo.DB.useLinkURLs = true end
        update_state()
        self:UnregisterEvent("PLAYER_LOGIN")
    elseif event == "PLAYER_ENTERING_WORLD" then
        update_state()
    end
end)

-- 8. 설정 UI 연결
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
