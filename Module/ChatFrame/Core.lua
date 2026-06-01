-- ==============================
-- 설정 및 테이블
-- ==============================
---@diagnostic disable: lowercase-global, param-type-mismatch, redundant-parameter, undefined-field, undefined-global
local addonName, dodo = ...
dodoDB = dodoDB or {}
dodo.DB = dodo.DB or dodoDB

-- ==============================
-- 상태 업데이트 라우터
-- ==============================
local function update_chat_module_state()
    if dodo.UpdateChatFontState then dodo.UpdateChatFontState() end
    if dodo.UpdateChatURLState then dodo.UpdateChatURLState() end
    if dodo.UpdateChatShortState then dodo.UpdateChatShortState() end
    if dodo.UpdateChatGuildButtonState then dodo.UpdateChatGuildButtonState() end
end

dodo.UpdateChatModuleState = update_chat_module_state

-- ==============================
-- 초기화
-- ==============================
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

if dodo.RegisterEditModeSystemSetting then
    dodo.RegisterEditModeSystemSetting(Enum.EditModeSystem.ChatFrame, {
        {
            name = "글씨 외곽선 적용",
            get = function() return dodo.DB and dodo.DB.useFontOutline ~= false end,
            set = function(checked)
                if dodo.DB then dodo.DB.useFontOutline = checked end
                update_chat_module_state()
            end,
            disabled = function() return dodo.DB and dodo.DB.enableChatModule == false end,
        },
        {
            name = "글씨 그림자 적용",
            get = function() return dodo.DB and dodo.DB.useFontShadow == true end,
            set = function(checked)
                if dodo.DB then dodo.DB.useFontShadow = checked end
                update_chat_module_state()
            end,
            disabled = function() return dodo.DB and dodo.DB.enableChatModule == false end,
        },
        {
            name = "글씨 크기 변경",
            get = function() return dodo.DB and dodo.DB.useFontSize ~= false end,
            set = function(checked)
                if dodo.DB then dodo.DB.useFontSize = checked end
                update_chat_module_state()
            end,
            disabled = function() return dodo.DB and dodo.DB.enableChatModule == false end,
        },
        {
            name = "글씨 크기",
            type = "slider",
            get = function() return dodo.DB and dodo.DB.fontSize or 13 end,
            set = function(val)
                if dodo.DB then dodo.DB.fontSize = val end
                update_chat_module_state()
            end,
            minVal = 10,
            maxVal = 18,
            step = 1,
            disabled = function() return dodo.DB and (dodo.DB.enableChatModule == false or dodo.DB.useFontSize == false) end,
        }
    })
end
