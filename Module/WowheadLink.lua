-- ==============================
-- Inspired
-- ==============================
-- Leatrix Plus (https://www.curseforge.com/wow/addons/leatrix-plus)

-- ==============================
-- 설정 및 테이블
-- ==============================
---@diagnostic disable: lowercase-global, param-type-mismatch, redundant-parameter, undefined-field, undefined-global
local addonName, dodo = ...
dodoDB = dodoDB or {}

-- ==============================
-- 캐싱
-- ==============================
local _G = _G
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
local function UpdateInstanceStatus()
    local _, instanceType, difficultyID = GetInstanceInfo()
    -- 8: 쐐기, raid: 레이드
    isInsideRestrictedInstance = (difficultyID == 8 or instanceType == "raid")
end

-- ==============================
-- 유틸리티
-- ==============================
local function SetWowheadLink(editbox, idType, id)
    if not editbox then return end
    local url = WOWHEAD_BASE .. idType .. "=" .. id
    if SHOW_COMMENTS then url = url .. COMMENT_SUFFIX end
    
    editbox.lastURL = url
    editbox:SetText(url)
    editbox:SetCursorPosition(0)
    editbox:Show()
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
    local function on_feedback_anim_finished(s)
        s:GetParent():SetAlpha(0)
    end

    local function on_editbox_text_changed(s)
        s:SetCursorPosition(0)
    end

    local function on_editbox_mouseup(s)
        s:SetFocus()
        s:HighlightText()
    end

    local function on_editbox_focus_gained(s)
        s:HighlightText()
    end

    local function on_editbox_char(s)
        if s.lastURL then
            s:SetText(s.lastURL)
            s:HighlightText()
        end
    end

    local function on_editbox_enter(s)
        GameTooltip:SetOwner(s, "ANCHOR_TOP")
        GameTooltip:SetText(L_TOOLTIP_TEXT, 1, 1, 1)
        GameTooltip:Show()
    end

    local function on_editbox_keydown(s, key)
        if key == "C" and (IsControlKeyDown() or IsMetaKeyDown()) then
            PlaySound(SOUNDKIT.TELL_MESSAGE)
            s.feedbackFrame:SetAlpha(1)
            s.feedbackAg:Stop()
            s.feedbackAg:Play()
        end
    end

    ag:SetScript("OnFinished", on_feedback_anim_finished)
    linkEditbox.feedbackAg = ag
    linkEditbox.feedbackFrame = feedbackFrame

    linkEditbox:SetScript("OnTextChanged", on_editbox_text_changed)
    linkEditbox:SetScript("OnMouseUp", on_editbox_mouseup)
    linkEditbox:SetScript("OnEditFocusGained", on_editbox_focus_gained)
    linkEditbox:SetScript("OnChar", on_editbox_char)
    linkEditbox:SetScript("OnEnter", on_editbox_enter)
    linkEditbox:SetScript("OnLeave", GameTooltip_Hide)

    linkEditbox:HookScript("OnKeyDown", on_editbox_keydown)

    return linkEditbox
end

-- ==============================
-- 동작
-- ==============================
-- 지도
local mapEditbox
local lastMapQuestID
local function UpdateMapLink()
    -- 쐐기/레이드 시 즉시 종료 (최우선 순위 체크)
    if isInsideRestrictedInstance then
        if mapEditbox then mapEditbox:Hide() end
        return
    end

    local questID = QuestMapFrame_GetDetailQuestID()
    local isEnabled = (dodoDB.useWowheadLink ~= false)

    if questID == lastMapQuestID and mapEditbox and mapEditbox:IsShown() then return end
    lastMapQuestID = questID

    if isEnabled and questID and questID ~= 0 and QuestMapFrame.DetailsFrame:IsShown() then
        if not mapEditbox then
            mapEditbox = CreateDirectEditBox(WorldMapFrame, "WowhadMapEditbox")
            mapEditbox:SetPoint("TOPRIGHT", WorldMapFrame, "BOTTOMRIGHT", -2, -2)
        end
        SetWowheadLink(mapEditbox, "quest", questID)
    elseif mapEditbox then
        mapEditbox:Hide()
    end
end

local function on_map_details_hide()
    if mapEditbox then mapEditbox:Hide() end
end

hooksecurefunc(QuestMapFrame.DetailsFrame, "Hide", on_map_details_hide)
hooksecurefunc("QuestMapFrame_ShowQuestDetails", UpdateMapLink)

-- 업적
local clickedAchievementBtn

local function on_achievement_click_timer()
    if clickedAchievementBtn then
        if not AchievementFrame:IsShown() or clickedAchievementBtn.collapsed then
            AchievementFrame.wowheadEditbox:Hide()
            AchievementFrame.lastAchiID = nil
        end
        clickedAchievementBtn = nil
    end
end

local function on_achievement_click(s)
    clickedAchievementBtn = s
    C_Timer.After(0.1, on_achievement_click_timer)
end

local function on_achievement_hide()
    if AchievementFrame.wowheadEditbox then
        AchievementFrame.wowheadEditbox:Hide()
    end
    AchievementFrame.lastAchiID = nil
end

local function on_achievement_tab_click()
    if AchievementFrame.wowheadEditbox then
        AchievementFrame.wowheadEditbox:Hide()
    end
    AchievementFrame.lastAchiID = nil
end

local function on_achievement_loaded()
    local achievementEditbox = CreateDirectEditBox(AchievementFrame, "WowheadAchievementEditbox")
    achievementEditbox:SetPoint("TOPRIGHT", AchievementFrame, "BOTTOMRIGHT", -2, -2)
    achievementEditbox:Hide()
    AchievementFrame.wowheadEditbox = achievementEditbox

    local function UpdateAchiLink(self, achievementID)
        if isInsideRestrictedInstance then
            achievementEditbox:Hide()
            return
        end

        local isEnabled = (dodoDB.useWowheadLink ~= false)
        local shouldShowLink = isEnabled and achievementID and achievementID ~= 0

        if shouldShowLink and achievementID == AchievementFrame.lastAchiID and achievementEditbox:IsShown() then return end
        AchievementFrame.lastAchiID = achievementID

        if shouldShowLink then
            SetWowheadLink(achievementEditbox, "achievement", achievementID)
        else
            achievementEditbox:Hide()
        end
    end

    hooksecurefunc(AchievementTemplateMixin, "DisplayObjectives", UpdateAchiLink)
    hooksecurefunc(AchievementTemplateMixin, "OnClick", on_achievement_click)

    AchievementFrame:HookScript("OnHide", on_achievement_hide)
    hooksecurefunc("AchievementFrameTab_OnClick", on_achievement_tab_click)
end

EventUtil.ContinueOnAddOnLoaded("Blizzard_AchievementUI", on_achievement_loaded)

-- 초기화 및 이벤트
local function on_instance_event(self, event)
    UpdateInstanceStatus()
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:SetScript("OnEvent", on_instance_event)

-- ==============================
-- 외부 노출 및 설정 동적 등록 (Option.lua 연동)
-- ==============================
local function WowheadLink()
    UpdateMapLink()
    if AchievementFrame and AchievementFrame:IsShown() and AchievementFrame.wowheadEditbox then
        -- 업적 창 표시 상태에서도 옵션 변경 반영
        if dodoDB.useWowheadLink == false then
            AchievementFrame.wowheadEditbox:Hide()
        end
    end
end

dodo.WowheadLink = WowheadLink

local SettingsPanel = SettingsPanel
local Checkbox = Checkbox

dodo.OptionRegistrations = dodo.OptionRegistrations or {}
dodo.OptionRegistrations["interface"] = dodo.OptionRegistrations["interface"] or {}
table.insert(dodo.OptionRegistrations["interface"], function(category)
    local layout = SettingsPanel:GetLayout(category)
    if not layout then return end

    Checkbox(category, "useWowheadLink", "와우헤드 링크", "지도, 업적프레임에 와우헤드 링크를 표시합니다.", true, dodo.WowheadLink)
end)
