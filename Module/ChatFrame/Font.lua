-- ============================================================================
-- dodo: ChatFrame Font (대화창 글꼴 및 휠 스크롤 설정)
-- License: GPLv3 (배포 가능 자유 라이선스)
-- ============================================================================
local addonName, dodo = ...
dodoDB = dodoDB or {}
dodo.DB = dodo.DB or dodoDB

-- 캐싱 및 와우 API 단축
local GameTooltip = GameTooltip
local IsControlKeyDown = IsControlKeyDown
local issecretvalue = issecretvalue
local NUM_CHAT_WINDOWS = NUM_CHAT_WINDOWS or 10
local type = type
local _G = _G

-- 1. 하이퍼링크 마우스 호버 시 툴팁 제어
local function on_hyperlink_enter(self, linkData)
    if not linkData or (issecretvalue and issecretvalue(linkData)) then
        -- KString 비밀값 문자열 조작 차단 방지
        return
    end
    if not linkData:find("^url:") then
        GameTooltip:SetOwner(self, "ANCHOR_CURSOR")
        GameTooltip:SetHyperlink(linkData)
        GameTooltip:Show()
    end
end

local function on_hyperlink_leave()
    GameTooltip:Hide()
end

-- URL 링크 클릭 시 팝업창을 띄워주는 클릭 훅 함수
local function on_hyperlink_click(self, link, text, button)
    if dodo.DB.enableChatModule and type(link) == "string" and link:sub(1, 4) == "url:" then
        local url = link:sub(5):gsub("||", "|")
        if dodo.ShowURLCopyPopup then
            dodo.ShowURLCopyPopup(url)
            return true
        end
    end
end

-- 2. 대화창 폰트 및 스타일 갱신
local function style_chat_frames()
    for i = 1, NUM_CHAT_WINDOWS do
        local frame = _G["ChatFrame"..i]
        if frame then
            if not dodo.DB.enableChatModule then
                -- 모듈 비활성화 시 기본값 복구
                local font, size = frame:GetFont()
                frame:SetFont(font, size or 14, "")
                frame:SetShadowOffset(1, -1)
                frame:SetShadowColor(0, 0, 0, 0.6)
                if frame.UpdateFont then frame:UpdateFont() end
            else
                -- 모듈 활성화 시 폰트 외곽선/그림자/크기 적용
                frame:SetHyperlinksEnabled(true)
                local name = frame:GetName()
                local eb = _G[name.."EditBox"]
                if eb then
                    eb:SetAltArrowKeyMode(false) -- 방향키 이동 시 Alt 제약 해제 (순정 모드)
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

                if frame.UpdateFont then frame:UpdateFont() end
            end

            -- 안전한 HookScript 방식으로 오염(Taint) 방지
            if not frame.dodoHyperlinkHooked then
                frame.dodoHyperlinkHooked = true
                frame:HookScript("OnHyperlinkEnter", on_hyperlink_enter)
                frame:HookScript("OnHyperlinkLeave", on_hyperlink_leave)
            end

            if not frame.dodoHyperlinkClickHooked then
                frame.dodoHyperlinkClickHooked = true
                frame:HookScript("OnHyperlinkClick", on_hyperlink_click)
            end
        end
    end
end

-- 3. 마우스 휠 스크롤 갱신 (Ctrl키 조합으로 맨 위/아래 이동)
local function on_mouse_wheel(selfScroll, delta)
    if delta > 0 then
        if IsControlKeyDown() then
            selfScroll:ScrollToTop()
        else
            selfScroll:ScrollUp()
        end
    else
        if IsControlKeyDown() then
            selfScroll:ScrollToBottom()
        else
            selfScroll:ScrollDown()
        end
    end
end

local function apply_mouse_wheel(enabled)
    for i = 1, NUM_CHAT_WINDOWS do
        local frame = _G["ChatFrame"..i]
        if frame then
            if enabled then
                -- HookScript 안전한 마우스 휠 체이닝
                if not frame.dodoMouseWheelHooked then
                    frame.dodoMouseWheelHooked = true
                    frame:HookScript("OnMouseWheel", on_mouse_wheel)
                end
                frame:EnableMouseWheel(true)
            else
                frame:EnableMouseWheel(false)
            end
        end
    end
end

-- 4. 업데이트 트리거 외부 노출
function dodo.UpdateChatFontState()
    local is_enabled = (dodo.DB and dodo.DB.enableChatModule ~= false)
    apply_mouse_wheel(is_enabled)
    style_chat_frames()
end
