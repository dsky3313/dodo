-- ==============================
-- Inspired
-- ==============================
-- Chattynator (https://www.curseforge.com/wow/addons/chattynator)
-- Guild Button (https://wago.io/Cx_wsXks4)

-- ==============================
-- 설정 및 테이블
-- ==============================
local dodo = _G.dodo
dodoDB = dodoDB or {}

-- ==============================
-- 캐싱
-- ==============================
local CreateFrame = CreateFrame

-- ==============================
-- 기능 구현
-- ==============================
-- 1. 대화창 모듈별 독립적 업데이트 함수 호출
local function update_chat_module_state()
    if dodo.UpdateChatFontState then dodo.UpdateChatFontState() end
    if dodo.UpdateChatURLState then dodo.UpdateChatURLState() end
    if dodo.UpdateChatShortState then dodo.UpdateChatShortState() end
    if dodo.UpdateChatGuildButtonState then dodo.UpdateChatGuildButtonState() end
end

dodo.UpdateChatModuleState = update_chat_module_state

-- 2. 초기화 및 PLAYER_LOGIN 이벤트
local function initialize()
    if dodoDB.enableChatModule == nil then dodoDB.enableChatModule = true end
    if dodoDB.useFontOutline == nil then dodoDB.useFontOutline = true end
    if dodoDB.useFontShadow == nil then dodoDB.useFontShadow = false end
    if dodoDB.useFontSize == nil then dodoDB.useFontSize = true end
    if dodoDB.fontSize == nil then dodoDB.fontSize = 13 end
    
    update_chat_module_state()
end

local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:SetScript("OnEvent", function(self, event)
    initialize()
    self:UnregisterAllEvents()
end)


