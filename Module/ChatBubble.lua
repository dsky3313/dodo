-- ==============================
-- Inspired
-- ==============================
-- adjust Chat Bubble Font (https://wago.io/AMt_WQ2Zk)

-- ==============================
-- 설정 및 테이블
-- ==============================
---@diagnostic disable: lowercase-global, param-type-mismatch, redundant-parameter, undefined-field, undefined-global
local addonName, dodo = ...
local module = {}
dodo:RegisterModule("ChatBubble", module)

local chatbubbleFontSize = 10

dodo.chatbubbleFontTable = {
    { label = "2002", value = "Fonts\\2002.TTF" },
    { label = "2002b", value = "Fonts\\2002b.TTF" },
    { label = "ARIALN", value = "Fonts\\ARIALN.TTF" },
    { label = "FRIZQT__", value = "Fonts\\FRIZQT__.TTF" },
    { label = "K_DAMAGE", value = "Fonts\\K_DAMAGE.TTF" },
    { label = "K_PAGETEXT", value = "Fonts\\K_PAGETEXT.TTF" },
}

-- ==============================
-- 캐싱
-- ==============================
local ChatBubbleFont = ChatBubbleFont
local ipairs = ipairs
local originalFontPath, originalFontSize, originalFontFlag

-- ==============================
-- 동작 및 라이프사이클 헬퍼
-- ==============================
local function update_feature()
    if not ChatBubbleFont then return end
    
    local defaultPath, defaultSize, defaultFlag = ChatBubbleFont:GetFont()
    local targetPath = (dodo.DB and dodo.DB.useChatBubbleFont ~= false) and (dodo.DB.chatbubbleFontPath or "Fonts\\2002.TTF") or (originalFontPath or defaultPath)
    local targetSize = (dodo.DB and dodo.DB.useChatBubbleFontSize ~= false) and (dodo.DB.chatbubbleFontSize or chatbubbleFontSize) or (originalFontSize or defaultSize)
    local targetFlag = "OUTLINE"

    if defaultPath ~= targetPath or defaultSize ~= targetSize or defaultFlag ~= targetFlag then
        ChatBubbleFont:SetFont(targetPath, targetSize, targetFlag)
    end
end

local function initialize()
    if ChatBubbleFont and not originalFontPath then
        originalFontPath, originalFontSize, originalFontFlag = ChatBubbleFont:GetFont()
    end
    -- DB 설정 초기값 세팅
    if dodo.DB then
        if dodo.DB.chatbubbleFontPath == nil then
            dodo.DB.chatbubbleFontPath = "Fonts\\2002.TTF"
        end
        if dodo.DB.chatbubbleFontSize == nil then
            dodo.DB.chatbubbleFontSize = chatbubbleFontSize
        end
        if dodo.DB.useChatBubbleFont == nil then
            dodo.DB.useChatBubbleFont = true
        end
        if dodo.DB.useChatBubbleFontSize == nil then
            dodo.DB.useChatBubbleFontSize = true
        end
    end
end

-- ==============================
-- 모듈 생명주기
-- ==============================
function module:OnEnable()
    initialize()
    update_feature()

    -- 1. 모듈설정창(dodoEditModePanel)에 글꼴 드롭다운 및 글꼴 크기 슬라이더를 직접 등록
    if dodo.RegisterEditModeSetting then
        local dropdownValues = {}
        for _, item in ipairs(dodo.chatbubbleFontTable) do
            table.insert(dropdownValues, { text = item.label, value = item.value })
        end

        dodo.RegisterEditModeSetting("인터페이스", {
            {
                name = "말풍선 글꼴",
                get = function()
                    return dodo.DB and dodo.DB.useChatBubbleFont ~= false
                end,
                set = function(checked)
                    if dodo.DB then dodo.DB.useChatBubbleFont = checked end
                    update_feature()
                    if dodoEditModePanel and dodoEditModePanel.UpdateDisabledStates then
                        dodoEditModePanel.UpdateDisabledStates()
                    end
                end
            },
            {
                type = "dropdown",
                get = function()
                    return dodo.DB and dodo.DB.chatbubbleFontPath or "Fonts\\2002.TTF"
                end,
                set = function(newValue)
                    if dodo.DB then dodo.DB.chatbubbleFontPath = newValue end
                    update_feature()
                end,
                values = dropdownValues
            },
            {
                name = "말풍선 글꼴 크기",
                get = function()
                    return dodo.DB and dodo.DB.useChatBubbleFontSize ~= false
                end,
                set = function(checked)
                    if dodo.DB then dodo.DB.useChatBubbleFontSize = checked end
                    update_feature()
                    if dodoEditModePanel and dodoEditModePanel.UpdateDisabledStates then
                        dodoEditModePanel.UpdateDisabledStates()
                    end
                end
            },
            {
                type = "slider",
                minVal = 8,
                maxVal = 14,
                step = 1,
                get = function()
                    return dodo.DB and dodo.DB.chatbubbleFontSize or chatbubbleFontSize
                end,
                set = function(newValue)
                    if dodo.DB then dodo.DB.chatbubbleFontSize = newValue end
                    update_feature()
                end
            }
        })
    end
end

-- ==============================
-- 설정 (대체로 사용하지 않으나 하위 호환을 위해 빈 껍데기 유지)
-- ==============================
function module:CreateOptions()
    -- 기존 Blizzard 설정창 옵션은 중복 표시 방지를 위해 비워둡니다.
end