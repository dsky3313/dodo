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
local function DeleteNow()
    local _, instanceType = GetInstanceInfo()
    if instanceType ~= "none" then return end

    local db = hodoDB or {}
    if not StaticPopup1 or not StaticPopup1EditBox then return end

    local _, _, itemLink = GetCursorInfo()
    if not itemLink then return end

    SetCVar("alwaysCompareItems", 0)
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
local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:SetScript("OnEvent", function(self)
    hodoDB = hodoDB or {}
    if hodoCreateOptions then hodoCreateOptions() end
    self:UnregisterAllEvents()
end)

local eventDeleteNow = CreateFrame("Frame")
eventDeleteNow:RegisterEvent("DELETE_ITEM_CONFIRM")
eventDeleteNow:SetScript("OnEvent", function()
    C_Timer.After(0.1, DeleteNow)
end)

hooksecurefunc("StaticPopup_OnHide", function()
    if GameTooltip then GameTooltip:Hide() end
    if DeleteItemLink then
        DeleteItemLink:SetText("")
        DeleteItemLink:Hide()
    end
    SetCVar("alwaysCompareItems", 1)
end)