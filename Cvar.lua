local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")

frame:SetScript("OnEvent", function(self, event, ...)
    SetCVar("nameplateUseClassColorForFriendlyPlayerUnitNames", 1)
    SetCVar("nameplateShowOnlyNameForFriendlyPlayerUnits", 1)
    
    print("|cff00ff00[설정 자동화]|r 아군 이름표 설정이 적용되었습니다.")
end)