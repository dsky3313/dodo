-- ==============================
-- Inspired
-- ==============================
-- Leatrix Plus (https://www.curseforge.com/wow/addons/leatrix-plus)

-- ==============================
-- 설정 및 테이블
-- ==============================
---@diagnostic disable: lowercase-global, param-type-mismatch, redundant-parameter, undefined-field, undefined-global
local addonName, dodo = ...
local module = {}
dodo:RegisterModule("WowheadLink", module)

local LibIcon = dodo.LibIcon

-- ==============================
-- 캐싱
-- ==============================
-- abc 가나다 순으로 정렬
local C_Timer = C_Timer
local CreateFrame = CreateFrame
local GameTooltip = GameTooltip
local GameTooltip_Hide = GameTooltip_Hide
local GetInstanceInfo = GetInstanceInfo
local hooksecurefunc = hooksecurefunc
local IsControlKeyDown = IsControlKeyDown
local IsMetaKeyDown = IsMetaKeyDown
local PlaySound = PlaySound

local SOUNDKIT = SOUNDKIT
local UIParent = UIParent

local COMMENT_SUFFIX = "#english-comments"
local SHOW_COMMENTS = true
local WOWHEAD_BASE = "https://wowhead.com/ko/"
local L_TOOLTIP_TEXT = "|cffaaffaa와우헤드 링크|r\n클릭하여 전체 선택 (Ctrl+C 복사)"
local L_COPY_DONE = "|cff00ff00복사 완료!|r"

-- 인스턴스 상태 캐싱 (쐐기/레이드 성능 최적화용)
local isInsideRestrictedInstance = false
local function update_instance_status()
    local _, instanceType, difficultyID = GetInstanceInfo()
    -- 8: 쐐기, raid: 레이드
    isInsideRestrictedInstance = (difficultyID == 8 or instanceType == "raid")
end

-- ==============================
-- 유틸리티
-- ==============================
local function set_wowhead_link(editbox, id_type, id)
    if not editbox then return end
    local url = WOWHEAD_BASE .. id_type .. "=" .. id
    if SHOW_COMMENTS then url = url .. COMMENT_SUFFIX end
    
    editbox.lastURL = url
    editbox:SetText(url)
    editbox:SetCursorPosition(0)
    editbox:Show()
end

-- ==============================
-- 디스플레이
-- ==============================
local function create_direct_edit_box(parent, name)
    local linkEditbox = CreateFrame("EditBox", name, parent, "InputBoxInstructionsTemplate")
    linkEditbox:SetSize(200, 18)
    linkEditbox:SetFontObject("GameFontHighlightSmall")
    linkEditbox:SetAutoFocus(false)
    linkEditbox:SetJustifyH("LEFT")
    linkEditbox:SetTextInsets(5, 5, 0, 0)

    -- 아이콘
    if LibIcon then
        local icon = LibIcon:Create(name .. "Icon", linkEditbox, { iconsize = { 20, 20 } })
        icon:SetPoint("RIGHT", linkEditbox, "LEFT", -7, 0)
        icon:ApplyConfig({
            type = "macro",
            icon = 7242384,
            label = "",
            useTooltip = false
        })
    end

    -- 복사 확인 피드백 설정 (아이콘 + 문구)
    local feedbackFrame = CreateFrame("Frame", nil, linkEditbox)
    feedbackFrame:SetAllPoints()
    feedbackFrame:SetAlpha(0)

    local checkIcon = feedbackFrame:CreateTexture(nil, "OVERLAY")
    checkIcon:SetPoint("CENTER", feedbackFrame, "CENTER", 0, 0)
    checkIcon:SetSize(24, 24)
    checkIcon:SetAtlas("UI-QuestTracker-Tracker-Check")

    local copyText = feedbackFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    copyText:SetPoint("TOP", checkIcon, "BOTTOM", 0, -2)
    copyText:SetText(L_COPY_DONE)

    local ag = feedbackFrame:CreateAnimationGroup()
    local fadeOut = ag:CreateAnimation("Alpha")
    fadeOut:SetFromAlpha(1)
    fadeOut:SetToAlpha(0)
    fadeOut:SetDuration(0.3)
    fadeOut:SetStartDelay(1.5)
    ag:SetScript("OnFinished", function() feedbackFrame:SetAlpha(0) end)
    linkEditbox.feedbackAg = ag
    linkEditbox.feedbackFrame = feedbackFrame

    linkEditbox:SetScript("OnTextChanged", function(self) self:SetCursorPosition(0) end)
    linkEditbox:SetScript("OnMouseUp", function(self)
        self:SetFocus()
        self:HighlightText()
    end)
    linkEditbox:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
    linkEditbox:SetScript("OnChar", function(self)
        if self.lastURL then
            self:SetText(self.lastURL)
            self:HighlightText()
        end
    end)
    linkEditbox:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(L_TOOLTIP_TEXT, 1, 1, 1)
        GameTooltip:Show()
    end)
    linkEditbox:SetScript("OnLeave", GameTooltip_Hide)

    linkEditbox:HookScript("OnKeyDown", function(self, key)
        if key == "C" and (IsControlKeyDown() or IsMetaKeyDown()) then
            PlaySound(SOUNDKIT.TELL_MESSAGE)
            self.feedbackFrame:SetAlpha(1)
            self.feedbackAg:Stop()
            self.feedbackAg:Play()
        end
    end)

    return linkEditbox
