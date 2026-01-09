------------------------------
-- 체크박스 위젯 (통합본)
------------------------------
function Checkbox(category, varName, label, tooltip, default)
    local varID = "hodo_" .. varName

    local setting = Settings.GetSetting(varID)
    if not setting then
        setting = Settings.RegisterAddOnSetting(category, varID, varName, hodoDB, Settings.VarType.Boolean, label, default)
    end

    local initializer = Settings.CreateControlInitializer("SettingsCheckboxControlTemplate", setting, nil, tooltip)
    setting:SetValueChangedCallback(function()
        if AuctionFilter then AuctionFilter() end
        if DeleteNow then DeleteNow() end
        if MykeyUpdate then MykeyUpdate() end
        if MyPartyStatusBG and MyPartyStatusBG:GetScript("OnEvent") then
            MyPartyStatusBG:GetScript("OnEvent")(MyPartyStatusBG, "HODO_OPTION_CHANGED")
        end
    end)

    local layout = SettingsPanel:GetLayout(category)
    if layout then
        layout:AddInitializer(initializer)
    end
    return setting, initializer
end