------------------------------
-- 테이블
------------------------------
-- 아이템 링크
local DeleteItemLink = StaticPopup1:CreateFontString(nil, "OVERLAY", "GameFontNormalMed1")
DeleteItemLink:SetPoint("CENTER", StaticPopup1, "CENTER", 0, 10)

-- 자동기입
local function getDeleteText()
    local rawText = gsub(DELETE_GOOD_ITEM, "[\r\n]", "")
    local _, DeleteNowText = strsplit('"', rawText)
    return DeleteNowText or "삭제"
end

-- 안내 문구 제거
local TypeDeleteLine = gsub(DELETE_GOOD_ITEM, "[\r\n]", "@")
local _, DeleteNowLocalizeDeleteText = strsplit("@", TypeDeleteLine, 2)
DeleteNowLocalizeDeleteText = gsub(DeleteNowLocalizeDeleteText or "", "%%s", "")
DeleteNowLocalizeDeleteText = gsub(DeleteNowLocalizeDeleteText, "@", "")


------------------------------
-- 동작
------------------------------
function DeleteNow()
    local db = hodoDB or {}
    if not StaticPopup1 or not StaticPopup1EditBox then return end

    local _, _, itemLink = GetCursorInfo()
    if not itemLink then return end
    SetCVar("alwaysCompareItems", 0)

    if db.DeleteNowEditbox then -- 자동입력
        StaticPopup1EditBox:Show()
        StaticPopup1EditBox:SetText(getDeleteText())
        StaticPopup1EditBox:SetFocus()
        StaticPopup1Button1:Enable()
    else
        StaticPopup1EditBox:Hide() -- Editbox 숨김
        StaticPopup1Button1:Enable()

        DeleteItemLink:SetText(itemLink)
        DeleteItemLink:Show()

        local currentText = StaticPopup1Text:GetText() or ""
        if DeleteNowLocalizeDeleteText ~= "" then
            currentText = gsub(currentText, DeleteNowLocalizeDeleteText, "")
        end
    StaticPopup1Text:SetText(currentText)
    end

    if itemLink then
        GameTooltip:SetOwner(StaticPopup1, "ANCHOR_NONE")
        GameTooltip:SetPoint("TOP", StaticPopup1, "BOTTOM", 0, -5)
        GameTooltip:SetHyperlink(itemLink)
        GameTooltip:Show()
    end
end


------------------------------
-- 이벤트
------------------------------
local initDeleteNow = CreateFrame("Frame")
initDeleteNow:RegisterEvent("DELETE_ITEM_CONFIRM")
initDeleteNow:SetScript("OnEvent", function()
    hodoDB = hodoDB or {}
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