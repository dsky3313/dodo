------------------------------
-- 테이블
------------------------------
local addonName, dodo = ...

------------------------------
-- 체크박스
------------------------------
function Checkbox(category, varName, label, tooltip, default, func)
    local varID = "dodo_" .. varName

    local setting = Settings.GetSetting(varID)
    if not setting then
        setting = Settings.RegisterAddOnSetting(category, varID, varName, dodoDB, Settings.VarType.Boolean, label, default)
    end

    local initializer = Settings.CreateControlInitializer("dodoCheckboxTemplate", setting, nil, tooltip)

    setting:SetValueChangedCallback(function()
        if type(func) == "function" then
            func()
        end
    end)

    local layout = SettingsPanel:GetLayout(category)
    if layout then
        layout:AddInitializer(initializer)
    end

    return setting, initializer
end