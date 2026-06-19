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
local lib_icon = dodo.LibIcon

-- ==============================
-- 캐싱
-- ==============================
local C_Timer = C_Timer
local CreateFrame = CreateFrame
local EventUtil = EventUtil
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
local is_inside_restricted_instance = false
local function update_instance_status()
    local _, instanceType, difficultyID = GetInstanceInfo()
    -- 8: 쐐기, raid: 레이드
    is_inside_restricted_instance = (difficultyID == 8 or instanceType == "raid")
end

-- ==============================
-- 유틸리티
-- ==============================
local function set_wowhead_link(editbox, idType, id)
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
local function create_direct_edit_box(parent, name)
    local linkEditbox = CreateFrame("EditBox", name, parent, "InputBoxInstructionsTemplate")
    linkEditbox:SetSize(200, 18)
    linkEditbox:SetFontObject("GameFontHighlightSmall")
    linkEditbox:SetAutoFocus(false)
    linkEditbox:SetJustifyH("LEFT")
    linkEditbox:SetTextInsets(5, 5, 0, 0)

    -- 아이콘
    if lib_icon then
        local icon = lib_icon:Create(name .. "Icon", linkEditbox, { iconsize = { 20, 20 } })
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
local map_editbox
local last_map_quest_id
local function update_map_link()
    if is_inside_restricted_instance then
        if map_editbox then map_editbox:Hide() end
        return
    end

    local questID = QuestMapFrame_GetDetailQuestID()
    local is_enabled = (dodoDB.useWowheadLink ~= false)

    if questID == last_map_quest_id and map_editbox and map_editbox:IsShown() then return end
    last_map_quest_id = questID

    if is_enabled and questID and questID ~= 0 and QuestMapFrame.DetailsFrame:IsShown() then
        if not map_editbox then
            map_editbox = create_direct_edit_box(WorldMapFrame, "WowhadMapEditbox")
            map_editbox:SetPoint("TOPRIGHT", WorldMapFrame, "BOTTOMRIGHT", -2, -2)
        end
        set_wowhead_link(map_editbox, "quest", questID)
    elseif map_editbox then
        map_editbox:Hide()
    end
end

local function on_map_details_hide()
    if map_editbox then map_editbox:Hide() end
end

hooksecurefunc(QuestMapFrame.DetailsFrame, "Hide", on_map_details_hide)
hooksecurefunc("QuestMapFrame_ShowQuestDetails", update_map_link)

-- 업적
local clicked_achievement_btn

local function on_achievement_click_timer()
    if clicked_achievement_btn then
        if not AchievementFrame:IsShown() or clicked_achievement_btn.collapsed then
            AchievementFrame.wowheadEditbox:Hide()
            AchievementFrame.lastAchiID = nil
        end
        clicked_achievement_btn = nil
    end
end

local function on_achievement_click(s)
    clicked_achievement_btn = s
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
    local achievement_editbox = create_direct_edit_box(AchievementFrame, "WowheadAchievementEditbox")
    achievement_editbox:SetPoint("TOPRIGHT", AchievementFrame, "BOTTOMRIGHT", -2, -2)
    achievement_editbox:Hide()
    AchievementFrame.wowheadEditbox = achievement_editbox

    local function UpdateAchiLink(self, achievementID)
        if is_inside_restricted_instance then
            achievement_editbox:Hide()
            return
        end

        local is_enabled = (dodoDB.useWowheadLink ~= false)
        local shouldShowLink = is_enabled and achievementID and achievementID ~= 0

        if shouldShowLink and achievementID == AchievementFrame.lastAchiID and achievement_editbox:IsShown() then return end
        AchievementFrame.lastAchiID = achievementID

        if shouldShowLink then
            set_wowhead_link(achievement_editbox, "achievement", achievementID)
        else
            achievement_editbox:Hide()
        end
    end

    hooksecurefunc(AchievementTemplateMixin, "DisplayObjectives", UpdateAchiLink)
    hooksecurefunc(AchievementTemplateMixin, "OnClick", on_achievement_click)

    AchievementFrame:HookScript("OnHide", on_achievement_hide)
    hooksecurefunc("AchievementFrameTab_OnClick", on_achievement_tab_click)
end

EventUtil.ContinueOnAddOnLoaded("Blizzard_AchievementUI", on_achievement_loaded)

-- 초기화 및 이벤트
local main_frame = CreateFrame("Frame")

local function update_module_state()
    local is_enabled = (dodoDB.useWowheadLink ~= false)
    if is_enabled then
        main_frame:RegisterEvent("PLAYER_ENTERING_WORLD")
        update_instance_status()
    else
        main_frame:UnregisterAllEvents()
        if map_editbox then map_editbox:Hide() end
        if AchievementFrame and AchievementFrame.wowheadEditbox then
            AchievementFrame.wowheadEditbox:Hide()
        end
    end
end

main_frame:SetScript("OnEvent", update_instance_status)

-- ==============================
-- 외부 노출 및 설정 동적 등록 (RegisterEditModeModuleSetting 이관)
-- ==============================
local function WowheadLink()
    update_module_state()
    update_map_link()
end

dodo.WowheadLink = WowheadLink

-- 로그인 대기
local init_frame = CreateFrame("Frame")
init_frame:RegisterEvent("PLAYER_LOGIN")
init_frame:SetScript("OnEvent", function(self, event)
    if dodoDB.useWowheadLink == nil then dodoDB.useWowheadLink = true end
    update_module_state()
    self:UnregisterAllEvents()
end)

if dodo.RegisterEditModeModuleSetting then
    dodo.RegisterEditModeModuleSetting("편의기능", {
        {
            name = "와우헤드 링크",
            get = function() return dodoDB and dodoDB.useWowheadLink ~= false end,
            set = function(checked)
                if dodoDB then dodoDB.useWowheadLink = checked end
                WowheadLink()
            end
        }
    })
end
