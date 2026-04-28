-- ==============================
-- Inspired
-- ==============================
-- Leatrix Plus (https://www.curseforge.com/wow/addons/leatrix-plus)

-- ==============================
-- 설정 및 테이블
-- ==============================
---@diagnostic disable: lowercase-global, undefined-field, undefined-global
local addonName, dodo = ...
dodoDB = dodoDB or {}

-- ==============================
-- 캐싱
-- ==============================
-- 함수
local CreateFrame = CreateFrame
local GetInstanceInfo = GetInstanceInfo
local hooksecurefunc = hooksecurefunc

-- 변수
local _G = _G
local COMMENT_SUFFIX = "#english-comments"
local SHOW_COMMENTS = true
local WOWHEAD_BASE = "https://wowhead.com/ko/"

local function isIns() -- 인스확인
    local _, instanceType, difficultyID = GetInstanceInfo()
    return (difficultyID == 8 or instanceType == "raid") -- 1 일반 / 8 쐐기
end

-- ==============================
-- 디스플레이
-- ==============================
local function CreateDirectEditBox(parent, name)
    local linkEditbox = CreateFrame("EditBox", name, parent, "InputBoxInstructionsTemplate")
    linkEditbox:SetSize(200, 18)
    linkEditbox:SetFontObject("GameFontHighlightSmall")
    linkEditbox:SetAutoFocus(false)
    linkEditbox:SetJustifyH("LEFT")
    linkEditbox:SetTextInsets(5, 5, 0, 0)

    -- 아이콘
    if dodo and dodo.IconLib then
        local icon = dodo.IconLib:Create(name .. "Icon", linkEditbox, { iconsize = { 20, 20 } })
        icon:SetPoint("RIGHT", linkEditbox, "LEFT", -7, 0)
        icon:ApplyConfig({
            type = "macro",
            icon = 7242384,
            label = "",
            useTooltip = false
        })
    end

    linkEditbox:SetScript("OnTextChanged", function(self)
        self:SetCursorPosition(0)
    end)

    linkEditbox:SetScript("OnMouseUp", function(self)
        self:SetFocus()
        self:HighlightText()
    end)

    linkEditbox:SetScript("OnEditFocusGained", function(self)
        self:HighlightText()
    end)

    -- 텍스트 수정 방지
    linkEditbox:SetScript("OnChar", function(self)
        if self.lastURL then
            self:SetText(self.lastURL)
            self:HighlightText()
        end
    end)

    linkEditbox:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("|cffaaffaa와우헤드 링크|r\n클릭하여 전체 선택 (Ctrl+C 복사)", 1, 1, 1)
        GameTooltip:Show()
    end)

    linkEditbox:SetScript("OnLeave", GameTooltip_Hide)

    return linkEditbox
end

-- ==============================
-- 동작
-- ==============================
-- 지도
local mapEditbox
local lastMapQuestID
local function UpdateMapLink()
    local questID = QuestMapFrame_GetDetailQuestID()
    local isEnabled = (dodoDB.useWowheadLink ~= false)

    -- 이전과 같은 퀘스트면 업데이트 건너뜀
    if questID == lastMapQuestID and mapEditbox and mapEditbox:IsShown() then return end
    lastMapQuestID = questID

    if isEnabled and not isIns() and questID and questID ~= 0 and QuestMapFrame.DetailsFrame:IsShown() then
        if not mapEditbox then
            mapEditbox = CreateDirectEditBox(WorldMapFrame, "WowhadMapEditbox")
            mapEditbox:SetPoint("TOPRIGHT", WorldMapFrame, "BOTTOMRIGHT", -2, -2)
        end

        local url = WOWHEAD_BASE .. "quest=" .. questID
        if SHOW_COMMENTS then url = url .. COMMENT_SUFFIX end

        mapEditbox.lastURL = url
        mapEditbox:SetText(url)
        mapEditbox:SetCursorPosition(0)
        mapEditbox:Show()
    elseif mapEditbox then
        mapEditbox:Hide()
    end
end

hooksecurefunc(QuestMapFrame.DetailsFrame, "Hide", function() if mapEditbox then mapEditbox:Hide() end end)
hooksecurefunc("QuestMapFrame_ShowQuestDetails", UpdateMapLink)

-- 업적
EventUtil.ContinueOnAddOnLoaded("Blizzard_AchievementUI", function()
    local achievementEditbox = CreateDirectEditBox(AchievementFrame, "WowheadAchievementEditbox")
    achievementEditbox:SetPoint("TOPRIGHT", AchievementFrame, "BOTTOMRIGHT", -2, -2)
    achievementEditbox:Hide()

    local lastAchiID
    local function UpdateAchiLink(self, achievementID)
        local isEnabled = (dodoDB.useWowheadLink ~= false)
        local shouldShowLink = isEnabled and not isIns() and achievementID and achievementID ~= 0

        -- 이전과 같은 업적면 업데이트 건너뜀
        if shouldShowLink and achievementID == lastAchiID and achievementEditbox:IsShown() then return end
        lastAchiID = achievementID

        if shouldShowLink then
            local url = WOWHEAD_BASE .. "achievement=" .. achievementID
            if SHOW_COMMENTS then url = url .. COMMENT_SUFFIX end

            achievementEditbox.lastURL = url
            achievementEditbox:SetText(url)
            achievementEditbox:SetCursorPosition(0)
            achievementEditbox:Show()
        else
            achievementEditbox:Hide()
        end
    end

    hooksecurefunc(AchievementTemplateMixin, "DisplayObjectives", UpdateAchiLink)

    hooksecurefunc(AchievementTemplateMixin, "OnClick", function(self)
        -- 토글 애니메이션 등을 고려하여 아주 짧은 대기 후 상태 확인
        C_Timer.After(0.05, function()
            if not AchievementFrame:IsShown() or self.collapsed then
                achievementEditbox:Hide()
                lastAchiID = nil
            end
        end)
    end)

    AchievementFrame:HookScript("OnHide", function()
        achievementEditbox:Hide()
        lastAchiID = nil
    end)

    hooksecurefunc("AchievementFrameTab_OnClick", function()
        achievementEditbox:Hide()
        lastAchiID = nil
    end)
end)
