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
local GetCursorInfo = GetCursorInfo
local GetInstanceInfo = GetInstanceInfo
local SetCVar = SetCVar
local gsub = gsub
local hooksecurefunc = hooksecurefunc
local select = select
local strsplit = strsplit

-- 변수
local C_Timer = C_Timer
local DELETE_GOOD_ITEM = DELETE_GOOD_ITEM
local GameTooltip = GameTooltip
local StaticPopup1 = StaticPopup1
local StaticPopup1Button1 = StaticPopup1Button1
local StaticPopup1EditBox = StaticPopup1EditBox
local StaticPopup1Text = StaticPopup1Text
local cachedDeleteWord = ""
local localizedDeleteMsg = ""

-- ==============================
-- 디스플레이
-- ==============================
local DeleteItemLink = StaticPopup1:CreateFontString(nil, "OVERLAY", "GameFontNormalMed1") -- 아이템 링크
DeleteItemLink:SetPoint("CENTER", StaticPopup1, "CENTER", 0, 10)
DeleteItemLink:Hide()

do
    local _, secondPart = strsplit("@", gsub(DELETE_GOOD_ITEM, "[\r\n]", "@"), 2)
    localizedDeleteMsg = gsub(secondPart or "", "%%s", "")
    localizedDeleteMsg = gsub(localizedDeleteMsg, "@", "")
    local rawText = gsub(DELETE_GOOD_ITEM, "[\r\n]", "")
    cachedDeleteWord = select(2, strsplit('"', rawText)) or "삭제"
end

-- ==============================
-- 동작
-- ==============================
local function DeleteNow()
    if not dodoDB then return end

    local _, _, itemLink = GetCursorInfo()
    if not StaticPopup1 or not StaticPopup1EditBox then return end
    if not itemLink then return end
    SetCVar("alwaysCompareItems", 0)
    DeleteItemLink:Hide()
    DeleteItemLink:SetText("")

    if dodoDB.deleteNowHideEditbox then
        StaticPopup1EditBox:Hide()
        StaticPopup1Button1:Enable()
        DeleteItemLink:SetText(itemLink) -- 입력창 숨김 + 아이템링크 표시
        DeleteItemLink:Show()
        -- print("|cff00ff00[dodo]|r 아이템파괴 + 아이템링크 표시") -- 디버깅

        local currentText = StaticPopup1Text:GetText() or ""
        if localizedDeleteMsg ~= "" then
            StaticPopup1Text:SetText((gsub(currentText, localizedDeleteMsg, "")))
        end
    elseif dodoDB.deleteNowAutoFill then
        StaticPopup1EditBox:Show()
        StaticPopup1EditBox:SetText(cachedDeleteWord) -- 자동 입력
        StaticPopup1EditBox:SetFocus()
        StaticPopup1Button1:Enable()
        -- print("|cff00ff00[dodo]|r 아이템파괴 자동입력") -- 디버깅
    else
        return
    end

    GameTooltip:SetOwner(StaticPopup1, "ANCHOR_NONE")
    GameTooltip:SetPoint("TOP", StaticPopup1, "BOTTOM", 0, -5)
    GameTooltip:SetHyperlink(itemLink)
    GameTooltip:Show()
end

-- ==============================
-- 이벤트
-- ==============================
local initDeleteNow = CreateFrame("Frame")
initDeleteNow:RegisterEvent("DELETE_ITEM_CONFIRM")
initDeleteNow:SetScript("OnEvent", function(self, event)
    if event == "DELETE_ITEM_CONFIRM" then
        C_Timer.After(0.1, DeleteNow)
    end
end)

hooksecurefunc("StaticPopup_OnHide", function(self)
    if self == StaticPopup1 then
        if GameTooltip then GameTooltip:Hide() end
        if DeleteItemLink then
            DeleteItemLink:SetText("")
            DeleteItemLink:Hide()
        end
        SetCVar("alwaysCompareItems", 1)
    end
end)

-- ==============================
-- 외부 노출 (Option.lua용)
-- ==============================
dodo.DeleteNow = DeleteNow