-- ==============================
-- Inspired
-- ==============================
-- EnhanceQoL (https://www.curseforge.com/wow/addons/eqol)
-- Leatrix Plus (https://www.curseforge.com/wow/addons/leatrix-plus)

-- ==============================
-- 설정 및 테이블
-- ==============================
---@diagnostic disable: lowercase-global, param-type-mismatch, redundant-parameter, undefined-field, undefined-global
local addonName, dodo = ...
local module = {}
dodo:RegisterModule("DeleteNow", module)

local originalAlwaysCompare = nil
local localizedDeleteMsg = nil

-- ==============================
-- 캐싱
-- ==============================
local CreateFrame = CreateFrame
local GameTooltip = GameTooltip
local GetCVar = GetCVar
local GetCursorInfo = GetCursorInfo
local SetCVar = SetCVar
local STATICPOPUP_NUMDIALOGS = _G.STATICPOPUP_NUMDIALOGS or 4
local gsub = gsub
local hooksecurefunc = hooksecurefunc
local select = select
local strsplit = strsplit

local dialogs = {}
for i = 1, STATICPOPUP_NUMDIALOGS do
    dialogs[i] = _G["StaticPopup"..i]
end

-- ==============================
-- 프레임 및 이벤트
-- ==============================
local DeleteItemLink = UIParent:CreateFontString(nil, "OVERLAY", "GameFontNormalMed1")
DeleteItemLink:Hide()

local function init_delete_msg()
    if localizedDeleteMsg then return end
    local DELETE_GOOD_ITEM = _G.DELETE_GOOD_ITEM or ""
    if DELETE_GOOD_ITEM ~= "" then
        local _, secondPart = strsplit("@", gsub(DELETE_GOOD_ITEM, "[\r\n]", "@"), 2)
        localizedDeleteMsg = gsub(secondPart or "", "%%s", "")
        localizedDeleteMsg = gsub(localizedDeleteMsg, "@", "")
    else
        localizedDeleteMsg = ""
    end
end

-- ==============================
-- 기능 1: 팝업 처리
-- ==============================
local function on_popup_show(self)
    if not dodo.DB then return end
    if dodo.DB.enableDeleteNowModule == false then return end

    init_delete_msg()

    if self.which == "DELETE_GOOD_ITEM" or self.which == "DELETE_GOOD_QUEST_ITEM" or self.which == "DELETE_ITEM" then
        local _, _, itemLink = GetCursorInfo()

        local name = self:GetName()
        local editBox = self.editBox or (name and _G[name.."EditBox"])
        local button1 = self.button1 or (name and _G[name.."Button1"])
        local textObj = self.text or (name and _G[name.."Text"])

        if not editBox or not button1 or not textObj then return end

        local currentText = textObj:GetText() or ""
        local dynamicWord = select(2, strsplit('"', currentText)) or _G.DELETE_ITEM_CONFIRM_STRING or "삭제"

        -- 에디트박스 숨김 처리 및 지금파괴(dynamicWord) 자동 기입
        editBox:Hide()
        editBox:SetText(dynamicWord)
        button1:Enable()

        -- 대상 아이템 링크 팝업 중앙에 표시
        DeleteItemLink:SetParent(self)
        DeleteItemLink:ClearAllPoints()
        DeleteItemLink:SetPoint("CENTER", self, "CENTER", 0, 10)
        if itemLink then
            DeleteItemLink:SetText(itemLink)
        else
            DeleteItemLink:SetText("")
        end
        DeleteItemLink:Show()

        if localizedDeleteMsg and localizedDeleteMsg ~= "" then
            textObj:SetText((gsub(currentText, localizedDeleteMsg, "")))
        end

        -- 팝업창 하단에 대상 아이템 툴팁 표시
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

local function on_popup_hide(self)
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
local function initialize()
    if dodo.DB and dodo.DB.enableDeleteNowModule == nil then
        dodo.DB.enableDeleteNowModule = false
    end
end

-- ==============================
-- 모듈 생명주기
-- ==============================
local isInitialized = false
function module:OnEnable()
    initialize()

    if isInitialized then return end
    isInitialized = true

    hooksecurefunc("StaticPopup_Show", function(which)
        if dodo.DB and dodo.DB.enableDeleteNowModule == false then return end
        if which == "DELETE_GOOD_ITEM" or which == "DELETE_GOOD_QUEST_ITEM" or which == "DELETE_ITEM" then
            for i = 1, STATICPOPUP_NUMDIALOGS do
                local dialog = dialogs[i]
                if dialog and dialog:IsShown() and dialog.which == which then
                    on_popup_show(dialog)
                end
            end
        end
    end)

    hooksecurefunc("StaticPopup_OnHide", function(self)
        on_popup_hide(self)
    end)

    -- dodoEditModePanel 내부에 2열 그리드로 세부 설정 주입
    if dodo.RegisterEditModeSetting then
        dodo.RegisterEditModeSetting("편의기능", {
            {
                name = "아이템 파괴 간소화",
                get = function() return dodo.DB and dodo.DB.enableDeleteNowModule or false end,
                set = function(checked)
                    if dodo.DB then 
                        dodo.DB.enableDeleteNowModule = checked 
                    end
                end
            }
        })
    end
end