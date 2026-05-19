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
-- 함수
local CreateFrame = CreateFrame
local ChatBubbleFont = ChatBubbleFont

-- ==============================
-- 동작
-- ==============================
local function chatBubble()
    if not dodo.DB or not ChatBubbleFont then return end

    local fontPath = dodo.DB.chatbubbleFontPath or "Fonts\\2002.TTF"
    local fontSize = dodo.DB.chatbubbleFontSize or chatbubbleFontSize
    local fontFlag = "OUTLINE"

    local curPath, curSize, curFlag = ChatBubbleFont:GetFont()
    if curPath ~= fontPath or curSize ~= fontSize or curFlag ~= fontFlag then
        ChatBubbleFont:SetFont(fontPath, fontSize, fontFlag)
    end
end

-- ==============================
-- 이벤트
-- ==============================
function module:OnEnable()
    if chatBubble then chatBubble() end
end

-- ==============================
-- 설정
-- ==============================
function module:CreateOptions()
    dodo.UI.Header(dodo.subCategoryInterface, "말풍선")
    dodo.UI.DropDown(dodo.subCategoryInterface, "chatbubbleFontPath", "말풍선 글꼴", "말풍선에 적용할 글꼴를 선택하세요.", dodo.chatbubbleFontTable, dodo.chatbubbleFontTable[1].value, chatBubble)
    dodo.UI.Slider(dodo.subCategoryInterface, "chatbubbleFontSize", "말풍선 글꼴 크기", "말풍선 글꼴 크기를 변경합니다.", 8, 14, 1, 1, "Integer", chatBubble)
end
