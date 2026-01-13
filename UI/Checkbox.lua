------------------------------
-- 테이블
------------------------------
local addonName, ns = ...

------------------------------
-- 체크박스
------------------------------
function Checkbox(category, varName, label, tooltip, default)
    local varID = "hodo_" .. varName

    local setting = Settings.GetSetting(varID)
    if not setting then
        setting = Settings.RegisterAddOnSetting(category, varID, varName, hodoDB, Settings.VarType.Boolean, label, default)
    end

    local initializer = Settings.CreateControlInitializer("hodoCheckboxTemplate", setting, nil, tooltip)
    setting:SetValueChangedCallback(function()

        if ns.AuctionFilter then ns.AuctionFilter() end
        if ns.DeleteNow then ns.DeleteNow() end
        if ns.Mykey then ns.Mykey() end
        if ns.PartyClass then ns.PartyClass() end

    end)

    -- 레이아웃에 추가
    local layout = SettingsPanel:GetLayout(category)
    if layout then
        layout:AddInitializer(initializer)
    end

    return setting, initializer
end