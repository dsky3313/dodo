-- ==============================
-- 테이블
-- ==============================
---@diagnostic disable: lowercase-global, undefined-field, undefined-global
local addonName, dodo = ...
dodoDB = dodoDB or {}

chatbubbleFontTable = {
    { label = "2002", value = "Fonts\\2002.TTF" },
    { label = "2002b", value = "Fonts\\2002b.TTF" },
    { label = "ARIALN", value = "Fonts\\ARIALN.TTF" },
    { label = "FRIZQT__", value = "Fonts\\FRIZQT__.TTF" },
    { label = "K_DAMAGE", value = "Fonts\\K_DAMAGE.TTF" },
    { label = "K_PAGETEXT", value = "Fonts\\K_PAGETEXT.TTF" },
}

local CreateFrame = CreateFrame
local ChatBubbleFont = ChatBubbleFont

-- ==============================
-- 동작
-- ==============================
local function chatBubble()
    if not dodoDB then return end

    local fontPath = dodoDB.chatbubbleFontPath or "Fonts\\2002.TTF"
    local fontSize = dodoDB.chatbubbleFontSize or 10
    local fontFlag = "OUTLINE"

    if ChatBubbleFont then ChatBubbleFont:SetFont(fontPath, fontSize, fontFlag) end
end

-- ==============================
-- 이벤트
-- ==============================
local initChatBubble = CreateFrame("Frame")
initChatBubble:RegisterEvent("ADDON_LOADED")
initChatBubble:SetScript("OnEvent", function(self, event, arg1)
    if arg1 == addonName then
        dodoDB = dodoDB or {}
        self:RegisterEvent("PLAYER_LOGIN")
    elseif event == "PLAYER_LOGIN" then
        if chatBubble then chatBubble() end
        self:UnregisterAllEvents()
        self:SetScript("OnEvent", nil)
    end
end)

dodo.ChatBubble = chatBubble