end

-- ==============================
-- 동작
-- ==============================
-- 지도
local mapEditbox
local lastMapQuestID
local function update_map_link()
    -- 쐐기/레이드 시 즉시 종료 (최우선 순위 체크)
    if isInsideRestrictedInstance then
        if mapEditbox then mapEditbox:Hide() end
        return
    end

    local questID = QuestMapFrame_GetDetailQuestID()
    local isEnabled = (dodo.DB and dodo.DB.enableWowheadLinkModule ~= false)

    if questID == lastMapQuestID and mapEditbox and mapEditbox:IsShown() then return end
    lastMapQuestID = questID

    if isEnabled and questID and questID ~= 0 and QuestMapFrame.DetailsFrame:IsShown() then
        if not mapEditbox then
            mapEditbox = create_direct_edit_box(WorldMapFrame, "WowhadMapEditbox")
            mapEditbox:SetPoint("TOPRIGHT", WorldMapFrame, "BOTTOMRIGHT", -2, -2)
        end
        set_wowhead_link(mapEditbox, "quest", questID)
    elseif mapEditbox then
        mapEditbox:Hide()
    end
end

hooksecurefunc(QuestMapFrame.DetailsFrame, "Hide", function() if mapEditbox then mapEditbox:Hide() end end)
hooksecurefunc("QuestMapFrame_ShowQuestDetails", update_map_link)

-- 업적
EventUtil.ContinueOnAddOnLoaded("Blizzard_AchievementUI", function()
    local achievementEditbox = create_direct_edit_box(AchievementFrame, "WowheadAchievementEditbox")
    achievementEditbox:SetPoint("TOPRIGHT", AchievementFrame, "BOTTOMRIGHT", -2, -2)
    achievementEditbox:Hide()

    local lastAchiID
    local function update_achi_link(self, achievementID)
        -- 쐐기/레이드 시 즉시 종료
        if isInsideRestrictedInstance then
            achievementEditbox:Hide()
            return
        end

        local isEnabled = (dodo.DB and dodo.DB.enableWowheadLinkModule ~= false)
        local shouldShowLink = isEnabled and achievementID and achievementID ~= 0

        if shouldShowLink and achievementID == lastAchiID and achievementEditbox:IsShown() then return end
        lastAchiID = achievementID

        if shouldShowLink then
            set_wowhead_link(achievementEditbox, "achievement", achievementID)
        else
            achievementEditbox:Hide()
        end
    end

    hooksecurefunc(AchievementTemplateMixin, "DisplayObjectives", update_achi_link)

    hooksecurefunc(AchievementTemplateMixin, "OnClick", function(self)
        C_Timer.After(0.1, function()
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

-- ==============================
-- 초기화
-- ==============================
local function initialize()
    if dodo.DB and dodo.DB.enableWowheadLinkModule == nil then
        dodo.DB.enableWowheadLinkModule = false
    end
end

-- ==============================
-- 모듈 생명주기
-- ==============================
function module:OnEnable()
    initialize()

    local frame = CreateFrame("Frame")
    frame:RegisterEvent("PLAYER_ENTERING_WORLD")
    frame:SetScript("OnEvent", function(self, event)
        update_instance_status()
    end)

    -- dodoEditModePanel 내부에 세부 설정 주입
    if dodo.RegisterEditModeSetting then
        dodo.RegisterEditModeSetting("인터페이스", {
            {
                name = "와우헤드 링크 복사",
                get = function() return dodo.DB and dodo.DB.enableWowheadLinkModule or false end,
                set = function(checked)
                    if dodo.DB then 
                        dodo.DB.enableWowheadLinkModule = checked 
                    end
                    update_map_link()
                end
            }
        })
    end
end
