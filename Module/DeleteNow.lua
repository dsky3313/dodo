-- ==============================
-- Inspired
-- ==============================
-- Leatrix Plus (https://www.curseforge.com/wow/addons/leatrix-plus)
-- EnhanceQoL

-- ==============================
-- 설정 및 테이블
-- ==============================
---@diagnostic disable: lowercase-global, undefined-field, undefined-global
local addonName, dodo = ...
dodoDB = dodoDB or {}

-- ==============================
-- 캐싱
-- ==============================
local CreateFrame = CreateFrame
local GetCursorInfo = GetCursorInfo
local SetCVar = SetCVar
local GetCVar = GetCVar
local gsub = gsub
local hooksecurefunc = hooksecurefunc
local select = select
local strsplit = strsplit
local GameTooltip = GameTooltip

local localizedDeleteMsg = ""
local originalAlwaysCompare = nil

-- ==============================
-- 디스플레이
-- ==============================
local DeleteItemLink = UIParent:CreateFontString(nil, "OVERLAY", "GameFontNormalMed1")
DeleteItemLink:Hide()

do
    local DELETE_GOOD_ITEM = _G.DELETE_GOOD_ITEM
    local _, secondPart = strsplit("@", gsub(DELETE_GOOD_ITEM, "[\r\n]", "@"), 2)
    localizedDeleteMsg = gsub(secondPart or "", "%%s", "")
    localizedDeleteMsg = gsub(localizedDeleteMsg, "@", "")
end

-- ==============================
-- 동작
-- ==============================
local function OnPopupShow(self)
    if not dodoDB then return end
    if dodoDB.deleteNowHideEditbox == false and dodoDB.deleteNowAutoFill == false then return end

    if self.which == "DELETE_GOOD_ITEM" or self.which == "DELETE_GOOD_QUEST_ITEM" or self.which == "DELETE_ITEM" then
        local _, _, itemLink = GetCursorInfo()

        local editBox = self.editBox or _G[self:GetName() and (self:GetName().."EditBox")]
        local button1 = self.button1 or _G[self:GetName() and (self:GetName().."Button1")]
        local textObj = self.text or _G[self:GetName() and (self:GetName().."Text")]

        if not editBox or not button1 or not textObj then return end

        local currentText = textObj:GetText() or ""
        local dynamicWord = select(2, strsplit('"', currentText)) or _G.DELETE_ITEM_CONFIRM_STRING or "삭제"

        if dodoDB.deleteNowHideEditbox then
            editBox:Hide()
            button1:Enable()

            DeleteItemLink:SetParent(self)
            DeleteItemLink:ClearAllPoints()
            DeleteItemLink:SetPoint("CENTER", self, "CENTER", 0, 10)
            if itemLink then
                DeleteItemLink:SetText(itemLink)
            else
                DeleteItemLink:SetText("")
            end
            DeleteItemLink:Show()

            if localizedDeleteMsg ~= "" then
                textObj:SetText((gsub(currentText, localizedDeleteMsg, "")))
            end
        elseif dodoDB.deleteNowAutoFill then
            editBox:Show()
            editBox:SetText(dynamicWord)
            editBox:SetFocus()
            button1:Enable()
        end

        if itemLink then
            GameTooltip:SetOwner(self, "ANCHOR_NONE")
            GameTooltip:SetPoint("TOP", self, "BOTTOM", 0, -5)
            GameTooltip:SetHyperlink(itemLink)
            GameTooltip:Show()

            if originalAlwaysCompare == nil then
                originalAlwaysCompare = GetCVar("alwaysCompareItems")
            end
            SetCVar("alwaysCompareItems", "0")

            self._eqolDeleteNowActive = true
        end
    end
end

local function OnPopupHide(self)
    if self._eqolDeleteNowActive then
        self._eqolDeleteNowActive = nil
        if originalAlwaysCompare then
            SetCVar("alwaysCompareItems", originalAlwaysCompare)
            originalAlwaysCompare = nil
        end
        if GameTooltip:GetOwner() == self then
            GameTooltip:Hide()
        end
        DeleteItemLink:SetText("")
        DeleteItemLink:Hide()
    end
end

-- ==============================
-- 초기화
-- ==============================
hooksecurefunc("StaticPopup_Show", function(which)
    if which == "DELETE_GOOD_ITEM" or which == "DELETE_GOOD_QUEST_ITEM" or which == "DELETE_ITEM" then
        local dialog = StaticPopup_Visible(which)
        if dialog then
            OnPopupShow(dialog)
        end
    end
end)

hooksecurefunc("StaticPopup_OnHide", function(self)
    OnPopupHide(self)
end)

-- ==============================
-- 외부 노출 (Option.lua용)
-- ==============================
dodo.DeleteNow = function() end -- 옵션창 콜백용 더미 함수