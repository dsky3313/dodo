-- ==============================
-- Inspired
-- ==============================
-- adjust Chat Bubble Font (https://wago.io/AMt_WQ2Zk)

-- ==============================
-- 설정 및 테이블
-- ==============================
---@diagnostic disable: lowercase-global, param-type-mismatch, redundant-parameter, undefined-field, undefined-global
local addonName, dodo = ...
dodoDB = dodoDB or {}

local DEFAULT_CHATBUBBLE_FONT_SIZE = 10

dodo.chatbubbleFontTable = {
    { label = "2002", text = "2002", value = "Fonts\\2002.TTF" },
    { label = "2002b", text = "2002b", value = "Fonts\\2002b.TTF" },
    { label = "ARIALN", text = "ARIALN", value = "Fonts\\ARIALN.TTF" },
    { label = "FRIZQT__", text = "FRIZQT__", value = "Fonts\\FRIZQT__.TTF" },
    { label = "K_DAMAGE", text = "K_DAMAGE", value = "Fonts\\K_DAMAGE.TTF" },
    { label = "K_PAGETEXT", text = "K_PAGETEXT", value = "Fonts\\K_PAGETEXT.TTF" },
}

-- ==============================
-- 캐싱
-- ==============================
local CreateFrame = CreateFrame
local ChatBubbleFont = ChatBubbleFont

-- 원래 폰트 설정을 저장하기 위한 백업 변수 (자원복구용)
local default_font_path, default_font_size, default_font_flag

local function backup_default_font()
    if ChatBubbleFont and not default_font_path then
        default_font_path, default_font_size, default_font_flag = ChatBubbleFont:GetFont()
    end
end

-- ==============================
-- 동작
-- ==============================
local function chat_bubble()
    if not dodoDB or not ChatBubbleFont then return end
    backup_default_font()

    -- 1. 글꼴 설정 적용 여부 확인
    local use_font = (dodoDB.useChatbubbleFont ~= false)
    local font_path = use_font and (dodoDB.chatbubbleFontPath or "Fonts\\2002.TTF") or default_font_path

    -- 2. 글꼴 크기 설정 적용 여부 확인
    local use_size = (dodoDB.useChatbubbleFontSize ~= false)
    local font_size = use_size and (dodoDB.chatbubbleFontSize or DEFAULT_CHATBUBBLE_FONT_SIZE) or default_font_size

    local font_flag = "OUTLINE"

    if font_path and font_size then
        local cur_path, cur_size, cur_flag = ChatBubbleFont:GetFont()
        if cur_path ~= font_path or cur_size ~= font_size or cur_flag ~= font_flag then
            ChatBubbleFont:SetFont(font_path, font_size, font_flag)
        end
    end
end

-- ==============================
-- 이벤트
-- ==============================
local init_chat_bubble = CreateFrame("Frame")
init_chat_bubble:RegisterEvent("ADDON_LOADED")
init_chat_bubble:SetScript("OnEvent", function(self, event, arg1)
    if arg1 == addonName then
        dodoDB = dodoDB or {}
        self:RegisterEvent("PLAYER_LOGIN")
    elseif event == "PLAYER_LOGIN" then
        chat_bubble()
        self:UnregisterAllEvents()
        self:SetScript("OnEvent", nil)
    end
end)

-- 외부 노출 (호환성 유지)
dodo.ChatBubble = chat_bubble

-- ==============================
-- 설정 등록
-- ==============================
if dodo.RegisterEditModeModuleSetting then
    dodo.RegisterEditModeModuleSetting("인터페이스", {
        -- 1. 글꼴 변경 토글 + 드롭다운 세트 (2열 결합)
        {
            name = "말풍선 글꼴 변경",
            get = function() return dodoDB and dodoDB.useChatbubbleFont ~= false end,
            set = function(checked)
                if dodoDB then dodoDB.useChatbubbleFont = checked end
                chat_bubble()
            end
        },
        {
            type = "dropdown",
            get = function() return dodoDB.chatbubbleFontPath or "Fonts\\2002.TTF" end,
            set = function(val)
                if dodoDB then dodoDB.chatbubbleFontPath = val end
                chat_bubble()
            end,
            values = dodo.chatbubbleFontTable,
            disabled = function() return dodoDB and dodoDB.useChatbubbleFont == false end,
        },

        -- 2. 글꼴 크기 변경 토글 + 슬라이더 세트 (2열 결합)
        {
            name = "말풍선 크기 변경",
            get = function() return dodoDB and dodoDB.useChatbubbleFontSize ~= false end,
            set = function(checked)
                if dodoDB then dodoDB.useChatbubbleFontSize = checked end
                chat_bubble()
            end
        },
        {
            type = "slider",
            get = function() return dodoDB.chatbubbleFontSize or 10 end,
            set = function(val)
                if dodoDB then dodoDB.chatbubbleFontSize = val end
                chat_bubble()
            end,
            minVal = 8,
            maxVal = 20,
            step = 1,
            disabled = function() return dodoDB and dodoDB.useChatbubbleFontSize == false end,
        }
    })
end
