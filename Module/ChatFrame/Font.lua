-- ==============================
-- 설정 및 테이블
-- ==============================
---@diagnostic disable: lowercase-global, param-type-mismatch, redundant-parameter, undefined-field, undefined-global
local addonName, dodo = ...
dodoDB = dodoDB or {}
dodo.DB = dodo.DB or dodoDB

-- ==============================
-- 캐싱
-- ==============================
local CreateFrame = CreateFrame
local GameTooltip = GameTooltip
local IsControlKeyDown = IsControlKeyDown
local NUM_CHAT_WINDOWS = NUM_CHAT_WINDOWS
local _G = _G
local type = type

-- 하이퍼링크 마우스오버 및 클릭 처리
local function on_hyperlink_enter(self, linkData)
    if not linkData:find("^url:") then
        GameTooltip:SetOwner(self, "ANCHOR_CURSOR")
        GameTooltip:SetHyperlink(linkData)
        GameTooltip:Show()
    end
end

local function on_hyperlink_leave()
    GameTooltip:Hide()
end

local function on_hyperlink_click(self, link, text, button)
    if dodo.DB.enableChatModule and type(link) == "string" and link:sub(1, 4) == "url:" then
        local url = link:sub(5):gsub("||", "|")
        local f = dodo.URLCopyFrame
        if f then
            f.EditBox:SetText(url)
            f:Show()
            f.EditBox:SetFocus()
            f.EditBox:HighlightText()
            return true
        end
    end
end

-- 폰트 및 대화창 스타일 적용
local function style_chat_frames()
    for i = 1, NUM_CHAT_WINDOWS do
        local frame = _G["ChatFrame"..i]
        if frame then
            if not dodo.DB.enableChatModule then
                local font, size = frame:GetFont()
                frame:SetFont(font, size or 14, "")
                frame:SetShadowOffset(1, -1)
                frame:SetShadowColor(0, 0, 0, 0.6)
                if frame.UpdateFont then
                    frame:UpdateFont()
                end
            else
                frame:SetHyperlinksEnabled(true)
                local name = frame:GetName()
                local eb = _G[name.."EditBox"]
                if eb then
                    eb:SetAltArrowKeyMode(false)
                end

                if dodo.DB.useFontShadow then
                    frame:SetShadowOffset(1, -1)
                    frame:SetShadowColor(0, 0, 0, 0.8)
                else
                    frame:SetShadowOffset(0, 0)
                    frame:SetShadowColor(0, 0, 0, 0)
                end

                local font = frame:GetFont()
                local size = 13
                if dodo.DB.useFontSize ~= false then
                    size = dodo.DB.fontSize or 13
                end
                local flags = dodo.DB.useFontOutline and "OUTLINE" or ""
                frame:SetFont(font, size, flags)

                if frame.UpdateFont then
                    frame:UpdateFont()
                end
            end

            if not frame.dodoHyperlinkHooked then
                frame.dodoHyperlinkHooked = true
                frame:SetScript("OnHyperlinkEnter", on_hyperlink_enter)
                frame:SetScript("OnHyperlinkLeave", on_hyperlink_leave)
            end

            if not frame.OldOnHyperlinkClickHooked then
                frame.OldOnHyperlinkClickHooked = true
                frame:HookScript("OnHyperlinkClick", on_hyperlink_click)
            end
        end
    end
end

-- 마우스 휠 스크롤 설정
local function on_mouse_wheel(selfScroll, delta)
    if delta > 0 then
        if IsControlKeyDown() then selfScroll:ScrollToTop() else selfScroll:ScrollUp() end
    else
        if IsControlKeyDown() then selfScroll:ScrollToBottom() else selfScroll:ScrollDown() end
    end
end

local function apply_mouse_wheel(enabled)
    for i = 1, NUM_CHAT_WINDOWS do
        local frame = _G["ChatFrame"..i]
        if frame then
            if enabled then
                frame:SetScript("OnMouseWheel", on_mouse_wheel)
                frame:EnableMouseWheel(true)
            else
                frame:SetScript("OnMouseWheel", nil)
                frame:EnableMouseWheel(false)
            end
        end
    end
end

-- 외부 라우터 노출
function dodo.UpdateChatFontState()
    local is_enabled = (dodo.DB and dodo.DB.enableChatModule ~= false)
    apply_mouse_wheel(is_enabled)
    style_chat_frames()
end
