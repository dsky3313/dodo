------------------------------
-- 테이블
------------------------------
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

------------------------------
-- 동작
------------------------------
local function ChatBubble()
    local fontPath = dodoDB.chatbubbleFontPath or "Fonts\\2002.TTF"
    local fontSize = dodoDB.chatbubbleFontSize or 10
    local fontFlag = "OUTLINE"

    if ChatBubbleFont then
        ChatBubbleFont:SetFont(fontPath, fontSize, fontFlag)
    end
end

------------------------------
-- 이벤트
------------------------------
local initChatBubble = CreateFrame("Frame")
initChatBubble:RegisterEvent("PLAYER_LOGIN")
initChatBubble:SetScript("OnEvent", function(self, event)
    if dodoCreateOptions then dodoCreateOptions() end
    if ChatBubble then ChatBubble() end
    self:UnregisterAllEvents()
end)

dodo.ChatBubble = ChatBubble