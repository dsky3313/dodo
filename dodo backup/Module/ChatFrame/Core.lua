-- ==============================
-- Inspired
-- ==============================
-- Chattynator (https://www.curseforge.com/wow/addons/chattynator)
-- Guild Button (https://wago.io/Cx_wsXks4)

-- ==============================
-- 설정 및 테이블
-- ==============================
local addonName, dodo = ...
dodoDB = dodoDB or {}
dodo.DB = dodo.DB or dodoDB

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
    if dodo.DB.enableChatModule == nil then dodo.DB.enableChatModule = true end
    if dodo.DB.useFontOutline == nil then dodo.DB.useFontOutline = true end
    if dodo.DB.useFontShadow == nil then dodo.DB.useFontShadow = false end
    if dodo.DB.useFontSize == nil then dodo.DB.useFontSize = true end
    if dodo.DB.fontSize == nil then dodo.DB.fontSize = 13 end
    
    update_chat_module_state()
end

local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:SetScript("OnEvent", function(self, event)
    initialize()
    self:UnregisterAllEvents()
end)

-- ==============================
-- 설정 등록
-- ==============================
if dodo.RegisterEditModeModuleSetting then
    dodo.RegisterEditModeModuleSetting("인터페이스", {
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

