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
local Checkbox = Checkbox
local CreateFrame = CreateFrame
local GameTooltip = GameTooltip
local GetCVar = GetCVar
local GetCursorInfo = GetCursorInfo
local SetCVar = SetCVar
local gsub = gsub
local hooksecurefunc = hooksecurefunc
local select = select
local strsplit = strsplit

local localized_delete_msg = ""
local original_always_compare = nil

-- 디스플레이 (UIParent 미생성 시점 에러 가드용 지연 생성 적용)
---@type FontString
local delete_item_link = nil

---@param parent Frame
---@return FontString
local function get_delete_item_link(parent)
    if not delete_item_link then
        delete_item_link = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalMed1")
    end
    return delete_item_link
end

do
    local DELETE_GOOD_ITEM = _G.DELETE_GOOD_ITEM
    local _, secondPart = strsplit("@", gsub(DELETE_GOOD_ITEM, "[\r\n]", "@"), 2)
    localized_delete_msg = gsub(secondPart or "", "%%s", "")
    localized_delete_msg = gsub(localized_delete_msg, "@", "")
end

-- ==============================
-- 동작
-- ==============================
local STATICPOPUP_NUMDIALOGS = _G.STATICPOPUP_NUMDIALOGS or 4

---@param self Frame
---@return nil
local function on_popup_show(self)
    if dodoDB and dodoDB.useDeleteNow == false then return end

    if self.which == "DELETE_GOOD_ITEM" or self.which == "DELETE_GOOD_QUEST_ITEM" or self.which == "DELETE_ITEM" then
        local _, _, itemLink = GetCursorInfo()

        local name = self:GetName()
        local editBox = self.editBox or (name and _G[name.."EditBox"])
        local button1 = self.button1 or (name and _G[name.."Button1"])
        local textObj = self.text or (name and _G[name.."Text"])

        if not editBox or not button1 or not textObj then return end

        local currentText = textObj:GetText() or ""
        local dynamicWord = select(2, strsplit('"', currentText)) or _G.DELETE_ITEM_CONFIRM_STRING or "삭제"

        editBox:Hide()
        editBox:SetText(dynamicWord)
        button1:Enable()

        local link_str = get_delete_item_link(self)
        link_str:SetParent(self)
        link_str:ClearAllPoints()
        link_str:SetPoint("CENTER", self, "CENTER", 0, 10)
        if itemLink then
            link_str:SetText(itemLink)
        else
            link_str:SetText("")
        end
        link_str:Show()

        if localized_delete_msg ~= "" then
            textObj:SetText((gsub(currentText, localized_delete_msg, "")))
        end

        if itemLink then
            GameTooltip:SetOwner(self, "ANCHOR_NONE")
            GameTooltip:SetPoint("TOP", self, "BOTTOM", 0, -5)
            GameTooltip:SetHyperlink(itemLink)
            GameTooltip:Show()

            if original_always_compare == nil then
                original_always_compare = GetCVar("alwaysCompareItems")
            end
            SetCVar("alwaysCompareItems", "0")

            self._eqolDeleteNowActive = true
        end
    end
end

---@param self Frame
---@return nil
local function on_popup_hide(self)
    if self._eqolDeleteNowActive then
        self._eqolDeleteNowActive = nil
        if original_always_compare then
            SetCVar("alwaysCompareItems", original_always_compare)
            original_always_compare = nil
        end
        if GameTooltip:GetOwner() == self then
            GameTooltip:Hide()
        end
        if delete_item_link then
            delete_item_link:SetText("")
            delete_item_link:Hide()
        end
    end
end

-- ==============================
-- 후킹 정적 이벤트 핸들러 (가비지 프리)
-- ==============================
---@param which string
---@return nil
local function on_static_popup_show(which)
    if dodoDB and dodoDB.useDeleteNow == false then return end

    if which == "DELETE_GOOD_ITEM" or which == "DELETE_GOOD_QUEST_ITEM" or which == "DELETE_ITEM" then
        for i = 1, STATICPOPUP_NUMDIALOGS do
            local dialog = _G["StaticPopup"..i]
            if dialog and dialog:IsShown() and dialog.which == which then
                on_popup_show(dialog)
            end
        end
    end
end

---@param self Frame
---@return nil
local function on_static_popup_hide(self)
    on_popup_hide(self)
end

-- ==============================
-- 초기화
-- ==============================
local hooked = false

---@param enable boolean
local function set_hooks(enable)
    if enable and not hooked then
        hooksecurefunc("StaticPopup_Show", on_static_popup_show)
        hooksecurefunc("StaticPopup_OnHide", on_static_popup_hide)
        hooked = true
    end
end

local function on_login_event(self)
    dodoDB = dodoDB or {}
    if dodoDB.useDeleteNow == nil then dodoDB.useDeleteNow = true end
    set_hooks(dodoDB.useDeleteNow)
    self:UnregisterEvent("PLAYER_LOGIN")
end

local init = CreateFrame("Frame")
init:RegisterEvent("PLAYER_LOGIN")
init:SetScript("OnEvent", on_login_event)

-- ==============================
-- 설정 등록
-- ==============================
dodo.OptionRegistrations = dodo.OptionRegistrations or {}
dodo.OptionRegistrations["인터페이스.편의기능"] = dodo.OptionRegistrations["인터페이스.편의기능"] or {}
table.insert(dodo.OptionRegistrations["인터페이스.편의기능"], function(category)
    Checkbox(category, "useDeleteNow", "아이템 파괴 간소화", "아이템 파괴 확인창에서 확인 입력 없이 즉시 삭제합니다.", true, function(value)
        set_hooks(value)
    end)
end)