------------------------------
-- 테이블
------------------------------
local addonName, dodo = ...
dodoDB = dodoDB or {}
local Lib = dodo.IconLib

local function isIns() -- 인스확인
    local _, instanceType, difficultyID = GetInstanceInfo()
    return (difficultyID == 8 or instanceType == "raid") -- 1 일반 / 8 쐐기
end

local BobberConfig = {
    isAction = true,
    type = "item",
    -- macrotext = "/cast 낚시\n/use 13",
    id = 202207,
    icon = nil,
    iconsize = {34, 34},
    iconposition = {"TOPLEFT", "SecondaryProfession2", "TOPLEFT", 250, -7},
    label = "낚시찌",
    fontsize = 12,
    fontposition = {"BOTTOMRIGHT", "self", "BOTTOMLEFT", -2, 2},
    cooldownSize = 12,
    outline = false,
    framestrata = "HIGH",
}

------------------------------
-- 디스플레이
------------------------------
local BobberButton = Lib:Create("quickBobber", UIParent, BobberConfig)
BobberButton:Hide()

local function quickBobber()
    local isEnabled = (dodoDB and dodoDB.useQuickBobber ~= false)

    if isEnabled and not isIns() and (ProfessionsBookFrame and ProfessionsBookFrame:IsShown()) then

        BobberButton:RegisterEvent("BAG_UPDATE_DELAYED")
        BobberButton:RegisterEvent("BAG_UPDATE_COOLDOWN")
        BobberButton:RegisterEvent("ACTIONBAR_UPDATE_COOLDOWN")
        BobberButton:RegisterEvent("SPELL_UPDATE_COOLDOWN")
        BobberButton:ApplyConfig(BobberConfig)
        BobberButton:Show()
    else
        BobberButton:UnregisterAllEvents()
        BobberButton:Hide()
    end
end

------------------------------
-- 이벤트
------------------------------
local initQuickBobber = CreateFrame("Frame")
initQuickBobber:RegisterEvent("ADDON_LOADED")
initQuickBobber:RegisterEvent("PLAYER_ENTERING_WORLD")

initQuickBobber:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == "Blizzard_ProfessionsBook" then
        ProfessionsBookFrame:HookScript("OnShow", quickBobber)
        ProfessionsBookFrame:HookScript("OnHide", quickBobber)
    elseif event == "PLAYER_ENTERING_WORLD" then
        quickBobber()
    end
end)

if ProfessionsBookFrame then
    ProfessionsBookFrame:HookScript("OnShow", quickBobber)
    ProfessionsBookFrame:HookScript("OnHide", quickBobber)
end