------------------------------
-- 테이블
------------------------------
local addonName, ns = ...

------------------------------
-- 디스플레이
------------------------------
-- 아이템 링크
local DeleteItemLink = StaticPopup1:CreateFontString(nil, "OVERLAY", "GameFontNormalMed1")
DeleteItemLink:SetPoint("CENTER", StaticPopup1, "CENTER", 0, 10)
DeleteItemLink:Hide()

-- 안내 문구 제거
local localizedDeleteMsg = ""
do
    local _, secondPart = strsplit("@", gsub(DELETE_GOOD_ITEM, "[\r\n]", "@"), 2)
    localizedDeleteMsg = gsub(secondPart or "", "%%s", "")
    localizedDeleteMsg = gsub(localizedDeleteMsg, "@", "")
end

-- 자동 기입용 단어
local cachedDeleteWord = ""
do
    local rawText = gsub(DELETE_GOOD_ITEM, "[\r\n]", "")
    cachedDeleteWord = select(2, strsplit('"', rawText)) or "삭제"
end

------------------------------
-- 동작
------------------------------
local function isIns()
    local _, instanceType, difficultyID = GetInstanceInfo()
    return (difficultyID == 8 or instanceType == "raid")
end

local function DeleteNow()
    if isIns() then return end

    local db = hodoDB or {}
    local _, _, itemLink = GetCursorInfo()

    if not StaticPopup1 or not StaticPopup1EditBox then return end
    if not itemLink then return end
    SetCVar("alwaysCompareItems", 0)
    DeleteItemLink:Hide()
    DeleteItemLink:SetText("")

    if db.deleteNowHideEditbox then
        StaticPopup1EditBox:Hide()
        StaticPopup1Button1:Enable()
        DeleteItemLink:SetText(itemLink) -- 입력창 숨김 + 아이템링크 표시
        DeleteItemLink:Show()

        local currentText = StaticPopup1Text:GetText() or ""
        if localizedDeleteMsg ~= "" then
            StaticPopup1Text:SetText((gsub(currentText, localizedDeleteMsg, "")))
        end
    elseif db.deleteNowAutoFill then
        StaticPopup1EditBox:Show()
        StaticPopup1EditBox:SetText(cachedDeleteWord) -- 자동 입력
        StaticPopup1EditBox:SetFocus()
        StaticPopup1Button1:Enable()
    else
        return
    end

    GameTooltip:SetOwner(StaticPopup1, "ANCHOR_NONE")
    GameTooltip:SetPoint("TOP", StaticPopup1, "BOTTOM", 0, -5)
    GameTooltip:SetHyperlink(itemLink)
    GameTooltip:Show()
end

ns.DeleteNow = DeleteNow

------------------------------
-- 이벤트
------------------------------
local initDeleteNow = CreateFrame("Frame")
initDeleteNow:RegisterEvent("PLAYER_ENTERING_WORLD")
initDeleteNow:RegisterEvent("DELETE_ITEM_CONFIRM")
initDeleteNow:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_ENTERING_WORLD" then
        C_Timer.After(0.1, function ()
            if isIns() then
                initDeleteNow:UnregisterEvent("DELETE_ITEM_CONFIRM")
            else
                initDeleteNow:RegisterEvent("DELETE_ITEM_CONFIRM")
            end
        end)
    elseif event == "DELETE_ITEM_CONFIRM" then
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